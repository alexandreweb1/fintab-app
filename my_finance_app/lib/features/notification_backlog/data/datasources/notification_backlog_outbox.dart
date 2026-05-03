import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/notification_backlog_item_entity.dart';
import '../models/notification_backlog_item_model.dart';

/// Local "outbox" for notification backlog items that haven't been synced
/// to Firestore yet. Notifications can arrive while offline; we persist them
/// locally first so they're never lost, then a sync worker uploads them later.
///
/// Stored in SharedPreferences as a JSON list under [_kKey]. Each entry has:
///   { localId, item: <toLocalMap()>, attempts, lastAttemptMs }
class NotificationBacklogOutbox {
  static const _kKey = 'backlog_outbox_v1';
  static const _kFailureCounterKey = 'notification_outbox_failures';

  final _controller = StreamController<List<OutboxEntry>>.broadcast();
  bool _initialized = false;

  /// Stream of currently-pending outbox entries (for UI merge).
  Stream<List<OutboxEntry>> watchPending() async* {
    yield await _readAll();
    yield* _controller.stream;
  }

  Future<void> _emit() async {
    if (_controller.isClosed) return;
    _controller.add(await _readAll());
  }

  Future<List<OutboxEntry>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(OutboxEntry.fromJson).toList();
    } catch (e) {
      debugPrint('[Outbox] Corrupt data, resetting: $e');
      await prefs.remove(_kKey);
      return [];
    }
  }

  Future<void> _writeAll(List<OutboxEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(entries.map((e) => e.toJson()).toList(growable: false));
    await prefs.setString(_kKey, encoded);
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    await _emit();
  }

  /// Adds a new item to the outbox. Returns the localId assigned to it.
  Future<String> enqueue(NotificationBacklogItemModel item) async {
    await _ensureInit();
    final entries = await _readAll();
    final localId = const Uuid().v4();
    entries.add(OutboxEntry(
      localId: localId,
      item: item.copyWith(id: localId, pendingSync: true),
      attempts: 0,
      lastAttemptMs: 0,
    ));
    await _writeAll(entries);
    await _emit();
    debugPrint('[Outbox] Enqueued localId=$localId, total=${entries.length}');
    return localId;
  }

  /// Marks an item as synced — removes it from the outbox.
  Future<void> markSynced(String localId) async {
    final entries = await _readAll();
    final before = entries.length;
    entries.removeWhere((e) => e.localId == localId);
    if (entries.length != before) {
      await _writeAll(entries);
      await _emit();
      debugPrint('[Outbox] Synced localId=$localId, remaining=${entries.length}');
    }
  }

  /// Updates the status (and optionally transactionId) of a still-pending item.
  /// No-op if already synced.
  Future<void> updateStatus(
    String localId, {
    required BacklogItemStatus status,
    String? transactionId,
  }) async {
    final entries = await _readAll();
    final idx = entries.indexWhere((e) => e.localId == localId);
    if (idx < 0) return;
    final old = entries[idx];
    entries[idx] = OutboxEntry(
      localId: old.localId,
      item: old.item.copyWith(status: status, transactionId: transactionId),
      attempts: old.attempts,
      lastAttemptMs: old.lastAttemptMs,
    );
    await _writeAll(entries);
    await _emit();
  }

  /// Records a failed sync attempt with the next allowed retry timestamp.
  Future<void> recordAttempt(String localId) async {
    final entries = await _readAll();
    final idx = entries.indexWhere((e) => e.localId == localId);
    if (idx < 0) return;
    final old = entries[idx];
    entries[idx] = OutboxEntry(
      localId: old.localId,
      item: old.item,
      attempts: old.attempts + 1,
      lastAttemptMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _writeAll(entries);

    final prefs = await SharedPreferences.getInstance();
    final cur = prefs.getInt(_kFailureCounterKey) ?? 0;
    await prefs.setInt(_kFailureCounterKey, cur + 1);
  }

  /// Returns entries that are due for a retry (respecting backoff).
  Future<List<OutboxEntry>> dueForRetry() async {
    await _ensureInit();
    final now = DateTime.now().millisecondsSinceEpoch;
    final all = await _readAll();
    return all.where((e) => e.nextRetryMs <= now).toList();
  }

  Future<List<OutboxEntry>> all() => _readAll();

  Future<void> dispose() async {
    await _controller.close();
  }
}

class OutboxEntry {
  final String localId;
  final NotificationBacklogItemModel item;
  final int attempts;
  final int lastAttemptMs;

  const OutboxEntry({
    required this.localId,
    required this.item,
    required this.attempts,
    required this.lastAttemptMs,
  });

  /// Backoff schedule: 0, 1s, 2s, 4s, 8s, 16s, 32s, 60s, 120s, 300s (max)
  int get nextRetryMs {
    if (attempts == 0) return 0;
    const schedule = [1, 2, 4, 8, 16, 32, 60, 120, 300];
    final idx = (attempts - 1).clamp(0, schedule.length - 1);
    return lastAttemptMs + schedule[idx] * 1000;
  }

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'item': item.toLocalMap(),
        'attempts': attempts,
        'lastAttemptMs': lastAttemptMs,
      };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      localId: json['localId'] as String,
      item: NotificationBacklogItemModel.fromMap(
        (json['item'] as Map).cast<String, dynamic>(),
        id: json['localId'] as String,
        pendingSync: true,
      ),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastAttemptMs: (json['lastAttemptMs'] as num?)?.toInt() ?? 0,
    );
  }
}
