import '../../../../features/transactions/domain/entities/transaction_entity.dart';

enum BacklogItemStatus {
  /// Auto-save was off (or failed) — waiting for manual import.
  pending,

  /// Auto-save was on and a transaction was created automatically.
  autoImported,

  /// User imported via the backlog screen "Importar" button.
  manuallyImported,

  /// User dismissed the item.
  ignored,
}

BacklogItemStatus backlogItemStatusFromString(String? raw) {
  switch (raw) {
    case 'autoImported':
      return BacklogItemStatus.autoImported;
    case 'manuallyImported':
      return BacklogItemStatus.manuallyImported;
    case 'ignored':
      return BacklogItemStatus.ignored;
    case 'pending':
    default:
      return BacklogItemStatus.pending;
  }
}

String backlogItemStatusToString(BacklogItemStatus status) {
  switch (status) {
    case BacklogItemStatus.autoImported:
      return 'autoImported';
    case BacklogItemStatus.manuallyImported:
      return 'manuallyImported';
    case BacklogItemStatus.ignored:
      return 'ignored';
    case BacklogItemStatus.pending:
      return 'pending';
  }
}

class NotificationBacklogItemEntity {
  final String id;
  final String userId;
  final double amount;

  /// null means the type could not be determined from the notification text.
  final TransactionType? type;

  /// Full raw text from the bank notification.
  final String rawText;

  /// Android package name of the source app (e.g. "com.nu.production").
  final String sourceApp;

  final DateTime receivedAt;

  final BacklogItemStatus status;

  /// FK to the transaction created from this item, when applicable.
  final String? transactionId;

  /// True when the item still lives only in the local outbox and
  /// hasn't been synced to Firestore yet.
  final bool pendingSync;

  const NotificationBacklogItemEntity({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.rawText,
    required this.sourceApp,
    required this.receivedAt,
    required this.status,
    this.transactionId,
    this.pendingSync = false,
  });

  /// Backwards-compat getter.
  bool get imported =>
      status == BacklogItemStatus.autoImported ||
      status == BacklogItemStatus.manuallyImported;
}
