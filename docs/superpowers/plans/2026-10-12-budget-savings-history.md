# Budget & Tabungan dari scan (Bagian 1–3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A balance screenshot goes to a Budget or a savings goal (optionally also recorded as "Saldo awal" income, never as spending); expenses can be paid from Budget or from a goal; goals and budgets show their own history.

**Architecture:** One pure function (`effectsOf`) says what an expense does to budgets and goals; the expense notifier applies it on add, applies the reverse on delete, and both on edit. `ExpenseModel` gets an optional `savingId` that links an expense to a goal by id (old entries keep the note-name match). The balance dialog returns a choice; `main_shell` routes it to the budget or goal and saves the income directly.

**Tech Stack:** Flutter 3.44, Riverpod (StateNotifier/StreamProvider), Cloud Firestore, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-12-budget-savings-bills-design.md` (Bagian 1–3; Bagian 4 Tagihan and 5 Utang are not in this plan)

## Global Constraints

- A balance read from a screenshot is never recorded as an expense.
- Budget usage changes only through recorded expenses; no automatic expense from a balance difference.
- `savingId` on an expense: category Tabungan/Savings = deposit (goal +amount); any other category = paid from savings (goal −amount, budget untouched); no `savingId` = today's behaviour (budget per category; legacy Tabungan matched by goal name in the note).
- A goal balance never goes below 0.
- No Firestore rules change (`/expenses` and `/budgets` have no key whitelist).
- Run shell commands from `D:/project-pribadi/fluter` in Git Bash; tests: `flutter test <file>`; analyzer: `flutter analyze <paths>` (pre-existing warnings in unrelated files are known).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- UI text is Indonesian with English fallback via `isId` like the surrounding code.

## Review Focus

1. Editing an old (pre-`savingId`) Tabungan expense must undo its old note-matched goal effect before applying the new one — test in Task 1.
2. Editing an expense from Budget to Tabungan (or back) must give the budget back and take from the goal — test in Task 1.
3. Paying from a goal more than its balance must be refused in the form, so deleting it later cannot inflate the goal — test in Task 1 (`canPayFromGoal`), validator in Task 3.
4. Scanning the same pocket again with "also record as income" on would double "In" — the checkbox defaults off when an identical Saldo awal income already exists this month — test in Task 4.
5. Cancelling the "Ganti / Update nominal" prompt for an existing budget must save nothing (no budget change, no income) — manual check in Task 4 Step 7.

---

### Task 1: Expense effects (pure) and `ExpenseModel.savingId`

**Files:**
- Modify: `lib/data/models/expense_model.dart` (field, constructor, `fromFirestore`, `toFirestore`)
- Create: `lib/core/services/expense_effects.dart`
- Test: `test/expense_effects_test.dart`

**Interfaces:**
- Produces:
  - `ExpenseModel.savingId` (`String?`), read from / written to Firestore key `savingId`.
  - `bool isSavingsDeposit(String category)`
  - `class ExpenseEffects { String? budgetCategory; double budgetDelta; DateTime date; String? savingId; String? goalNote; double goalDelta; ExpenseEffects get reversed; }`
  - `ExpenseEffects effectsOf(ExpenseModel e)`
  - `double goalAmountAfter(double current, double delta)`
  - `SavingModel? legacyGoalFor(String note, List<SavingModel> goals)`
  - `bool canPayFromGoal(SavingModel goal, double amount, {ExpenseModel? editing})`

- [ ] **Step 1: Write the failing test**

```dart
// test/expense_effects_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance_manager/core/services/expense_effects.dart';
import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';

