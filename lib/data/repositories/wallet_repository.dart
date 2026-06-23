import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/transfer_model.dart';
import 'package:family_finance_manager/data/models/wallet_model.dart';

class WalletRepository {
  final FirestoreDataSource _dataSource;

  WalletRepository({required FirestoreDataSource dataSource}) : _dataSource = dataSource;

  Future<void> createWallet(WalletModel wallet) => _dataSource.createWallet(wallet);
  Future<List<WalletModel>> getWallets(String familyId) => _dataSource.getWallets(familyId);
  Stream<QuerySnapshot> streamWallets(String familyId) => _dataSource.streamWallets(familyId);
  Future<WalletModel?> getWallet(String id) => _dataSource.getWallet(id);
  Future<void> updateWallet(WalletModel wallet) => _dataSource.updateWallet(wallet);
  Future<void> deleteWallet(String id) => _dataSource.deleteWallet(id);
  Future<void> createTransfer(TransferModel transfer) => _dataSource.createTransfer(transfer);
  Future<List<TransferModel>> getTransfers(String familyId) => _dataSource.getTransfers(familyId);
}
