import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/opening_balance.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/providers/budget_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';

/// Puts a balance into this month's budget of a category the user picks.
/// An existing budget asks: replace with the balance, or type a new amount.
/// Returns the category, or null when nothing was saved.
Future<String?> allocateToBudget(
  BuildContext context,
  WidgetRef ref,
  double amount,
) async {
  final isId = ref.read(localeProvider).languageCode == 'id';
  final familyId = ref.read(financeScopeIdProvider);
  final categories = ref
      .read(effectiveExpenseCategoriesProvider(familyId))
      .where((c) => !BudgetRepository.isSavingsCategory(c) && c != 'Lainnya')
      .toList();
  final category = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                isId
                    ? 'Budget untuk ${CurrencyFormatter.format(amount)}'
                    : 'Budget for ${CurrencyFormatter.format(amount)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final c in categories)
              ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c)),
          ],
        ),
      ),
    ),
  );
  if (category == null || !context.mounted) return null;

  final repo = ref.read(budgetRepositoryProvider);
  final month = BudgetRepository.monthKey(DateTime.now());
  final existing = (await repo.getBudgetsByMonth(
    familyId,
    month,
  )).where((b) => b.category == category).firstOrNull;
  var newAmount = amount;
  if (existing != null) {
    if (!context.mounted) return null;
    final picked = await _askReplaceOrUpdate(
      context,
      isId,
      category,
      existing.budgetAmount,
      amount,
    );
    if (picked == null) return null; // cancelled: nothing saved
    newAmount = picked;
  }
  final spent = existing == null
      ? await repo.spentInMonth(familyId, category, month)
      : 0.0;
  final model = budgetFromBalance(
    existing: existing,
    familyId: familyId,
    category: category,
    month: month,
    amount: newAmount,
    spent: spent,
  );
  final notifier = ref.read(budgetNotifierProvider.notifier);
  if (existing == null) {
    await notifier.setBudget(model);
  } else {
    await notifier.updateBudget(model);
  }
  final failed = ref.read(budgetNotifierProvider).hasError;
  ref.invalidate(budgetsByMonthProvider(familyId));
  ref.invalidate(dashboardProvider);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed
              ? (isId
                    ? 'Budget gagal disimpan. Cek koneksi lalu coba lagi.'
                    : "Couldn't save the budget. Check your connection.")
              : (isId
                    ? 'Budget $category jadi ${CurrencyFormatter.format(newAmount)}.'
                    : '$category budget set to ${CurrencyFormatter.format(newAmount)}.'),
        ),
        backgroundColor: failed ? AppTheme.errorColor : AppTheme.incomeColor,
      ),
    );
  }
  // Nothing saved: no "Saldo awal" income for it either.
  return failed ? null : category;
}

/// "Ganti ke saldo sekarang" returns [balance]; "Update nominal" returns the
/// typed amount; cancel returns null.
Future<double?> _askReplaceOrUpdate(
  BuildContext context,
  bool isId,
  String category,
  double current,
  double balance,
) {
  final ctrl = TextEditingController(text: current.toStringAsFixed(0));
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        isId ? 'Budget $category sudah ada' : '$category budget exists',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isId
                ? 'Sekarang ${CurrencyFormatter.format(current)}. Ganti ke saldo sekarang, atau isi nominal baru:'
                : 'Now ${CurrencyFormatter.format(current)}. Replace with the balance, or type a new amount:',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixText: '${CurrencyFormatter.currentCurrency.symbol} ',
              labelText: isId ? 'Nominal baru' : 'New amount',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isId ? 'Batal' : 'Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, balance),
          child: Text(
            isId
                ? 'Ganti ke ${CurrencyFormatter.format(balance)}'
                : 'Use ${CurrencyFormatter.format(balance)}',
          ),
        ),
        FilledButton(
          onPressed: () {
            final v = CurrencyFormatter.parse(ctrl.text);
            if (v > 0) Navigator.pop(ctx, v);
          },
          child: Text(isId ? 'Update nominal' : 'Update amount'),
        ),
      ],
    ),
  );
}
