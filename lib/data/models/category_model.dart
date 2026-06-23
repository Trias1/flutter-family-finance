import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String familyId;
  final String type;
  final String name;
  final DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.familyId,
    required this.type,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      type: data['type'] ?? 'expense',
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'type': type,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
