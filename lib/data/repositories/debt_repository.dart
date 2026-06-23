import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/data/models/debt_payment_model.dart';

class DebtRepository {
  final FirestoreDataSource _dataSource;

  DebtRepository({required FirestoreDataSource dataSource}) : _dataSource = dataSource;

  Future<void> createDebt(DebtModel debt) => _dataSource.createDebt(debt);
  Future<List<DebtModel>> getDebts(String familyId) => _dataSource.getDebts(familyId);
  Stream<QuerySnapshot<Map<String, dynamic>>> streamDebts(String familyId) => _dataSource.streamDebts(familyId);
  Future<DebtModel?> getDebt(String id) => _dataSource.getDebt(id);
  Future<void> updateDebt(DebtModel debt) => _dataSource.updateDebt(debt);
  Future<void> deleteDebt(String id) => _dataSource.deleteDebt(id);
  Future<List<DebtPaymentModel>> getDebtPayments(String debtId) => _dataSource.getDebtPayments(debtId);
  Future<void> createDebtPayment(DebtPaymentModel payment) => _dataSource.createDebtPayment(payment);
}
