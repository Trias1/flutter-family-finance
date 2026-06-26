import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/repositories/transaction_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

final incomeStreamProvider = StreamProvider.family<List<IncomeModel>, String>((ref, familyId) {
  return ref.watch(transactionRepositoryProvider).streamIncomes(familyId).map(
    (snapshot) {
      final list = snapshot.docs.map((doc) => IncomeModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    },
  );
});

class IncomeNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repository;
  final FirestoreDataSource _dataSource;

  IncomeNotifier(this._repository, this._dataSource) : super(const AsyncValue.data(null));

  Future<void> addIncome(IncomeModel income) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createIncome(income);
    });
  }

  Future<void> updateIncome(IncomeModel income) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.updateIncome(income));
  }

  Future<void> deleteIncome(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteIncome(id);
    });
  }
}

final incomeNotifierProvider = StateNotifierProvider<IncomeNotifier, AsyncValue<void>>((ref) {
  return IncomeNotifier(
    ref.watch(transactionRepositoryProvider),
    ref.watch(firestoreDataSourceProvider),
  );
});
