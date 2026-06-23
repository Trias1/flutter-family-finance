import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class DashboardData {
  final double totalIncome;
  final double totalExpense;
  final double totalSavings;
  final double totalBudgetRemaining;
  final List<IncomeModel> recentIncomes;
  final List<ExpenseModel> recentExpenses;
  final List<SavingModel> savings;
  final List<BudgetModel> budgets;

  DashboardData({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.totalBudgetRemaining,
    required this.recentIncomes,
    required this.recentExpenses,
    required this.savings,
    required this.budgets,
  });

  double get totalBalance => totalIncome - totalExpense;
}

Future<List<T>> _safeQuery<T>(Future<List<T>> Function() query) async {
  try {
    return await query();
  } catch (e) {
    return [];
  }
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final familyId = ref.watch(financeScopeIdProvider);
  final dataSource = ref.watch(firestoreDataSourceProvider);
  final budgetRepo = BudgetRepository(dataSource: dataSource);

  final results = await Future.wait([
    _safeQuery(() => dataSource.getIncomes(familyId)),
    _safeQuery(() => dataSource.getExpenses(familyId)),
    _safeQuery(() => dataSource.getSavings(familyId)),
    _safeQuery(() async {
      final month =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
      return budgetRepo.getBudgetsByMonth(familyId, month);
    }),
  ]);

  final incomes = results[0] as List<IncomeModel>;
  final expenses = results[1] as List<ExpenseModel>;
  final savings = results[2] as List<SavingModel>;
  final budgets = results[3] as List<BudgetModel>;

  final totalIncome = incomes.fold<double>(0, (sum, e) => sum + e.amount);
  final totalExpense = expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final totalSavings = savings.fold<double>(
    0,
    (sum, e) => sum + e.currentAmount,
  );
  final totalBudgetRemaining = budgets.fold<double>(
    0,
    (sum, e) => sum + e.remaining,
  );

  return DashboardData(
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    totalSavings: totalSavings,
    totalBudgetRemaining: totalBudgetRemaining,
    recentIncomes: incomes.take(5).toList(),
    recentExpenses: expenses.take(5).toList(),
    savings: savings,
    budgets: budgets,
  );
});
