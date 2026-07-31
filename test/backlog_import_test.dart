import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_finance_app/features/notification_backlog/data/datasources/notification_backlog_datasource.dart';
import 'package:my_finance_app/features/notification_backlog/data/datasources/notification_backlog_outbox.dart';
import 'package:my_finance_app/features/notification_backlog/data/datasources/notification_backlog_sync_worker.dart';
import 'package:my_finance_app/features/notification_backlog/data/models/notification_backlog_item_model.dart';
import 'package:my_finance_app/features/notification_backlog/domain/entities/notification_backlog_item_entity.dart';
import 'package:my_finance_app/features/notification_backlog/presentation/providers/backlog_provider.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';

/// Datasource whose Firestore write NEVER resolves — reproduces the offline /
/// unreachable-backend condition (with offline persistence a write to a doc
/// that doesn't exist under this id stays pending forever).
class _HangingDatasource implements NotificationBacklogDatasource {
  bool markStatusCalled = false;

  @override
  Stream<List<NotificationBacklogItemModel>> watchItems(String userId) =>
      const Stream.empty();

  @override
  Future<String> addItem(NotificationBacklogItemModel item) async => 'fake-id';

  @override
  Future<void> markStatus(
    String itemId, {
    required BacklogItemStatus status,
    String? transactionId,
  }) {
    markStatusCalled = true;
    return Completer<void>().future; // never completes
  }

  @override
  Future<void> deleteItem(String itemId) async {}

  @override
  Future<void> deleteAllPending(String userId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BacklogNotifier.markManuallyImported', () {
    // Regression for the dead "Importar" button: on Android the pending item is
    // a still-local outbox item, so markStatus() targets a Firestore doc that
    // doesn't exist under that id and — with offline persistence — the write
    // Future never resolves. When this was awaited, markManuallyImported() never
    // returned and _importManually() never reached showAnimatedDialog(): the
    // item flipped to "Importada" but no dialog opened. The Firestore write must
    // be fire-and-forget so the caller returns immediately.
    test('returns promptly even when the Firestore write never resolves',
        () async {
      SharedPreferences.setMockInitialValues({});
      final outbox = NotificationBacklogOutbox();
      addTearDown(outbox.dispose);
      final ds = _HangingDatasource();
      final worker = NotificationBacklogSyncWorker(outbox: outbox, remote: ds);
      final notifier = BacklogNotifier(ds, outbox, worker, 'user-1');

      // Simulate an Android-captured local item sitting in the outbox.
      final localId = await outbox.enqueue(NotificationBacklogItemModel(
        id: '',
        userId: 'user-1',
        amount: 42.0,
        type: TransactionType.expense,
        rawText: 'Compra aprovada R\$ 42,00',
        sourceApp: 'com.nu.production',
        receivedAt: DateTime(2026, 7, 27),
        status: BacklogItemStatus.pending,
      ));

      // Must NOT hang on the never-resolving Firestore write.
      await notifier
          .markManuallyImported(localId)
          .timeout(const Duration(seconds: 2));

      // The remote write is still attempted (fire-and-forget)...
      expect(ds.markStatusCalled, isTrue);
      // ...and the local outbox already reflects the new status, so the UI flips.
      final entries = await outbox.all();
      expect(entries.single.item.status, BacklogItemStatus.manuallyImported);
    });
  });
}
