import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'local_notification_service.dart';

/// Registers this device for FCM pushes (used by the scheduled price-alert
/// check in Cloud Functions) and routes incoming alert messages.
///
/// Tokens live in `fcm_tokens/{uid}` as an array — one doc per account, so the
/// Cloud Function can address every device of the alert's owner. iOS delivery
/// additionally requires the APNs key configured in the Firebase console;
/// until then every call here fails soft and the on-open local check still
/// covers iOS.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _fgSub;
  StreamSubscription<RemoteMessage>? _openSub;
  String _uid = '';

  Future<void> init({
    required String uid,
    required void Function() onAlertTap,
  }) async {
    if (kIsWeb || uid.isEmpty) return;
    _uid = uid;
    final messaging = FirebaseMessaging.instance;

    try {
      // Permission: on iOS this is the system prompt (no-op once answered);
      // on Android 13+ the local-notifications init already asked.
      await messaging.requestPermission();
      // Foreground pushes on iOS: let the system banner show them.
      await messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('[Push] permission setup failed: $e');
    }

    try {
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      // Expected on iOS while APNs isn't configured for the Firebase project.
      debugPrint('[Push] getToken failed: $e');
    }

    _tokenSub?.cancel();
    _tokenSub = messaging.onTokenRefresh.listen(_saveToken,
        onError: (Object e) => debugPrint('[Push] token refresh error: $e'));

    // Foreground: Android doesn't display FCM notification messages while the
    // app is open, so mirror them as a local notification. iOS already shows
    // the banner via the presentation options above.
    _fgSub?.cancel();
    _fgSub = FirebaseMessaging.onMessage.listen((m) {
      if (m.data['type'] != 'price_alert') return;
      final n = m.notification;
      if (n == null) return;
      if (!kIsWeb && Platform.isAndroid) {
        LocalNotificationService.instance.showPriceAlert(
          id: (m.data['alertId'] ?? n.title ?? '').hashCode & 0x7fffffff,
          title: n.title ?? 'Alerta de preço',
          body: n.body ?? '',
        );
      }
    });

    // Tap on a push while the app was in background → open the alerts screen.
    _openSub?.cancel();
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (m.data['type'] == 'price_alert') onAlertTap();
    });

    // Cold start from a push tap.
    try {
      final initial = await messaging.getInitialMessage();
      if (initial?.data['type'] == 'price_alert') onAlertTap();
    } catch (e) {
      debugPrint('[Push] getInitialMessage failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    if (_uid.isEmpty || token.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('fcm_tokens').doc(_uid).set({
        'tokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Push] saveToken failed: $e');
    }
  }

  /// Unregisters this device from the current account. MUST run before the
  /// Firebase sign-out (the fcm_tokens rule requires auth.uid == doc id) —
  /// otherwise the device keeps receiving the previous account's alerts.
  Future<void> removeToken() async {
    if (kIsWeb || _uid.isEmpty) return;
    _tokenSub?.cancel();
    _tokenSub = null;
    _fgSub?.cancel();
    _fgSub = null;
    _openSub?.cancel();
    _openSub = null;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('fcm_tokens')
            .doc(_uid)
            .set({
          'tokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      }
      // Invalidate locally so the next account gets a fresh token.
      await messaging.deleteToken();
    } catch (e) {
      debugPrint('[Push] removeToken failed: $e');
    } finally {
      _uid = '';
    }
  }
}
