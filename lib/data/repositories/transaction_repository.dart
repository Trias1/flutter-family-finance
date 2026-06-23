import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';

class TransactionRepository {
  final FirestoreDataSource _dataSource;

  TransactionRepository({required FirestoreDataSource dataSource})
      : _dataSource = dataSource;

  Future<void> createIncome(IncomeModel income) {
    return _dataSource.createIncome(income);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamIncomes(String familyId) {
    return _dataSource.streamIncomes(familyId);
  }

  Future<void> updateIncome(IncomeModel income) {
    return _dataSource.updateIncome(income);
  }

  Future<void> deleteIncome(String id) {
    return _dataSource.deleteIncome(id);
  }

  Future<void> createExpense(ExpenseModel expense) {
    return _dataSource.createExpense(expense);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamExpenses(String familyId) {
    return _dataSource.streamExpenses(familyId);
  }

  Future<ExpenseModel?> getExpense(String id) {
    return _dataSource.getExpense(id);
  }

  Future<void> updateExpense(ExpenseModel expense) {
    return _dataSource.updateExpense(expense);
  }

  Future<void> deleteExpense(String id) {
    return _dataSource.deleteExpense(id);
  }
}
