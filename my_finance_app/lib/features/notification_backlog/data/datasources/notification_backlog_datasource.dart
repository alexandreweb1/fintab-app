import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/notification_backlog_item_entity.dart';
import '../models/notification_backlog_item_model.dart';

abstract class NotificationBacklogDatasource {
  Stream<List<NotificationBacklogItemModel>> watchItems(String userId);

  /// Returns the Firestore-assigned doc id.
  Future<String> addItem(NotificationBacklogItemModel item);

  /// Updates the status (and optionally the linked transactionId).
  Future<void> markStatus(
    String itemId, {
    required BacklogItemStatus status,
    String? transactionId,
  });

  Future<void> deleteItem(String itemId);
  Future<void> deleteAllPending(String userId);
}

class NotificationBacklogFirestoreDatasource
    implements NotificationBacklogDatasource {
  final FirebaseFirestore _firestore;

  NotificationBacklogFirestoreDatasource(this._firestore);

  CollectionReference get _col =>
      _firestore.collection('notification_backlog');

  @override
  Stream<List<NotificationBacklogItemModel>> watchItems(String userId) {
    // No composite index needed: single-field filter + client-side sort.
    return _col.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final items = snap.docs
          .map(NotificationBacklogItemModel.fromFirestore)
          .toList()
        ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      // Cap at 200 most recent to avoid large lists.
      return items.length > 200 ? items.sublist(0, 200) : items;
    });
  }

  @override
  Future<String> addItem(NotificationBacklogItemModel item) async {
    final ref = await _col.add(item.toFirestore());
    return ref.id;
  }

  @override
  Future<void> markStatus(
    String itemId, {
    required BacklogItemStatus status,
    String? transactionId,
  }) async {
    final imported = status == BacklogItemStatus.autoImported ||
        status == BacklogItemStatus.manuallyImported;
    final patch = <String, dynamic>{
      'status': backlogItemStatusToString(status),
      'imported': imported, // keep legacy field in sync for backwards compat
    };
    if (transactionId != null) {
      patch['transactionId'] = transactionId;
    }
    await _col.doc(itemId).update(patch);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _col.doc(itemId).delete();
  }

  @override
  Future<void> deleteAllPending(String userId) async {
    // Use the legacy `imported` field to avoid requiring a composite index
    // on (userId, status). The legacy field is kept in sync by markStatus().
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('imported', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
