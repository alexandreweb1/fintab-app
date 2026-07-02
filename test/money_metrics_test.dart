import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/home/domain/money_metrics.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';

TransactionEntity _tx(TransactionType type, double amount, DateTime date) =>
    TransactionEntity(
      id: '$type-$amount-${date.millisecondsSinceEpoch}',
      userId: 'u',
      title: 't',
      amount: amount,
      type: type,
      category: 'c',
      date: date,
    );

void main() {
  group('computeNetWorthHistory', () {
    test('accumulates income minus expense up to each month end', () {
      final now = DateTime(2026, 3, 15);
      final txs = [
        _tx(TransactionType.income, 1000, DateTime(2026, 1, 10)),
        _tx(TransactionType.expense, 200, DateTime(2026, 1, 20)),
        _tx(TransactionType.income, 500, DateTime(2026, 2, 5)),
        _tx(TransactionType.expense, 100, DateTime(2026, 3, 3)),
      ];
      final h = computeNetWorthHistory(txs, now: now, months: 3);
      expect(h.length, 3);
      expect(h[0].value, 800); // Jan: 1000-200
      expect(h[1].value, 1300); // Feb: +500
      expect(h[2].value, 1200); // Mar: -100
    });

    test('external transfer (no source) adds to net worth; internal nets out',
        () {
      final now = DateTime(2026, 1, 31);
      final txs = [
        _tx(TransactionType.transfer, 300, DateTime(2026, 1, 5)), // external in
        TransactionEntity(
          id: 'internal',
          userId: 'u',
          title: 't',
          amount: 50,
          type: TransactionType.transfer,
          category: 'c',
          date: DateTime(2026, 1, 6),
          walletId: 'a',
          sourceWalletId: 'b', // internal → ignored by net worth
        ),
      ];
      final h = computeNetWorthHistory(txs, now: now, months: 1);
      expect(h.single.value, 300);
    });
  });

  group('computeAgeOfMoney', () {
    test('single income then expense 10 days later → age ~10', () {
      final txs = [
        _tx(TransactionType.income, 1000, DateTime(2026, 3, 1)),
        _tx(TransactionType.expense, 400, DateTime(2026, 3, 11)),
      ];
      final age = computeAgeOfMoney(txs, now: DateTime(2026, 3, 15));
      expect(age, 10);
    });

    test('null when there is no spending', () {
      final txs = [_tx(TransactionType.income, 1000, DateTime(2026, 3, 1))];
      expect(computeAgeOfMoney(txs, now: DateTime(2026, 3, 15)), isNull);
    });

    test('FIFO consumes oldest income first', () {
      final txs = [
        _tx(TransactionType.income, 100, DateTime(2026, 3, 1)),
        _tx(TransactionType.income, 100, DateTime(2026, 3, 11)),
        // spend 100 on day 21: consumes the day-1 lot → age 20
        _tx(TransactionType.expense, 100, DateTime(2026, 3, 21)),
      ];
      expect(computeAgeOfMoney(txs, now: DateTime(2026, 3, 25)), 20);
    });
  });
}
