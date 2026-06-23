import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

class ReportData {
  final List<IncomeModel> incomes;
  final List<ExpenseModel> expenses;
  final List<SavingModel> savings;
  final double totalIncome;
  final double totalExpense;
  final double totalBalance;
  final List<IncomeModel> filteredIncomes;
  final List<ExpenseModel> filteredExpenses;
  final double filteredTotalIncome;
  final double filteredTotalExpense;
  final double filteredTotalBalance;

  ReportData({
    required this.incomes,
    required this.expenses,
    required this.savings,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalBalance,
    required this.filteredIncomes,
    required this.filteredExpenses,
    required this.filteredTotalIncome,
    required this.filteredTotalExpense,
    required this.filteredTotalBalance,
  });
}

final reportProvider = FutureProvider.family<ReportData, String>((ref, familyId) async {
  final dataSource = ref.watch(firestoreDataSourceProvider);
  final incomes = await dataSource.getIncomes(familyId);
  final expenses = await dataSource.getExpenses(familyId);
  final savings = await dataSource.getSavings(familyId);

  final totalIncome = incomes.fold<double>(0, (sum, e) => sum + e.amount);
  final totalExpense = expenses.fold<double>(0, (sum, e) => sum + e.amount);

  return ReportData(
    incomes: incomes,
    expenses: expenses,
    savings: savings,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    totalBalance: totalIncome - totalExpense,
    filteredIncomes: incomes,
    filteredExpenses: expenses,
    filteredTotalIncome: totalIncome,
    filteredTotalExpense: totalExpense,
    filteredTotalBalance: totalIncome - totalExpense,
  );
});