ExpenseModel exp(double amount, String category, {String? note, String? savingId}) =>
    ExpenseModel(
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
    final g = legacyGoalFor('Setor Neo NOW', [goal('a', 'Haji', 0), goal('b', 'Neo NOW', 0)]);
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

  test('cannot pay more than the goal holds (editing counts the old amount)', () {
    final g = goal('g1', 'Neo NOW', 50000);
    expect(canPayFromGoal(g, 50000), isTrue);
    expect(canPayFromGoal(g, 80000), isFalse);
    final old = exp(40000, 'Makanan', savingId: 'g1');
    expect(canPayFromGoal(g, 80000, editing: old), isTrue); // 50k + 40k back
    final other = exp(40000, 'Makanan', savingId: 'g2');
    expect(canPayFromGoal(g, 80000, editing: other), isFalse);
  });

  test('savingId round-trips through Firestore data', () {
    final data = exp(1000, 'Makanan', savingId: 'g1').toFirestore();
    expect(data['savingId'], 'g1');
    expect(exp(1000, 'Makanan').toFirestore().containsKey('savingId'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/expense_effects_test.dart`
Expected: FAIL — `expense_effects.dart` not found / `savingId` not a parameter.

- [ ] **Step 3: Add `savingId` to `ExpenseModel`**

In `lib/data/models/expense_model.dart`:
- add field `final String? savingId;` after `recurringId`, with a doc comment `/// The goal this expense pays from (or deposits into, for Tabungan).`
- constructor: `this.savingId,` after `this.recurringId,`
- `fromFirestore`: `savingId: data['savingId'],`
- `toFirestore`: add `if (savingId != null) 'savingId': savingId,` (omit when null so old documents and rules stay as they are).

- [ ] **Step 4: Write `expense_effects.dart`**

```dart
// lib/core/services/expense_effects.dart
import 'dart:math' as math;

import 'package:family_finance_manager/data/models/expense_model.dart';
import 'package:family_finance_manager/data/models/saving_model.dart';

/// Money put into savings, not spending.
bool isSavingsDeposit(String category) =>
    category == 'Tabungan' || category == 'Savings';

/// What one expense does to budgets and goals while it exists. Adding an
/// expense applies it, deleting applies [reversed], editing applies the old
/// one reversed and then the new one.
class ExpenseEffects {
  /// Budget of this category (in the month of [date]) changes by
  /// [budgetDelta]; null when no budget is touched.
  final String? budgetCategory;
  final double budgetDelta;
  final DateTime date;

  /// Goal by id; or, for entries made before goals were linked by id, the
  /// goal whose name is in [goalNote]. Either changes by [goalDelta].
  final String? savingId;
  final String? goalNote;
  final double goalDelta;

  const ExpenseEffects({
    required this.date,
    this.budgetCategory,
    this.budgetDelta = 0,
    this.savingId,
    this.goalNote,
    this.goalDelta = 0,
  });

  ExpenseEffects get reversed => ExpenseEffects(
    date: date,
    budgetCategory: budgetCategory,
    budgetDelta: -budgetDelta,
    savingId: savingId,
    goalNote: goalNote,
    goalDelta: -goalDelta,
  );
}

ExpenseEffects effectsOf(ExpenseModel e) {
  final id = e.savingId;
  if (id != null && id.isNotEmpty) {
    return ExpenseEffects(
      date: e.date,
      savingId: id,
      goalDelta: isSavingsDeposit(e.category) ? e.amount : -e.amount,
    );
  }
  if (isSavingsDeposit(e.category)) {
    final note = e.note?.trim();
    return ExpenseEffects(
      date: e.date,
      goalNote: note == null || note.isEmpty ? null : note,
      goalDelta: e.amount,
    );
  }
  return ExpenseEffects(
    date: e.date,
    budgetCategory: e.category,
    budgetDelta: e.amount,
  );
}

double goalAmountAfter(double current, double delta) =>
    math.max(0, current + delta).toDouble();

/// Old entries named the goal in the note ("Setor Neo NOW").
SavingModel? legacyGoalFor(String note, List<SavingModel> goals) {
  final lower = note.toLowerCase();
  for (final g in goals) {
    if (lower.contains(g.name.toLowerCase())) return g;
  }
  return null;
}

/// Whether [goal] holds [amount] to pay with. When [editing] an expense
/// that already paid from this goal, its old amount counts as available.
bool canPayFromGoal(SavingModel goal, double amount, {ExpenseModel? editing}) {
  final back = editing != null &&
          editing.savingId == goal.id &&
          !isSavingsDeposit(editing.category)
      ? editing.amount
      : 0.0;
  return amount <= goal.currentAmount + back;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/expense_effects_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/expense_model.dart lib/core/services/expense_effects.dart test/expense_effects_test.dart
git commit -m "feat(android): expenses can link a goal by id (effects in one place)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Apply effects in `ExpenseNotifier`; budgets ignore savings-paid spending

**Files:**
- Modify: `lib/features/expense/presentation/providers/expense_provider.dart` (replace `_updateGoalsForExpense`, `_reverseGoalsForExpense` and the add/update/delete bodies)
- Modify: `lib/data/repositories/budget_repository.dart:62-72` (`spentInMonth`)
- Test: `test/expense_effects_test.dart` (one more case)

**Interfaces:**
- Consumes: `effectsOf`, `ExpenseEffects.reversed`, `goalAmountAfter`, `legacyGoalFor` (Task 1).
- Produces: `ExpenseNotifier.addExpense/updateExpense/deleteExpense` keep their signatures (`Future<String?>`).

- [ ] **Step 1: Add the failing test for budget spending**

Append to `test/expense_effects_test.dart` inside `main()`:

```dart
  test('only budget-paid expenses count as budget spending', () {
    final list = [
      exp(50000, 'Transportasi'),
      exp(30000, 'Transportasi', savingId: 'g1'),
      exp(20000, 'Makanan'),
    ];
    expect(budgetSpent(list, 'Transportasi', '2026-10'), 50000);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/expense_effects_test.dart`
Expected: FAIL — `budgetSpent` not defined.

- [ ] **Step 3: Implement `budgetSpent` and use it in `spentInMonth`**

Add to `lib/core/services/expense_effects.dart`:

```dart
/// What the budget of [category] in [month] ("2026-10") has used: expenses
/// that cut a budget (not deposits, not paid from savings).
double budgetSpent(List<ExpenseModel> expenses, String category, String month) {
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  return expenses
      .map(effectsOf)
      .where((fx) => fx.budgetCategory == category && key(fx.date) == month)
      .fold<double>(0, (sum, fx) => sum + fx.budgetDelta);
}
```

Replace the body of `BudgetRepository.spentInMonth` (`lib/data/repositories/budget_repository.dart`):

```dart
  Future<double> spentInMonth(
    String familyId,
    String category,
    String month,
  ) async {
    if (isSavingsCategory(category)) return 0;
    final expenses = await _dataSource.getExpenses(familyId);
    return budgetSpent(expenses, category, month);
  }
```
(add `import 'package:family_finance_manager/core/services/expense_effects.dart';`).

- [ ] **Step 4: Rewrite the notifier around effects**

In `expense_provider.dart`, delete `_updateGoalsForExpense` and `_reverseGoalsForExpense`, keep `_updateBudgetForExpense`, and add inside `ExpenseNotifier`:

```dart
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
```

Then the three methods' guarded bodies become:

```dart
  // addExpense
      await _repository.createExpense(expense);
      await _apply(expense.familyId, effectsOf(expense));

  // updateExpense
      final old = await _repository.getExpense(expense.id);
      await _repository.updateExpense(expense);
      if (old == null) return;
      await _apply(expense.familyId, effectsOf(old).reversed);
      await _apply(expense.familyId, effectsOf(expense));

  // deleteExpense
      final expense = await _repository.getExpense(id);
      await _repository.deleteExpense(id);
      if (expense == null) return;
      await _apply(expense.familyId, effectsOf(expense).reversed);
```

Keep the `state = ...` / `return result.error?.toString();` lines unchanged. Imports: add `expense_effects.dart`; `saving_model.dart` import becomes unused — remove it.

Also update `lib/data/repositories/transaction_repository.dart` / datasource only if `getExpense` builds `ExpenseModel` without `fromFirestore` (check: `grep -n "ExpenseModel(" lib/data`); every construction from Firestore must go through `fromFirestore` so `savingId` is kept.

- [ ] **Step 5: Run tests and analyzer**

Run: `flutter test test/expense_effects_test.dart && flutter analyze lib/features/expense lib/data lib/core/services`
Expected: tests PASS (10); analyzer shows no errors (known unused-import/unnecessary-cast warnings elsewhere may remain).

- [ ] **Step 6: Commit**

```bash
git add lib/features/expense/presentation/providers/expense_provider.dart lib/data/repositories/budget_repository.dart lib/core/services/expense_effects.dart test/expense_effects_test.dart
git commit -m "fix(android): expenses move goals and budgets by one rule

Add, edit and delete apply the same effects: budget-paid spending cuts its
budget, savings-paid spending lowers its goal, deposits raise it. Editing
undoes the old effect first, so switching Budget <-> Tabungan or changing
the goal stays correct.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: "Sumber uang" in the expense form; fix "Tarik dari tabungan"

**Files:**
- Modify: `lib/features/expense/presentation/pages/expense_page.dart` (around `selectedSavingId` at :303, the category `onChanged` at :381-385, the goal dropdown at :387-422, the model at :506-516)
- Modify: `lib/features/savings/presentation/pages/savings_page.dart:945-967` (withdraw dialog)

**Interfaces:**
- Consumes: `ExpenseModel.savingId`, `canPayFromGoal`, `isSavingsDeposit` (Task 1).

- [ ] **Step 1: Form state**

Next to `String? selectedSavingId;` (:303):

```dart
    String? selectedSavingId = expense?.savingId;
    // "Sumber uang": paid from a goal instead of a budget.
    bool fromSavings =
        expense?.savingId != null && !isSavingsDeposit(expense!.category);
```

In the category `onChanged` (:381-385) keep the goal when paying from savings:

```dart
                      setSheetState(() {
                        selectedCategory = v ?? categories.first;
                        if (!fromSavings) selectedSavingId = null;
                      });
```

- [ ] **Step 2: The source selector and goal dropdown**

Replace the block `if (selectedCategory == 'Tabungan') ...[ ... ]` (:387-422) with:

```dart
                  if (selectedCategory != 'Tabungan' && savings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text('Budget'),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.savings_outlined),
                          label: Text(isId ? 'Tabungan' : 'Savings'),
                        ),
                      ],
                      selected: {fromSavings},
                      onSelectionChanged: (s) => setSheetState(() {
                        fromSavings = s.first;
                        if (!fromSavings) selectedSavingId = null;
                      }),
                    ),
                  ],
                  if (selectedCategory == 'Tabungan' || fromSavings) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: savings.any((s) => s.id == selectedSavingId)
                          ? selectedSavingId
                          : null,
                      decoration: InputDecoration(
                        labelText: selectedCategory == 'Tabungan'
                            ? (isId ? 'Setor ke tabungan' : 'Deposit into')
                            : (isId ? 'Bayar dari tabungan' : 'Pay from savings'),
                        prefixIcon: const Icon(Icons.savings),
                      ),
                      items: savings
                          .where((s) => !s.isGoldInvestment)
                          .map(
                            (s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(
                                '${s.name} · ${CurrencyFormatter.format(s.currentAmount)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedSavingId = v),
                      validator: (v) {
                        if (v == null) {
                          return isId ? 'Pilih tabungan' : 'Choose a goal';
                        }
                        if (selectedCategory == 'Tabungan') return null;
                        final g = savings.firstWhere((s) => s.id == v);
                        final amount = double.tryParse(amountController.text) ?? 0;
                        return canPayFromGoal(g, amount, editing: expense)
                            ? null
                            : (isId
                                  ? 'Saldo ${g.name} tidak cukup'
                                  : 'Not enough in ${g.name}');
                      },
                    ),
                  ],
```

(The old code wrote the goal name into an empty note so the name match worked; with `savingId` that is no longer needed — do not keep it.)

- [ ] **Step 3: Save the link**

In the `ExpenseModel(...)` at :506-516 add:

```dart
                                savingId:
                                    selectedCategory == 'Tabungan' || fromSavings
                                    ? selectedSavingId
                                    : null,
```

Add imports `core/services/expense_effects.dart` and (if missing) `core/utils/currency_formatter.dart`.

- [ ] **Step 4: Fix "Tarik dari tabungan"**

In `savings_page.dart` withdraw dialog (:945-967) the goal is lowered by `withdrawFromSaving` and then a Tabungan expense whose note contains the goal name raised it again (net 0). A withdrawal moves money out of savings; it is not spending. Delete the `ExpenseModel` construction and the `addExpense` call (from `final fId = ...` through `.addExpense(expense);`, keeping `ref.invalidate(...)` lines — re-declare `final fId = ref.read(financeScopeIdProvider);` before them). Remove imports that become unused (`expense_model.dart`, `expense_provider.dart`) if analyzer flags them.

- [ ] **Step 5: Analyze**

Run: `flutter analyze lib/features/expense lib/features/savings`
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/expense/presentation/pages/expense_page.dart lib/features/savings/presentation/pages/savings_page.dart
git commit -m "feat(android): pay an expense from Budget or from a savings goal

The expense form asks where the money comes from. From a goal, the goal
goes down (refused when it holds too little) and no budget is cut.
Withdrawing from a goal no longer records a Tabungan expense that put the
money straight back.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Balance screenshot -> Budget or Tabungan (+ optional Saldo awal income)

**Files:**
- Modify: `lib/core/services/opening_balance.dart` (add `budgetFromBalance`, `recordIncomeByDefault`, `openingBalanceNote`; remove `isSavingsPurpose`)
- Modify: `test/opening_balance_test.dart`
- Modify: `lib/features/savings/presentation/widgets/balance_sync.dart` (`showBalanceDialog`: actions Batal / Tabungan / Budget + income checkbox; remove `offerGoalForSavings`)
- Create: `lib/features/budget/presentation/widgets/budget_from_balance.dart`
- Modify: `lib/core/widgets/main_shell.dart` (balance branch in `_scanReceipt`)

**Interfaces:**
- Consumes: `BalanceReading`, `BalanceLine` (`balance_parser.dart`), `BudgetModel`, `BudgetRepository.spentInMonth/monthKey`, `IncomeModel`, `incomeNotifierProvider.addIncome`.
- Produces:
  - `enum BalanceAction { cancel, goalUpdated, budget }`
  - `class BalanceChoice { BalanceAction action; BalanceLine line; bool recordIncome; String? goalName; }`
  - `Future<BalanceChoice> showBalanceDialog(BuildContext, WidgetRef, BalanceReading, {SavingModel? preselect, bool allowBudget = true, bool Function(BalanceLine line)? incomeDefault})`
  - `Future<String?> allocateToBudget(BuildContext, WidgetRef, double amount)` → chosen category, or null when cancelled
  - `BudgetModel budgetFromBalance({BudgetModel? existing, required String familyId, required String category, required String month, required double amount, required double spent})`
  - `bool recordIncomeByDefault(List<IncomeModel> incomes, {required String source, required double amount, required DateTime now})`
  - `String openingBalanceNote(BalanceReading r, BalanceLine line, {required String purpose, required bool isId})`

- [ ] **Step 1: Failing tests**

Replace the `isSavingsPurpose` test in `test/opening_balance_test.dart` with:

```dart
  test('budget from a balance: new budget starts at the balance', () {
    final b = budgetFromBalance(
      familyId: 'f', category: 'Transportasi', month: '2026-10',
      amount: 200000, spent: 15000,
    );
    expect(b.id, '');
    expect(b.budgetAmount, 200000);
    expect(b.usedAmount, 15000);
  });

  test('budget from a balance: existing keeps id, usage and rollover', () {
    final old = BudgetModel(
      id: 'b1', familyId: 'f', month: '2026-10', category: 'Transportasi',
      budgetAmount: 300000, usedAmount: 120000, rolloverAmount: 5000,
    );
    final b = budgetFromBalance(
      existing: old, familyId: 'f', category: 'Transportasi',
      month: '2026-10', amount: 400000, spent: 0,
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
      id: 'i', familyId: 'f', userId: 'u', amount: 81416.69,
      category: 'Saldo awal', note: note, date: date,
    );
    expect(recordIncomeByDefault([], source: source, amount: 81416.69, now: now), isTrue);
    // Same pocket and amount this month, whatever it was for.
    expect(
      recordIncomeByDefault([saldo('Untuk Makanan · $source', DateTime(2026, 10, 3))],
          source: source, amount: 81416.69, now: now),
      isFalse,
    );
    expect(
      recordIncomeByDefault([saldo('Untuk Makanan · $source', DateTime(2026, 9, 30))],
          source: source, amount: 81416.69, now: now),
      isTrue,
    );
  });

  test('income note names where the money went', () {
    expect(
      openingBalanceNote(neo, neo.lines[1], purpose: 'Transportasi', isId: true),
      'Untuk Transportasi · Saldo Bank Neo · Neo NOW',
    );
  });
```

Add imports for `budget_model.dart` and `income_model.dart`. (Check `IncomeModel`'s constructor in `lib/data/models/income_model.dart` and match its required parameters.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/opening_balance_test.dart`
Expected: FAIL — `budgetFromBalance` / `recordIncomeByDefault` / `openingBalanceNote` not defined.

- [ ] **Step 3: Implement the helpers**

In `lib/core/services/opening_balance.dart` delete `isSavingsPurpose` and add:

```dart
/// The budget a balance sets: a new one starts at [amount] with what was
/// already [spent] this month; an existing one keeps its id, usage and
/// rollover and only gets the new amount.
BudgetModel budgetFromBalance({
  BudgetModel? existing,
  required String familyId,
  required String category,
  required String month,
  required double amount,
  required double spent,
}) => BudgetModel(
  id: existing?.id ?? '',
  familyId: familyId,
  month: month,
  category: category,
  budgetAmount: amount,
  usedAmount: existing?.usedAmount ?? spent,
  rolloverAmount: existing?.rolloverAmount ?? 0,
);

/// "Also record as income" starts off when this month already has a Saldo
/// awal from the same pocket ([source], e.g. "Saldo Bank Neo · Neo NOW")
/// and amount: a re-scan would double "In".
bool recordIncomeByDefault(
  List<IncomeModel> incomes, {
  required String source,
  required double amount,
  required DateTime now,
}) => !incomes.any(
  (i) =>
      i.category == 'Saldo awal' &&
      (i.note ?? '').endsWith(source) &&
      i.amount == amount &&
      i.date.year == now.year &&
      i.date.month == now.month,
);

/// "Untuk Transportasi · Saldo Bank Neo · Neo NOW".
String openingBalanceNote(
  BalanceReading r,
  BalanceLine line, {
  required String purpose,
  required bool isId,
}) => noteWithPurpose(
  openingBalanceDraft(r, line, isId: isId).noteFor(isId: isId) ?? '',
  purpose,
  isId: isId,
)!;
```

Imports: `budget_model.dart`, `income_model.dart`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/opening_balance_test.dart`
Expected: PASS.

- [ ] **Step 5: Dialog — choose Budget or Tabungan**

In `balance_sync.dart`:
- `enum BalanceAction { cancel, goalUpdated, budget }`; `BalanceChoice` gains `final bool recordIncome;` and `final String? goalName;` (constructor `const BalanceChoice(this.action, this.line, {this.recordIncome = false, this.goalName})`).
- `showBalanceDialog` parameters: replace `fixedLine`/`allowIncome` with `bool allowBudget = true` (goal menu passes `false`) and `bool Function(BalanceLine line)? incomeDefault`. Dialog state: `var recordIncome = incomeDefault?.call(line) ?? true; var touchedIncome = false;` — when the user picks another pocket and has not touched the checkbox, set `recordIncome = incomeDefault?.call(line) ?? true`; the checkbox `onChanged` sets `touchedIncome = true`.
- Content: keep the amount and pocket chips; replace the "Catat pemasukan" hint text with
  - goals radio list under the heading `isId ? 'Tabungan:' : 'Savings:'` (only when goals exist), and
  - when `allowBudget`: `CheckboxListTile(contentPadding: EdgeInsets.zero, value: recordIncome, onChanged: (v) => setState(() => recordIncome = v ?? false), title: Text(isId ? 'Catat juga sebagai pemasukan (Saldo awal)' : 'Also record as income (Saldo awal)'), subtitle: Text(isId ? 'Matikan kalau ini cuma update saldo.' : 'Turn off for a balance update.'))`.
- Actions: `Batal` (→ cancel); `if (goals.isNotEmpty)` `TextButton` "Tabungan"/"Savings" (→ goalUpdated, after `_setGoalBalance`); `if (allowBudget)` `FilledButton` "Budget" (→ budget). With `allowBudget: false` the goal button is a `FilledButton` labelled `Perbarui saldo`.
- Return `BalanceChoice(action, line, recordIncome: allowBudget && recordIncome, goalName: chosen?.name)`.
- Delete `offerGoalForSavings`. `syncGoalFromScreenshot` calls `showBalanceDialog(..., preselect: goal, allowBudget: false)`.

- [ ] **Step 6: `allocateToBudget` and the shell flow**

Create `lib/features/budget/presentation/widgets/budget_from_balance.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_finance_manager/core/locale/locale_provider.dart';
import 'package:family_finance_manager/core/services/opening_balance.dart';
import 'package:family_finance_manager/core/theme/app_theme.dart';
import 'package:family_finance_manager/core/utils/currency_formatter.dart';
import 'package:family_finance_manager/data/repositories/budget_repository.dart';
import 'package:family_finance_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:family_finance_manager/features/budget/presentation/providers/budget_provider.dart';
import 'package:family_finance_manager/features/categories/presentation/providers/category_provider.dart';
import 'package:family_finance_manager/features/dashboard/presentation/providers/dashboard_provider.dart';

/// Puts a balance into this month's budget of a category the user picks.
/// An existing budget asks: replace with the balance, or type a new amount.
/// Returns the category, or null when nothing was saved.
Future<String?> allocateToBudget(
  BuildContext context,
  WidgetRef ref,
  double amount,
) async {
  final isId = ref.read(localeProvider).languageCode == 'id';
  final familyId = ref.read(financeScopeIdProvider);
  final categories = ref
      .read(effectiveExpenseCategoriesProvider(familyId))
      .where((c) => !BudgetRepository.isSavingsCategory(c) && c != 'Lainnya')
      .toList();
  final category = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              isId
                  ? 'Budget untuk ${CurrencyFormatter.format(amount)}'
                  : 'Budget for ${CurrencyFormatter.format(amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final c in categories)
            ListTile(title: Text(c), onTap: () => Navigator.pop(ctx, c)),
        ],
      ),
    ),
  );
  if (category == null || !context.mounted) return null;

  final repo = BudgetRepository(dataSource: ref.read(firestoreDataSourceProvider));
  final month = BudgetRepository.monthKey(DateTime.now());
  final existing = (await repo.getBudgetsByMonth(familyId, month))
      .where((b) => b.category == category)
      .firstOrNull;
  var newAmount = amount;
  if (existing != null) {
    if (!context.mounted) return null;
    final picked = await _askReplaceOrUpdate(context, isId, category, existing.budgetAmount, amount);
    if (picked == null) return null; // cancelled: nothing saved
    newAmount = picked;
  }
  final spent = existing == null ? await repo.spentInMonth(familyId, category, month) : 0.0;
  final model = budgetFromBalance(
    existing: existing,
    familyId: familyId,
    category: category,
    month: month,
    amount: newAmount,
    spent: spent,
  );
  final notifier = ref.read(budgetNotifierProvider.notifier);
  if (existing == null) {
    await notifier.setBudget(model);
  } else {
    await notifier.updateBudget(model);
  }
  ref.invalidate(budgetsByMonthProvider(familyId));
  ref.invalidate(dashboardProvider);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isId
              ? 'Budget $category jadi ${CurrencyFormatter.format(newAmount)}.'
              : '$category budget set to ${CurrencyFormatter.format(newAmount)}.',
        ),
        backgroundColor: AppTheme.incomeColor,
      ),
    );
  }
  return category;
}

