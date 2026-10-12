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
  final back =
      editing != null &&
          editing.savingId == goal.id &&
          !isSavingsDeposit(editing.category)
      ? editing.amount
      : 0.0;
  return amount <= goal.currentAmount + back;
}

/// What the budget of [category] in [month] ("2026-10") has used: expenses
/// that cut a budget (not deposits, not paid from savings).
double budgetSpent(List<ExpenseModel> expenses, String category, String month) {
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  return expenses
      .map(effectsOf)
      .where((fx) => fx.budgetCategory == category && key(fx.date) == month)
      .fold<double>(0, (sum, fx) => sum + fx.budgetDelta);
}

/// Rows for one goal's history: linked by id, or old Tabungan entries that
/// name the goal in the note.
bool belongsToGoal(ExpenseModel e, SavingModel goal) {
  if (e.savingId != null) return e.savingId == goal.id;
  return isSavingsDeposit(e.category) &&
      (e.note ?? '').toLowerCase().contains(goal.name.toLowerCase());
}

/// The spending a budget of [category] in [month] ("2026-10") is made of,
/// newest first.
List<ExpenseModel> budgetExpenses(
  List<ExpenseModel> all,
  String category,
  String month,
) {
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  return all
      .where(
        (e) => effectsOf(e).budgetCategory == category && key(e.date) == month,
      )
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
}
