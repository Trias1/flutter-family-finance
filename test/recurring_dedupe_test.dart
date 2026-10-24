import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/recurring_service.dart';
import 'package:family_finance_manager/data/models/recurring_model.dart';

void main() {
  RecordedEntry entry(
    DateTime date, {
    double amount = 8400000,
    String category = 'Gaji',
    String? recurringId,
  }) => (
    date: date,
    amount: amount,
    category: category,
    recurringId: recurringId,
  );

  bool recorded(
    List<RecordedEntry> existing, {
    RecurringFrequency frequency = RecurringFrequency.monthly,
    DateTime? due,
  }) => RecurringService.alreadyRecorded(
    frequency: frequency,
    due: due ?? DateTime(2026, 6, 28),
    category: 'Gaji',
    amount: 8400000,
    existing: existing,
  );

  test('a salary entered by hand that month is not added again', () {
    // The case seen in production: Gaji entered on 26 June for the 28th.
    expect(recorded([entry(DateTime(2026, 6, 28))]), isTrue);
    expect(recorded([entry(DateTime(2026, 6, 25))]), isTrue);
    expect(recorded([entry(DateTime(2026, 6, 28), category: ' gaji ')]), isTrue);
  });

  test('other months, categories or amounts do not count', () {
    expect(recorded([entry(DateTime(2026, 5, 28))]), isFalse);
    expect(recorded([entry(DateTime(2026, 6, 28), category: 'Bonus')]), isFalse);
    expect(recorded([entry(DateTime(2026, 6, 28), amount: 600000)]), isFalse);
    expect(recorded([]), isFalse);
  });

  test("the template's own records never block it", () {
    expect(
      recorded([entry(DateTime(2026, 6, 28), recurringId: 'abc')]),
      isFalse,
    );
  });

  test('weekly allows a few days either way, daily only the same day', () {
    final due = DateTime(2026, 10, 10);
    expect(
      recorded(
        [entry(DateTime(2026, 10, 8))],
        frequency: RecurringFrequency.weekly,
        due: due,
      ),
      isTrue,
    );
    expect(
      recorded(
        [entry(DateTime(2026, 10, 5))],
        frequency: RecurringFrequency.weekly,
        due: due,
      ),
      isFalse,
    );
    expect(
      recorded(
        [entry(DateTime(2026, 10, 9))],
        frequency: RecurringFrequency.daily,
        due: due,
      ),
      isFalse,
    );
    expect(
      recorded(
        [entry(DateTime(2026, 10, 10, 20))],
        frequency: RecurringFrequency.daily,
        due: due,
      ),
      isTrue,
    );
  });
}
