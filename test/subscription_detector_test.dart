import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/subscriptions/domain/subscription_detector.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';

TransactionEntity _tx(String title, double amount, DateTime date,
        {TransactionType type = TransactionType.expense}) =>
    TransactionEntity(
      id: '$title-${date.millisecondsSinceEpoch}',
      userId: 'u',
      title: title,
      amount: amount,
      type: type,
      category: 'Lazer',
      date: date,
    );

void main() {
  group('detectSubscriptions', () {
    final now = DateTime(2026, 3, 20);

    test('detects a monthly known-merchant charge with 2 occurrences', () {
      final txs = [
        _tx('Netflix', 39.90, DateTime(2026, 1, 15)),
        _tx('Netflix', 39.90, DateTime(2026, 2, 15)),
      ];
      final subs = detectSubscriptions(txs, now: now);
      expect(subs.length, 1);
      expect(subs.first.name, 'Netflix');
      expect(subs.first.monthlyAmount, 39.90);
      expect(subs.first.occurrences, 2);
    });

    test('detects an unknown merchant only with 3+ monthly charges', () {
      final two = [
        _tx('Padoca do Zé', 30, DateTime(2026, 1, 10)),
        _tx('Padoca do Zé', 30, DateTime(2026, 2, 10)),
      ];
      expect(detectSubscriptions(two, now: now), isEmpty);

      final three = [...two, _tx('Padoca do Zé', 30, DateTime(2026, 3, 10))];
      expect(detectSubscriptions(three, now: now).length, 1);
    });

    test('ignores dismissed keys', () {
      final txs = [
        _tx('Spotify', 21.90, DateTime(2026, 1, 5)),
        _tx('Spotify', 21.90, DateTime(2026, 2, 5)),
      ];
      final key = normalizeSubscriptionTitle('Spotify');
      expect(detectSubscriptions(txs, dismissed: {key}, now: now), isEmpty);
    });

    test('skips a subscription abandoned long ago', () {
      final txs = [
        _tx('Netflix', 39.90, DateTime(2025, 1, 15)),
        _tx('Netflix', 39.90, DateTime(2025, 2, 15)),
      ];
      // Last charge > 1 year before "now" → treated as canceled.
      expect(detectSubscriptions(txs, now: now), isEmpty);
    });

    test('does not flag one-off purchases', () {
      final txs = [_tx('Geladeira', 2000, DateTime(2026, 2, 1))];
      expect(detectSubscriptions(txs, now: now), isEmpty);
    });
  });
}
