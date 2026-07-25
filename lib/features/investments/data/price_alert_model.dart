import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/investment_asset.dart';
import '../domain/price_alert.dart';

class PriceAlertModel extends PriceAlert {
  const PriceAlertModel({
    required super.id,
    required super.userId,
    required super.ticker,
    required super.quoteSymbol,
    required super.name,
    required super.kind,
    required super.condition,
    required super.targetPrice,
    required super.active,
    required super.createdAt,
    super.triggeredAt,
    super.triggeredPrice,
  });

  factory PriceAlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final target = (data['targetPrice'] as num?)?.toDouble() ?? 0;
    final triggered = (data['triggeredPrice'] as num?)?.toDouble();
    return PriceAlertModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      ticker: data['ticker'] as String? ?? '',
      quoteSymbol: data['quoteSymbol'] as String? ?? '',
      name: data['name'] as String? ?? '',
      kind: AssetKind.fromId(data['kind'] as String?),
      condition: AlertCondition.fromId(data['condition'] as String?),
      targetPrice: target.isFinite ? target : 0,
      active: data['active'] as bool? ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      triggeredAt: (data['triggeredAt'] as Timestamp?)?.toDate(),
      triggeredPrice: (triggered != null && triggered.isFinite) ? triggered : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'ticker': ticker,
        'quoteSymbol': quoteSymbol,
        'name': name,
        'kind': kind.id,
        'condition': condition.id,
        'targetPrice': targetPrice,
        'active': active,
        'createdAt': createdAt,
        if (triggeredAt != null) 'triggeredAt': triggeredAt,
        if (triggeredPrice != null) 'triggeredPrice': triggeredPrice,
      };
}
