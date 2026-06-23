import 'package:cloud_firestore/cloud_firestore.dart';

class DebtPaymentModel {
  final String id;
  final String debtId;
  final double amount;
  final DateTime date;
  final String? note;

  DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.note,
  });

  factory DebtPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DebtPaymentModel(
      id: doc.id,
      debtId: data['debtId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'debtId': debtId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}
