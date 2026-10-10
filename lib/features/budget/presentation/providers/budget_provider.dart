import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/budget_alert_service.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(dataSource: ref.watch(firestoreDataSourceProvider));
});

final budgetStreamProvider = StreamProvider.family<List<BudgetModel>, String>((ref, familyId) {
  return ref.watch(budgetRepositoryProvider).streamBudgets(familyId).map(
    (snapshot) => snapshot.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList(),
  );
});

final budgetsByMonthProvider = FutureProvider.family<List<BudgetModel>, String>((ref, familyId) async {
  final month = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
  return ref.watch(budgetRepositoryProvider).getBudgetsByMonth(familyId, month);
});

final budgetHistoryProvider = FutureProvider.family<List<BudgetModel>, String>((ref, familyId) {
  return ref.watch(budgetRepositoryProvider).getAllBudgets(familyId);
});

final budgetAlertWatcherProvider = Provider<void>((ref) {
  final familyId = ref.watch(financeScopeIdProvider);
  final budgetsAsync = ref.watch(budgetStreamProvider(familyId));
  final locale = ref.watch(localeProvider);
  final isId = locale.languageCode == 'id';
  budgetsAsync.whenData((budgets) {
    BudgetAlertService().checkBudgets(budgets, isIndonesian: isId);
  });
});

class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  final BudgetRepository _repository;

  BudgetNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> setBudget(BudgetModel budget) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.setBudget(budget));
  }

  Future<void> updateBudget(BudgetModel budget) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.updateBudget(budget));
  }

  Future<void> deleteBudget(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.deleteBudget(id));
  }
}

final budgetNotifierProvider = StateNotifierProvider<BudgetNotifier, AsyncValue<void>>((ref) {
  return BudgetNotifier(ref.watch(budgetRepositoryProvider));
});
