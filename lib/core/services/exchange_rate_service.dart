import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_settings_provider.dart';

/// Exchange rates expressed as "units of currency per 1 USD" (USD base).
/// Fiat rates come from open.er-api.com; BTC is derived from CoinGecko.
@immutable
class ExchangeRates {
  /// Map of ISO-4217 (plus 'BTC') → units per 1 USD.
  final Map<String, double> perUsd;
  final DateTime? updatedAt;

  const ExchangeRates({this.perUsd = const {}, this.updatedAt});

  bool get isEmpty => perUsd.isEmpty;
  bool get isNotEmpty => perUsd.isNotEmpty;

  /// Converts [amount] from currency [from] to [to] (ISO codes). Returns null
  /// when a needed rate is missing. Identity conversion returns the amount
  /// unchanged (no float drift).
  double? convert(double amount, String from, String to) {
    if (from == to) return amount;
    final rf = perUsd[from];
    final rt = perUsd[to];
    if (rf == null || rt == null || rf == 0) return null;
    return amount / rf * rt;
  }
}

/// Fetches live exchange rates from free public APIs.
class ExchangeRateService {
  static const _fiatUrl = 'https://open.er-api.com/v6/latest/USD';
  static const _btcUrl =
      'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd';
  static const _timeout = Duration(seconds: 12);

  /// Returns a map of currency code → units per 1 USD. Fiat and BTC are fetched
  /// independently so a failure of one source doesn't lose the other.
  static Future<Map<String, double>> fetchRates() async {
    final result = <String, double>{};

    try {
      final resp = await http.get(Uri.parse(_fiatUrl)).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rates = data['rates'];
        if (rates is Map) {
          rates.forEach((k, v) {
            if (v is num) result[k.toString()] = v.toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('[FX] fiat fetch error: $e');
    }

    try {
      final resp = await http.get(Uri.parse(_btcUrl)).timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final btcUsd = (data['bitcoin'] is Map)
            ? (data['bitcoin']['usd'] as num?)?.toDouble()
            : null;
        if (btcUsd != null && btcUsd > 0) {
          result['BTC'] = 1 / btcUsd; // BTC per 1 USD
        }
      }
    } catch (e) {
      debugPrint('[FX] btc fetch error: $e');
    }

    return result;
  }
}

class ExchangeRateNotifier extends StateNotifier<ExchangeRates> {
  ExchangeRateNotifier() : super(const ExchangeRates()) {
    _init();
  }

  static const _kCacheKey = 'exchange_rates_cache';
  static const _kCacheTimeKey = 'exchange_rates_updated_at';
  static const _maxAge = Duration(hours: 12);

  bool _refreshing = false;

  Future<void> _init() async {
    await _loadCache();
    await refreshIfStale();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      final ts = prefs.getInt(_kCacheTimeKey);
      if (raw != null) {
        final decoded = (jsonDecode(raw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        state = ExchangeRates(
          perUsd: decoded,
          updatedAt:
              ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
        );
      }
    } catch (e) {
      debugPrint('[FX] cache load error: $e');
    }
  }

  Future<void> refreshIfStale() async {
    final updated = state.updatedAt;
    if (updated != null && DateTime.now().difference(updated) < _maxAge) return;
    await refresh();
  }

  /// Forces a fresh fetch. Keeps the previous (cached) rates if the fetch fails.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final rates = await ExchangeRateService.fetchRates();
      if (rates.isNotEmpty) {
        final now = DateTime.now();
        state = ExchangeRates(perUsd: rates, updatedAt: now);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kCacheKey, jsonEncode(rates));
        await prefs.setInt(_kCacheTimeKey, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('[FX] refresh error: $e');
    } finally {
      _refreshing = false;
    }
  }
}

/// Live exchange rates (cached, refreshed at most every 12h).
final exchangeRatesProvider =
    StateNotifierProvider<ExchangeRateNotifier, ExchangeRates>(
  (ref) => ExchangeRateNotifier(),
);

/// A convert function bound to the current rates. Returns null when the needed
/// rate is unavailable.
final currencyConverterProvider =
    Provider<double? Function(double, AppCurrency, AppCurrency)>((ref) {
  final rates = ref.watch(exchangeRatesProvider);
  return (amount, from, to) => rates.convert(amount, from.code, to.code);
});
