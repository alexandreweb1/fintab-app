import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A live (delayed ~15 min) market quote for an asset, in its NATIVE currency.
@immutable
class AssetQuote {
  final String symbol;
  final String? name;
  final double price;
  final String currency; // 'BRL', 'USD', …
  final double? previousClose;
  final double? dayHigh;
  final double? dayLow;
  final double? week52High;
  final double? week52Low;

  /// Percent change vs previous close (day change). May come pre-computed
  /// (crypto 24h) or be derived from [previousClose].
  final double? changePercent;

  const AssetQuote({
    required this.symbol,
    required this.price,
    required this.currency,
    this.name,
    this.previousClose,
    this.dayHigh,
    this.dayLow,
    this.week52High,
    this.week52Low,
    this.changePercent,
  });

  double? get dayChangePercent {
    if (changePercent != null) return changePercent;
    if (previousClose != null && previousClose! > 0) {
      return (price - previousClose!) / previousClose! * 100;
    }
    return null;
  }
}

/// A search hit when adding an asset.
class AssetSearchResult {
  final String symbol; // provider symbol (Yahoo ticker or CoinGecko id)
  final String name;
  final String exchange;
  final String kind; // 'stock' | 'crypto'
  const AssetSearchResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.kind,
  });
}

/// Fetches quotes from free, no-auth endpoints:
///  - Stocks (B3 with `.SA`, and US) via Yahoo Finance chart endpoint.
///  - Crypto via CoinGecko (priced directly in BRL + USD).
class InvestmentQuoteService {
  static const _timeout = Duration(seconds: 12);
  static const _ua = {'User-Agent': 'Mozilla/5.0 (Fintab)'};

  // ── Stocks (Yahoo chart) ───────────────────────────────────────────────────

  /// [yahooSymbol] already includes any suffix (e.g. 'PETR4.SA', 'AAPL').
  static Future<AssetQuote?> fetchStock(String yahooSymbol) async {
    final url =
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol'
        '?range=1d&interval=1d';
    try {
      final resp =
          await http.get(Uri.parse(url), headers: _ua).timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = (data['chart']?['result'] as List?)?.firstOrNull;
      final meta = result?['meta'] as Map<String, dynamic>?;
      if (meta == null) return null;
      final price = (meta['regularMarketPrice'] as num?)?.toDouble();
      if (price == null) return null;
      return AssetQuote(
        symbol: yahooSymbol,
        name: (meta['longName'] ?? meta['shortName']) as String?,
        price: price,
        currency: (meta['currency'] as String?) ?? 'BRL',
        previousClose: (meta['chartPreviousClose'] as num?)?.toDouble() ??
            (meta['previousClose'] as num?)?.toDouble(),
        dayHigh: (meta['regularMarketDayHigh'] as num?)?.toDouble(),
        dayLow: (meta['regularMarketDayLow'] as num?)?.toDouble(),
        week52High: (meta['fiftyTwoWeekHigh'] as num?)?.toDouble(),
        week52Low: (meta['fiftyTwoWeekLow'] as num?)?.toDouble(),
      );
    } catch (e) {
      debugPrint('[Quote] stock $yahooSymbol error: $e');
      return null;
    }
  }

  // ── Crypto (CoinGecko) ─────────────────────────────────────────────────────

  /// [ids] are CoinGecko ids (e.g. 'bitcoin'). Returns id → quote (BRL native).
  static Future<Map<String, AssetQuote>> fetchCrypto(List<String> ids) async {
    if (ids.isEmpty) return {};
    final url = 'https://api.coingecko.com/api/v3/simple/price'
        '?ids=${ids.join(',')}&vs_currencies=brl,usd&include_24hr_change=true';
    try {
      final resp =
          await http.get(Uri.parse(url), headers: _ua).timeout(_timeout);
      if (resp.statusCode != 200) return {};
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final out = <String, AssetQuote>{};
      data.forEach((id, v) {
        final m = v as Map<String, dynamic>;
        final brl = (m['brl'] as num?)?.toDouble();
        if (brl == null) return;
        out[id] = AssetQuote(
          symbol: id,
          price: brl,
          currency: 'BRL',
          changePercent: (m['brl_24h_change'] as num?)?.toDouble(),
        );
      });
      return out;
    } catch (e) {
      debugPrint('[Quote] crypto error: $e');
      return {};
    }
  }

