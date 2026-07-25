import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_suggestion.dart';

/// Callback invoked when the user taps on a transaction suggestion notification.
typedef OnSuggestionTap = void Function(NotificationSuggestion suggestion);

/// Callback invoked when the user taps a price-alert notification.
typedef OnPriceAlertTap = void Function();

class LocalNotificationService {
  LocalNotificationService._();
  static final instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  OnSuggestionTap? _onSuggestionTap;
  OnPriceAlertTap? _onPriceAlertTap;

  static const _channelId = 'transaction_suggestions';
  static const _channelName = 'Sugestões de lançamento';
  static const _channelDesc =
      'Notifica quando uma transação financeira é detectada em outra notificação';

  static const _billChannelId = 'bill_reminders';
  static const _billChannelName = 'Lembretes de contas';
  static const _billChannelDesc =
      'Avisa quando uma conta a pagar ou receber está perto do vencimento';

  // The id must match the Cloud Function's `android.notification.channelId`
  // and the manifest's default_notification_channel_id, so FCM pushes landing
  // with the app in background use this same channel.
  static const _alertChannelId = 'price_alerts';
  static const _alertChannelName = 'Alertas de preço';
  static const _alertChannelDesc =
      'Avisa quando um ativo atinge o preço-alvo de um alerta';

  bool _tzReady = false;

  Future<void> init({
    required OnSuggestionTap onSuggestionTap,
    OnPriceAlertTap? onPriceAlertTap,
  }) async {
    _onSuggestionTap = onSuggestionTap;
    _onPriceAlertTap = onPriceAlertTap;

    // Timezone DB — required by zonedSchedule for bill reminders.
    try {
      tzdata.initializeTimeZones();
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
      _tzReady = true;
    } catch (e) {
      debugPrint('[LocalNotif] timezone init failed: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request POST_NOTIFICATIONS permission (Android 13+)
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // Pre-create the price-alerts channel so FCM pushes delivered while the
    // app is in background (which bypass this plugin) land on it.
    try {
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _alertChannelId,
          _alertChannelName,
          description: _alertChannelDesc,
          importance: Importance.high,
        ),
      );
    } catch (e) {
      debugPrint('[LocalNotif] createNotificationChannel failed: $e');
    }

    // Request iOS permission (Darwin).
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedules (or reschedules) a bill reminder to fire at [when]. Past dates
  /// are ignored. [id] must be stable per bill so rescheduling replaces it.
  Future<void> scheduleBillReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_tzReady) return;
    if (!when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _billChannelId,
            _billChannelName,
            channelDescription: _billChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[LocalNotif] scheduleBillReminder failed: $e');
    }
  }

  Future<void> cancelBillReminder(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[LocalNotif] cancelBillReminder failed: $e');
    }
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

  /// Shows an immediate price-alert notification. [title]/[body] come ready
  /// from the checker (or from a foreground FCM message).
  Future<void> showPriceAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannelId,
            _alertChannelName,
            channelDescription: _alertChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode({'kind': 'price_alert'}),
      );
    } catch (e) {
      debugPrint('[LocalNotif] showPriceAlert failed: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map['kind'] == 'price_alert') {
        _onPriceAlertTap?.call();
        return;
      }
      final suggestion = NotificationSuggestion.fromJson(map);
      _onSuggestionTap?.call(suggestion);
    } catch (_) {}
  }
}
