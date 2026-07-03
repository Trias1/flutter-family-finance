import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';

class BudgetRepository {
  final FirestoreDataSource _dataSource;

  BudgetRepository({required FirestoreDataSource dataSource})
      : _dataSource = dataSource;

  Future<void> setBudget(BudgetModel budget) {
    return _dataSource.setBudget(budget);
  }

  Future<List<BudgetModel>> getBudgetsByMonth(String familyId, String month) {
    return _dataSource.getBudgetsByMonth(familyId, month);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBudgets(String familyId) {
    return _dataSource.streamBudgets(familyId);
  }

  Future<void> updateBudget(BudgetModel budget) {
    return _dataSource.updateBudget(budget);
  }

  Future<void> deleteBudget(String id) {
    return _dataSource.deleteBudget(id);
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
      await setBudget(BudgetModel(
        id: '',
        familyId: familyId,
        month: currentMonth,
        category: b.category,
        budgetAmount: b.budgetAmount,
        usedAmount: 0,
        rolloverAmount: b.remaining > 0 ? b.remaining : 0,
      ));
    }
  }
}
