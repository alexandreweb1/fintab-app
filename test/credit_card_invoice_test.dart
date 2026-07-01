import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:my_finance_app/features/wallets/domain/credit_card_invoice.dart';
import 'package:my_finance_app/features/wallets/domain/entities/wallet_entity.dart';

WalletEntity _card({int closingDay = 5, int dueDay = 15}) => WalletEntity(
      id: 'card1',
      userId: 'u',
      name: 'Card',
      iconCodePoint: 0,
      colorValue: 0,
      type: WalletType.creditCard,
      closingDay: closingDay,
      dueDay: dueDay,
    );

TransactionEntity _tx({
  required double amount,
  required DateTime date,
  TransactionType type = TransactionType.expense,
  String? source,
}) =>
    TransactionEntity(
      id: '${date.millisecondsSinceEpoch}_$amount',
      userId: 'u',
      title: 'x',
      amount: amount,
      type: type,
      category: 'c',
      date: date,
      walletId: 'card1',
      sourceWalletId: type == TransactionType.transfer ? (source ?? 'bank') : null,
    );

void main() {
  group('computeCardInvoices', () {
    test('groups purchases by billing cycle and includes the open cycle', () {
      final now = DateTime(2026, 3, 10);
      final txs = [
        _tx(amount: 100, date: DateTime(2026, 2, 10)), // after Feb 5 → Mar 5
        _tx(amount: 50, date: DateTime(2026, 3, 3)), // before Mar 5 → Mar 5
      ];
      final invoices = computeCardInvoices(_card(), txs, now: now);

      // Most-recent first: [Apr(open,0), Mar(closed,150)].
      expect(invoices.length, 2);
      expect(invoices.first.isOpen, true);
      expect(invoices.first.total, 0);

      final march = invoices[1];
      expect(march.total, 150);
      expect(march.status, InvoiceStatus.closed);
      expect(march.closingDate, DateTime(2026, 3, 5));
      expect(march.dueDate, DateTime(2026, 3, 15));
    });

    test('payment allocated FIFO marks the oldest invoice paid', () {
      final now = DateTime(2026, 3, 10);
      final txs = [
        _tx(amount: 150, date: DateTime(2026, 3, 3)),
        _tx(
            amount: 150,
            date: DateTime(2026, 3, 8),
            type: TransactionType.transfer),
      ];
      final invoices = computeCardInvoices(_card(), txs, now: now);
      final march = invoices.firstWhere(
          (i) => i.closingDate == DateTime(2026, 3, 5));
      expect(march.paidAmount, 150);
      expect(march.status, InvoiceStatus.paid);
      expect(march.remaining, 0);
    });

    test('refund (income) reduces the cycle total', () {
      final now = DateTime(2026, 3, 6);
      final txs = [
        _tx(amount: 200, date: DateTime(2026, 3, 2)),
        _tx(amount: 50, date: DateTime(2026, 3, 3), type: TransactionType.income),
      ];
      final invoices = computeCardInvoices(_card(), txs, now: now);
      final march = invoices.firstWhere(
          (i) => i.closingDate == DateTime(2026, 3, 5));
      expect(march.total, 150);
    });

    test('closed and past due without payment is overdue', () {
      final now = DateTime(2026, 3, 20); // after Mar 15 due
      final txs = [_tx(amount: 100, date: DateTime(2026, 3, 3))];
      final invoices = computeCardInvoices(_card(), txs, now: now);
      final march = invoices.firstWhere(
          (i) => i.closingDate == DateTime(2026, 3, 5));
      expect(march.status, InvoiceStatus.overdue);
    });

    test('due day before closing day rolls the due date to next month', () {
      // Close 28, due 5 → due is the 5th of the following month.
      final due = dueDateForClosing(DateTime(2026, 1, 28), 28, 5);
      expect(due, DateTime(2026, 2, 5));
    });
  });
}
