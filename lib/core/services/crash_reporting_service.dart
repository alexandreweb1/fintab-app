import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Crashlytics.
///
/// Global error handlers are wired once in [install] (called after Firebase
/// init). Collection is gated by the same consent flag as Analytics
/// (`AppSettings.telemetryEnabled`), so opting out silences both. Use
/// [recordNonFatal] to surface swallowed failures (e.g. a query error that
/// would otherwise collapse into an empty list) without crashing the app.
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService instance = CrashReportingService._();

  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  /// Routes uncaught Flutter and platform errors to Crashlytics. Call once,
  /// after `Firebase.initializeApp()`.
  void install() {
    FlutterError.onError = _crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Enable/disable collection — same consent decision as Analytics.
  Future<void> setEnabled(bool enabled) =>
      _crashlytics.setCrashlyticsCollectionEnabled(enabled);

  /// Record a non-fatal error (a swallowed stream/query failure, a parse
  /// guard tripping) with optional [reason] so we learn about integrity
  /// issues in production instead of them failing silently.
  Future<void> recordNonFatal(Object error, StackTrace stack,
          {String? reason}) =>
      _crashlytics.recordError(error, stack, reason: reason, fatal: false);
}
