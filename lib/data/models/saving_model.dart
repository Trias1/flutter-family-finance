import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/saving_entity.dart';

enum SavingCategory { general, emergency, vacation, house, education, gold }

class SavingModel {
  final String id;
  final String familyId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? bankName;
  final DateTime targetDate;
  final DateTime createdAt;
  final SavingCategory category;
  
  // Gold investment fields
  final String? goldType; // LM 0.5gr, Antam 1gr, Antam 5gr, UBS, etc
  final double? goldGrams; // jumlah gram
  final double? purchasePricePerGram; // harga beli per gram
  final double? currentPricePerGram; // harga sekarang per gram (manual update)
  final String? purchaseSource; // Tokopedia, Pegadaian, Toko Emas, etc

  SavingModel({
    required this.id,
    required this.familyId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.bankName,
    required this.targetDate,
    DateTime? createdAt,
    this.category = SavingCategory.general,
    this.goldType,
    this.goldGrams,
    this.purchasePricePerGram,
    this.currentPricePerGram,
    this.purchaseSource,
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
      category: _parseCategory(data['category']),
      goldType: data['goldType'] as String?,
      goldGrams: data['goldGrams'] != null ? (data['goldGrams'] as num).toDouble() : null,
      purchasePricePerGram: data['purchasePricePerGram'] != null ? (data['purchasePricePerGram'] as num).toDouble() : null,
      currentPricePerGram: data['currentPricePerGram'] != null ? (data['currentPricePerGram'] as num).toDouble() : null,
      purchaseSource: data['purchaseSource'] as String?,
    );
  }

  static SavingCategory _parseCategory(String? value) {
    switch (value) {
      case 'emergency':
        return SavingCategory.emergency;
      case 'vacation':
        return SavingCategory.vacation;
      case 'house':
        return SavingCategory.house;
      case 'education':
        return SavingCategory.education;
      case 'gold':
        return SavingCategory.gold;
      default:
        return SavingCategory.general;
    }
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
      'category': category.name,
      if (goldType != null) 'goldType': goldType,
      if (goldGrams != null) 'goldGrams': goldGrams,
      if (purchasePricePerGram != null) 'purchasePricePerGram': purchasePricePerGram,
      if (currentPricePerGram != null) 'currentPricePerGram': currentPricePerGram,
      if (purchaseSource != null) 'purchaseSource': purchaseSource,
    };
  }

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
  double get remaining => targetAmount - currentAmount;
  
  // Gold investment helpers
  bool get isGoldInvestment => category == SavingCategory.gold;
  
  double get goldCurrentValue {
    if (!isGoldInvestment || goldGrams == null || currentPricePerGram == null) return currentAmount;
    return goldGrams! * currentPricePerGram!;
  }
  
  double get goldProfitLoss {
    if (!isGoldInvestment || goldGrams == null || purchasePricePerGram == null || currentPricePerGram == null) return 0;
    final purchaseValue = goldGrams! * purchasePricePerGram!;
    final currentValue = goldGrams! * currentPricePerGram!;
    return currentValue - purchaseValue;
  }
  
  double get goldProfitLossPercent {
    if (!isGoldInvestment || goldGrams == null || purchasePricePerGram == null || currentPricePerGram == null) return 0;
    final purchaseValue = goldGrams! * purchasePricePerGram!;
    if (purchaseValue == 0) return 0;
    return (goldProfitLoss / purchaseValue) * 100;
  }

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
