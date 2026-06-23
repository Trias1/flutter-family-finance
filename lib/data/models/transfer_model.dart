import 'package:cloud_firestore/cloud_firestore.dart';

class TransferModel {
  final String id;
  final String familyId;
  final String fromWalletId;
  final String toWalletId;
  final double amount;
  final double? fee;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  TransferModel({
    required this.id,
    required this.familyId,
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    this.fee,
    this.note,
    required this.date,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TransferModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransferModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      fromWalletId: data['fromWalletId'] ?? '',
      toWalletId: data['toWalletId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      fee: (data['fee'] ?? 0).toDouble(),
      note: data['note'],
      date: (data['date'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'fromWalletId': fromWalletId,
      'toWalletId': toWalletId,
      'amount': amount,
      'fee': fee,
      'note': note,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
