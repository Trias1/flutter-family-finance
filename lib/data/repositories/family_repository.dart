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

  Future<void> ensureFamilyInvite(FamilyModel family) {
    return _dataSource.ensureFamilyInvite(family);
  }

  Future<void> updateFamily(FamilyModel family) {
    return _dataSource.updateFamily(family);
  }

  Future<void> transferOwnership(String familyId, String newOwnerId) {
    return _dataSource.transferFamilyOwnership(familyId, newOwnerId);
  }

  // 8 characters from 32 unambiguous symbols (no 0/O, 1/I): about 10^12
  // combinations, drawn from a cryptographically secure source.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
