import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_finance_manager/domain/entities/family_entity.dart';

class FamilyModel {
  final String id;
  final String name;
  final String? photoUrl;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  FamilyModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.inviteCode,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyModel(
      id: doc.id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      inviteCode: data['inviteCode'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  FamilyModel copyWith({String? id, String? name, String? photoUrl, String? inviteCode, String? createdBy, DateTime? createdAt}) {
    return FamilyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FamilyEntity toEntity() {
    return FamilyEntity(
      id: id,
      name: name,
      photoUrl: photoUrl,
      inviteCode: inviteCode,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  factory FamilyModel.fromEntity(FamilyEntity entity) {
    return FamilyModel(
      id: entity.id,
      name: entity.name,
      photoUrl: entity.photoUrl,
      inviteCode: entity.inviteCode,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
    );
  }
}
