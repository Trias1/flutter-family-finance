import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/expense_effects.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';

ExpenseModel exp(
  double amount,
  String category, {
  String? note,
  String? savingId,
}) => ExpenseModel(
  id: 'e',
  familyId: 'f',
  userId: 'u',
  amount: amount,
  category: category,
  note: note,
  savingId: savingId,
  date: DateTime(2026, 10, 12),
);

SavingModel goal(String id, String name, double current) => SavingModel(
  id: id,
  familyId: 'f',
  name: name,
  targetAmount: 10000000,
  currentAmount: current,
  targetDate: DateTime(2027, 1, 1),
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  test('budget expense: cuts the budget of its category only', () {
    final fx = effectsOf(exp(50000, 'Transportasi'));
    expect(fx.budgetCategory, 'Transportasi');
    expect(fx.budgetDelta, 50000);
    expect(fx.savingId, isNull);
    expect(fx.goalNote, isNull);
  });

  test('paid from savings: goal goes down, budget untouched', () {
    final fx = effectsOf(exp(80000, 'Makanan', savingId: 'g1'));
    expect(fx.budgetCategory, isNull);
    expect(fx.savingId, 'g1');
    expect(fx.goalDelta, -80000);
  });

  test('deposit with a goal id: goal goes up', () {
    final fx = effectsOf(exp(100000, 'Tabungan', savingId: 'g1'));
    expect(fx.savingId, 'g1');
    expect(fx.goalDelta, 100000);
    expect(fx.budgetCategory, isNull);
  });

  test('old deposit without id: goal found by name in the note', () {
    final fx = effectsOf(exp(100000, 'Tabungan', note: 'Setor Neo NOW'));
    expect(fx.savingId, isNull);
    expect(fx.goalNote, 'Setor Neo NOW');
    expect(fx.goalDelta, 100000);
    final g = legacyGoalFor('Setor Neo NOW', [
      goal('a', 'Haji', 0),
      goal('b', 'Neo NOW', 0),
    ]);
    expect(g?.id, 'b');
  });

  test('reversed undoes every effect (delete / first half of edit)', () {
    final old = effectsOf(exp(100000, 'Tabungan', note: 'Neo NOW')).reversed;
    expect(old.goalDelta, -100000);
    expect(old.goalNote, 'Neo NOW');
    final budget = effectsOf(exp(50000, 'Transportasi')).reversed;
    expect(budget.budgetDelta, -50000);
  });

  test('edit Budget -> Tabungan: budget gets money back, goal pays', () {
    final undo = effectsOf(exp(50000, 'Transportasi')).reversed;
    final redo = effectsOf(exp(50000, 'Transportasi', savingId: 'g1'));
    expect(undo.budgetCategory, 'Transportasi');
    expect(undo.budgetDelta, -50000);
    expect(redo.budgetCategory, isNull);
    expect(redo.goalDelta, -50000);
  });

  test('a goal never goes below zero', () {
    expect(goalAmountAfter(30000, -50000), 0);
    expect(goalAmountAfter(30000, 20000), 50000);
  });

  test(
    'cannot pay more than the goal holds (editing counts the old amount)',
    () {
      final g = goal('g1', 'Neo NOW', 50000);
      expect(canPayFromGoal(g, 50000), isTrue);
      expect(canPayFromGoal(g, 80000), isFalse);
      final old = exp(40000, 'Makanan', savingId: 'g1');
      expect(canPayFromGoal(g, 80000, editing: old), isTrue); // 50k + 40k back
      final other = exp(40000, 'Makanan', savingId: 'g2');
      expect(canPayFromGoal(g, 80000, editing: other), isFalse);
    },
  );

  test('savingId round-trips through Firestore data', () {
    final data = exp(1000, 'Makanan', savingId: 'g1').toFirestore();
    expect(data['savingId'], 'g1');
    // Written as null too: an edit back to Budget must clear the old link
    // (Firestore update() keeps fields that are left out).
    final cleared = exp(1000, 'Makanan').toFirestore();
    expect(cleared.containsKey('savingId'), isTrue);
    expect(cleared['savingId'], isNull);
  });

  test('only budget-paid expenses count as budget spending', () {
    final list = [
      exp(50000, 'Transportasi'),
      exp(30000, 'Transportasi', savingId: 'g1'),
      exp(20000, 'Makanan'),
    ];
    expect(budgetSpent(list, 'Transportasi', '2026-10'), 50000);
  });

  test('goal history: linked by id, or old Tabungan entries naming it', () {
    final g = goal('g1', 'Neo NOW', 0);
    expect(belongsToGoal(exp(1, 'Makanan', savingId: 'g1'), g), isTrue);
    expect(belongsToGoal(exp(1, 'Tabungan', savingId: 'g1'), g), isTrue);
    expect(belongsToGoal(exp(1, 'Tabungan', savingId: 'g2'), g), isFalse);
    expect(belongsToGoal(exp(1, 'Tabungan', note: 'setor neo now'), g), isTrue);
    expect(belongsToGoal(exp(1, 'Tabungan', note: 'Haji'), g), isFalse);
    expect(belongsToGoal(exp(1, 'Makanan', note: 'Neo NOW'), g), isFalse);
  });

  test('undoing a deposit that was already spent is refused', () {
    // Deposit 100k into the goal, then 100k paid from it: goal is at 0.
    final undo = effectsOf(exp(100000, 'Tabungan', savingId: 'g1')).reversed;
    expect(overdrawnGoal([undo], [goal('g1', 'Neo NOW', 0)]), 'Neo NOW');
    expect(overdrawnGoal([undo], [goal('g1', 'Neo NOW', 100000)]), isNull);
    // An edit counts the net change: 50k - 100k + 60k = 10k left.
    final redo = effectsOf(exp(60000, 'Tabungan', savingId: 'g1'));
    expect(overdrawnGoal([undo, redo], [goal('g1', 'Neo NOW', 50000)]), isNull);
    // Old entries matched by name are checked the same way.
    final legacy = effectsOf(exp(100000, 'Tabungan', note: 'Neo NOW')).reversed;
    expect(overdrawnGoal([legacy], [goal('g1', 'Neo NOW', 0)]), 'Neo NOW');
  });

  test('overall balance: money left the wallet once, at the deposit', () {
    // Deposit 1jt into a goal, then 1jt paid from it: the wallet lost 1jt.
    final list = [
      exp(1000000, 'Tabungan', savingId: 'g1'),
      exp(1000000, 'Makanan', savingId: 'g1'),
      exp(50000, 'Transportasi'),
    ];
    expect(walletSpent(list), 1050000);
  });

  test('budget sheet lists only budget-paid spending of that month', () {
    final list = [
      exp(50000, 'Transportasi'),
      exp(30000, 'Transportasi', savingId: 'g1'),
      ExpenseModel(
        id: 'x',
        familyId: 'f',
        userId: 'u',
        amount: 9,
        category: 'Transportasi',
        date: DateTime(2026, 9, 30),
      ),
    ];
    final rows = budgetExpenses(list, 'Transportasi', '2026-10');
    expect(rows.map((e) => e.amount), [50000]);
  });
}
