import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around Firebase Analytics.
///
/// Holds the singleton instance and exposes the growth funnel we care about:
/// `open → sign up → first transaction → keep adding`. Firebase already tracks
/// `first_open`, `session_start`, `screen_view` and retention automatically;
/// these custom events let us measure activation on real users.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalytics get analytics => _analytics;

  /// Add to MaterialApp.navigatorObservers to log `screen_view` on every push.
  /// Cached so app rebuilds (theme/locale changes) reuse the same observer
  /// instead of detaching/reattaching a fresh one each time.
  late final FirebaseAnalyticsObserver navigatorObserver =
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Toggle collection (e.g. if the user opts out in settings).
  Future<void> setEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);

  // ── Funnel events ──────────────────────────────────────────────────────────

  Future<void> logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method);

  Future<void> logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  /// The activation moment: the user's very first transaction.
  Future<void> logFirstTransaction() =>
      _analytics.logEvent(name: 'first_transaction');

  /// Every transaction added, tagged by how it was captured
  /// (manual, notification, clipboard, share…).
  Future<void> logTransactionAdded({required String type, String? source}) =>
      _analytics.logEvent(
        name: 'transaction_added',
        parameters: {
          'type': type,
          if (source != null) 'source': source,
        },
      );

  /// Generic escape hatch for one-off events.
  Future<void> logEvent(String name, [Map<String, Object>? params]) =>
      _analytics.logEvent(name: name, parameters: params);
}
