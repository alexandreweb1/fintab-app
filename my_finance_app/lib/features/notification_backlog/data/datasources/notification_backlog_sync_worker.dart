import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notification_backlog_datasource.dart';
import 'notification_backlog_outbox.dart';

/// Periodically tries to push outbox entries to Firestore, respecting
/// each entry's exponential backoff. Fires also on demand via [tickNow].
class NotificationBacklogSyncWorker {
  final NotificationBacklogOutbox _outbox;
  final NotificationBacklogDatasource _remote;
  final Duration tickInterval;

  Timer? _timer;
  bool _running = false;

  NotificationBacklogSyncWorker({
    required NotificationBacklogOutbox outbox,
    required NotificationBacklogDatasource remote,
    this.tickInterval = const Duration(seconds: 15),
  })  : _outbox = outbox,
        _remote = remote;

  void start() {
    _timer ??= Timer.periodic(tickInterval, (_) => tickNow());
    // Try once immediately on start (kick off sync of pending items).
    Future.microtask(tickNow);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> tickNow() async {
    if (_running) return;
    _running = true;
    try {
      final due = await _outbox.dueForRetry();
      if (due.isEmpty) return;
      debugPrint('[Outbox/Sync] tick: ${due.length} due');
      for (final entry in due) {
        try {
          final firestoreId = await _remote.addItem(entry.item);
          await _outbox.markSynced(entry.localId);
          debugPrint(
              '[Outbox/Sync] synced localId=${entry.localId} → $firestoreId');
        } catch (e) {
          debugPrint('[Outbox/Sync] failed localId=${entry.localId}: $e');
          await _outbox.recordAttempt(entry.localId);
        }
      }
    } finally {
      _running = false;
    }
  }
}
