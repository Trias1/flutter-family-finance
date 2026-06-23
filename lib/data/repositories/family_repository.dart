import 'dart:math';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/family_model.dart';

class FamilyRepository {
  final FirestoreDataSource _dataSource;

  FamilyRepository({required FirestoreDataSource dataSource})
      : _dataSource = dataSource;

  Future<FamilyModel> createFamily(String name, String createdBy) {
    final code = _generateInviteCode();
    final family = FamilyModel(
      id: '',
      name: name,
      inviteCode: code,
      createdBy: createdBy,
    );
    return _dataSource.createFamily(family);
  }

  Future<FamilyModel?> getFamily(String id) {
    return _dataSource.getFamily(id);
  }

  Future<FamilyModel?> joinFamily(String code) {
    return _dataSource.getFamilyByInviteCode(code);
  }

  Future<void> updateFamily(FamilyModel family) {
    return _dataSource.updateFamily(family);
  }

  Future<void> transferOwnership(String familyId, String newOwnerId) {
    return _dataSource.transferFamilyOwnership(familyId, newOwnerId);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
