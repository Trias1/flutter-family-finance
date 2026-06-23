class UserEntity {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String? familyId;
  final String role;
  final DateTime createdAt;

  UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.familyId,
    this.role = 'member',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
