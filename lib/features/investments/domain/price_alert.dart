import 'package:equatable/equatable.dart';

import 'investment_asset.dart';

/// Direction of a price alert relative to the target price.
enum AlertCondition {
  above,
  below;

  String get id => name;

  static AlertCondition fromId(String? id) =>
      id == 'below' ? AlertCondition.below : AlertCondition.above;
}

/// A one-shot price alert on an asset: fires once when the quote crosses the
/// target, then stays inactive until the user re-arms it.
class PriceAlert extends Equatable {
  final String id;
  final String userId;

  /// Human ticker shown to the user (e.g. PETR4, AAPL, BTC).
  final String ticker;

  /// Provider symbol used to fetch quotes: "PETR4.SA" (Yahoo B3),
  /// "AAPL" (Yahoo US), or a CoinGecko id like "bitcoin".
  final String quoteSymbol;

  final String name;
  final AssetKind kind;
  final AlertCondition condition;
  final double targetPrice;
  final bool active;
  final DateTime createdAt;
  final DateTime? triggeredAt;
  final double? triggeredPrice;

  const PriceAlert({
    required this.id,
    required this.userId,
    required this.ticker,
    required this.quoteSymbol,
    required this.name,
    required this.kind,
    required this.condition,
    required this.targetPrice,
    required this.active,
    required this.createdAt,
    this.triggeredAt,
    this.triggeredPrice,
  });

  /// Native currency of the target/quote for this alert.
  String get currency => kind.currency;

  @override
  List<Object?> get props => [
        id,
        userId,
        ticker,
        quoteSymbol,
        name,
        kind,
        condition,
        targetPrice,
        active,
        createdAt,
        triggeredAt,
        triggeredPrice,
      ];
}

/// Pure trigger check shared by the on-open checker (and mirrored by the
/// scheduled Cloud Function). Crossing is inclusive: "above 42" fires at 42.00.
bool shouldTriggerAlert(PriceAlert alert, double price) {
  if (!alert.active) return false;
  if (!price.isFinite || price <= 0) return false;
  if (!alert.targetPrice.isFinite || alert.targetPrice <= 0) return false;
  return alert.condition == AlertCondition.above
      ? price >= alert.targetPrice
      : price <= alert.targetPrice;
}
