import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/income_entity.dart';

class IncomeModel {
  final String id;
  final String familyId;
  final String userId;
  final double amount;
  final String category;
  final String? note;
  final String? attachment;
  final String? recurringId;
  final DateTime date;
  final DateTime createdAt;

  IncomeModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.amount,
    required this.category,
    this.note,
    this.attachment,
    this.recurringId,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory IncomeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return IncomeModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      note: data['note'],
      attachment: data['attachment'],
      recurringId: data['recurringId'],
      date: (data['date'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'userId': userId,
      'amount': amount,
      'category': category,
      'note': note,
      'attachment': attachment,
      'recurringId': recurringId,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  IncomeEntity toEntity() {
    return IncomeEntity(
      id: id,
      familyId: familyId,
      userId: userId,
      amount: amount,
      category: category,
      note: note,
      attachment: attachment,
      date: date,
      createdAt: createdAt,
    );
  }

  factory IncomeModel.fromEntity(IncomeEntity entity) {
    return IncomeModel(
      id: entity.id,
      familyId: entity.familyId,
      userId: entity.userId,
      amount: entity.amount,
      category: entity.category,
      note: entity.note,
      attachment: entity.attachment,
      date: entity.date,
      createdAt: entity.createdAt,
    );
  }
}
