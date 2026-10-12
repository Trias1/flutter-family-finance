import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/balance_parser.dart';
import 'package:family_finance_manager/core/services/receipt_parser.dart';
import 'package:family_finance_manager/core/services/receipt_scanner.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/savings/presentation/providers/saving_provider.dart';

/// Goals a bank balance can be written to (gold is tracked in grams).
List<SavingModel> _cashGoals(WidgetRef ref) {
  final scope = ref.read(financeScopeIdProvider);
  final goals = ref.read(savingStreamProvider(scope)).valueOrNull ?? const [];
  return goals.where((g) => !g.isGoldInvestment).toList();
}

/// Whether [goal] is kept at [bank] ("Bank Neo Commerce" ~ "Bank Neo").
bool goalAtBank(SavingModel goal, String? bank) {
  if (bank == null || goal.bankName == null) return false;
  return ReceiptParser.bankIn(goal.bankName!) == bank;
}

enum BalanceAction { cancel, goalUpdated, income }

/// What the user did with a balance read from a screenshot, and which of
/// its balances (pockets) they picked.
class BalanceChoice {
  final BalanceAction action;
  final BalanceLine line;
  const BalanceChoice(this.action, this.line);
}

/// The balance read from a bank screen. The user picks the balance (when
/// the screen has pockets) and either records it as money in or sets a
/// goal's balance to it; with [allowIncome] false only the goal update is
/// offered. A balance is never recorded as spending.
Future<BalanceChoice> showBalanceDialog(
  BuildContext context,
  WidgetRef ref,
  BalanceReading reading, {
  SavingModel? preselect,
  BalanceLine? fixedLine,
  bool allowIncome = true,
}) async {
  final isId = ref.read(localeProvider).languageCode == 'id';
  final goals = _cashGoals(ref);
  final atBank = goals.where((g) => goalAtBank(g, reading.bank)).toList();
  final ordered = [...atBank, ...goals.where((g) => !atBank.contains(g))];
  SavingModel? chosen =
      preselect ??
      (atBank.length == 1 ? atBank.first : null) ??
      (ordered.isEmpty ? null : ordered.first);
  // Screens with pockets (Neo: total, Tabungan Neo, Neo NOW) show each one;
  // the pocket named in the goal is picked until the user picks another.
  BalanceLine pocketFor(SavingModel? g) =>
      (g == null ? null : reading.lineFor(g.name)) ?? reading.lines.first;
  var line = fixedLine ?? pocketFor(chosen);
  var pickedPocket = fixedLine != null;
  final cancelled = BalanceChoice(BalanceAction.cancel, line);
  if (!allowIncome && goals.isEmpty) return cancelled;

  final action = await showDialog<BalanceAction>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
        return AlertDialog(
          title: Text(
            reading.bank == null
                ? (isId ? 'Saldo terbaca' : 'Balance read')
                : (isId ? 'Saldo ${reading.bank}' : '${reading.bank} balance'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.format(line.amount),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (reading.lines.length > 1 && fixedLine == null) ...[
                  const SizedBox(height: 10),
                  Text(
                    isId ? 'Saldo yang mana?' : 'Which balance?',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final l in reading.lines)
                        ChoiceChip(
                          label: Text(
                            '${l.label} · ${CurrencyFormatter.format(l.amount)}',
                          ),
                          selected: identical(l, line),
                          onSelected: (_) => setState(() {
                            line = l;
                            pickedPocket = true;
                          }),
                        ),
                    ],
                  ),
                ],
                if (allowIncome) ...[
                  const SizedBox(height: 10),
                  Text(
                    isId
                        ? 'Catat pemasukan: masuk sebagai "Saldo awal", lalu pilih untuk apa (Tabungan, Transport, Makan...).'
                        : 'Record as income: saved as "Saldo awal"; then pick what it is for.',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
                if (goals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    isId
                        ? 'Atau jadikan saldo goal (tidak dicatat sebagai transaksi):'
                        : 'Or set a goal balance (no transaction recorded):',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  RadioGroup<SavingModel>(
                    groupValue: chosen,
                    onChanged: (g) => setState(() {
                      chosen = g ?? chosen;
                      if (!pickedPocket) line = pocketFor(chosen);
                    }),
                    child: Column(
                      children: [
                        for (final g in ordered)
                          RadioListTile<SavingModel>(
                            contentPadding: EdgeInsets.zero,
                            value: g,
                            title: Text(g.name),
                            subtitle: Text(
                              [
                                if (g.bankName != null) g.bankName!,
                                '${isId ? 'sekarang' : 'now'} ${CurrencyFormatter.format(g.currentAmount)}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, BalanceAction.cancel),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            if (goals.isNotEmpty && allowIncome)
              TextButton(
                onPressed: () => Navigator.pop(ctx, BalanceAction.goalUpdated),
                child: Text(isId ? 'Perbarui goal' : 'Update goal'),
              )
            else if (goals.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, BalanceAction.goalUpdated),
                child: Text(isId ? 'Perbarui saldo' : 'Update balance'),
              ),
            if (allowIncome)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, BalanceAction.income),
                child: Text(isId ? 'Catat pemasukan' : 'Record income'),
              ),
          ],
        );
      },
    ),
  );
  if (action == null || action == BalanceAction.cancel) {
    return BalanceChoice(BalanceAction.cancel, line);
  }
  if (action == BalanceAction.income) {
    return BalanceChoice(BalanceAction.income, line);
  }
  final goal = chosen;
  if (goal == null || !context.mounted) return cancelled;
  await _setGoalBalance(context, ref, goal, line.amount, isId: isId);
  return BalanceChoice(BalanceAction.goalUpdated, line);
}

/// After a balance was recorded as income "Untuk Tabungan": offer to set a
/// goal's balance to the same amount.
Future<void> offerGoalForSavings(
  BuildContext context,
  WidgetRef ref,
  BalanceReading reading,
  BalanceLine line,
) => showBalanceDialog(
  context,
  ref,
  reading,
  fixedLine: line,
  allowIncome: false,
);

/// Only the goal's balance changes; nothing is recorded as spending.
Future<void> _setGoalBalance(
  BuildContext context,
  WidgetRef ref,
  SavingModel goal,
  double amount, {
  required bool isId,
}) async {
  try {
    await ref
        .read(savingRepositoryProvider)
        .updateSaving(
          goal.copyWith(currentAmount: amount, balanceSyncedAt: DateTime.now()),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isId
                ? 'Saldo ${goal.name} jadi ${CurrencyFormatter.format(amount)}.'
                : '${goal.name} balance set to ${CurrencyFormatter.format(amount)}.',
          ),
          backgroundColor: AppTheme.incomeColor,
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isId
                ? 'Saldo gagal disimpan. Cek koneksi lalu coba lagi.'
                : "Couldn't save the balance. Check your connection.",
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

/// "Update balance from screenshot" on a goal: pick the bank app's account
/// screen and read its balance.
Future<void> syncGoalFromScreenshot(
  BuildContext context,
  WidgetRef ref,
  SavingModel goal,
) async {
  final isId = ref.read(localeProvider).languageCode == 'id';
  final messenger = ScaffoldMessenger.of(context);
  ScanResult? scan;
  try {
    scan = await ReceiptScanner.pickAndRead(fromCamera: false);
  } catch (_) {
    scan = null;
  }
  if (scan == null || !context.mounted) return;
  final reading = BalanceParser.parse(scan.text);
  if (reading == null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          isId
              ? 'Saldo tidak terbaca. Pakai screenshot halaman saldo/rekening dengan nominal terlihat.'
              : "Couldn't read a balance. Use a screenshot of the account screen with the amount showing.",
        ),
      ),
    );
    return;
  }
  await showBalanceDialog(
    context,
    ref,
    reading,
    preselect: goal,
    allowIncome: false,
  );
}
