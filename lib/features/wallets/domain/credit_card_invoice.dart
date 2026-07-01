import '../../transactions/domain/entities/transaction_entity.dart';
import 'entities/wallet_entity.dart';

enum InvoiceStatus {
  /// Current cycle — still accepting purchases (closing date in the future).
  open,

  /// Cycle closed, awaiting payment.
  closed,

  /// Fully paid.
  paid,

  /// Closed and past its due date without full payment.
  overdue,
}

/// A single credit-card invoice (fatura) for one billing cycle.
class CardInvoice {
  final DateTime closingDate;
  final DateTime dueDate;

  /// Purchase/refund transactions that fall in this cycle (most recent first).
  final List<TransactionEntity> transactions;

  /// Net total of the cycle (purchases minus refunds).
  final double total;

  /// Payments allocated to this invoice (FIFO, oldest cycle first).
  final double paidAmount;

  final InvoiceStatus status;

  const CardInvoice({
    required this.closingDate,
    required this.dueDate,
    required this.transactions,
    required this.total,
    required this.paidAmount,
    required this.status,
  });

  double get remaining {
    final r = total - paidAmount;
    return r < 0 ? 0 : r;
  }

  bool get isOpen => status == InvoiceStatus.open;
  bool get isPaid => status == InvoiceStatus.paid;
}

DateTime _dateOnly(DateTime x) => DateTime(x.year, x.month, x.day);

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

int _clampDay(int day, int year, int month) =>
    day.clamp(1, _daysInMonth(year, month));

({int year, int month}) _nextMonth(int year, int month) =>
    month == 12 ? (year: year + 1, month: 1) : (year: year, month: month + 1);

/// The closing date of the invoice that a purchase on [date] belongs to.
/// Purchases on or before the closing day land in that month's invoice; later
/// purchases roll into the next month's.
DateTime closingDateForPurchase(DateTime date, int closingDay) {
  final d = _dateOnly(date);
  final cand = DateTime(d.year, d.month, _clampDay(closingDay, d.year, d.month));
  if (!d.isAfter(cand)) return cand;
  final n = _nextMonth(d.year, d.month);
  return DateTime(n.year, n.month, _clampDay(closingDay, n.year, n.month));
}

/// The due date for an invoice that closes on [closingDate]. When the due day
/// falls after the closing day it's the same month; otherwise the next month.
DateTime dueDateForClosing(DateTime closingDate, int closingDay, int dueDay) {
  if (dueDay > closingDay) {
    return DateTime(closingDate.year, closingDate.month,
        _clampDay(dueDay, closingDate.year, closingDate.month));
  }
  final n = _nextMonth(closingDate.year, closingDate.month);
  return DateTime(n.year, n.month, _clampDay(dueDay, n.year, n.month));
}

/// Builds the list of invoices for a credit-card [card] from its [cardTxs]
/// (all transactions whose walletId is the card). Expenses are purchases,
/// income entries are refunds (reduce the cycle), and transfers into the card
/// are payments allocated FIFO to the oldest unpaid invoices.
///
/// Returned most-recent first. Always includes the current (open) cycle even
/// when it has no transactions yet.
List<CardInvoice> computeCardInvoices(
  WalletEntity card,
  Iterable<TransactionEntity> cardTxs, {
  DateTime? now,
}) {
  final today = _dateOnly(now ?? DateTime.now());
  final closingDay = card.closingDay;
  final dueDay = card.dueDay;

  // Group purchases/refunds by their invoice closing date.
  final byCycle = <int, List<TransactionEntity>>{};
  final cycleTotal = <int, double>{};
  var totalPayments = 0.0;

  for (final t in cardTxs) {
    if (t.isTransfer) {
      // A transfer INTO the card (destination == card) is a payment.
      if (t.walletId == card.id) totalPayments += t.amount;
      continue;
    }
    final signed = t.isExpense ? t.amount : -t.amount; // income = refund
    final close = closingDateForPurchase(t.date, closingDay);
    final key = close.millisecondsSinceEpoch;
    (byCycle[key] ??= []).add(t);
    cycleTotal[key] = (cycleTotal[key] ?? 0) + signed;
  }

  // Ensure the current cycle exists even when empty.
  final currentClose = closingDateForPurchase(today, closingDay);
  byCycle.putIfAbsent(currentClose.millisecondsSinceEpoch, () => []);
  cycleTotal.putIfAbsent(currentClose.millisecondsSinceEpoch, () => 0);

  // Ascending closing dates for FIFO payment allocation.
  final keysAsc = byCycle.keys.toList()..sort();

  var paymentPool = totalPayments;
  final invoices = <CardInvoice>[];
  for (final key in keysAsc) {
    final closingDate = DateTime.fromMillisecondsSinceEpoch(key);
    final total = cycleTotal[key] ?? 0;
    final txs = byCycle[key]!
      ..sort((a, b) => b.date.compareTo(a.date));

    // Allocate payments oldest-first, capped at the cycle's positive total.
    var paid = 0.0;
    if (total > 0 && paymentPool > 0) {
      paid = paymentPool >= total ? total : paymentPool;
      paymentPool -= paid;
    }

    final dueDate = dueDateForClosing(closingDate, closingDay, dueDay);
    final isCurrent = !closingDate.isBefore(today);
    final fullyPaid = total > 0 && paid >= total - 0.001;

    final InvoiceStatus status;
    if (fullyPaid) {
      status = InvoiceStatus.paid;
    } else if (isCurrent) {
      status = InvoiceStatus.open;
    } else if (today.isAfter(_dateOnly(dueDate))) {
      status = InvoiceStatus.overdue;
    } else {
      status = InvoiceStatus.closed;
    }

    invoices.add(CardInvoice(
      closingDate: closingDate,
      dueDate: dueDate,
      transactions: txs,
      total: total,
      paidAmount: paid,
      status: status,
    ));
  }

  // Most recent first for display.
  return invoices.reversed.toList();
}
