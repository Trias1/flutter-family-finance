import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/data/repositories/saving_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final savingRepositoryProvider = Provider<SavingRepository>((ref) {
  return SavingRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

final savingStreamProvider = StreamProvider.family<List<SavingModel>, String>((
  ref,
  familyId,
) {
  // No scope yet (profile still loading): skip a query the rules would deny.
  if (familyId.isEmpty) return Stream.value(const <SavingModel>[]);
  return ref.watch(savingRepositoryProvider).streamSavings(familyId).map((
    snapshot,
  ) {
    final list = snapshot.docs
        .map((doc) => SavingModel.fromFirestore(doc))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

class SavingNotifier extends StateNotifier<AsyncValue<void>> {
  final SavingRepository _repository;
  final FirestoreDataSource _dataSource;

  SavingNotifier(this._repository, this._dataSource)
    : super(const AsyncValue.data(null));

  Future<void> createSaving(SavingModel saving) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.createSaving(saving));
  }

  Future<void> updateSaving(SavingModel saving) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.updateSaving(saving));
  }

  Future<void> deleteSaving(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.deleteSaving(id));
  }

  Future<void> addToSaving(String savingId, double amount) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final savingData = await _dataSource.getSaving(savingId);
      if (savingData == null) throw Exception('Saving not found');
      final updated = savingData.copyWith(
        currentAmount: savingData.currentAmount + amount,
      );
      await _repository.updateSaving(updated);
    });
  }

  Future<void> withdrawFromSaving(String savingId, double amount) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final savingData = await _dataSource.getSaving(savingId);
      if (savingData == null) throw Exception('Saving not found');
      if (savingData.currentAmount < amount)
        throw Exception('Saldo tabungan tidak mencukupi');
      final updated = savingData.copyWith(
        currentAmount: savingData.currentAmount - amount,
      );
      await _repository.updateSaving(updated);
    });
  }
}

final savingNotifierProvider =
    StateNotifierProvider<SavingNotifier, AsyncValue<void>>((ref) {
      return SavingNotifier(
        ref.watch(savingRepositoryProvider),
        ref.watch(firestoreDataSourceProvider),
      );
    });
