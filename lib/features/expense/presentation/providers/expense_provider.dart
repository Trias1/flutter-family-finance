import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/data/repositories/saving_repository.dart';
import 'package:family_finance_manager/data/repositories/transaction_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/income/presentation/providers/income_provider.dart';

final expenseStreamProvider = StreamProvider.family<List<ExpenseModel>, String>((ref, familyId) {
  // No scope yet (profile still loading): skip a query the rules would deny.
  if (familyId.isEmpty) return Stream.value(const <ExpenseModel>[]);
  return ref.watch(transactionRepositoryProvider).streamExpenses(familyId).map(
    (snapshot) {
      final list = snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    },
  );
});

// Increments atomically and keeps rolloverAmount (rebuilding the model here
// used to reset it to 0 on the first expense of the month).
Future<void> _updateBudgetForExpense(BudgetRepository budgetRepo, String familyId, String category, double amount, DateTime date) {
  return budgetRepo.applyExpense(familyId, category, amount, date);
}

Future<void> _updateGoalsForExpense(SavingRepository savingRepo, String familyId, String note, double amount) async {
  // If expense is Tabungan/Savings category, add amount to matching Goals by name in note
  final savings = await savingRepo.getSavings(familyId);
  final noteLower = note.toLowerCase();
  final match = savings.where((s) => noteLower.contains(s.name.toLowerCase())).firstOrNull;
  if (match == null) return;

  final updated = SavingModel(
    id: match.id,
    familyId: match.familyId,
    name: match.name,
    targetAmount: match.targetAmount,
    currentAmount: match.currentAmount + amount,
    bankName: match.bankName,
    targetDate: match.targetDate,
    createdAt: match.createdAt,
    category: match.category,
    goldType: match.goldType,
    goldGrams: match.goldGrams,
    purchasePricePerGram: match.purchasePricePerGram,
    currentPricePerGram: match.currentPricePerGram,
    purchaseSource: match.purchaseSource,
  );
  await savingRepo.updateSaving(updated);
}

Future<void> _reverseGoalsForExpense(SavingRepository savingRepo, String familyId, String note, double amount) async {
  // Reverse goals effect: subtract amount from matching Goals (clamp at 0)
  final savings = await savingRepo.getSavings(familyId);
  final noteLower = note.toLowerCase();
  final match = savings.where((s) => noteLower.contains(s.name.toLowerCase())).firstOrNull;
  if (match == null) return;

  final newAmount = (match.currentAmount - amount).clamp(0, double.infinity).toDouble();
  final updated = SavingModel(
    id: match.id,
    familyId: match.familyId,
    name: match.name,
    targetAmount: match.targetAmount,
    currentAmount: newAmount,
    bankName: match.bankName,
    targetDate: match.targetDate,
    createdAt: match.createdAt,
    category: match.category,
    goldType: match.goldType,
    goldGrams: match.goldGrams,
    purchasePricePerGram: match.purchasePricePerGram,
    currentPricePerGram: match.currentPricePerGram,
    purchaseSource: match.purchaseSource,
  );
  await savingRepo.updateSaving(updated);
}

class ExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repository;
  final BudgetRepository _budgetRepo;
  final SavingRepository _savingRepo;

  ExpenseNotifier(this._repository, this._budgetRepo, this._savingRepo) : super(const AsyncValue.data(null));

  Future<String?> addExpense(ExpenseModel expense) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await _repository.createExpense(expense);
      await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, expense.amount, expense.date);

      if ((expense.category == 'Tabungan' || expense.category == 'Savings') &&
          expense.note != null && expense.note!.isNotEmpty) {
        await _updateGoalsForExpense(_savingRepo, expense.familyId, expense.note!, expense.amount);
      }
    });
    state = result.error != null
        ? AsyncValue<void>.error(result.error!, result.stackTrace!)
        : const AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> updateExpense(ExpenseModel expense) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final old = await _repository.getExpense(expense.id);
      await _repository.updateExpense(expense);
      if (old == null) return;

      final wasSavings = old.category == 'Tabungan' || old.category == 'Savings';
      final isSavings = expense.category == 'Tabungan' || expense.category == 'Savings';

      // Goals: reverse old effect, then apply new effect
      if (wasSavings && old.note != null && old.note!.isNotEmpty) {
        await _reverseGoalsForExpense(_savingRepo, expense.familyId, old.note!, old.amount);
      }
      if (isSavings && expense.note != null && expense.note!.isNotEmpty) {
        await _updateGoalsForExpense(_savingRepo, expense.familyId, expense.note!, expense.amount);
      }

      // Budget update (skip Tabungan/Savings)
      if (old.category == expense.category) {
        if (!isSavings) {
          final diff = expense.amount - old.amount;
          if (diff != 0) await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, diff, expense.date);
        }
      } else {
        if (!wasSavings) {
          await _updateBudgetForExpense(_budgetRepo, expense.familyId, old.category, -old.amount, old.date);
        }
        if (!isSavings) {
          await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, expense.amount, expense.date);
        }
      }
    });
    state = result.error != null
        ? AsyncValue<void>.error(result.error!, result.stackTrace!)
        : const AsyncValue.data(null);
    return result.error?.toString();
  }

  Future<String?> deleteExpense(String id) async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      final expense = await _repository.getExpense(id);
      await _repository.deleteExpense(id);
      if (expense == null) return;

      if (expense.category == 'Tabungan' || expense.category == 'Savings') {
        if (expense.note != null && expense.note!.isNotEmpty) {
          await _reverseGoalsForExpense(_savingRepo, expense.familyId, expense.note!, expense.amount);
        }
      } else {
        await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, -expense.amount, expense.date);
      }
    });
    state = result.error != null
        ? AsyncValue<void>.error(result.error!, result.stackTrace!)
        : const AsyncValue.data(null);
    return result.error?.toString();
  }
}

final expenseNotifierProvider = StateNotifierProvider<ExpenseNotifier, AsyncValue<void>>((ref) {
  return ExpenseNotifier(
    ref.watch(transactionRepositoryProvider),
    BudgetRepository(dataSource: ref.watch(firestoreDataSourceProvider)),
    SavingRepository(dataSource: ref.watch(firestoreDataSourceProvider)),
  );
});
