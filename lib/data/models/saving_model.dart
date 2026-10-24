import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/saving_entity.dart';

enum SavingCategory {
  general,
  emergency,
  vacation,
  house,
  education,
  gold,
  rent,
  hajj,
  wedding,
  vehicle,
}

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

  /// Starts again each year once the target date passes (rent, school fees).
  final bool repeatYearly;

  /// When the balance was last set from a bank screenshot.
  final DateTime? balanceSyncedAt;

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
    this.repeatYearly = false,
    this.balanceSyncedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// A copy with some fields changed; keeps every other field, including
  /// the category, gold details and the yearly repeat.
  SavingModel copyWith({
    String? name,
    double? targetAmount,
    double? currentAmount,
    String? bankName,
    DateTime? targetDate,
    SavingCategory? category,
    bool? repeatYearly,
    DateTime? balanceSyncedAt,
  }) {
    return SavingModel(
      id: id,
      familyId: familyId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      bankName: bankName ?? this.bankName,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt,
      category: category ?? this.category,
      goldType: goldType,
      goldGrams: goldGrams,
      purchasePricePerGram: purchasePricePerGram,
      currentPricePerGram: currentPricePerGram,
      purchaseSource: purchaseSource,
      repeatYearly: repeatYearly ?? this.repeatYearly,
      balanceSyncedAt: balanceSyncedAt ?? this.balanceSyncedAt,
    );
  }

  /// Months left until [targetDate], at least one.
  int monthsLeft([DateTime? now]) {
    final from = now ?? DateTime.now();
    final months =
        (targetDate.year - from.year) * 12 + targetDate.month - from.month;
    return months < 1 ? 1 : months;
  }

  /// What to put aside each month from now to reach the target in time.
  double monthlyNeeded([DateTime? now]) {
    final left = remaining;
    return left <= 0 ? 0 : left / monthsLeft(now);
  }

  /// Where the balance should be today if saving evenly from creation to
  /// the target date; behind when [currentAmount] is below it.
  double expectedByNow([DateTime? now]) {
    final at = now ?? DateTime.now();
    final total = targetDate.difference(createdAt).inDays;
    if (total <= 0) return targetAmount;
    final done = at.difference(createdAt).inDays.clamp(0, total);
    return targetAmount * done / total;
  }

  /// For a yearly goal whose date has passed: the next yearly date on or
  /// after [now]; otherwise null.
  DateTime? nextYearlyDate([DateTime? now]) {
    final at = now ?? DateTime.now();
    if (!repeatYearly ||
        !targetDate.isBefore(DateTime(at.year, at.month, at.day))) {
      return null;
    }
    var next = targetDate;
    while (next.isBefore(DateTime(at.year, at.month, at.day))) {
      next = DateTime(next.year + 1, next.month, next.day);
    }
    return next;
  }

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
      goldGrams: data['goldGrams'] != null
          ? (data['goldGrams'] as num).toDouble()
          : null,
      purchasePricePerGram: data['purchasePricePerGram'] != null
          ? (data['purchasePricePerGram'] as num).toDouble()
          : null,
      currentPricePerGram: data['currentPricePerGram'] != null
          ? (data['currentPricePerGram'] as num).toDouble()
          : null,
      purchaseSource: data['purchaseSource'] as String?,
      repeatYearly: data['repeatYearly'] == true,
      balanceSyncedAt: (data['balanceSyncedAt'] as Timestamp?)?.toDate(),
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
      case 'rent':
        return SavingCategory.rent;
      case 'hajj':
        return SavingCategory.hajj;
      case 'wedding':
        return SavingCategory.wedding;
      case 'vehicle':
        return SavingCategory.vehicle;
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
      if (purchasePricePerGram != null)
        'purchasePricePerGram': purchasePricePerGram,
      if (currentPricePerGram != null)
        'currentPricePerGram': currentPricePerGram,
      if (purchaseSource != null) 'purchaseSource': purchaseSource,
      if (repeatYearly) 'repeatYearly': true,
      if (balanceSyncedAt != null)
        'balanceSyncedAt': Timestamp.fromDate(balanceSyncedAt!),
    };
  }

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0;
  double get remaining => targetAmount - currentAmount;

  // Gold investment helpers
  bool get isGoldInvestment => category == SavingCategory.gold;

  double get goldCurrentValue {
    if (!isGoldInvestment || goldGrams == null || currentPricePerGram == null)
      return currentAmount;
    return goldGrams! * currentPricePerGram!;
  }

  double get goldProfitLoss {
    if (!isGoldInvestment ||
        goldGrams == null ||
        purchasePricePerGram == null ||
        currentPricePerGram == null)
      return 0;
    final purchaseValue = goldGrams! * purchasePricePerGram!;
    final currentValue = goldGrams! * currentPricePerGram!;
    return currentValue - purchaseValue;
  }

  double get goldProfitLossPercent {
    if (!isGoldInvestment ||
        goldGrams == null ||
        purchasePricePerGram == null ||
        currentPricePerGram == null)
      return 0;
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
