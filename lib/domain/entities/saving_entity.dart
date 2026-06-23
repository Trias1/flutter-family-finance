class SavingEntity {
  final String id;
  final String familyId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? bankName;
  final DateTime targetDate;
  final DateTime createdAt;

  SavingEntity({
    required this.id,
    required this.familyId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.bankName,
    required this.targetDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
  double get remaining => targetAmount - currentAmount;
}
