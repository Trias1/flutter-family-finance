import 'package:flutter/material.dart';
import 'package:family_finance_manager/core/services/expense_effects.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';

/// One goal's history: deposits (+) and spending paid from it (−), newest
/// first. Entries are linked by id; older ones by the goal's name in the
/// note.
void showGoalHistory(
  BuildContext context, {
  required SavingModel goal,
  required List<ExpenseModel> expenses,
  required List<IncomeModel> incomes,
  required bool isId,
}) {
  final name = goal.name.toLowerCase();
  final rows = <({String label, DateTime date, double amount, bool plus})>[
    for (final e in expenses.where((e) => belongsToGoal(e, goal)))
      (
        label: isSavingsDeposit(e.category)
            ? (isId ? 'Setor' : 'Deposit')
            : '${isId ? 'Dipakai' : 'Spent'} · ${e.category}',
        date: e.date,
        amount: e.amount,
        plus: isSavingsDeposit(e.category),
      ),
    for (final i in incomes.where(
      (i) =>
          isSavingsDeposit(i.category) &&
          (i.note ?? '').toLowerCase().contains(name),
    ))
      (
        label: isId ? 'Setor' : 'Deposit',
        date: i.date,
        amount: i.amount,
        plus: true,
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 18,
                  color: AppTheme.savingsColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isId ? 'Saldo Saat Ini:' : 'Current Balance:',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                Text(
                  CurrencyFormatter.format(goal.currentAmount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.savingsColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isId ? 'Histori Transaksi' : 'Transaction History',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    isId ? 'Belum ada transaksi' : 'No transactions yet',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final r = rows[index];
                    final color = r.plus
                        ? AppTheme.incomeColor
                        : AppTheme.expenseColor;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              r.plus ? Icons.add : Icons.remove,
                              size: 14,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  DateFormatter.format(r.date),
                                  style: TextStyle(fontSize: 10, color: muted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${r.plus ? '+' : '-'}${CurrencyFormatter.format(r.amount)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
