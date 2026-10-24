import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringFrequency { daily, weekly, monthly, yearly }

class RecurringModel {
  final String id;
  final String familyId;
  final String userId;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final String? note;
  final RecurringFrequency frequency;
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDate;
  final DateTime? lastGeneratedDate;
  final bool isActive;
  final DateTime createdAt;

  RecurringModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.frequency,
    this.interval = 1,
    this.dayOfMonth,
    this.dayOfWeek,
    required this.startDate,
    this.endDate,
    required this.nextDate,
    this.lastGeneratedDate,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RecurringModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'expense',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? '',
      note: data['note'],
      frequency: _parseFrequency(data['frequency']),
      interval: data['interval'] ?? 1,
      dayOfMonth: data['dayOfMonth'],
      dayOfWeek: data['dayOfWeek'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      nextDate: (data['nextDate'] as Timestamp).toDate(),
      lastGeneratedDate: data['lastGeneratedDate'] != null
          ? (data['lastGeneratedDate'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'userId': userId,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'frequency': frequency.name,
      'interval': interval,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextDate': Timestamp.fromDate(nextDate),
      'lastGeneratedDate': lastGeneratedDate != null
          ? Timestamp.fromDate(lastGeneratedDate!)
          : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static RecurringFrequency _parseFrequency(String? s) {
    switch (s) {
      case 'daily':
        return RecurringFrequency.daily;
      case 'weekly':
        return RecurringFrequency.weekly;
      case 'monthly':
        return RecurringFrequency.monthly;
      case 'yearly':
        return RecurringFrequency.yearly;
      default:
        return RecurringFrequency.monthly;
    }
  }

  DateTime calculateNextDate() {
    final current = nextDate;
    switch (frequency) {
      case RecurringFrequency.daily:
        return current.add(Duration(days: interval));
      case RecurringFrequency.weekly:
        return current.add(Duration(days: 7 * interval));
      case RecurringFrequency.monthly:
        var next = DateTime(
          current.year,
          current.month + interval,
          current.day,
        );
        if (dayOfMonth != null) {
          next = DateTime(current.year, current.month + interval, dayOfMonth!);
        }
        return next;
      case RecurringFrequency.yearly:
        return DateTime(current.year + interval, current.month, current.day);
    }
  }
}
