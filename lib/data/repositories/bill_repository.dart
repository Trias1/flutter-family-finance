import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/bill_model.dart';

class BillRepository {
  final FirestoreDataSource _dataSource;

  BillRepository({required FirestoreDataSource dataSource})
    : _dataSource = dataSource;

  Future<void> createBill(BillModel bill) {
    return _dataSource.createBill(bill);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBills(String familyId) {
    return _dataSource.streamBills(familyId);
  }

  Future<List<BillModel>> getBills(String familyId) async {
    final snapshot = await _dataSource.streamBills(familyId).first;
    return snapshot.docs.map((doc) => BillModel.fromFirestore(doc)).toList();
  }

  Future<void> updateBill(BillModel bill) {
    return _dataSource.updateBill(bill);
  }

  Future<void> deleteBill(String id) {
    return _dataSource.deleteBill(id);
  }
}
