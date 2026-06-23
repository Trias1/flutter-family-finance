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
}
