import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/user_entity.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? familyId;
  final String role;
  final DateTime createdAt;
  final List<Map<String, String>> familyHistory;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.familyId,
    this.role = 'member',
    DateTime? createdAt,
    List<Map<String, String>>? familyHistory,
  })  : createdAt = createdAt ?? DateTime.now(),
        familyHistory = familyHistory ?? [];

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawHistory = data['familyHistory'] as List<dynamic>? ?? [];
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      familyId: data['familyId'],
      role: data['role'] ?? 'member',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      familyHistory: rawHistory.map((e) => Map<String, String>.from(e as Map)).toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'familyId': familyId,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'familyHistory': familyHistory,
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      name: name,
      email: email,
      photoUrl: photoUrl,
      familyId: familyId,
      role: role,
      createdAt: createdAt,
    );
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      photoUrl: entity.photoUrl,
      familyId: entity.familyId,
      role: entity.role,
      createdAt: entity.createdAt,
    );
  }
}