/// "Ganti ke saldo sekarang" returns [balance]; "Update nominal" returns the
/// typed amount; cancel returns null.
Future<double?> _askReplaceOrUpdate(
  BuildContext context,
  bool isId,
  String category,
  double current,
  double balance,
) {
  final ctrl = TextEditingController(text: current.toStringAsFixed(0));
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isId ? 'Budget $category sudah ada' : '$category budget exists'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isId
              ? 'Sekarang ${CurrencyFormatter.format(current)}. Ganti ke saldo sekarang, atau isi nominal baru:'
              : 'Now ${CurrencyFormatter.format(current)}. Replace with the balance, or type a new amount:'),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(prefixText: 'Rp ', labelText: isId ? 'Nominal baru' : 'New amount'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isId ? 'Batal' : 'Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, balance),
          child: Text(isId ? 'Ganti ke ${CurrencyFormatter.format(balance)}' : 'Use ${CurrencyFormatter.format(balance)}'),
        ),
        FilledButton(
          onPressed: () {
            final v = CurrencyFormatter.parse(ctrl.text);
            if (v > 0) Navigator.pop(ctx, v);
          },
          child: Text(isId ? 'Update nominal' : 'Update amount'),
        ),
      ],
    ),
  );
}
```

(Verify provider names with `grep -n "budgetNotifierProvider\|budgetsByMonthProvider\|firestoreDataSourceProvider" -r lib | head` and match the imports to where they are declared.)

In `main_shell.dart` `_scanReceipt`, replace the balance branch body with:

```dart
    final reading = BalanceParser.parse(scan.text);
    if (reading != null) {
      final incomes = ref.read(incomeStreamProvider(ref.read(financeScopeIdProvider))).valueOrNull ?? const [];
      final choice = await showBalanceDialog(
        context,
        ref,
        reading,
        incomeDefault: (line) => recordIncomeByDefault(
          incomes,
          source: openingBalanceDraft(reading, line, isId: isId).noteFor(isId: isId) ?? '',
          amount: line.amount,
          now: DateTime.now(),
        ),
      );
      if (!mounted) return;
      String? purpose;
      if (choice.action == BalanceAction.budget) {
        purpose = await allocateToBudget(context, ref, choice.line.amount);
      } else if (choice.action == BalanceAction.goalUpdated) {
        purpose = 'Tabungan ${choice.goalName ?? ''}'.trim();
      }
      if (purpose != null && choice.recordIncome && mounted) {
        await _saveOpeningBalance(choice.line.amount, openingBalanceNote(reading, choice.line, purpose: purpose, isId: isId));
      }
      return; // a balance never becomes spending
    }
