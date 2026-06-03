import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sends financial data to Android home screen widgets via MethodChannel.
/// The native side (Kotlin AppWidgetProviders) reads SharedPreferences
/// with the same keys and calls AppWidgetManager.updateAppWidget().
class HomeWidgetService {
  static const _channel = MethodChannel('com.alexdev.myfinanceapp/home_widget');

  static Future<void> updateAll({
    required double balance,
    required double monthIncome,
    required double monthExpense,
    required String monthLabel,
    required List<Map<String, dynamic>> recentTransactions,
    required int healthScore,
    required bool isPro,
  }) async {
    try {
      await _channel.invokeMethod('updateWidgets', {
        'balance': balance,
        'monthIncome': monthIncome,
        'monthExpense': monthExpense,
        'monthLabel': monthLabel,
        'recentTransactions': recentTransactions,
        'healthScore': healthScore,
        'isPro': isPro,
      });
    } on PlatformException catch (_) {
      // Silently fail — widget update is best-effort
    }
  }

  /// Returns true if the user opened the app by tapping the "+" home widget.
  /// Consumed once on the native side.
  static Future<bool> consumeOpenAddDialogIntent() async {
    try {
      final result = await const MethodChannel(
              'com.alexdev.myfinanceapp/notification_permission')
          .invokeMethod<bool>('consumeOpenAddDialogIntent');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}

final homeWidgetSyncProvider = Provider<void>((ref) {
  // We just define it — it is watched in main_screen so it runs on every rebuild
});
