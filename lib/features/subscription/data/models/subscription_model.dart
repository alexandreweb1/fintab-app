import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/subscription_entity.dart';

class SubscriptionModel extends SubscriptionEntity {
  const SubscriptionModel({
    required super.type,
    required super.status,
    required super.purchaseToken,
    required super.productId,
    super.expiryDate,
    required super.updatedAt,
  });

  factory SubscriptionModel.none() => SubscriptionModel(
        type: SubscriptionType.none,
        status: SubscriptionStatus.expired,
        purchaseToken: '',
        productId: '',
        expiryDate: null,
        updatedAt: DateTime.now(),
      );

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return SubscriptionModel.none();

    final data = doc.data() as Map<String, dynamic>? ?? {};

    return SubscriptionModel(
      type: _parseType(data['type'] as String?),
      status: _parseStatus(data['status'] as String?),
      purchaseToken: data['purchaseToken'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': _typeToString(type),
      'status': _statusToString(status),
      'purchaseToken': purchaseToken,
      'productId': productId,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static SubscriptionType _parseType(String? value) {
    switch (value) {
      case 'monthly':
        return SubscriptionType.monthly;
      case 'annual':
        return SubscriptionType.annual;
      default:
        return SubscriptionType.none;
    }
  }

  static SubscriptionStatus _parseStatus(String? value) {
    if (value == 'active') return SubscriptionStatus.active;
    return SubscriptionStatus.expired;
  }

  static String _typeToString(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.monthly:
        return 'monthly';
      case SubscriptionType.annual:
        return 'annual';
      case SubscriptionType.none:
        return 'none';
    }
  }

  static String _statusToString(SubscriptionStatus status) {
    return status == SubscriptionStatus.active ? 'active' : 'expired';
  }
}
