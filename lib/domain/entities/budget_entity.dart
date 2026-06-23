class BudgetEntity {
  final String id;
  final String familyId;
  final String month;
  final String category;
  final double budgetAmount;
  final double usedAmount;

  BudgetEntity({
    required this.id,
    required this.familyId,
    required this.month,
    required this.category,
    required this.budgetAmount,
    this.usedAmount = 0,
  });

  double get remaining => budgetAmount - usedAmount;
  double get percentage => budgetAmount > 0 ? (usedAmount / budgetAmount) * 100 : 0;
  bool get isExceeded => usedAmount > budgetAmount;
  bool get isAlmostExceeded => percentage >= 80;
}
