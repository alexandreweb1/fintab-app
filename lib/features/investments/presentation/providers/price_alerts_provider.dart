import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/local_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/investment_quote_service.dart';
import '../../data/price_alert_model.dart';
import '../../domain/investment_asset.dart';
import '../../domain/price_alert.dart';

/// Set to true when the user taps a price-alert notification (local or push);
/// MainScreen listens and opens the alerts screen.
final pendingPriceAlertTapProvider = StateProvider<bool>((ref) => false);

/// All of the signed-in user's price alerts, newest first. Alerts are personal
/// (not workspace-shared): they follow the account, not the Carteira.
final priceAlertsStreamProvider = StreamProvider<List<PriceAlert>>((ref) {
  final uid = ref.watch(authStateProvider).value?.id ?? '';
  if (uid.isEmpty) return const Stream.empty();
  return ref
      .watch(firestoreProvider)
      .collection('price_alerts')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
    final list = snap.docs.map(PriceAlertModel.fromFirestore).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

final priceAlertsProvider = Provider<List<PriceAlert>>(
    (ref) => ref.watch(priceAlertsStreamProvider).value ?? const []);

// ── Writes ───────────────────────────────────────────────────────────────────

class PriceAlertsNotifier extends StateNotifier<AsyncValue<void>> {
  final FirebaseFirestore _fs;
  final String _uid;
  PriceAlertsNotifier(this._fs, this._uid) : super(const AsyncValue.data(null));

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('price_alerts');

  Future<bool> add({
    required String ticker,
    required String quoteSymbol,
    required String name,
    required AssetKind kind,
    required AlertCondition condition,
    required double targetPrice,
  }) async {
    if (_uid.isEmpty || !targetPrice.isFinite || targetPrice <= 0) return false;
    state = const AsyncValue.loading();
    try {
      final model = PriceAlertModel(
        id: const Uuid().v4(),
        userId: _uid,
        ticker: ticker,
        quoteSymbol: quoteSymbol,
        name: name,
        kind: kind,
        condition: condition,
        targetPrice: targetPrice,
        active: true,
        createdAt: DateTime.now(),
      );
      await _col.doc(model.id).set(model.toFirestore());
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _col.doc(id).delete();
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Re-arms a triggered alert so it can fire again.
  Future<bool> rearm(String id) async {
    try {
      await _col.doc(id).update({
        'active': true,
        'triggeredAt': FieldValue.delete(),
        'triggeredPrice': FieldValue.delete(),
      });
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final priceAlertsNotifierProvider =
    StateNotifierProvider<PriceAlertsNotifier, AsyncValue<void>>((ref) {
  return PriceAlertsNotifier(
    ref.watch(firestoreProvider),
    ref.watch(authStateProvider).value?.id ?? '',
  );
});

// ── On-open / on-resume checker ──────────────────────────────────────────────

String _fmtAlertPrice(double v, String currency, {bool crypto = false}) =>
    NumberFormat.currency(
      locale: currency == 'USD' ? 'en_US' : 'pt_BR',
      symbol: currency == 'USD' ? 'US\$' : 'R\$',
      // Cheap crypto keeps extra decimals so targets don't render as 0,00.
      decimalDigits: crypto && v.abs() < 1 ? 8 : 2,
    ).format(v);

/// Fetches quotes for the user's active alerts and fires the ones whose
/// condition is met. The Firestore transaction guarantees each alert fires at
/// most once even when the scheduled Cloud Function checks concurrently.
class PriceAlertChecker {
  final FirebaseFirestore _fs;
  final String _uid;
  DateTime? _lastRun;
  bool _busy = false;

  PriceAlertChecker(this._fs, this._uid);

  static const _minInterval = Duration(minutes: 10);

  Future<int> checkNow({bool force = false}) async {
    if (kIsWeb || _uid.isEmpty || _busy) return 0;
    final now = DateTime.now();
    if (!force &&
        _lastRun != null &&
        now.difference(_lastRun!) < _minInterval) {
      return 0;
    }
    _busy = true;
    _lastRun = now;
    try {
      final snap = await _fs
          .collection('price_alerts')
          .where('userId', isEqualTo: _uid)
          .where('active', isEqualTo: true)
          .get();
      if (snap.docs.isEmpty) return 0;
      final alerts = snap.docs.map(PriceAlertModel.fromFirestore).toList();

      // One quote fetch per unique symbol: crypto batched, stocks in parallel.
      final cryptoIds = alerts
          .where((a) => a.kind.isCrypto)
          .map((a) => a.quoteSymbol)
          .toSet()
          .toList();
      final stockSyms =
          alerts.where((a) => !a.kind.isCrypto).map((a) => a.quoteSymbol).toSet();

      final prices = <String, double>{};
      final cryptoQuotes = await InvestmentQuoteService.fetchCrypto(cryptoIds);
      cryptoQuotes.forEach((id, q) => prices[id] = q.price);
      await Future.wait(stockSyms.map((s) async {
        final q = await InvestmentQuoteService.fetchStock(s);
        if (q != null) prices[s] = q.price;
      }));

      var fired = 0;
      for (final alert in alerts) {
        final price = prices[alert.quoteSymbol];
        if (price == null || !shouldTriggerAlert(alert, price)) continue;
        final won = await _claimTrigger(alert.id, price);
        if (!won) continue;
        fired++;
        final up = alert.condition == AlertCondition.above;
        final condTxt = up ? 'acima de' : 'abaixo de';
        final crypto = alert.kind.isCrypto;
        await LocalNotificationService.instance.showPriceAlert(
          id: alert.id.hashCode & 0x7fffffff,
          title:
              '${up ? '📈' : '📉'} ${alert.ticker} atingiu ${_fmtAlertPrice(price, alert.currency, crypto: crypto)}',
          body:
              'Seu alerta de $condTxt ${_fmtAlertPrice(alert.targetPrice, alert.currency, crypto: crypto)} disparou. Toque para ver.',
        );
      }
      return fired;
    } catch (e) {
      debugPrint('[PriceAlerts] check failed: $e');
      return 0;
    } finally {
      _busy = false;
    }
  }

  /// Atomically flips the alert to triggered; returns false if someone else
  /// (the scheduled function or another device) already fired it.
  Future<bool> _claimTrigger(String alertId, double price) async {
    final docRef = _fs.collection('price_alerts').doc(alertId);
    try {
      return await _fs.runTransaction<bool>((tx) async {
        final fresh = await tx.get(docRef);
        final data = fresh.data();
        if (data == null || data['active'] != true) return false;
        tx.update(docRef, {
          'active': false,
          'triggeredAt': DateTime.now(),
          'triggeredPrice': price,
        });
        return true;
      });
    } catch (e) {
      debugPrint('[PriceAlerts] claim failed: $e');
      return false;
    }
  }
}

final priceAlertCheckerProvider = Provider<PriceAlertChecker>((ref) {
  return PriceAlertChecker(
    ref.watch(firestoreProvider),
    ref.watch(authStateProvider).value?.id ?? '',
  );
});
