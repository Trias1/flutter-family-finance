import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/expense_entity.dart';

class ExpenseModel {
  final String id;
  final String familyId;
  final String userId;
  final double amount;
  final String category;
  final String? note;
  final String? attachment;
  final String? recurringId;

  /// The goal this expense pays from (or deposits into, for Tabungan).
  final String? savingId;
  final DateTime date;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.amount,
    required this.category,
    this.note,
    this.attachment,
    this.recurringId,
    this.savingId,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      note: data['note'],
      attachment: data['attachment'],
      recurringId: data['recurringId'],
      savingId: data['savingId'],
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
      if (savingId != null) 'savingId': savingId,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ExpenseEntity toEntity() {
    return ExpenseEntity(
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

  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
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
