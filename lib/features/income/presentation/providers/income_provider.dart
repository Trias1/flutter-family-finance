import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  IncomeNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String?> addIncome(IncomeModel income) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.createIncome(income));
    state = result.error != null
        ? AsyncValue<void>.error(result.error!, result.stackTrace!)
        : const AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> updateIncome(IncomeModel income) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.updateIncome(income));
    state = result.error != null
        ? AsyncValue<void>.error(result.error!, result.stackTrace!)
        : const AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> deleteIncome(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.deleteIncome(id));
    state = result.error != null
        ? AsyncValue<void>.error(result.error!, result.stackTrace!)
        : const AsyncValue.data(null);
    return result.error?.toString();
  }
}

final incomeNotifierProvider = StateNotifierProvider<IncomeNotifier, AsyncValue<void>>((ref) {
  return IncomeNotifier(ref.watch(transactionRepositoryProvider));
});
