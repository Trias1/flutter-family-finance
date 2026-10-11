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

/// Asks which goal the balance belongs to (the one at the same bank first)
/// and sets that goal's balance. Returns false when the user says this is
/// not a savings balance, so a scan can go on to the transaction flows.
/// Only the goal's balance changes; nothing is recorded as spending.
Future<bool> offerBalanceUpdate(
  BuildContext context,
  WidgetRef ref,
  BalanceReading reading, {
  SavingModel? preselect,
}) async {
  final isId = ref.read(localeProvider).languageCode == 'id';
  final goals = _cashGoals(ref);
  if (goals.isEmpty) return false;
  final atBank = goals.where((g) => goalAtBank(g, reading.bank)).toList();
  final ordered = [...atBank, ...goals.where((g) => !atBank.contains(g))];
  var chosen =
      preselect ?? (atBank.length == 1 ? atBank.first : null) ?? ordered.first;

  final result = await showDialog<SavingModel?>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
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
                CurrencyFormatter.format(reading.amount),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isId
                    ? 'Jadikan saldo goal ini? Hanya angka saldonya yang berubah, tidak dicatat sebagai pengeluaran.'
                    : 'Use this as the goal balance? Only the balance changes; nothing is recorded as spending.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              RadioGroup<SavingModel>(
                groupValue: chosen,
                onChanged: (g) => setState(() => chosen = g ?? chosen),
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isId ? 'Bukan saldo tabungan' : 'Not a savings balance',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, chosen),
            child: Text(isId ? 'Perbarui saldo' : 'Update balance'),
          ),
        ],
      ),
    ),
  );
  if (result == null) return false;
  try {
    await ref
        .read(savingRepositoryProvider)
        .updateSaving(
          result.copyWith(
            currentAmount: reading.amount,
            balanceSyncedAt: DateTime.now(),
          ),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isId
                ? 'Saldo ${result.name} jadi ${CurrencyFormatter.format(reading.amount)}.'
                : '${result.name} balance set to ${CurrencyFormatter.format(reading.amount)}.',
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
  return true;
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
  await offerBalanceUpdate(context, ref, reading, preselect: goal);
}
