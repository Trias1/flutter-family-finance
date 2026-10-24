import 'package:family_finance_manager/core/services/notification_service.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';

class BudgetAlertService {
  static final BudgetAlertService _instance = BudgetAlertService._();
  factory BudgetAlertService() => _instance;
  BudgetAlertService._();

  final Set<String> _notifiedExceeded = {};
  final Set<String> _notifiedAlmostExceeded = {};

  void checkBudgets(List<BudgetModel> budgets, {bool isIndonesian = true}) {
    for (final budget in budgets) {
      if (budget.effectiveBudget <= 0) continue;
      if (budget.isExceeded && _notifiedExceeded.add(budget.id)) {
        NotificationService().show(
          id: budget.id.hashCode,
          title: isIndonesian ? 'Anggaran Terlampaui!' : 'Budget Exceeded!',
          body: isIndonesian
              ? 'Kategori ${budget.category} sudah melebihi anggaran ${CurrencyFormatter.formatWithoutSymbol(budget.effectiveBudget)}'
              : 'Category ${budget.category} has exceeded the budget of ${CurrencyFormatter.formatWithoutSymbol(budget.effectiveBudget)}',
        );
      } else if (budget.isAlmostExceeded &&
          _notifiedAlmostExceeded.add(budget.id)) {
        NotificationService().show(
          id: budget.id.hashCode,
          title: isIndonesian
              ? 'Anggaran Hampir Habis'
              : 'Budget Almost Exhausted',
          body: isIndonesian
              ? 'Kategori ${budget.category} sudah mencapai ${budget.percentage.toStringAsFixed(0)}% dari anggaran'
              : 'Category ${budget.category} has reached ${budget.percentage.toStringAsFixed(0)}% of the budget',
        );
      }
    }
  }

  void reset() {
    _notifiedExceeded.clear();
    _notifiedAlmostExceeded.clear();
  }
}
