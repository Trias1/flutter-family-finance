import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/recurring_model.dart';

class RecurringRepository {
  final FirestoreDataSource _dataSource;

  RecurringRepository({required FirestoreDataSource dataSource}) : _dataSource = dataSource;

  Future<void> createRecurring(RecurringModel recurring) => _dataSource.createRecurring(recurring);
  Future<List<RecurringModel>> getRecurrings(String familyId) => _dataSource.getRecurrings(familyId);
  Stream<QuerySnapshot<Map<String, dynamic>>> streamRecurrings(String familyId) => _dataSource.streamRecurrings(familyId);
  Future<List<RecurringModel>> getDueRecurrings() => _dataSource.getDueRecurrings();
  Future<void> updateRecurring(RecurringModel recurring) => _dataSource.updateRecurring(recurring);
  Future<void> deleteRecurring(String id) => _dataSource.deleteRecurring(id);
}
