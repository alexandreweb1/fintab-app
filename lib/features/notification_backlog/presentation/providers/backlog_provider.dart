import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_suggestion.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/notification_backlog_datasource.dart';
import '../../data/datasources/notification_backlog_outbox.dart';
import '../../data/datasources/notification_backlog_sync_worker.dart';
import '../../data/models/notification_backlog_item_model.dart';
import '../../domain/entities/notification_backlog_item_entity.dart';

// ── Infrastructure ───────────────────────────────────────────────────────────

final backlogDatasourceProvider = Provider<NotificationBacklogDatasource>(
  (ref) =>
      NotificationBacklogFirestoreDatasource(ref.watch(firestoreProvider)),
);

final backlogOutboxProvider = Provider<NotificationBacklogOutbox>(
  (ref) {
    final outbox = NotificationBacklogOutbox();
    ref.onDispose(outbox.dispose);
    return outbox;
  },
);

final backlogSyncWorkerProvider = Provider<NotificationBacklogSyncWorker>(
  (ref) {
    final worker = NotificationBacklogSyncWorker(
      outbox: ref.watch(backlogOutboxProvider),
      remote: ref.watch(backlogDatasourceProvider),
    );
    worker.start();
    ref.onDispose(worker.stop);
    return worker;
  },
);

// ── Streams ──────────────────────────────────────────────────────────────────

/// Items already synced to Firestore.
final _firestoreBacklogStreamProvider =
    StreamProvider<List<NotificationBacklogItemEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(backlogDatasourceProvider).watchItems(user.id);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Items still in the local outbox (not synced yet).
final _outboxStreamProvider =
    StreamProvider<List<NotificationBacklogItemEntity>>((ref) {
  return ref
      .watch(backlogOutboxProvider)
      .watchPending()
      .map((entries) => entries.map((e) => e.item).toList());
});

/// Streams all backlog items for the current user, newest first.
/// Merge of (Firestore-synced items) + (local outbox items still pending).
final backlogItemsStreamProvider =
    Provider<AsyncValue<List<NotificationBacklogItemEntity>>>((ref) {
  final remote = ref.watch(_firestoreBacklogStreamProvider);
  final local = ref.watch(_outboxStreamProvider);

  return remote.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (remoteItems) {
      final localItems = local.value ?? const <NotificationBacklogItemEntity>[];
      final merged = <NotificationBacklogItemEntity>[
        ...localItems, // pendingSync ones first
        ...remoteItems,
      ]..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      return AsyncValue.data(
        merged.length > 200 ? merged.sublist(0, 200) : merged,
      );
    },
  );
});

/// Count of items not yet imported (pending), used for the badge in settings.
final unimportedBacklogCountProvider = Provider<int>((ref) {
  return ref.watch(backlogItemsStreamProvider).when(
        data: (items) =>
            items.where((i) => i.status == BacklogItemStatus.pending).length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});

// ── Notifier ─────────────────────────────────────────────────────────────────

class BacklogNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationBacklogDatasource _ds;
  final NotificationBacklogOutbox _outbox;
  final NotificationBacklogSyncWorker _worker;
  final String _userId;

  BacklogNotifier(this._ds, this._outbox, this._worker, this._userId)
      : super(const AsyncValue.data(null));

  /// Called from main_screen when a bank notification is received.
  /// Persists locally first (always succeeds) — sync worker uploads later.
  /// Returns the localId (used to link the item to a created transaction).
  Future<String?> addFromSuggestion(NotificationSuggestion suggestion) async {
    if (_userId.isEmpty) return null;
    try {
      final item = NotificationBacklogItemModel(
        id: '', // filled by outbox
        userId: _userId,
        amount: suggestion.amount,
        type: suggestion.type,
        rawText: suggestion.rawText,
        sourceApp: suggestion.sourceApp,
        receivedAt: DateTime.now(),
        status: BacklogItemStatus.pending,
      );
      final localId = await _outbox.enqueue(item);
      // Kick off sync immediately (won't block).
      unawaitedTick();
      return localId;
    } catch (e) {
      debugPrint('[Backlog] enqueue failed: $e');
      return null;
    }
  }

  /// After auto-saving the transaction, link it to the backlog item.
  /// Works whether the item is still in the outbox (local) or already synced.
  Future<void> markAutoImported(
    String backlogItemId, {
    required String transactionId,
  }) async {
    // Try outbox first (cheap, no network)
    try {
      await _outbox.updateStatus(
        backlogItemId,
        status: BacklogItemStatus.autoImported,
        transactionId: transactionId,
      );
    } catch (e) {
      debugPrint('[Backlog] outbox.updateStatus failed: $e');
    }
    // Also mirror the status to Firestore — if the item was already synced
    // under this id the update succeeds; if not, the doc doesn't exist yet and
    // the worker uploads the up-to-date payload from the outbox later.
    //
    // Fire-and-forget on purpose: awaiting this network write would hang the
    // caller whenever Firestore is unreachable or the doc doesn't exist under
    // this id (with offline persistence the write Future stays pending until
    // the server acks). The awaited outbox update above already reflects the
    // new status locally.
    unawaited(
      _ds
          .markStatus(
            backlogItemId,
            status: BacklogItemStatus.autoImported,
            transactionId: transactionId,
          )
          .catchError((Object _) {
        // Expected if doc isn't in Firestore yet — outbox holds the new status.
      }),
    );
  }

  /// Marks one item as manually imported (user clicked "Importar").
  ///
  /// The local outbox update is awaited (fast, no network) so the UI flips
  /// immediately. The Firestore write is fire-and-forget: awaiting it here used
  /// to hang the caller when Firestore was unreachable or the doc didn't exist
  /// under this id (for a still-local item the doc lives under a different, not-
  /// yet-synced id, so `.doc(id).update()` never resolves with offline
  /// persistence). That hang blocked `_importManually` from ever opening the
  /// import dialog — the item flipped to "Importada" but no dialog appeared.
  Future<void> markManuallyImported(String itemId) async {
    try {
      await _outbox.updateStatus(
        itemId,
        status: BacklogItemStatus.manuallyImported,
      );
    } catch (_) {}
    unawaited(
      _ds
          .markStatus(itemId, status: BacklogItemStatus.manuallyImported)
          .catchError((Object e) {
        debugPrint('[Backlog] markManuallyImported firestore failed: $e');
      }),
    );
  }

  /// Permanently removes one item from the backlog (Firestore + outbox).
  Future<void> dismiss(String itemId) async {
    try {
      await _outbox.markSynced(itemId);
    } catch (_) {}
    try {
      await _ds.deleteItem(itemId);
    } catch (e) {
      debugPrint('[Backlog] dismiss failed: $e');
    }
  }

  /// Removes all pending (non-imported) items for this user.
  Future<void> dismissAllPending() async {
    if (_userId.isEmpty) return;
    state = const AsyncValue.loading();
    try {
      await _ds.deleteAllPending(_userId);
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void unawaitedTick() {
    // Fire-and-forget: tell the worker to try syncing now.
    Future.microtask(_worker.tickNow);
  }
}

final backlogNotifierProvider =
    StateNotifierProvider<BacklogNotifier, AsyncValue<void>>((ref) {
  // Use the real UID, not effectiveUserId — backlog is per-user (a collaborator
  // shouldn't write to the master's backlog), to avoid Firestore permission-denied.
  final userId = ref.watch(authStateProvider).value?.id ?? '';
  return BacklogNotifier(
    ref.watch(backlogDatasourceProvider),
    ref.watch(backlogOutboxProvider),
    ref.watch(backlogSyncWorkerProvider),
    userId,
  );
});
