class FamilyEntity {
  final String id;
  final String name;
  final String? photoUrl;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  FamilyEntity({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.inviteCode,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
