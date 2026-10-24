import 'package:flutter/material.dart';
import 'package:family_finance_manager/core/services/expense_effects.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/core/utils/date_formatter.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';

/// The spending a budget is made of this month (paid from the budget, not
/// from savings), newest first.
void showBudgetExpenses(
  BuildContext context, {
  required String category,
  required String month,
  required List<ExpenseModel> expenses,
  required bool isId,
}) {
  final rows = budgetExpenses(expenses, category, month);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final muted = Theme.of(ctx).colorScheme.onSurfaceVariant;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${rows.length} ${isId ? 'pengeluaran bulan ini' : 'expenses this month'}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      isId ? 'Belum ada pengeluaran.' : 'No spending yet.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final e = rows[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (e.note == null || e.note!.isEmpty)
                              ? e.category
                              : e.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(DateFormatter.format(e.date)),
                        trailing: Text(
                          '-${CurrencyFormatter.format(e.amount)}',
                          style: const TextStyle(
                            color: AppTheme.expenseColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
