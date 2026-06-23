import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/recurring_model.dart';
import 'package:family_finance_manager/data/repositories/recurring_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

final recurringStreamProvider = StreamProvider.family<List<RecurringModel>, String>((ref, familyId) {
  return ref.watch(recurringRepositoryProvider).streamRecurrings(familyId).map((snapshot) {
    return snapshot!.docs.map((doc) => RecurringModel.fromFirestore(doc)).toList();
  });
});

class RecurringNotifier extends StateNotifier<AsyncValue<void>> {
  final RecurringRepository _repository;

  RecurringNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String?> createRecurring(RecurringModel recurring) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.createRecurring(recurring));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> updateRecurring(RecurringModel recurring) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.updateRecurring(recurring));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> deleteRecurring(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.deleteRecurring(id));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> toggleActive(RecurringModel recurring) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.updateRecurring(RecurringModel(
      id: recurring.id,
      familyId: recurring.familyId,
      userId: recurring.userId,
      type: recurring.type,
      amount: recurring.amount,
      category: recurring.category,
      note: recurring.note,
      frequency: recurring.frequency,
      interval: recurring.interval,
      dayOfMonth: recurring.dayOfMonth,
      dayOfWeek: recurring.dayOfWeek,
      startDate: recurring.startDate,
      endDate: recurring.endDate,
      nextDate: recurring.nextDate,
      lastGeneratedDate: recurring.lastGeneratedDate,
      isActive: !recurring.isActive,
      createdAt: recurring.createdAt,
    )));
    state = AsyncValue.data(null);
    return result.error?.toString();
  }
}

final recurringNotifierProvider = StateNotifierProvider<RecurringNotifier, AsyncValue<void>>((ref) {
  return RecurringNotifier(ref.watch(recurringRepositoryProvider));
});
