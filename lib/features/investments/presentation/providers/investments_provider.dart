import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/services/exchange_rate_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/investment_models.dart';
import '../../data/investment_quote_service.dart';
import '../../domain/investment_asset.dart';
import '../../domain/investment_trade.dart';

// ── Streams ─────────────────────────────────────────────────────────────────

final investmentAssetsStreamProvider =
    StreamProvider<List<InvestmentAsset>>((ref) {
  final auth = ref.watch(authStateProvider);
  final uid = ref.watch(effectiveUserIdProvider);
  return auth.when(
    data: (user) {
      if (user == null || uid.isEmpty) return const Stream.empty();
      return ref
          .watch(firestoreProvider)
          .collection('investment_assets')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((s) {
        final list = s.docs
            .map((d) => InvestmentAssetModel.fromFirestore(d) as InvestmentAsset)
            .toList();
        list.sort((a, b) => a.ticker.compareTo(b.ticker));
        return list;
      });
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final investmentTradesStreamProvider =
    StreamProvider<List<InvestmentTrade>>((ref) {
  final auth = ref.watch(authStateProvider);
  final uid = ref.watch(effectiveUserIdProvider);
  return auth.when(
    data: (user) {
      if (user == null || uid.isEmpty) return const Stream.empty();
      return ref
          .watch(firestoreProvider)
          .collection('investment_trades')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((s) => s.docs
              .map((d) => InvestmentTradeModel.fromFirestore(d) as InvestmentTrade)
              .toList());
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Trades for one asset (soonest first).
final tradesForAssetProvider =
    Provider.family<List<InvestmentTrade>, String>((ref, assetId) {
  final all = ref.watch(investmentTradesStreamProvider).value ?? const [];
  final list = all.where((t) => t.assetId == assetId).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return list;
});

// ── Quotes ──────────────────────────────────────────────────────────────────

@immutable
class QuotesState {
  final Map<String, AssetQuote> bySymbol;
  final bool loading;
  final DateTime? updatedAt;
  const QuotesState(
      {this.bySymbol = const {}, this.loading = false, this.updatedAt});

  QuotesState copyWith(
          {Map<String, AssetQuote>? bySymbol,
          bool? loading,
          DateTime? updatedAt}) =>
      QuotesState(
        bySymbol: bySymbol ?? this.bySymbol,
        loading: loading ?? this.loading,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class QuotesNotifier extends StateNotifier<QuotesState> {
  QuotesNotifier() : super(const QuotesState());

  bool _busy = false;

  Future<void> refresh(List<InvestmentAsset> assets) async {
    if (_busy || assets.isEmpty) return;
    _busy = true;
    state = state.copyWith(loading: true);
    try {
      final map = {...state.bySymbol};
      final stocks = assets.where((a) => !a.kind.isCrypto).toList();
      final cryptos = assets.where((a) => a.kind.isCrypto).toList();

      await Future.wait(stocks.map((a) async {
        final q = await InvestmentQuoteService.fetchStock(a.quoteSymbol);
        if (q != null) map[a.quoteSymbol] = q;
      }));

      if (cryptos.isNotEmpty) {
        final cq = await InvestmentQuoteService.fetchCrypto(
            cryptos.map((a) => a.quoteSymbol).toList());
        map.addAll(cq);
      }
      state = QuotesState(
          bySymbol: map, loading: false, updatedAt: DateTime.now());
    } catch (e) {
      state = state.copyWith(loading: false);
    } finally {
      _busy = false;
    }
  }
}

final investmentQuotesProvider =
    StateNotifierProvider<QuotesNotifier, QuotesState>(
        (ref) => QuotesNotifier());

// ── Positions (assets × trades × quotes, consolidated in BRL) ───────────────

class PositionView {
  final InvestmentAsset asset;
  final PositionSummary summary;
  final AssetQuote? quote;
  final ExchangeRates _rates;

  const PositionView(this.asset, this.summary, this.quote, this._rates);

  double? get price => quote?.price;
  double? get dayChangePct => quote?.dayChangePercent;

  /// Converts a native-currency value to BRL (identity for BRL assets).
  double toBrl(double v) {
    if (asset.kind.currency == 'BRL') return v;
    return _rates.convert(v, asset.kind.currency, 'BRL') ?? v;
  }

  double get marketValueNative =>
      summary.quantity * (price ?? summary.avgCost);
  double get unrealizedNative =>
      price == null ? 0 : summary.quantity * (price! - summary.avgCost);
  double get unrealizedPct =>
      summary.costBasis > 0 ? unrealizedNative / summary.costBasis * 100 : 0;

  double get marketValueBrl => toBrl(marketValueNative);
  double get costBasisBrl => toBrl(summary.costBasis);
  double get unrealizedBrl => toBrl(unrealizedNative);
  double get realizedBrl => toBrl(summary.realizedPnl);
}

/// One PositionView per asset (including sold-out ones, for realized P&L).
final investmentPositionsProvider = Provider<List<PositionView>>((ref) {
  final assets = ref.watch(investmentAssetsStreamProvider).value ?? const [];
  final trades = ref.watch(investmentTradesStreamProvider).value ?? const [];
  final quotes = ref.watch(investmentQuotesProvider).bySymbol;
  final rates = ref.watch(exchangeRatesProvider);

  final byAsset = <String, List<InvestmentTrade>>{};
  for (final t in trades) {
    (byAsset[t.assetId] ??= []).add(t);
  }

  final views = assets
      .map((a) => PositionView(
            a,
            computePosition(byAsset[a.id] ?? const []),
            quotes[a.quoteSymbol],
            rates,
          ))
      .toList();
  // Holdings first, then by market value.
  views.sort((a, b) {
    if (a.summary.hasHoldings != b.summary.hasHoldings) {
      return a.summary.hasHoldings ? -1 : 1;
    }
    return b.marketValueBrl.compareTo(a.marketValueBrl);
  });
  return views;
});

class PortfolioTotal {
  final double marketValue; // BRL
  final double cost; // BRL
  final double unrealized; // BRL
  final double realized; // BRL (all-time, incl. closed positions)
  final double dayChange; // BRL (today's move)
  double get unrealizedPct => cost > 0 ? unrealized / cost * 100 : 0;

  const PortfolioTotal({
    required this.marketValue,
    required this.cost,
    required this.unrealized,
    required this.realized,
    required this.dayChange,
  });
}

final portfolioTotalProvider = Provider<PortfolioTotal>((ref) {
  final positions = ref.watch(investmentPositionsProvider);
  var mv = 0.0, cost = 0.0, unreal = 0.0, realized = 0.0, dayAbs = 0.0;
  for (final p in positions) {
    realized += p.realizedBrl;
    if (!p.summary.hasHoldings) continue;
    mv += p.marketValueBrl;
    cost += p.costBasisBrl;
    unreal += p.unrealizedBrl;
    final dp = p.dayChangePct;
    if (dp != null && dp != -100) {
      // Amount of today's market value attributable to today's move.
      dayAbs += p.marketValueBrl - p.marketValueBrl / (1 + dp / 100);
    }
  }
  return PortfolioTotal(
    marketValue: mv,
    cost: cost,
    unrealized: unreal,
    realized: realized,
    dayChange: dayAbs,
  );
});

// ── Notifiers (mutations) ───────────────────────────────────────────────────

class InvestmentsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final String _uid;
  InvestmentsNotifier(this._ref, this._uid)
      : super(const AsyncValue.data(null));

  FirebaseFirestore get _fs => _ref.read(firestoreProvider);

  Future<String?> addAsset({
    required String ticker,
    required String quoteSymbol,
    required String name,
    required AssetKind kind,
  }) async {
    try {
      final id = const Uuid().v4();
      await _fs.collection('investment_assets').doc(id).set(
            InvestmentAssetModel(
              id: id,
              userId: _uid,
              ticker: ticker,
              quoteSymbol: quoteSymbol,
              name: name,
              kind: kind,
              createdAt: DateTime.now(),
            ).toFirestore(),
          );
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteAsset(String assetId) async {
    try {
      final trades = await _fs
          .collection('investment_trades')
          .where('userId', isEqualTo: _uid)
          .where('assetId', isEqualTo: assetId)
          .get();
      final batch = _fs.batch();
      for (final d in trades.docs) {
        batch.delete(d.reference);
      }
      batch.delete(_fs.collection('investment_assets').doc(assetId));
      await batch.commit();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> addTrade({
    required String assetId,
    required TradeSide side,
    required double quantity,
    required double unitPrice,
    double fees = 0,
    required DateTime date,
  }) async {
    try {
      final id = const Uuid().v4();
      await _fs.collection('investment_trades').doc(id).set(
            InvestmentTradeModel(
              id: id,
              userId: _uid,
              assetId: assetId,
              side: side,
              quantity: quantity,
              unitPrice: unitPrice,
              fees: fees,
              date: date,
              createdAt: DateTime.now(),
            ).toFirestore(),
          );
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteTrade(String tradeId) async {
    try {
      await _fs.collection('investment_trades').doc(tradeId).delete();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final investmentsNotifierProvider =
    StateNotifierProvider<InvestmentsNotifier, AsyncValue<void>>((ref) {
  return InvestmentsNotifier(ref, ref.watch(effectiveUserIdProvider));
});
