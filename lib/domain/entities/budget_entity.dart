class BudgetEntity {
  final String id;
  final String familyId;
  final String month;
  final String category;
  final double budgetAmount;
  final double usedAmount;
  final double rolloverAmount;

  BudgetEntity({
    required this.id,
    required this.familyId,
    required this.month,
    required this.category,
    required this.budgetAmount,
    this.usedAmount = 0,
    this.rolloverAmount = 0,
  });

  /// This month's limit plus whatever was left over from last month.
  double get effectiveBudget => budgetAmount + rolloverAmount;
  double get remaining => effectiveBudget - usedAmount;
  double get percentage => effectiveBudget > 0 ? (usedAmount / effectiveBudget) * 100 : 0;
  bool get isExceeded => usedAmount > effectiveBudget;
  bool get isAlmostExceeded => percentage >= 80;
}
