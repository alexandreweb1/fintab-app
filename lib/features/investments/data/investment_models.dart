import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/investment_asset.dart';
import '../domain/investment_trade.dart';

class InvestmentAssetModel extends InvestmentAsset {
  const InvestmentAssetModel({
    required super.id,
    required super.userId,
    super.workspaceId,
    required super.ticker,
    required super.quoteSymbol,
    required super.name,
    required super.kind,
    required super.createdAt,
  });

  factory InvestmentAssetModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InvestmentAssetModel(
      id: doc.id,
      userId: d['userId'] as String,
      workspaceId: d['workspaceId'] as String?,
      ticker: d['ticker'] as String? ?? '',
      quoteSymbol: d['quoteSymbol'] as String? ?? '',
      name: d['name'] as String? ?? '',
      kind: AssetKind.fromId(d['kind'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        // Omit workspaceId when null so pre-migration creates keep matching the
        // legacy Firestore rule branch (no workspaceId in the payload).
        if (workspaceId != null) 'workspaceId': workspaceId,
        'ticker': ticker,
        'quoteSymbol': quoteSymbol,
        'name': name,
        'kind': kind.id,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

class InvestmentTradeModel extends InvestmentTrade {
  const InvestmentTradeModel({
    required super.id,
    required super.userId,
    super.workspaceId,
    required super.assetId,
    required super.side,
    required super.quantity,
    required super.unitPrice,
    super.fees,
    required super.date,
    required super.createdAt,
  });

  factory InvestmentTradeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InvestmentTradeModel(
      id: doc.id,
      userId: d['userId'] as String,
      workspaceId: d['workspaceId'] as String?,
      assetId: d['assetId'] as String? ?? '',
      side: TradeSide.fromId(d['side'] as String?),
      quantity: (d['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (d['unitPrice'] as num?)?.toDouble() ?? 0,
      fees: (d['fees'] as num?)?.toDouble() ?? 0,
      date: (d['date'] as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        if (workspaceId != null) 'workspaceId': workspaceId,
        'assetId': assetId,
        'side': side.id,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'fees': fees,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
