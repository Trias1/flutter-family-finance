import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/debt_model.dart';
import 'package:family_finance_manager/data/models/debt_payment_model.dart';
import 'package:family_finance_manager/data/repositories/debt_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

final debtStreamProvider = StreamProvider.family<List<DebtModel>, String>((ref, familyId) {
  return ref.watch(debtRepositoryProvider).streamDebts(familyId).map((snapshot) {
    final list = snapshot!.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

final debtPaymentsProvider = FutureProvider.family<List<DebtPaymentModel>, String>((ref, debtId) {
  return ref.watch(debtRepositoryProvider).getDebtPayments(debtId);
});

class DebtNotifier extends StateNotifier<AsyncValue<void>> {
  final DebtRepository _repository;

  DebtNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String?> createDebt(DebtModel debt) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.createDebt(debt));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> updateDebt(DebtModel debt) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.updateDebt(debt));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> deleteDebt(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.deleteDebt(id));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> addPayment(String debtId, double amount, String? note) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final debt = await _repository.getDebt(debtId);
      if (debt == null) throw Exception('Hutang tidak ditemukan');
      final newRemaining = debt.remainingAmount - amount;
      final newStatus = newRemaining <= 0 ? DebtStatus.paid : DebtStatus.active;
      await _repository.updateDebt(DebtModel(
        id: debt.id,
        familyId: debt.familyId,
        userId: debt.userId,
        personName: debt.personName,
        type: debt.type,
        amount: debt.amount,
        remainingAmount: newRemaining < 0 ? 0 : newRemaining,
        description: debt.description,
        dueDate: debt.dueDate,
        status: newStatus,
        createdAt: debt.createdAt,
      ));
      await _repository.createDebtPayment(DebtPaymentModel(
        id: '',
        debtId: debtId,
        amount: amount,
        date: DateTime.now(),
        note: note,
      ));
    });
    state = AsyncValue.data(null);
    return result.error?.toString();
  }
}

final debtNotifierProvider = StateNotifierProvider<DebtNotifier, AsyncValue<void>>((ref) {
  return DebtNotifier(ref.watch(debtRepositoryProvider));
});
