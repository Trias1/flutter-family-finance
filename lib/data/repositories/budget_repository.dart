import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/core/services/expense_effects.dart';

class BudgetRepository {
  final FirestoreDataSource _dataSource;

  BudgetRepository({required FirestoreDataSource dataSource})
    : _dataSource = dataSource;

  Future<void> setBudget(BudgetModel budget) {
    return _dataSource.setBudget(budget);
  }

  Future<List<BudgetModel>> getBudgetsByMonth(
    String familyId,
    String month, {
    bool cacheOnly = false,
  }) {
    return _dataSource.getBudgetsByMonth(familyId, month, cacheOnly: cacheOnly);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBudgets(String familyId) {
    return _dataSource.streamBudgets(familyId);
  }

  Future<List<BudgetModel>> getAllBudgets(String familyId) {
    return _dataSource.getAllBudgets(familyId);
  }

  Future<void> updateBudget(BudgetModel budget) {
    return _dataSource.updateBudget(budget);
  }

  Future<void> deleteBudget(String id) {
    return _dataSource.deleteBudget(id);
  }

  static bool isSavingsCategory(String category) =>
      category == 'Tabungan' || category == 'Savings';

  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  /// Adds [delta] to the "used" amount of the budget for [category] in the
  /// month of [date]. Savings transfers are not spending, so they are skipped.
  Future<void> applyExpense(
    String familyId,
    String category,
    double delta,
    DateTime date,
  ) async {
    if (delta == 0 || isSavingsCategory(category)) return;
    final budgets = await getBudgetsByMonth(familyId, monthKey(date));
    final match = budgets.where((b) => b.category == category).firstOrNull;
    if (match == null) return;
    await _dataSource.incrementBudgetUsed(match.id, delta);
  }

  /// What was already spent in [category] during [month], for a budget
  /// created mid-month.
  Future<double> spentInMonth(
    String familyId,
    String category,
    String month,
  ) async {
    if (isSavingsCategory(category)) return 0;
    final expenses = await _dataSource.getExpenses(familyId);
    return budgetSpent(expenses, category, month);
  }

  Future<void> rolloverIfNeeded(String familyId) async {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prev = DateTime(now.year, now.month - 1, 1);
    final prevMonth = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';

    final current = await getBudgetsByMonth(familyId, currentMonth);
    if (current.isNotEmpty) return;

    final prevBudgets = await getBudgetsByMonth(familyId, prevMonth);
    if (prevBudgets.isEmpty) return;

    for (final b in prevBudgets) {
      // A fixed id per family/month/category: if two devices roll over at
      // the same time they write the same document instead of duplicates.
      final safeCategory = b.category.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      await setBudget(
        BudgetModel(
          id: 'rollover_${familyId}_${currentMonth}_$safeCategory',
          familyId: familyId,
          month: currentMonth,
          category: b.category,
          budgetAmount: b.budgetAmount,
          usedAmount: 0,
          rolloverAmount: b.remaining > 0 ? b.remaining : 0,
        ),
      );
    }
  }
}
