class IncomeEntity {
  final String id;
  final String familyId;
  final String userId;
  final double amount;
  final String category;
  final String? note;
  final String? attachment;
  final DateTime date;
  final DateTime createdAt;

  IncomeEntity({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.amount,
    required this.category,
    this.note,
    this.attachment,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
