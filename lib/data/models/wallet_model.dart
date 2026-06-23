import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletType { cash, bank, ewallet }

class WalletModel {
  final String id;
  final String familyId;
  final String name;
  final WalletType type;
  final double balance;
  final String? icon;
  final String? colorHex;
  final DateTime createdAt;

  WalletModel({
    required this.id,
    required this.familyId,
    required this.name,
    this.type = WalletType.cash,
    this.balance = 0,
    this.icon,
    this.colorHex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel(
      id: doc.id,
      familyId: data['familyId'] ?? '',
      name: data['name'] ?? '',
      type: _parseType(data['type']),
      balance: (data['balance'] ?? 0).toDouble(),
      icon: data['icon'],
      colorHex: data['colorHex'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'familyId': familyId,
      'name': name,
      'type': type.name,
      'balance': balance,
      'icon': icon,
      'colorHex': colorHex,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static WalletType _parseType(String? s) {
    switch (s) {
      case 'bank': return WalletType.bank;
      case 'ewallet': return WalletType.ewallet;
      default: return WalletType.cash;
    }
  }
}