  // ── Price history (chart) ──────────────────────────────────────────────────

  /// Closing-price series for a stock over [range]/[interval] (Yahoo).
  static Future<List<double>> fetchStockHistory(
    String yahooSymbol, {
    required String range,
    required String interval,
  }) async {
    final url =
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol'
        '?range=$range&interval=$interval';
    try {
      final resp =
          await http.get(Uri.parse(url), headers: _ua).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = (data['chart']?['result'] as List?)?.firstOrNull;
      final closes = (result?['indicators']?['quote'] as List?)
          ?.firstOrNull?['close'] as List?;
      if (closes == null) return [];
      return closes.whereType<num>().map((v) => v.toDouble()).toList();
    } catch (e) {
      debugPrint('[Quote] stock history error: $e');
      return [];
    }
  }

  /// Price series (BRL) for a crypto over [days] (CoinGecko).
  static Future<List<double>> fetchCryptoHistory(
    String coingeckoId, {
    required int days,
  }) async {
    final url = 'https://api.coingecko.com/api/v3/coins/$coingeckoId'
        '/market_chart?vs_currency=brl&days=$days';
    try {
      final resp =
          await http.get(Uri.parse(url), headers: _ua).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final prices = (data['prices'] as List?) ?? [];
      return prices
          .whereType<List>()
          .where((p) => p.length >= 2 && p[1] is num)
          .map((p) => (p[1] as num).toDouble())
          .toList();
    } catch (e) {
      debugPrint('[Quote] crypto history error: $e');
      return [];
    }
  }

  // ── Search (add-asset UX) ──────────────────────────────────────────────────

  static Future<List<AssetSearchResult>> searchStocks(String query) async {
    if (query.trim().length < 2) return [];
    final url = 'https://query1.finance.yahoo.com/v1/finance/search'
        '?q=${Uri.encodeQueryComponent(query)}&quotesCount=10&newsCount=0';
    try {
      final resp =
          await http.get(Uri.parse(url), headers: _ua).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final quotes = (data['quotes'] as List?) ?? [];
      return quotes
          .whereType<Map<String, dynamic>>()
          .where((q) => q['symbol'] != null && q['quoteType'] == 'EQUITY')
          .map((q) => AssetSearchResult(
                symbol: q['symbol'] as String,
                name: (q['longname'] ?? q['shortname'] ?? q['symbol'])
                    as String,
                exchange: (q['exchange'] as String?) ?? '',
                kind: 'stock',
              ))
          .toList();
    } catch (e) {
      debugPrint('[Quote] search error: $e');
      return [];
    }
  }

  static Future<List<AssetSearchResult>> searchCrypto(String query) async {
    if (query.trim().length < 2) return [];
    final url =
        'https://api.coingecko.com/api/v3/search?query=${Uri.encodeQueryComponent(query)}';
    try {
      final resp =
          await http.get(Uri.parse(url), headers: _ua).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final coins = (data['coins'] as List?) ?? [];
      return coins
          .whereType<Map<String, dynamic>>()
          .take(10)
          .map((c) => AssetSearchResult(
                symbol: c['id'] as String, // CoinGecko id
                name: '${c['name']} (${c['symbol']?.toString().toUpperCase()})',
                exchange: 'Crypto',
                kind: 'crypto',
              ))
          .toList();
    } catch (e) {
      debugPrint('[Quote] crypto search error: $e');
      return [];
    }
  }
}
