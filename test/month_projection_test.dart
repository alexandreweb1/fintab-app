import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/home/domain/month_projection.dart';
import 'package:my_finance_app/features/recurring/domain/entities/recurring_transaction_entity.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';

TransactionEntity _tx({
  required double amount,
  required TransactionType type,
  required DateTime date,
  String category = 'Geral',
}) =>
    TransactionEntity(
      id: 'tx',
      userId: 'u',
      title: 't',
      amount: amount,
      type: type,
      category: category,
      date: date,
    );

RecurringTransactionEntity _rec({
  required double amount,
  required TransactionType type,
  required int day,
  required DateTime start,
  RecurrenceFrequency freq = RecurrenceFrequency.monthly,
}) =>
    RecurringTransactionEntity(
      id: 'rec',
      userId: 'u',
      title: 't',
      amount: amount,
      type: type,
      category: 'c',
      frequency: freq,
      dayOfRecurrence: day,
      startDate: start,
      createdAt: DateTime(2020),
    );

void main() {
  group('computeMonthProjection', () {
    test('current month projects remaining days from recurrences', () {
      final now = DateTime(2026, 6, 15);
      final result = computeMonthProjection(
        allTxs: [
          _tx(amount: 1000, type: TransactionType.income, date: DateTime(2026, 6, 1)),
          _tx(amount: 300, type: TransactionType.expense, date: DateTime(2026, 6, 10)),
        ],
        recurrences: [
          // Falls on Jun 25 — after "today" (Jun 15), so it's projected.
          _rec(
            amount: 200,
            type: TransactionType.expense,
            day: 25,
            start: DateTime(2026, 1, 25),
          ),
        ],
        selectedMonth: DateTime(2026, 6, 1),
        now: now,
      );

      expect(result.realizedIncome, closeTo(1000, 0.001));
      expect(result.realizedExpense, closeTo(300, 0.001));
      expect(result.currentBalance, closeTo(700, 0.001));
      // 700 realized − 200 projected expense on Jun 25.
      expect(result.projectedEndBalance, closeTo(500, 0.001));
      expect(result.projectedNet, closeTo(500, 0.001));
      expect(result.hasProjection, isTrue);
      expect(result.showProjection, isTrue);
      expect(result.daysRemaining, 15);
    });

    test('a recurrence already passed this month is not double-counted', () {
      final now = DateTime(2026, 6, 20);
      final result = computeMonthProjection(
        allTxs: const [],
        recurrences: [
          // Day 10 is in the past relative to "today" (Jun 20): not projected.
          _rec(
            amount: 500,
            type: TransactionType.expense,
            day: 10,
            start: DateTime(2026, 1, 10),
          ),
        ],
        selectedMonth: DateTime(2026, 6, 1),
        now: now,
      );

      // No future occurrence remains → projection equals current balance.
      expect(result.projectedEndBalance, closeTo(result.currentBalance, 0.001));
    });

    test('past month has no projection but realizes the full month', () {
      final now = DateTime(2026, 6, 15);
      final result = computeMonthProjection(
        allTxs: [
          _tx(amount: 500, type: TransactionType.income, date: DateTime(2026, 4, 10)),
          _tx(amount: 100, type: TransactionType.expense, date: DateTime(2026, 5, 5)),
        ],
        recurrences: const [],
        selectedMonth: DateTime(2026, 5, 1),
        now: now,
      );

      // 500 carried in from April − 100 spent in May.
      expect(result.currentBalance, closeTo(400, 0.001));
      expect(result.projectedEndBalance, closeTo(400, 0.001));
      expect(result.projectedNet, closeTo(-100, 0.001));
      expect(result.hasProjection, isFalse);
      expect(result.showProjection, isFalse);
      expect(result.daysRemaining, 0);
    });

    test('transfers are ignored for balance and income/expense', () {
      final now = DateTime(2026, 6, 15);
      final result = computeMonthProjection(
        allTxs: [
          _tx(amount: 1000, type: TransactionType.transfer, date: DateTime(2026, 6, 5)),
          _tx(amount: 50, type: TransactionType.expense, date: DateTime(2026, 6, 6)),
        ],
        recurrences: const [],
        selectedMonth: DateTime(2026, 6, 1),
        now: now,
      );

      expect(result.realizedIncome, closeTo(0, 0.001));
      expect(result.realizedExpense, closeTo(50, 0.001));
      expect(result.currentBalance, closeTo(-50, 0.001));
    });

    test('idle current month yields no meaningful projection', () {
      final now = DateTime(2026, 6, 15);
      final result = computeMonthProjection(
        allTxs: const [],
        recurrences: const [],
        selectedMonth: DateTime(2026, 6, 1),
        now: now,
      );

      expect(result.hasProjection, isTrue); // days remain in the month
      expect(result.hasActivity, isFalse); // ...but nothing to project
      expect(result.showProjection, isFalse);
    });
  });
}
