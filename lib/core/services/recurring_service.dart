import 'package:family_finance_manager/data/datasources/firestore_datasource.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';
import 'package:family_finance_manager/data/models/recurring_model.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';

/// Turns due recurring entries into real income/expense records.
///
/// Runs for the signed-in user only (the rules let each person write their
/// own records), and each occurrence gets a fixed document id, so running on
/// two phones or twice in a row never creates duplicates. An occurrence the
/// user already entered by hand (see [alreadyRecorded]) is skipped.
/// What [RecurringService.alreadyRecorded] needs from an income or expense.
typedef RecordedEntry = ({
  DateTime date,
  double amount,
  String category,
  String? recurringId,
});

class RecurringService {
  static final RecurringService _instance = RecurringService._();
  factory RecurringService() => _instance;
  RecurringService._();

  final FirestoreDataSource _dataSource = FirestoreDataSource();
  late final BudgetRepository _budgetRepo = BudgetRepository(
    dataSource: _dataSource,
  );

  // Missed periods are caught up, but never more than this many at once.
  static const _maxCatchUp = 24;
  bool _running = false;

  Future<void> checkAndGenerate({
    required String scopeId,
    required String uid,
  }) async {
    if (_running || scopeId.isEmpty || uid.isEmpty) return;
    _running = true;
    try {
      final due = await _dataSource.getDueRecurrings(scopeId);
      for (final recurring in due.where((r) => r.userId == uid)) {
        await _catchUp(recurring);
      }
    } catch (_) {
      // Try again on the next run; nothing is half-written per occurrence.
    } finally {
      _running = false;
    }
  }

  Future<void> _catchUp(RecurringModel recurring) async {
    var current = recurring;
    final now = DateTime.now();
    List<RecordedEntry>? existing;
    for (var i = 0; i < _maxCatchUp && !current.nextDate.isAfter(now); i++) {
      if (current.endDate != null &&
          current.nextDate.isAfter(current.endDate!)) {
        await _dataSource.updateRecurring(_copy(current, isActive: false));
        return;
      }
      existing ??= await _recorded(recurring);
      if (!alreadyRecorded(
        frequency: current.frequency,
        due: current.nextDate,
        category: current.category,
        amount: current.amount,
        existing: existing,
      )) {
        await _generate(current);
      }
      current = _copy(
        current,
        nextDate: current.calculateNextDate(),
        lastGeneratedDate: now,
      );
      await _dataSource.updateRecurring(current);
    }
  }

  /// Records in the same scope and of the same type, loaded once per
  /// template.
  Future<List<RecordedEntry>> _recorded(RecurringModel r) async {
    if (r.type == 'income') {
      return [
        for (final i in await _dataSource.getIncomes(r.familyId))
          (
            date: i.date,
            amount: i.amount,
            category: i.category,
            recurringId: i.recurringId,
          ),
      ];
    }
    return [
      for (final e in await _dataSource.getExpenses(r.familyId))
        (
          date: e.date,
          amount: e.amount,
          category: e.category,
          recurringId: e.recurringId,
        ),
    ];
  }

  /// Whether the user already entered this occurrence by hand: a record
  /// not made by a recurring template, with the same category and amount,
  /// in the same period as [due] (same day for daily, within three days for
  /// weekly, same month for monthly and yearly). A salary noted on the 25th
  /// then stops the template from adding another on the 28th.
  static bool alreadyRecorded({
    required RecurringFrequency frequency,
    required DateTime due,
    required String category,
    required double amount,
    required Iterable<RecordedEntry> existing,
  }) {
    bool samePeriod(DateTime d) => switch (frequency) {
      RecurringFrequency.daily =>
        d.year == due.year && d.month == due.month && d.day == due.day,
      RecurringFrequency.weekly =>
        DateTime(d.year, d.month, d.day)
                .difference(DateTime(due.year, due.month, due.day))
                .inDays
                .abs() <=
            3,
      RecurringFrequency.monthly ||
      RecurringFrequency.yearly => d.year == due.year && d.month == due.month,
    };
    final want = category.trim().toLowerCase();
    return existing.any(
      (e) =>
          e.recurringId == null &&
          e.category.trim().toLowerCase() == want &&
          (e.amount - amount).abs() < 0.5 &&
          samePeriod(e.date),
    );
  }

  Future<void> _generate(RecurringModel r) async {
    final d = r.nextDate;
    final id =
        'rec_${r.id}_${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    if (r.type == 'income') {
      await _dataSource.setIncomeWithId(
        id,
        IncomeModel(
          id: id,
          familyId: r.familyId,
          userId: r.userId,
          amount: r.amount,
          category: r.category,
          note: r.note,
          recurringId: r.id,
          date: d,
        ),
      );
    } else {
      await _dataSource.setExpenseWithId(
        id,
        ExpenseModel(
          id: id,
          familyId: r.familyId,
          userId: r.userId,
          amount: r.amount,
          category: r.category,
          note: r.note,
          recurringId: r.id,
          date: d,
        ),
      );
      // Generated spending counts against the budget like any other.
      await _budgetRepo.applyExpense(r.familyId, r.category, r.amount, d);
    }
  }

  RecurringModel _copy(
    RecurringModel r, {
    DateTime? nextDate,
    DateTime? lastGeneratedDate,
    bool? isActive,
  }) {
    return RecurringModel(
      id: r.id,
      familyId: r.familyId,
      userId: r.userId,
      type: r.type,
      amount: r.amount,
      category: r.category,
      note: r.note,
      frequency: r.frequency,
      interval: r.interval,
      dayOfMonth: r.dayOfMonth,
      dayOfWeek: r.dayOfWeek,
      startDate: r.startDate,
      endDate: r.endDate,
      nextDate: nextDate ?? r.nextDate,
      lastGeneratedDate: lastGeneratedDate ?? r.lastGeneratedDate,
      isActive: isActive ?? r.isActive,
      createdAt: r.createdAt,
    );
  }
}
