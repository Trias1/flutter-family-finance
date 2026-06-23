import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/saving_entity.dart';

class SavingModel {
  final String id;
  final String familyId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? bankName;
  final DateTime targetDate;
  final DateTime createdAt;

  SavingModel({
    required this.id,
    required this.familyId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.bankName,
    required this.targetDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SavingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavingModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      name: data['name'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0).toDouble(),
      currentAmount: (data['currentAmount'] ?? 0).toDouble(),
      bankName: data['bankName'] as String?,
      targetDate: (data['targetDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      if (bankName != null) 'bankName': bankName,
      'targetDate': Timestamp.fromDate(targetDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
  double get remaining => targetAmount - currentAmount;

  SavingEntity toEntity() {
    return SavingEntity(
      id: id,
      familyId: familyId,
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      bankName: bankName,
      targetDate: targetDate,
      createdAt: createdAt,
    );
  }

  factory SavingModel.fromEntity(SavingEntity entity) {
    return SavingModel(
      id: entity.id,
      familyId: entity.familyId,
      name: entity.name,
      targetAmount: entity.targetAmount,
      currentAmount: entity.currentAmount,
      bankName: entity.bankName,
      targetDate: entity.targetDate,
      createdAt: entity.createdAt,
    );
  }
}
