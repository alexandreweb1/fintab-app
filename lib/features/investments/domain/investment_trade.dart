import 'package:equatable/equatable.dart';

enum TradeSide {
  buy,
  sell;

  String get id => name;
  static TradeSide fromId(String? id) =>
      id == 'sell' ? TradeSide.sell : TradeSide.buy;
}

/// A single buy/sell operation on an asset, in the asset's native currency.
class InvestmentTrade extends Equatable {
  final String id;
  final String userId;

  /// The Carteira (workspace) this trade belongs to. Null on legacy docs
  /// (treated as the owner's default Carteira).
  final String? workspaceId;
  final String assetId;
  final TradeSide side;
  final double quantity;
  final double unitPrice;
  final double fees;
  final DateTime date;
  final DateTime createdAt;

  const InvestmentTrade({
    required this.id,
    required this.userId,
    this.workspaceId,
    required this.assetId,
    required this.side,
    required this.quantity,
    required this.unitPrice,
    this.fees = 0,
    required this.date,
    required this.createdAt,
  });

  bool get isBuy => side == TradeSide.buy;

  @override
  List<Object?> get props => [
        id,
        userId,
        workspaceId,
        assetId,
        side,
        quantity,
        unitPrice,
        fees,
        date,
        createdAt,
      ];
}

/// Result of consolidating a set of trades for one asset, using the Brazilian
/// weighted-average-cost method (a sale realizes P&L against the average cost
/// but does NOT change the average cost). All values in the asset's native
/// currency.
class PositionSummary {
  /// Current holdings (buys − sells).
  final double quantity;

  /// Weighted average cost per unit (including fees on buys).
  final double avgCost;

  /// Remaining cost basis = quantity × avgCost.
  final double costBasis;

  /// Realized profit/loss from sells so far.
  final double realizedPnl;

  const PositionSummary({
    required this.quantity,
    required this.avgCost,
    required this.costBasis,
    required this.realizedPnl,
  });

  bool get hasHoldings => quantity > 1e-9;
}

/// Pure consolidation of [trades] (any order) into a [PositionSummary].
PositionSummary computePosition(Iterable<InvestmentTrade> trades) {
  final sorted = trades.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });

  var qty = 0.0;
  var totalCost = 0.0; // cost basis of current holdings
  var realized = 0.0;

  for (final t in sorted) {
    if (t.isBuy) {
      qty += t.quantity;
      totalCost += t.quantity * t.unitPrice + t.fees;
    } else {
      // Sell: realize against current average cost; average cost unchanged.
      final avg = qty > 1e-9 ? totalCost / qty : 0.0;
      final sellQty = t.quantity > qty ? qty : t.quantity; // clamp oversell
      realized += sellQty * (t.unitPrice - avg) - t.fees;
      qty -= sellQty;
      totalCost -= sellQty * avg;
      if (qty <= 1e-9) {
        qty = 0;
        totalCost = 0;
      }
    }
  }

  final avgCost = qty > 1e-9 ? totalCost / qty : 0.0;
  return PositionSummary(
    quantity: qty,
    avgCost: avgCost,
    costBasis: qty * avgCost,
    realizedPnl: realized,
  );
}
