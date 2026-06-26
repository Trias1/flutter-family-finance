import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/wallet_model.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/data/repositories/transaction_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/income/presentation/providers/income_provider.dart';

final expenseStreamProvider = StreamProvider.family<List<ExpenseModel>, String>((ref, familyId) {
  return ref.watch(transactionRepositoryProvider).streamExpenses(familyId).map(
    (snapshot) {
      final list = snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    },
  );
});

String _monthKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

Future<void> _updateBudgetForExpense(BudgetRepository budgetRepo, String familyId, String category, double amount, DateTime date) async {
  // Skip budget update for savings-related transactions
  if (category == 'Tabungan' || category == 'Savings') return;
  
  final month = _monthKey(date);
  final budgets = await budgetRepo.getBudgetsByMonth(familyId, month);
  final match = budgets.where((b) => b.category == category).firstOrNull;
  if (match == null) return;
  final updated = BudgetModel(
    id: match.id,
    familyId: match.familyId,
    month: match.month,
    category: match.category,
    budgetAmount: match.budgetAmount,
    usedAmount: match.usedAmount + amount,
  );
  await budgetRepo.updateBudget(updated);
}

class ExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final TransactionRepository _repository;
  final BudgetRepository _budgetRepo;
  final FirestoreDataSource _dataSource;

  ExpenseNotifier(this._repository, this._budgetRepo, this._dataSource) : super(const AsyncValue.data(null));

  Future<void> addExpense(ExpenseModel expense) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.createExpense(expense);
      await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, expense.amount, expense.date);
      if (expense.walletId != null) {
        await _adjustWallet(expense.walletId!, -expense.amount);
      }
    });
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final old = await _repository.getExpense(expense.id);
      await _repository.updateExpense(expense);
      if (old == null) return;
      
      // Skip budget update for savings-related transactions
      final isOldSavings = old.category == 'Tabungan' || old.category == 'Savings';
      final isNewSavings = expense.category == 'Tabungan' || expense.category == 'Savings';
      
      if (old.category == expense.category) {
        if (!isNewSavings) {
          final diff = expense.amount - old.amount;
          if (diff != 0) await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, diff, expense.date);
        }
      } else {
        if (!isOldSavings) {
          await _updateBudgetForExpense(_budgetRepo, expense.familyId, old.category, -old.amount, old.date);
        }
        if (!isNewSavings) {
          await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, expense.amount, expense.date);
        }
      }
    });
  }

  Future<void> deleteExpense(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final expense = await _repository.getExpense(id);
      await _repository.deleteExpense(id);
      if (expense != null) {
        // Skip budget update for savings-related transactions
        if (expense.category != 'Tabungan' && expense.category != 'Savings') {
          await _updateBudgetForExpense(_budgetRepo, expense.familyId, expense.category, -expense.amount, expense.date);
        }
        if (expense.walletId != null) {
          await _adjustWallet(expense.walletId!, expense.amount);
        }
      }
    });
  }

  Future<void> _adjustWallet(String walletId, double amount) async {
    final wallet = await _dataSource.getWallet(walletId);
    if (wallet == null) return;
    await _dataSource.updateWallet(WalletModel(
      id: wallet.id,
      familyId: wallet.familyId,
      name: wallet.name,
      type: wallet.type,
      balance: wallet.balance + amount,
      icon: wallet.icon,
      colorHex: wallet.colorHex,
      createdAt: wallet.createdAt,
    ));
  }
}

final expenseNotifierProvider = StateNotifierProvider<ExpenseNotifier, AsyncValue<void>>((ref) {
  return ExpenseNotifier(
    ref.watch(transactionRepositoryProvider),
    BudgetRepository(dataSource: ref.watch(firestoreDataSourceProvider)),
    ref.watch(firestoreDataSourceProvider),
  );
});
