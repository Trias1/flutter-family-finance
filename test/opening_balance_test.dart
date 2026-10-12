import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/balance_parser.dart';
import 'package:family_finance_manager/core/services/opening_balance.dart';
import 'package:family_finance_manager/data/models/budget_model.dart';
import 'package:family_finance_manager/data/models/income_model.dart';

void main() {
  const neo = BalanceReading([
    BalanceLine('Total Saldo', 281643.2),
    BalanceLine('Neo NOW', 81416.69),
  ], 'Bank Neo');

  test('a balance becomes money in under Saldo awal, never spending', () {
    final draft = openingBalanceDraft(neo, neo.lines[1], isId: true);
    expect(draft.isIncoming, isTrue);
    expect(draft.amount, 81416.69);
    expect(draft.categoryHint, 'opening_balance');
    expect(draft.noteFor(isId: true), 'Saldo Bank Neo · Neo NOW');
  });

  test('a bare "Saldo" label and an unknown bank keep the note short', () {
    const plain = BalanceReading([BalanceLine('Saldo', 500000)], null);
    expect(
      openingBalanceDraft(
        plain,
        plain.lines.first,
        isId: true,
      ).noteFor(isId: true),
      'Saldo',
    );
    expect(
      openingBalanceDraft(
        plain,
        plain.lines.first,
        isId: false,
      ).noteFor(isId: false),
      'Balance',
    );
  });

  test('"Untuk" goes in front of the note', () {
    expect(
      noteWithPurpose('Saldo Bank Neo · Neo NOW', 'Transportasi', isId: true),
      'Untuk Transportasi · Saldo Bank Neo · Neo NOW',
    );
    expect(noteWithPurpose('', 'Makanan', isId: false), 'For Makanan');
    expect(noteWithPurpose('Gaji', null, isId: true), 'Gaji');
    expect(noteWithPurpose('', null, isId: true), isNull);
  });

  test('budget from a balance: new budget starts at the balance', () {
    final b = budgetFromBalance(
      familyId: 'f',
      category: 'Transportasi',
      month: '2026-10',
      amount: 200000,
      spent: 15000,
    );
    expect(b.id, '');
    expect(b.budgetAmount, 200000);
    expect(b.usedAmount, 15000);
  });

  test('budget from a balance: existing keeps id, usage and rollover', () {
    final old = BudgetModel(
      id: 'b1',
      familyId: 'f',
      month: '2026-10',
      category: 'Transportasi',
      budgetAmount: 300000,
      usedAmount: 120000,
      rolloverAmount: 5000,
    );
    final b = budgetFromBalance(
      existing: old,
      familyId: 'f',
      category: 'Transportasi',
      month: '2026-10',
      amount: 400000,
      spent: 0,
    );
    expect(b.id, 'b1');
    expect(b.budgetAmount, 400000);
    expect(b.usedAmount, 120000);
    expect(b.rolloverAmount, 5000);
  });

  test('income checkbox is off when this pocket was already recorded', () {
    final now = DateTime(2026, 10, 12);
    const source = 'Saldo Bank Neo · Neo NOW';
    IncomeModel saldo(String note, DateTime date) => IncomeModel(
      id: 'i',
      familyId: 'f',
      userId: 'u',
      amount: 81416.69,
      category: 'Saldo awal',
      note: note,
      date: date,
    );
    expect(
      recordIncomeByDefault([], source: source, amount: 81416.69, now: now),
      isTrue,
    );
    // Same pocket and amount this month, whatever it was for.
    expect(
      recordIncomeByDefault(
        [saldo('Untuk Makanan · $source', DateTime(2026, 10, 3))],
        source: source,
        amount: 81416.69,
        now: now,
      ),
      isFalse,
    );
    expect(
      recordIncomeByDefault(
        [saldo('Untuk Makanan · $source', DateTime(2026, 9, 30))],
        source: source,
        amount: 81416.69,
        now: now,
      ),
      isTrue,
    );
  });

  test('income note names where the money went', () {
    expect(
      openingBalanceNote(
        neo,
        neo.lines[1],
        purpose: 'Transportasi',
        isId: true,
      ),
      'Untuk Transportasi · Saldo Bank Neo · Neo NOW',
    );
  });
}
