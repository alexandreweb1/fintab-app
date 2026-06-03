import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_suggestion.dart';

class NotificationListenerBridge {
  static const _eventChannel =
      EventChannel('com.alexdev.myfinanceapp/notifications');
  static const _methodChannel =
      MethodChannel('com.alexdev.myfinanceapp/notification_permission');

  /// Cached broadcast stream — must only call receiveBroadcastStream() once.
  static Stream<String>? _rawStream;

  /// Returns a single, cached stream of suggestions from the native service.
  /// Safe to call multiple times (e.g. after hot-reload) — always returns
  /// the same underlying broadcast stream.
  ///
  /// Individual events that fail JSON parsing are skipped (not fatal).
  static Stream<NotificationSuggestion> get suggestionStream {
    if (!_isAndroid) {
      debugPrint('[NotifBridge] Not Android — returning empty stream');
      return const Stream.empty();
    }

    if (_rawStream == null) {
      debugPrint('[NotifBridge] Creating new EventChannel subscription');
      _rawStream = _eventChannel
          .receiveBroadcastStream()
          .map((event) => event as String)
          .asBroadcastStream();
    }

    return _rawStream!.transform(
      StreamTransformer<String, NotificationSuggestion>.fromHandlers(
        handleData: (data, sink) {
          try {
            debugPrint('[NotifBridge] Raw event received: $data');
            final map = jsonDecode(data) as Map<String, dynamic>;
            sink.add(NotificationSuggestion.fromJson(map));
          } catch (e) {
            debugPrint('[NotifBridge] Failed to parse event: $e');
          }
        },
        handleError: (error, stackTrace, sink) {
          debugPrint('[NotifBridge] Stream error: $error');
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  /// Resets the cached stream. Call this if the EventChannel needs to be
  /// re-established (e.g. after the native activity is recreated).
  static void resetStream() {
    _rawStream = null;
  }

  static Future<bool> isPermissionGranted() async {
    if (!_isAndroid) return false;
    try {
      return await _methodChannel.invokeMethod<bool>('isPermissionGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openPermissionSettings() async {
    if (!_isAndroid) return;
    try {
      await _methodChannel.invokeMethod('openPermissionSettings');
    } catch (_) {}
  }

  /// Consumes a suggestion that was stored in the Android intent when the
  /// user tapped a native notification (app may have been closed at the time).
  /// Returns null if there is nothing pending.
  static Future<NotificationSuggestion?> consumeIntentSuggestion() async {
    if (!_isAndroid) return null;
    try {
      final json =
          await _methodChannel.invokeMethod<String>('consumeIntentSuggestion');
      if (json == null) return null;
      debugPrint('[NotifBridge] Intent suggestion consumed: $json');
      final map = jsonDecode(json) as Map<String, dynamic>;
      return NotificationSuggestion.fromJson(map);
    } catch (e) {
      debugPrint('[NotifBridge] consumeIntentSuggestion error: $e');
      return null;
    }
  }

  static bool get _isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;
}
