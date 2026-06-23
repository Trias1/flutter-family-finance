import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/family_model.dart';
import 'package:family_finance_manager/data/models/user_model.dart';
import 'package:family_finance_manager/data/repositories/family_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

class FamilyNotifier extends StateNotifier<AsyncValue<FamilyModel?>> {
  final FamilyRepository _repository;
  final AuthNotifier _authNotifier;

  FamilyNotifier(this._repository, this._authNotifier)
    : super(const AsyncValue.data(null));

  Future<String?> createFamily(String name, String userId) async {
    state = const AsyncValue.loading();
    try {
      final family = await _repository.createFamily(name, userId);
      final err = await _authNotifier.joinFamily(
        family.id,
        familyName: family.name,
        role: 'admin',
      );
      if (err != null) throw Exception(err);
      state = AsyncValue.data(family);
      return null;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return e.toString();
    }
  }

  Future<String?> transferOwnership(
    FamilyModel family,
    String newOwnerId,
  ) async {
    try {
      await _repository.transferOwnership(family.id, newOwnerId);
      final updated = await _repository.getFamily(family.id);
      state = AsyncValue.data(updated);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> joinFamily(String code) async {
    state = const AsyncValue.loading();
    try {
      final family = await _repository.joinFamily(code);
      if (family == null) throw Exception('Kode undangan tidak valid');
      final err = await _authNotifier.joinFamily(
        family.id,
        familyName: family.name,
      );
      if (err != null) throw Exception(err);
      state = AsyncValue.data(family);
      return null;
    } catch (e) {
      state = AsyncValue.error(e.toString(), StackTrace.current);
      return e.toString();
    }
  }
}

final familyMembersProvider = FutureProvider<List<UserModel>>((ref) {
  final familyId = ref.watch(familyIdProvider);
  if (familyId.isEmpty) return Future.value([]);
  return ref.watch(firestoreDataSourceProvider).getUsersByFamilyId(familyId);
});

final familyNotifierProvider =
    StateNotifierProvider<FamilyNotifier, AsyncValue<FamilyModel?>>((ref) {
      return FamilyNotifier(
        ref.watch(familyRepositoryProvider),
        ref.watch(authNotifierProvider.notifier),
      );
    });
