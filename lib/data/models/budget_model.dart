import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/budget_entity.dart';

class BudgetModel {
  final String id;
  final String familyId;
  final String month;
  final String category;
  final double budgetAmount;
  final double usedAmount;

  BudgetModel({
    required this.id,
    required this.familyId,
    required this.month,
    required this.category,
    required this.budgetAmount,
    this.usedAmount = 0,
  });

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      month: data['month'] ?? '',
      category: data['category'] ?? '',
      budgetAmount: (data['budgetAmount'] ?? 0).toDouble(),
      usedAmount: (data['usedAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'month': month,
      'category': category,
      'budgetAmount': budgetAmount,
      'usedAmount': usedAmount,
    };
  }

  double get remaining => budgetAmount - usedAmount;
  double get percentage => budgetAmount > 0 ? (usedAmount / budgetAmount) * 100 : 0;
  bool get isExceeded => usedAmount > budgetAmount;
  bool get isAlmostExceeded => percentage >= 80;

  BudgetEntity toEntity() {
    return BudgetEntity(
      id: id,
      familyId: familyId,
      month: month,
      category: category,
      budgetAmount: budgetAmount,
      usedAmount: usedAmount,
    );
  }

  factory BudgetModel.fromEntity(BudgetEntity entity) {
    return BudgetModel(
      id: entity.id,
      familyId: entity.familyId,
      month: entity.month,
      category: entity.category,
      budgetAmount: entity.budgetAmount,
      usedAmount: entity.usedAmount,
    );
  }
}
