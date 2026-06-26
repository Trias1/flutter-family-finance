import 'package:cloud_firestore/cloud_firestore.dart';

enum WishlistPriority { low, medium, high }

class WishlistItemModel {
  final String id;
  final String familyId;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final WishlistPriority priority;
  final bool isAchieved;
  final DateTime createdAt;

  WishlistItemModel({
    required this.id,
    required this.familyId,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.deadline,
    this.priority = WishlistPriority.medium,
    this.isAchieved = false,
    required this.createdAt,
  });

  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  bool get isOverdue =>
      deadline != null && deadline!.isBefore(DateTime.now()) && !isAchieved;

  factory WishlistItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WishlistItemModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      name: data['name'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0).toDouble(),
      savedAmount: (data['savedAmount'] ?? 0).toDouble(),
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      priority: _parsePriority(data['priority']),
      isAchieved: data['isAchieved'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'name': name,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'priority': priority.name,
      'isAchieved': isAchieved,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static WishlistPriority _parsePriority(String? value) {
    switch (value) {
      case 'low':
        return WishlistPriority.low;
      case 'high':
        return WishlistPriority.high;
      default:
        return WishlistPriority.medium;
    }
  }
}
