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

enum BalanceAction { cancel, goalUpdated, budget }

/// What the user did with a balance read from a screenshot, which of its
/// balances (pockets) they picked, and whether it should also be recorded
/// as money in ("Saldo awal").
class BalanceChoice {
  final BalanceAction action;
  final BalanceLine line;
  final bool recordIncome;
  final String? goalName;
  const BalanceChoice(
    this.action,
    this.line, {
    this.recordIncome = false,
    this.goalName,
  });
}

/// The balance read from a bank screen. The user picks the balance (when
/// the screen has pockets) and where it goes: a Budget (the caller asks
/// which category) or a goal, whose balance is set to it right here. With
/// [allowBudget] false only the goal update is offered. "Also record as
/// income" starts as [incomeDefault] says for the picked pocket. A balance
/// is never recorded as spending.
Future<BalanceChoice> showBalanceDialog(
  BuildContext context,
  WidgetRef ref,
  BalanceReading reading, {
  SavingModel? preselect,
  bool allowBudget = true,
  bool Function(BalanceLine line)? incomeDefault,
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
  var line = pocketFor(chosen);
  var pickedPocket = false;
  // Follows the pocket (off when it was already recorded this month) until
  // the user ticks or unticks it.
  var recordIncome = incomeDefault?.call(line) ?? true;
  var touchedIncome = false;
  void showPocket(BalanceLine l) {
    line = l;
    if (!touchedIncome) recordIncome = incomeDefault?.call(l) ?? true;
  }

  final cancelled = BalanceChoice(BalanceAction.cancel, line);
  if (!allowBudget && goals.isEmpty) return cancelled;

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
                if (reading.lines.length > 1) ...[
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
                            showPocket(l);
                            pickedPocket = true;
                          }),
                        ),
                    ],
                  ),
                ],
                if (goals.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    isId ? 'Tabungan:' : 'Savings:',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  RadioGroup<SavingModel>(
                    groupValue: chosen,
                    onChanged: (g) => setState(() {
                      chosen = g ?? chosen;
                      if (!pickedPocket) showPocket(pocketFor(chosen));
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
                if (allowBudget)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: recordIncome,
                    onChanged: (v) => setState(() {
                      recordIncome = v ?? false;
                      touchedIncome = true;
                    }),
                    title: Text(
                      isId
                          ? 'Catat juga sebagai pemasukan (Saldo awal)'
                          : 'Also record as income (Saldo awal)',
                    ),
                    subtitle: Text(
                      isId
                          ? 'Matikan kalau ini cuma update saldo.'
                          : 'Turn off for a balance update.',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, BalanceAction.cancel),
              child: Text(isId ? 'Batal' : 'Cancel'),
            ),
            if (goals.isNotEmpty && allowBudget)
              TextButton(
                onPressed: () => Navigator.pop(ctx, BalanceAction.goalUpdated),
                child: Text(isId ? 'Tabungan' : 'Savings'),
              )
            else if (goals.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, BalanceAction.goalUpdated),
                child: Text(isId ? 'Perbarui saldo' : 'Update balance'),
              ),
            if (allowBudget)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, BalanceAction.budget),
                child: const Text('Budget'),
              ),
          ],
        );
      },
    ),
  );
  if (action == null || action == BalanceAction.cancel) {
    return BalanceChoice(BalanceAction.cancel, line);
  }
  final income = allowBudget && recordIncome;
  if (action == BalanceAction.budget) {
    return BalanceChoice(BalanceAction.budget, line, recordIncome: income);
  }
  final goal = chosen;
  if (goal == null || !context.mounted) return cancelled;
  final saved = await _setGoalBalance(
    context,
    ref,
    goal,
    line.amount,
    isId: isId,
  );
  // A goal that could not be saved records no income either.
  if (!saved) return BalanceChoice(BalanceAction.cancel, line);
  return BalanceChoice(
    BalanceAction.goalUpdated,
    line,
    recordIncome: income,
    goalName: goal.name,
  );
}

/// Only the goal's balance changes; nothing is recorded as spending.
/// Returns whether it was saved.
Future<bool> _setGoalBalance(
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
    return true;
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
    return false;
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
    allowBudget: false,
  );
}
