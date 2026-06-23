import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/recurring_model.dart';

class RecurringService {
  static final RecurringService _instance = RecurringService._();
  factory RecurringService() => _instance;
  RecurringService._();

  final FirestoreDataSource _dataSource = FirestoreDataSource();

  Future<void> checkAndGenerate() async {
    try {
      final due = await _dataSource.getDueRecurrings();
      for (final recurring in due) {
        await _generateTransaction(recurring);
      }
    } catch (_) {}
  }

  Future<void> _generateTransaction(RecurringModel recurring) async {
    if (recurring.endDate != null && recurring.nextDate.isAfter(recurring.endDate!)) {
      await _dataSource.updateRecurring(RecurringModel(
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
        isActive: false,
        createdAt: recurring.createdAt,
      ));
      return;
    }

    final now = DateTime.now();
    if (recurring.type == 'income') {
      await _dataSource.createIncome(IncomeModel(
        id: '',
        familyId: recurring.familyId,
        userId: recurring.userId,
        amount: recurring.amount,
        category: recurring.category,
        note: recurring.note,
        recurringId: recurring.id,
        date: recurring.nextDate,
      ));
    } else {
      await _dataSource.createExpense(ExpenseModel(
        id: '',
        familyId: recurring.familyId,
        userId: recurring.userId,
        amount: recurring.amount,
        category: recurring.category,
        note: recurring.note,
        recurringId: recurring.id,
        date: recurring.nextDate,
      ));
    }

    final nextDate = recurring.calculateNextDate();
    await _dataSource.updateRecurring(RecurringModel(
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
      nextDate: nextDate,
      lastGeneratedDate: now,
      isActive: true,
      createdAt: recurring.createdAt,
    ));
  }
}
