import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';

class PredictionResult {
  final List<double> dailyBalances;
  final double predictedEndBalance;
  final double averageDailyIncome;
  final double averageDailyExpense;

  PredictionResult({
    required this.dailyBalances,
    required this.predictedEndBalance,
    required this.averageDailyIncome,
    required this.averageDailyExpense,
  });
}

class PredictionService {
  PredictionResult predict30Days({
    required List<IncomeModel> incomes,
    required List<ExpenseModel> expenses,
    required double currentBalance,
  }) {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    final recentIncomes = incomes
        .where((i) => i.date.isAfter(threeMonthsAgo))
        .toList();
    final recentExpenses = expenses
        .where((e) => e.date.isAfter(threeMonthsAgo))
        .toList();

    final daysInRange = DateTime.now().difference(threeMonthsAgo).inDays;
    final avgIncome = daysInRange > 0
        ? recentIncomes.fold<double>(0.0, (s, i) => s + i.amount) / daysInRange
        : 0.0;
    final avgExpense = daysInRange > 0
        ? recentExpenses.fold<double>(0.0, (s, e) => s + e.amount) / daysInRange
        : 0.0;

    final dailyBalances = <double>[];
    var balance = currentBalance;
    for (int d = 1; d <= 30; d++) {
      balance += avgIncome - avgExpense;
      dailyBalances.add(balance);
    }

    return PredictionResult(
      dailyBalances: dailyBalances,
      predictedEndBalance: dailyBalances.last,
      averageDailyIncome: avgIncome,
      averageDailyExpense: avgExpense,
    );
  }
}
