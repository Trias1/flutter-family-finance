import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/core/services/expense_effects.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/data/repositories/saving_repository.dart';
import 'package:family_finance_manager/data/repositories/transaction_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/income/presentation/providers/income_provider.dart';

final expenseStreamProvider = StreamProvider.family<List<ExpenseModel>, String>(
  (ref, familyId) {
    // No scope yet (profile still loading): skip a query the rules would deny.
    if (familyId.isEmpty) return Stream.value(const <ExpenseModel>[]);
    return ref
        .watch(transactionRepositoryProvider)
        .streamExpenses(familyId)
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.date.compareTo(a.date));
          return list;
        });
  },
);

// Increments atomically and keeps rolloverAmount (rebuilding the model here
// used to reset it to 0 on the first expense of the month).
Future<void> _updateBudgetForExpense(
  BudgetRepository budgetRepo,
  String familyId,
  String category,
  double amount,
  DateTime date,
) {
  return budgetRepo.applyExpense(familyId, category, amount, date);
}

class ExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repository;
  final BudgetRepository _budgetRepo;
  final SavingRepository _savingRepo;

  ExpenseNotifier(this._repository, this._budgetRepo, this._savingRepo)
    : super(const AsyncValue.data(null));

  /// Applies [fx] to the budget and the goal it names.
  Future<void> _apply(String familyId, ExpenseEffects fx) async {
    if (fx.budgetCategory != null && fx.budgetDelta != 0) {
      await _updateBudgetForExpense(
        _budgetRepo,
        familyId,
        fx.budgetCategory!,
        fx.budgetDelta,
        fx.date,
      );
    }
    if (fx.goalDelta == 0 || (fx.savingId == null && fx.goalNote == null)) {
      return;
    }
    final goals = await _savingRepo.getSavings(familyId);
    final goal = fx.savingId != null
        ? goals.where((g) => g.id == fx.savingId).firstOrNull
        : legacyGoalFor(fx.goalNote!, goals);
    if (goal == null) return;
    await _savingRepo.updateSaving(
      goal.copyWith(
        currentAmount: goalAmountAfter(goal.currentAmount, fx.goalDelta),
      ),
    );
  }

  Future<String?> _run(Future<void> Function() body) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(body);
    state = result.error != null
        ? AsyncValue<void>.error(result.error!, result.stackTrace!)
        : const AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> addExpense(ExpenseModel expense) => _run(() async {
    await _repository.createExpense(expense);
    await _apply(expense.familyId, effectsOf(expense));
  });

  /// Undoes what the old version did to budgets and goals, then applies the
  /// new one (so Budget <-> Tabungan or another goal stays right).
  Future<String?> updateExpense(ExpenseModel expense) => _run(() async {
    final old = await _repository.getExpense(expense.id);
    await _repository.updateExpense(expense);
    if (old == null) return;
    await _apply(expense.familyId, effectsOf(old).reversed);
    await _apply(expense.familyId, effectsOf(expense));
  });

  Future<String?> deleteExpense(String id) => _run(() async {
    final expense = await _repository.getExpense(id);
    await _repository.deleteExpense(id);
    if (expense == null) return;
    await _apply(expense.familyId, effectsOf(expense).reversed);
  });
}

final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<void>>((ref) {
      return ExpenseNotifier(
        ref.watch(transactionRepositoryProvider),
        BudgetRepository(dataSource: ref.watch(firestoreDataSourceProvider)),
        SavingRepository(dataSource: ref.watch(firestoreDataSourceProvider)),
      );
    });
