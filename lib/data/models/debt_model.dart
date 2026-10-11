import 'package:cloud_firestore/cloud_firestore.dart';

enum DebtType { hutang, piutang }

enum DebtStatus { active, paid, cancelled }

class DebtModel {
  final String id;
  final String familyId;
  final String userId;
  final String personName;
  final DebtType type;
  final double amount;
  final double remainingAmount;
  final String? description;
  final DateTime? dueDate;
  final DebtStatus status;
  final DateTime createdAt;

  DebtModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.personName,
    required this.type,
    required this.amount,
    double? remainingAmount,
    this.description,
    this.dueDate,
    this.status = DebtStatus.active,
    DateTime? createdAt,
  }) : remainingAmount = remainingAmount ?? amount,
       createdAt = createdAt ?? DateTime.now();

  factory DebtModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DebtModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      userId: data['userId'] ?? '',
      personName: data['personName'] ?? '',
      type: data['type'] == 'piutang' ? DebtType.piutang : DebtType.hutang,
      amount: (data['amount'] ?? 0).toDouble(),
      remainingAmount: (data['remainingAmount'] ?? data['amount'] ?? 0)
          .toDouble(),
      description: data['description'],
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      status: _parseStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'userId': userId,
      'personName': personName,
      'type': type == DebtType.piutang ? 'piutang' : 'hutang',
      'amount': amount,
      'remainingAmount': remainingAmount,
      'description': description,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'status': status == DebtStatus.paid
          ? 'paid'
          : status == DebtStatus.cancelled
          ? 'cancelled'
          : 'active',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DebtStatus _parseStatus(String? s) {
    switch (s) {
      case 'paid':
        return DebtStatus.paid;
      case 'cancelled':
        return DebtStatus.cancelled;
      default:
        return DebtStatus.active;
    }
  }

  double get progress =>
      amount > 0 ? ((amount - remainingAmount) / amount) * 100 : 0;
  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status == DebtStatus.active;
}
