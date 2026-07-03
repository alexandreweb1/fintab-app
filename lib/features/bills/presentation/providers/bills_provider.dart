import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/usecases/add_transaction_usecase.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/bill_model.dart';
import '../../domain/bill_entity.dart';

// ── Stream + derived providers ──────────────────────────────────────────────

final billsStreamProvider = StreamProvider<List<BillEntity>>((ref) {
  final scope = ref.watch(activeLedgerScopeProvider);

  // New-style shared member: server-side workspace query.
  if (scope is MemberScope) {
    return workspaceCollectionQuery(
            ref.watch(firestoreProvider), 'bills', scope.workspaceId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => BillModel.fromFirestore(d) as BillEntity)
          .toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  final auth = ref.watch(authStateProvider);
  final uid = ref.watch(effectiveUserIdProvider);
  return auth.when(
    data: (user) {
      if (user == null || uid.isEmpty) return const Stream.empty();
      return ref
          .watch(firestoreProvider)
          .collection('bills')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((snap) {
        final list = snap.docs
            .map((d) => BillModel.fromFirestore(d) as BillEntity)
            .toList();
        list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return applyWorkspaceScope(list, (e) => e.workspaceId, scope);
      });
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Unpaid bills, soonest due first.
final upcomingBillsProvider = Provider<List<BillEntity>>((ref) {
  final all = ref.watch(billsStreamProvider).value ?? const [];
  return all.where((b) => !b.isPaid).toList();
});

/// Unpaid bills already past their due date.
final overdueBillsProvider = Provider<List<BillEntity>>((ref) =>
    (ref.watch(billsStreamProvider).value ?? const [])
        .where((b) => b.isOverdue())
        .toList());

/// Total of unpaid PAYABLE bills still due before the end of the current month
/// (used by Safe to Spend as a committed outflow).
final committedBillsThisMonthProvider = Provider<double>((ref) {
  final now = DateTime.now();
  final all = ref.watch(billsStreamProvider).value ?? const [];
  return all
      .where((b) =>
          !b.isPaid &&
          b.isPayable &&
          b.dueDate.year == now.year &&
          b.dueDate.month == now.month &&
          b.dueDate.day >= now.day)
      .fold<double>(0, (s, b) => s + b.amount);
});

// ── Notifier ────────────────────────────────────────────────────────────────

class BillsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final String _uid;
  final String? _workspaceId;
  BillsNotifier(this._ref, this._uid, this._workspaceId)
      : super(const AsyncValue.data(null));

  CollectionReference get _col =>
      _ref.read(firestoreProvider).collection('bills');

  int _notifId(String id) => id.hashCode & 0x7fffffff;

  void _scheduleReminder(BillEntity bill) {
    final when = bill.reminderAt;
    LocalNotificationService.instance.cancelBillReminder(_notifId(bill.id));
    if (when == null || bill.reminderDaysBefore < 0 || bill.isPaid) return;
    final verb = bill.isPayable ? 'Pagar' : 'Receber';
    final amount = bill.amount.toStringAsFixed(2).replaceAll('.', ',');
    LocalNotificationService.instance.scheduleBillReminder(
      id: _notifId(bill.id),
      title: '📅 $verb: ${bill.title}',
      body: 'Vence em ${bill.dueDate.day.toString().padLeft(2, '0')}/'
          '${bill.dueDate.month.toString().padLeft(2, '0')} · R\$ $amount',
      when: when,
    );
  }

  Future<bool> _persist(BillEntity bill) async {
    state = const AsyncValue.loading();
    try {
      await _col.doc(bill.id).set(BillModel.fromEntity(bill).toFirestore());
      _scheduleReminder(bill);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> add({
    required String title,
    required double amount,
    required DateTime dueDate,
    required BillType type,
    String category = 'Contas',
    String walletId = '',
    int reminderDaysBefore = 1,
    bool repeatMonthly = false,
  }) {
    final bill = BillEntity(
      id: const Uuid().v4(),
      userId: _uid,
      workspaceId: _workspaceId,
      title: title,
      amount: amount,
      dueDate: dueDate,
      type: type,
      category: category,
      walletId: walletId,
      reminderDaysBefore: reminderDaysBefore,
      repeatMonthly: repeatMonthly,
      createdAt: DateTime.now(),
    );
    return _persist(bill);
  }

  Future<bool> update(BillEntity bill) => _persist(bill);

  Future<bool> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      LocalNotificationService.instance.cancelBillReminder(_notifId(id));
      await _col.doc(id).delete();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Marks the bill paid: creates the matching transaction, links it, cancels
  /// the reminder, and (when repeatMonthly) seeds next month's bill.
  Future<bool> markPaid(BillEntity bill) async {
    state = const AsyncValue.loading();
    try {
      final txId = const Uuid().v4();
      final tx = TransactionEntity(
        id: txId,
        userId: _uid,
        // The settlement transaction lives in the bill's workspace; legacy
        // bills (null) fall back to the current write stamp.
        workspaceId: bill.workspaceId ?? _workspaceId,
        title: bill.title,
        amount: bill.amount,
        type: bill.isPayable
            ? TransactionType.expense
            : TransactionType.income,
        category: bill.category,
        date: DateTime.now(),
        walletId: bill.walletId,
      );
      final txResult = await _ref
          .read(addTransactionUseCaseProvider)
          .call(AddTransactionParams(transaction: tx));
      final linkedTxId = txResult.fold<String?>((_) => null, (_) => txId);
      final paid = bill.copyWith(
        isPaid: true,
        paidDate: DateTime.now(),
        transactionId: linkedTxId,
      );
      await _col.doc(paid.id).set(BillModel.fromEntity(paid).toFirestore());
      LocalNotificationService.instance.cancelBillReminder(_notifId(bill.id));

      if (bill.repeatMonthly) {
        final d = bill.dueDate;
        final nextMonthLast = DateTime(d.year, d.month + 2, 0).day;
        final nextDue =
            DateTime(d.year, d.month + 1, d.day.clamp(1, nextMonthLast));
        await add(
          title: bill.title,
          amount: bill.amount,
          dueDate: nextDue,
          type: bill.type,
          category: bill.category,
          walletId: bill.walletId,
          reminderDaysBefore: bill.reminderDaysBefore,
          repeatMonthly: true,
        );
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final billsNotifierProvider =
    StateNotifierProvider<BillsNotifier, AsyncValue<void>>((ref) {
  return BillsNotifier(
    ref,
    ref.watch(ledgerOwnerIdProvider),
    ref.watch(workspaceStampProvider),
  );
});
