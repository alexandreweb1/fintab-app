import 'package:equatable/equatable.dart';

enum SubscriptionType { monthly, annual, none }

enum SubscriptionStatus { active, expired }

class SubscriptionEntity extends Equatable {
  final SubscriptionType type;
  final SubscriptionStatus status;
  final String purchaseToken;
  final String productId;
  final DateTime? expiryDate;
  final DateTime updatedAt;

  const SubscriptionEntity({
    required this.type,
    required this.status,
    required this.purchaseToken,
    required this.productId,
    this.expiryDate,
    required this.updatedAt,
  });

  factory SubscriptionEntity.none() => SubscriptionEntity(
        type: SubscriptionType.none,
        status: SubscriptionStatus.expired,
        purchaseToken: '',
        productId: '',
        expiryDate: null,
        updatedAt: DateTime.now(),
      );

  /// A assinatura está ativa se o status é active E:
  /// - É vitalícia (sem expiração), OU
  /// - Ainda não expirou
  bool get isActive {
    if (status != SubscriptionStatus.active) return false;
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }

  @override
  List<Object?> get props =>
      [type, status, purchaseToken, productId, expiryDate, updatedAt];
}
