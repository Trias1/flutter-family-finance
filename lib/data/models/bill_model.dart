import 'package:cloud_firestore/cloud_firestore.dart';

enum BillRepeatType { none, weekly, monthly, yearly }

enum BillStatus { unpaid, paid, overdue }

class BillModel {
  final String id;
  final String familyId;
  final String name;
  final double amount;
  final DateTime dueDate;
  final BillRepeatType repeatType;
  final BillStatus status;
  final DateTime? paidDate;
  final String? note;
  final DateTime createdAt;

  const BillModel({
    this.id = '',
    required this.familyId,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.repeatType = BillRepeatType.none,
    this.status = BillStatus.unpaid,
    this.paidDate,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
        'familyId': familyId,
        'name': name,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'repeatType': repeatType.name,
        'status': status.name,
        'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
        'note': note,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory BillModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return BillModel(
      id: doc.id,
      familyId: data['familyId'] as String,
      name: data['name'] as String,
      amount: (data['amount'] as num).toDouble(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      repeatType: BillRepeatType.values.firstWhere(
        (e) => e.name == (data['repeatType'] as String? ?? 'none'),
      ),
      status: BillStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'unpaid'),
      ),
      paidDate: data['paidDate'] != null
          ? (data['paidDate'] as Timestamp).toDate()
          : null,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  BillModel copyWith({
    String? id,
    String? familyId,
    String? name,
    double? amount,
    DateTime? dueDate,
    BillRepeatType? repeatType,
    BillStatus? status,
    DateTime? paidDate,
    String? note,
    DateTime? createdAt,
  }) {
    return BillModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      repeatType: repeatType ?? this.repeatType,
      status: status ?? this.status,
      paidDate: paidDate ?? this.paidDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
