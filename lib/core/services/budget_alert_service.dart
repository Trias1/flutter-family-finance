import 'package:family_finance_manager/core/services/notification_service.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';

class BudgetAlertService {
  static final BudgetAlertService _instance = BudgetAlertService._();
  factory BudgetAlertService() => _instance;
  BudgetAlertService._();

  final Set<String> _notifiedExceeded = {};
  final Set<String> _notifiedAlmostExceeded = {};

  void checkBudgets(List<BudgetModel> budgets) {
    for (final budget in budgets) {
      if (budget.budgetAmount <= 0) continue;
      if (budget.isExceeded && _notifiedExceeded.add(budget.id)) {
        NotificationService().show(
          id: budget.id.hashCode,
          title: 'Anggaran Terlampaui!',
          body:
              'Kategori ${budget.category} sudah melebihi anggaran ${CurrencyFormatter.formatWithoutSymbol(budget.budgetAmount)}',
        );
      } else if (budget.isAlmostExceeded &&
          _notifiedAlmostExceeded.add(budget.id)) {
        NotificationService().show(
          id: budget.id.hashCode,
          title: 'Anggaran Hampir Habis',
          body:
              'Kategori ${budget.category} sudah mencapai ${budget.percentage.toStringAsFixed(0)}% dari anggaran',
        );
      }
    }
  }

  void reset() {
    _notifiedExceeded.clear();
    _notifiedAlmostExceeded.clear();
  }
}
