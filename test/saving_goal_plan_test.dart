import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';

SavingModel goal({
  double target = 12000000,
  double current = 0,
  required DateTime created,
  required DateTime due,
  bool yearly = false,
  SavingCategory category = SavingCategory.rent,
}) => SavingModel(
  id: 'g',
  familyId: 'f',
  name: 'Kontrakan',
  targetAmount: target,
  currentAmount: current,
  targetDate: due,
  createdAt: created,
  repeatYearly: yearly,
  category: category,
);

void main() {
  final now = DateTime(2026, 10, 11);

  test('monthly amount spreads what is left over the months left', () {
    final g = goal(
      current: 3000000,
      created: DateTime(2026, 1, 1),
      due: DateTime(2027, 4, 11),
    );
    expect(g.monthsLeft(now), 6);
    expect(g.monthlyNeeded(now), 1500000);
  });

  test('a reached or overdue goal never asks for more than what is left', () {
    final reached = goal(
      current: 12000000,
      created: DateTime(2026, 1, 1),
      due: DateTime(2027, 1, 1),
    );
    expect(reached.monthlyNeeded(now), 0);
    final overdue = goal(
      current: 2000000,
      created: DateTime(2025, 1, 1),
      due: DateTime(2026, 9, 1),
    );
    expect(overdue.monthsLeft(now), 1);
    expect(overdue.monthlyNeeded(now), 10000000);
  });

  test('on track compares with an even pace from the start date', () {
    final g = goal(
      created: DateTime(2026, 1, 1),
      due: DateTime(2027, 1, 1),
      current: 9000000,
    );
    // 283 of 365 days have passed: about 9.3 jt expected by now.
    expect(g.expectedByNow(now), closeTo(9304110, 1));
    expect(g.currentAmount < g.expectedByNow(now), isTrue);
  });

  test('a yearly goal moves to its next date once the date passes', () {
    final g = goal(
      created: DateTime(2025, 6, 1),
      due: DateTime(2026, 6, 1),
      yearly: true,
    );
    expect(g.nextYearlyDate(now), DateTime(2027, 6, 1));
    final notYet = goal(
      created: DateTime(2026, 1, 1),
      due: DateTime(2026, 12, 1),
      yearly: true,
    );
    expect(notYet.nextYearlyDate(now), isNull);
    final oneOff = goal(
      created: DateTime(2025, 1, 1),
      due: DateTime(2026, 6, 1),
    );
    expect(oneOff.nextYearlyDate(now), isNull);
  });

  test('copyWith keeps category, yearly repeat and the start date', () {
    final g = goal(
      created: DateTime(2026, 1, 1),
      due: DateTime(2027, 1, 1),
      yearly: true,
      category: SavingCategory.hajj,
    );
    final updated = g.copyWith(currentAmount: 3000000);
    expect(updated.category, SavingCategory.hajj);
    expect(updated.repeatYearly, isTrue);
    expect(updated.createdAt, DateTime(2026, 1, 1));
    expect(updated.toFirestore()['category'], 'hajj');
    expect(updated.toFirestore()['repeatYearly'], isTrue);
  });
}