```

and add to the shell state:

```dart
  Future<void> _saveOpeningBalance(double amount, String note) async {
    final uid = ref.read(firebaseAuthDataSourceProvider).currentUser?.uid ?? '';
    final fId = ref.read(financeScopeIdProvider);
    final error = await ref.read(incomeNotifierProvider.notifier).addIncome(
      IncomeModel(id: '', familyId: fId, userId: uid, amount: amount, category: 'Saldo awal', note: note, date: DateTime.now()),
    );
    ref.invalidate(incomeStreamProvider(fId));
    ref.invalidate(dashboardProvider);
    if (!mounted) return;
    final isId = ref.read(localeProvider).languageCode == 'id';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null
          ? (isId ? 'Pemasukan Saldo awal tercatat.' : 'Opening balance recorded as income.')
          : (isId ? 'Pemasukan gagal disimpan.' : "Couldn't save the income.")),
      backgroundColor: error == null ? AppTheme.incomeColor : AppTheme.errorColor,
    ));
  }
```

Remove the now-unused `IncomePage.openFromReceipt(... openingBalanceDraft ...)` call and `isSavingsPurpose`/`offerGoalForSavings` uses; fix imports.

- [ ] **Step 7: Analyze, test, manual check**

Run: `flutter analyze lib && flutter test $(ls test/*_test.dart | grep -v widget_test)`
Expected: no errors; all tests pass.
Manual (emulator, test account): share the Neo screenshot → pick Neo NOW → Budget → Transportasi (new) → budget 81.417, income "Untuk Transportasi · Saldo Bank Neo · Neo NOW". Again → Transportasi exists → Batal → nothing changes (Review Focus 5). Again → Update nominal 400.000 → budget 400.000, used unchanged; income checkbox started off (Review Focus 4).

- [ ] **Step 8: Commit**

```bash
git add lib/core/services/opening_balance.dart test/opening_balance_test.dart lib/features/savings/presentation/widgets/balance_sync.dart lib/features/budget/presentation/widgets/budget_from_balance.dart lib/core/widgets/main_shell.dart
git commit -m "feat(android): a balance screenshot fills a budget or a goal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Goal history per goal

**Files:**
- Modify: `lib/core/services/expense_effects.dart` (add `belongsToGoal`)
- Test: `test/expense_effects_test.dart`
- Create: `lib/features/savings/presentation/widgets/goal_history_sheet.dart` (moved from `dashboard_page.dart:861-` `_showSavingHistory`)
- Modify: `lib/features/dashboard/presentation/pages/dashboard_page.dart:789,861-…`
- Modify: `lib/features/savings/presentation/pages/savings_page.dart` (goal card `onTap`)

**Interfaces:**
- Produces: `bool belongsToGoal(ExpenseModel e, SavingModel goal)`; `void showGoalHistory(BuildContext context, {required SavingModel goal, required List<ExpenseModel> expenses, required List<IncomeModel> incomes, required bool isId})`.

- [ ] **Step 1: Failing test**

```dart
  test('goal history: linked by id, or old Tabungan entries naming it', () {
    final g = goal('g1', 'Neo NOW', 0);
    expect(belongsToGoal(exp(1, 'Makanan', savingId: 'g1'), g), isTrue);
    expect(belongsToGoal(exp(1, 'Tabungan', savingId: 'g1'), g), isTrue);
    expect(belongsToGoal(exp(1, 'Tabungan', savingId: 'g2'), g), isFalse);
    expect(belongsToGoal(exp(1, 'Tabungan', note: 'setor neo now'), g), isTrue);
    expect(belongsToGoal(exp(1, 'Tabungan', note: 'Haji'), g), isFalse);
    expect(belongsToGoal(exp(1, 'Makanan', note: 'Neo NOW'), g), isFalse);
  });
```

- [ ] **Step 2: Run** `flutter test test/expense_effects_test.dart` — Expected: FAIL (`belongsToGoal` undefined).

- [ ] **Step 3: Implement**

```dart
/// Rows for one goal's history.
bool belongsToGoal(ExpenseModel e, SavingModel goal) {
  if (e.savingId != null) return e.savingId == goal.id;
  return isSavingsDeposit(e.category) &&
      (e.note ?? '').toLowerCase().contains(goal.name.toLowerCase());
}
```

- [ ] **Step 4: Move the sheet**

Cut `_showSavingHistory` from `dashboard_page.dart` into `goal_history_sheet.dart` as `showGoalHistory(...)` with the parameters above. Inside, build rows from:
- `expenses.where((e) => belongsToGoal(e, goal))`: label `isSavingsDeposit(e.category) ? (isId ? 'Setor' : 'Deposit') : '${isId ? 'Dipakai' : 'Spent'} · ${e.category}'`, amount sign `+` for deposits and `−` otherwise;
- `incomes.where((i) => isSavingsDeposit(i.category) && (i.note ?? '').toLowerCase().contains(goal.name.toLowerCase()))` as `+`.
Keep the existing sheet layout/styling code as is. Dashboard `:789` becomes `onTap: () => showGoalHistory(context, goal: s, expenses: data.allExpenses, incomes: data.allIncomes, isId: isId)`.

- [ ] **Step 5: Open it from the Goals page**

In `savings_page.dart`, wrap each goal card `Container` (inside `itemBuilder`) in `InkWell(borderRadius: BorderRadius.circular(14), onTap: () => showGoalHistory(context, goal: saving, expenses: ref.read(expenseStreamProvider(familyId)).valueOrNull ?? const [], incomes: ref.read(incomeStreamProvider(familyId)).valueOrNull ?? const [], isId: isId), child: ...)`, and `ref.watch(expenseStreamProvider(familyId))` + `ref.watch(incomeStreamProvider(familyId))` at the top of `build` so the lists are loaded.

- [ ] **Step 6: Test + analyze + commit**

Run: `flutter test test/expense_effects_test.dart && flutter analyze lib/features/savings lib/features/dashboard`
Expected: PASS, no errors.

```bash
git add lib/core/services/expense_effects.dart test/expense_effects_test.dart lib/features/savings lib/features/dashboard/presentation/pages/dashboard_page.dart
git commit -m "feat(android): each goal shows its own history

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Budget expenses sheet and source badge in History

**Files:**
- Modify: `lib/core/services/expense_effects.dart` (add `budgetExpenses`)
- Test: `test/expense_effects_test.dart`
- Create: `lib/features/budget/presentation/widgets/budget_expenses_sheet.dart`
- Modify: `lib/features/budget/presentation/pages/budget_page.dart` (budget card `onTap`)
- Modify: `lib/features/transactions/presentation/providers/transaction_history_provider.dart` (`TransactionItem.savingId`)
- Modify: `lib/features/transactions/presentation/pages/transactions_page.dart:~315` (badge)

**Interfaces:**
- Produces: `List<ExpenseModel> budgetExpenses(List<ExpenseModel> all, String category, String month)`; `void showBudgetExpenses(BuildContext, {required String category, required String month, required List<ExpenseModel> expenses, required bool isId})`; `TransactionItem.savingId` (`String?`).

- [ ] **Step 1: Failing test**

```dart
  test('budget sheet lists only budget-paid spending of that month', () {
    final list = [
      exp(50000, 'Transportasi'),
      exp(30000, 'Transportasi', savingId: 'g1'),
      ExpenseModel(id: 'x', familyId: 'f', userId: 'u', amount: 9, category: 'Transportasi', date: DateTime(2026, 9, 30)),
    ];
    final rows = budgetExpenses(list, 'Transportasi', '2026-10');
    expect(rows.map((e) => e.amount), [50000]);
  });
```

- [ ] **Step 2: Run** — Expected: FAIL (`budgetExpenses` undefined).

- [ ] **Step 3: Implement**

```dart
List<ExpenseModel> budgetExpenses(
  List<ExpenseModel> all,
  String category,
  String month,
) {
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  return all.where((e) {
    final fx = effectsOf(e);
    return fx.budgetCategory == category && key(e.date) == month;
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}
```

- [ ] **Step 4: Sheet + tap**

`showBudgetExpenses` = `showModalBottomSheet` with a title `'$category · ${n} ${isId ? 'pengeluaran' : 'expenses'}'`, then for each row a `ListTile(dense: true, title: Text(e.note ?? e.category), subtitle: Text(DateFormatter.format(e.date)), trailing: Text('-${CurrencyFormatter.format(e.amount)}', style: const TextStyle(color: AppTheme.expenseColor, fontWeight: FontWeight.w600)))`, and an empty state `Text(isId ? 'Belum ada pengeluaran.' : 'No spending yet.')`. In `budget_page.dart`, make each budget card tappable (`InkWell` around the card, `onTap: () => showBudgetExpenses(context, category: b.category, month: b.month, expenses: ref.read(expenseStreamProvider(familyId)).valueOrNull ?? const [], isId: isId)`), with `ref.watch(expenseStreamProvider(familyId))` in `build`.

- [ ] **Step 5: Badge in History**

Add `final String? savingId;` to `TransactionItem` (constructor `this.savingId`), set `savingId: e.savingId` for expenses in `load`. In `transactions_page.dart` next to the category text (~:266) for `item.type == TransactionType.expense` show a small chip: `item.savingId != null && !isSavingsDeposit(item.category)` → `'Tabungan · ${goalName}'` (look the name up from `ref.watch(savingStreamProvider(scope)).valueOrNull`), else if `!isSavingsDeposit(item.category)` → `'Budget'`. Style like existing small labels (fontSize 10, `onSurfaceVariant`, rounded container).

- [ ] **Step 6: Test, analyze, commit**

Run: `flutter test $(ls test/*_test.dart | grep -v widget_test) && flutter analyze lib`
Expected: PASS, no errors.

```bash
git add lib/core/services/expense_effects.dart test/expense_effects_test.dart lib/features/budget lib/features/transactions
git commit -m "feat(android): budgets list their spending; History shows Budget or Tabungan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Docs and end-to-end check

**Files:**
- Modify: `AGENTS.md` (Feature Status + Key Decisions)

- [ ] **Step 1: Update AGENTS.md**

Replace the Key Decision line `**Goals Summary** - transaction history show all Tabungan/Savings expense (tidak filter by saving name)` with `**Goals Summary** - riwayat per goal (savingId; data lama cocok nama di catatan)`. Add Feature Status lines:
`- [x] Saldo screenshot -> Budget/Tabungan (+ Saldo awal opsional), tidak pernah pengeluaran`
`- [x] Sumber uang pengeluaran Budget/Tabungan (savingId), riwayat per goal & per budget`
`- [ ] Tagihan bisa di-scan (Bagian 4) & Utang dari scan (Bagian 5) - spec 2026-10-12`

- [ ] **Step 2: Emulator check** (`flutter run -d emulator-5554`; start the AVD with `D:\AndroidAVD\start-pixel.ps1` only if the user agrees — laptop RAM)

1. Expense Makanan 20.000 from Tabungan "Neo NOW" (balance ≥ 20.000) → goal −20.000, Makanan budget unchanged, History shows "Tabungan · Neo NOW".
2. Edit it to Budget → goal +20.000 back, budget Makanan +20.000.
3. Delete it → budget back.
4. Tap the goal → only its rows. Tap the Makanan budget → its rows.
5. Withdraw 10.000 from a goal → goal −10.000 (stays down).

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: budget and savings from scans (Bagian 1-3) done

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
