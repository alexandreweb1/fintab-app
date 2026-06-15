import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_suggestion.dart';

const _kPrefKey = 'notification_detection_enabled';
const _kAutoSaveKey = 'notification_auto_save_enabled';
const _kClipboardCaptureKey = 'clipboard_capture_enabled';

// ── Detection toggle ─────────────────────────────────────────────────────────

/// Whether the notification-to-transaction detection is enabled by the user.
/// Persisted in SharedPreferences, defaults to true.
final notificationDetectionEnabledProvider =
    StateNotifierProvider<_NotificationDetectionNotifier, bool>(
  (ref) => _NotificationDetectionNotifier(),
);

class _NotificationDetectionNotifier extends StateNotifier<bool> {
  _NotificationDetectionNotifier() : super(true) {
    _loaded = _load();
  }

  late final Future<void> _loaded;

  /// Completes when the initial value has been read from disk.
  Future<void> get loaded => _loaded;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kPrefKey) ?? true;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = !state;
    await prefs.setBool(_kPrefKey, state);
  }

  Future<void> setValue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = value;
    await prefs.setBool(_kPrefKey, value);
  }
}

// ── Auto-save toggle (pre-launch pending transactions) ──────────────────────

/// When enabled, detected notifications are saved automatically as pending
/// transactions instead of just showing a notification suggestion.
final notificationAutoSaveProvider =
    StateNotifierProvider<_AutoSaveNotifier, bool>(
  (ref) => _AutoSaveNotifier(),
);

class _AutoSaveNotifier extends StateNotifier<bool> {
  _AutoSaveNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kAutoSaveKey) ?? false;
  }

  Future<void> setValue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = value;
    await prefs.setBool(_kAutoSaveKey, value);
  }
}

// ── Clipboard quick-capture (iOS + Android) ─────────────────────────────────

/// When enabled, returning to the app checks the clipboard for a copied
/// transaction (e.g. an amount copied from a bank app) and offers to launch it.
/// Opt-in because reading the clipboard surfaces the iOS "pasted from…" banner.
/// Persisted in SharedPreferences, defaults to false.
final clipboardCaptureEnabledProvider =
    StateNotifierProvider<_ClipboardCaptureNotifier, bool>(
  (ref) => _ClipboardCaptureNotifier(),
);

class _ClipboardCaptureNotifier extends StateNotifier<bool> {
  _ClipboardCaptureNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kClipboardCaptureKey) ?? false;
  }

  Future<void> setValue(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    state = value;
    await prefs.setBool(_kClipboardCaptureKey, value);
  }
}

// ── Pending suggestion ──────────────────────────────────────────────────────

/// Holds the suggestion that came from tapping a local notification.
/// When non-null, the UI should open AddTransactionDialog pre-filled.
final pendingSuggestionProvider =
    StateProvider<NotificationSuggestion?>((ref) => null);
