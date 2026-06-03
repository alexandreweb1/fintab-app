import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_suggestion.dart';

/// Callback invoked when the user taps on a transaction suggestion notification.
typedef OnSuggestionTap = void Function(NotificationSuggestion suggestion);

class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  OnSuggestionTap? _onSuggestionTap;

  static const _channelId = 'transaction_suggestions';
  static const _channelName = 'Sugestões de lançamento';
  static const _channelDesc =
      'Notifica quando uma transação financeira é detectada em outra notificação';

  Future<void> init({required OnSuggestionTap onSuggestionTap}) async {
    _onSuggestionTap = onSuggestionTap;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request POST_NOTIFICATIONS permission (Android 13+)
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Shows a suggestion notification with pre-filled amount and type.
  Future<void> showSuggestion(NotificationSuggestion suggestion) async {
    try {
      final typeLabel = suggestion.type?.name == 'expense'
          ? 'despesa'
          : suggestion.type?.name == 'income'
              ? 'receita'
              : null;

      final body = typeLabel != null
          ? 'Toque para lançar como $typeLabel'
          : 'Toque para registrar a transação';

      final amountStr = suggestion.amount
          .toStringAsFixed(2)
          .replaceAll('.', ',');

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      await _plugin.show(
        suggestion.amount.hashCode,
        '💰 Lançar R\$ $amountStr?',
        body,
        const NotificationDetails(android: androidDetails),
        payload: jsonEncode({
          'amount': suggestion.amount,
          'type': suggestion.type?.name ?? 'unknown',
          'text': suggestion.rawText,
          'sourceApp': suggestion.sourceApp,
        }),
      );
    } catch (e) {
      debugPrint('[LocalNotif] Failed to show suggestion: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final suggestion = NotificationSuggestion.fromJson(map);
      _onSuggestionTap?.call(suggestion);
    } catch (_) {}
  }
}
