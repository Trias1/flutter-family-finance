import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';

enum TransactionType { income, expense }

class TransactionItem {
  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final String userId;

  /// For expenses: the goal it was paid from (or deposited into).
  final String? savingId;

  TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.date,
    required this.createdAt,
    required this.userId,
    this.savingId,
  });
}

class TransactionHistoryNotifier
    extends StateNotifier<AsyncValue<List<TransactionItem>>> {
  final FirestoreDataSource _dataSource;

  TransactionHistoryNotifier(this._dataSource)
    : super(const AsyncValue.data([]));

  Future<void> load(String familyId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final incomes = await _dataSource.getIncomes(familyId);
      final expenses = await _dataSource.getExpenses(familyId);

      final items = <TransactionItem>[
        ...incomes.map(
          (i) => TransactionItem(
            id: i.id,
            type: TransactionType.income,
            amount: i.amount,
            category: i.category,
            note: i.note,
            date: i.date,
            createdAt: i.createdAt,
            userId: i.userId,
          ),
        ),
        ...expenses.map(
          (e) => TransactionItem(
            id: e.id,
            type: TransactionType.expense,
            amount: e.amount,
            category: e.category,
            note: e.note,
            date: e.date,
            createdAt: e.createdAt,
            userId: e.userId,
            savingId: e.savingId,
          ),
        ),
      ];

      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }
}

final transactionHistoryProvider =
    StateNotifierProvider<
      TransactionHistoryNotifier,
      AsyncValue<List<TransactionItem>>
    >((ref) {
      return TransactionHistoryNotifier(ref.watch(firestoreDataSourceProvider));
    });
