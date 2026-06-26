import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';

class SavingRepository {
  final FirestoreDataSource _dataSource;

  SavingRepository({required FirestoreDataSource dataSource})
      : _dataSource = dataSource;

  Future<void> createSaving(SavingModel saving) {
    return _dataSource.createSaving(saving);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamSavings(String familyId) {
    return _dataSource.streamSavings(familyId);
  }

  Future<List<SavingModel>> getSavings(String familyId) async {
    final snapshot = await _dataSource.streamSavings(familyId).first;
    return snapshot.docs.map((doc) => SavingModel.fromFirestore(doc)).toList();
  }

  Future<void> updateSaving(SavingModel saving) {
    return _dataSource.updateSaving(saving);
  }

  Future<void> deleteSaving(String id) {
    return _dataSource.deleteSaving(id);
  }
}
