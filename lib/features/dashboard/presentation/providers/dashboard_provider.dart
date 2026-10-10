import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/services/prediction_service.dart';
import 'package:family_finance_manager/core/services/widget_service.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class DailySummary {
  final double totalIncome;
  final double totalExpense;
  final List<IncomeModel> incomes;
  final List<ExpenseModel> expenses;

  DailySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.incomes,
    required this.expenses,
  });

  double get net => totalIncome - totalExpense;
}

class DashboardData {
  final double totalIncome;
  final double totalExpense;
  final double totalSavings;
  final double totalBudgetRemaining;
  final List<IncomeModel> recentIncomes;
  final List<ExpenseModel> recentExpenses;
  final List<SavingModel> savings;
  final List<BudgetModel> budgets;
  final List<IncomeModel> allIncomes;
  final List<ExpenseModel> allExpenses;
  final List<BillModel> upcomingBills;
  final Map<DateTime, DailySummary> dailySummary;
  final Map<DateTime, List<BillModel>> billsByDate;
  final PredictionResult? prediction;
  final List<DebtModel> debts;

  /// Collections that could not be loaded (e.g. offline or no permission).
  final List<String> failedSections;

  DashboardData({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.totalBudgetRemaining,
    required this.recentIncomes,
    required this.recentExpenses,
    required this.savings,
    required this.budgets,
    required this.allIncomes,
    required this.allExpenses,
    required this.upcomingBills,
    required this.dailySummary,
    required this.billsByDate,
    this.prediction,
    this.debts = const [],
    this.failedSections = const [],
  });

  double get totalBalance => totalIncome - totalExpense;

  bool _thisMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  /// This month only. Moving money into savings is not spending, matching
  /// the rest of the dashboard and the web.
  double get monthIncome => allIncomes
      .where((e) => _thisMonth(e.date))
      .fold<double>(0, (sum, e) => sum + e.amount);

  double get monthExpense => allExpenses
      .where(
        (e) =>
            _thisMonth(e.date) &&
            e.category != 'Tabungan' &&
            e.category != 'Savings',
      )
      .fold<double>(0, (sum, e) => sum + e.amount);
}

Map<DateTime, DailySummary> _buildDailySummary(
  List<IncomeModel> incomes,
  List<ExpenseModel> expenses,
) {
  final Map<DateTime, List<IncomeModel>> incomeByDay = {};
  final Map<DateTime, List<ExpenseModel>> expenseByDay = {};

  for (final income in incomes) {
    final day = DateTime(income.date.year, income.date.month, income.date.day);
    incomeByDay.putIfAbsent(day, () => []).add(income);
  }
  for (final expense in expenses) {
    final day = DateTime(expense.date.year, expense.date.month, expense.date.day);
    expenseByDay.putIfAbsent(day, () => []).add(expense);
  }

  final allDates = {...incomeByDay.keys, ...expenseByDay.keys};
  return {
    for (final date in allDates)
      date: DailySummary(
        totalIncome:
            (incomeByDay[date] ?? []).fold<double>(0, (s, e) => s + e.amount),
        totalExpense:
            (expenseByDay[date] ?? []).fold<double>(0, (s, e) => s + e.amount),
        incomes: incomeByDay[date] ?? [],
        expenses: expenseByDay[date] ?? [],
      ),
  };
}

/// One failed collection should not blank the whole dashboard, but the user
/// must be told: failures are recorded under [name] and shown as a banner.
Future<List<T>> _safeQuery<T>(
  String name,
  List<String> failed,
  Future<List<T>> Function() query,
) async {
  try {
    return await query();
  } catch (e) {
    failed.add(name);
    return [];
  }
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final familyId = ref.watch(financeScopeIdProvider);
  final dataSource = ref.watch(firestoreDataSourceProvider);
  final budgetRepo = BudgetRepository(dataSource: dataSource);

  final failed = <String>[];
  final results = await Future.wait([
    _safeQuery('incomes', failed, () => dataSource.getIncomes(familyId)),
    _safeQuery('expenses', failed, () => dataSource.getExpenses(familyId)),
    _safeQuery('savings', failed, () => dataSource.getSavings(familyId)),
    _safeQuery('budgets', failed, () async {
      await budgetRepo.rolloverIfNeeded(familyId);
      final month =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
      return budgetRepo.getBudgetsByMonth(familyId, month);
    }),
    _safeQuery('bills', failed, () => dataSource.getBills(familyId)),
    _safeQuery('debts', failed, () => dataSource.getDebts(familyId)),
  ]);

  final incomes = results[0] as List<IncomeModel>;
  final expenses = results[1] as List<ExpenseModel>;
  final savings = results[2] as List<SavingModel>;
  final budgets = results[3] as List<BudgetModel>;
  final allBills = results[4] as List<BillModel>;
  final debts = results[5] as List<DebtModel>;

  final totalIncome = incomes.fold<double>(0, (sum, e) => sum + e.amount);
  final totalExpense = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final totalSavings = savings.fold<double>(
    0,
    (sum, e) => sum + e.currentAmount,
  );
  final totalBudgetRemaining = budgets
      .where((b) => b.category != 'Tabungan' && b.category != 'Savings')
      .fold<double>(0, (sum, e) => sum + e.remaining);

  WidgetService.updateBalance(totalIncome - totalExpense);

  final upcomingBills = allBills
      .where((b) => b.status != BillStatus.paid)
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  final Map<DateTime, List<BillModel>> billsByDate = {};
  for (final bill in allBills) {
    final day = DateTime(bill.dueDate.year, bill.dueDate.month, bill.dueDate.day);
    billsByDate.putIfAbsent(day, () => []).add(bill);
  }

  return DashboardData(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    totalSavings: totalSavings,
    totalBudgetRemaining: totalBudgetRemaining,
    recentIncomes: incomes.take(5).toList(),
    recentExpenses: expenses.take(5).toList(),
    savings: savings,
    budgets: budgets,
    allIncomes: incomes,
    allExpenses: expenses,
    upcomingBills: upcomingBills.take(3).toList(),
    dailySummary: _buildDailySummary(incomes, expenses),
    billsByDate: billsByDate,
    debts: debts,
    failedSections: failed,
    prediction: PredictionService().predict30Days(
      incomes: incomes,
      expenses: expenses,
      currentBalance: totalIncome - totalExpense,
    ),
  );
});
