import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../features/transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/notification_backlog_item_entity.dart';

class NotificationBacklogItemModel extends NotificationBacklogItemEntity {
  const NotificationBacklogItemModel({
    required super.id,
    required super.userId,
    required super.amount,
    required super.type,
    required super.rawText,
    required super.sourceApp,
    required super.receivedAt,
    required super.status,
    super.transactionId,
    super.pendingSync = false,
  });

  factory NotificationBacklogItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationBacklogItemModel.fromMap(data, id: doc.id);
  }

  factory NotificationBacklogItemModel.fromMap(
    Map<String, dynamic> data, {
    required String id,
    bool pendingSync = false,
  }) {
    final typeStr = data['type'] as String?;
    // Lazy migration: legacy docs have `imported: bool` and no `status` field.
    // - imported:true  → manuallyImported (we can't recover the original auto/manual distinction)
    // - imported:false → pending
    BacklogItemStatus status;
    if (data.containsKey('status')) {
      status = backlogItemStatusFromString(data['status'] as String?);
    } else {
      final imported = data['imported'] as bool? ?? false;
      status = imported
          ? BacklogItemStatus.manuallyImported
          : BacklogItemStatus.pending;
    }

    final receivedRaw = data['receivedAt'];
    DateTime receivedAt;
    if (receivedRaw is Timestamp) {
      receivedAt = receivedRaw.toDate();
    } else if (receivedRaw is int) {
      receivedAt = DateTime.fromMillisecondsSinceEpoch(receivedRaw);
    } else if (receivedRaw is String) {
      receivedAt = DateTime.tryParse(receivedRaw) ?? DateTime.now();
    } else {
      receivedAt = DateTime.now();
    }

    return NotificationBacklogItemModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      amount: (data['amount'] as num? ?? 0).toDouble(),
      type: typeStr == 'expense'
          ? TransactionType.expense
          : typeStr == 'income'
              ? TransactionType.income
              : null,
      rawText: data['rawText'] as String? ?? '',
      sourceApp: data['sourceApp'] as String? ?? '',
      receivedAt: receivedAt,
      status: status,
      transactionId: data['transactionId'] as String?,
      pendingSync: pendingSync,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'amount': amount,
        'type': type == TransactionType.expense
            ? 'expense'
            : type == TransactionType.income
                ? 'income'
                : null,
        'rawText': rawText,
        'sourceApp': sourceApp,
        'receivedAt': Timestamp.fromDate(receivedAt),
        'status': backlogItemStatusToString(status),
        'transactionId': transactionId,
        // Keep `imported` for backwards compatibility with old code paths
        // (e.g. deleteAllPending query that filters by it).
        'imported': imported,
      };

  /// Plain map for local persistence (SharedPreferences/JSON).
  Map<String, dynamic> toLocalMap() => {
        'userId': userId,
        'amount': amount,
        'type': type == TransactionType.expense
            ? 'expense'
            : type == TransactionType.income
                ? 'income'
                : null,
        'rawText': rawText,
        'sourceApp': sourceApp,
        'receivedAt': receivedAt.millisecondsSinceEpoch,
        'status': backlogItemStatusToString(status),
        'transactionId': transactionId,
      };

  NotificationBacklogItemModel copyWith({
    String? id,
    BacklogItemStatus? status,
    String? transactionId,
    bool? pendingSync,
  }) {
    return NotificationBacklogItemModel(
      id: id ?? this.id,
      userId: userId,
      amount: amount,
      type: type,
      rawText: rawText,
      sourceApp: sourceApp,
      receivedAt: receivedAt,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }
}
