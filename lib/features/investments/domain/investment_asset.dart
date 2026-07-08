import 'package:equatable/equatable.dart';

/// The kind of tracked asset — drives which quote source and currency is used.
enum AssetKind {
  stockBr, // B3 equity/FII → Yahoo symbol "<ticker>.SA", BRL
  stockUs, // US equity → Yahoo symbol "<ticker>", USD
  crypto; // crypto → CoinGecko id, priced in BRL

  String get id => name;

  static AssetKind fromId(String? id) {
    for (final k in AssetKind.values) {
      if (k.id == id) return k;
    }
    return AssetKind.stockBr;
  }

  /// Native currency of the quote for this kind.
  String get currency => this == AssetKind.stockUs ? 'USD' : 'BRL';

  bool get isCrypto => this == AssetKind.crypto;
}

class InvestmentAsset extends Equatable {
  final String id;
  final String userId;

  /// The Carteira (workspace) this asset belongs to. Null on pre-migration /
  /// legacy docs, which the client treats as the owner's default Carteira.
  final String? workspaceId;

  /// Human ticker shown to the user (e.g. PETR4, AAPL, BTC).
  final String ticker;

  /// Provider symbol used to fetch quotes: "PETR4.SA" (Yahoo B3),
  /// "AAPL" (Yahoo US), or a CoinGecko id like "bitcoin".
  final String quoteSymbol;

  final String name;
  final AssetKind kind;
  final DateTime createdAt;

  const InvestmentAsset({
    required this.id,
    required this.userId,
    this.workspaceId,
    required this.ticker,
    required this.quoteSymbol,
    required this.name,
    required this.kind,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, userId, workspaceId, ticker, quoteSymbol, name, kind, createdAt];
}
