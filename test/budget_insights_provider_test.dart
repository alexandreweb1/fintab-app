import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/core/providers/selected_month_provider.dart';
import 'package:my_finance_app/features/budget/domain/entities/budget_entity.dart';
import 'package:my_finance_app/features/budget/presentation/providers/budget_insights_provider.dart';
import 'package:my_finance_app/features/budget/presentation/providers/budget_provider.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:my_finance_app/features/transactions/presentation/providers/transactions_provider.dart';

BudgetSummary _summary(String cat, double limit, double spent) => BudgetSummary(
      budget: BudgetEntity(
        id: cat,
        userId: 'u',
        categoryId: cat,
        categoryName: cat,
        limitAmount: limit,
        month: DateTime(2026, 6, 1),
      ),
      spentAmount: spent,
    );

TransactionEntity _tx(
  String category,
  double amount,
  DateTime date, {
  TransactionType type = TransactionType.expense,
}) =>
    TransactionEntity(
      id: '$category-${date.millisecondsSinceEpoch}-$amount',
      userId: 'u',
      title: category,
      amount: amount,
      type: type,
      category: category,
      date: date,
    );

ProviderContainer _container({
  required List<TransactionEntity> txs,
  required List<BudgetSummary> summaries,
  BudgetPeriod viewMode = BudgetPeriod.monthly,
  DateTime? month,
}) {
  final c = ProviderContainer(overrides: [
    visibleTransactionsProvider.overrideWithValue(txs),
    activeBudgetSummariesProvider.overrideWithValue(summaries),
    budgetViewModeProvider.overrideWith((ref) => viewMode),
    selectedMonthProvider.overrideWith((ref) => month ?? DateTime(2026, 6, 1)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('unplannedSpendingProvider (monthly)', () {
    test('groups unbudgeted expenses, excludes budgeted / income / transfer / '
        'out-of-window', () {
      final container = _container(
        summaries: [
          _summary('Feira', 1000, 1200),
          _summary('Transporte', 1000, 600),
        ],
        txs: [
          _tx('Feira', 1200, DateTime(2026, 6, 3)), // budgeted → excluded
          _tx('feira', 100, DateTime(2026, 6, 9)), // budgeted (case) → excluded
          _tx('Transporte', 600, DateTime(2026, 6, 5)), // budgeted → excluded
          _tx('Pneu', 400, DateTime(2026, 6, 10)), // unplanned
          _tx('Empréstimo', 650, DateTime(2026, 6, 12)), // unplanned
          _tx('Empréstimo', 50, DateTime(2026, 6, 20)), // unplanned (same cat)
          _tx('Salário', 6000, DateTime(2026, 6, 1),
              type: TransactionType.income), // income → excluded
          _tx('Aporte', 300, DateTime(2026, 6, 6),
              type: TransactionType.transfer), // transfer → excluded
          _tx('Pneu', 999, DateTime(2026, 5, 28)), // prev month → excluded
          _tx('Pneu', 999, DateTime(2026, 7, 2)), // next month → excluded
        ],
      );

      final unplanned = container.read(unplannedSpendingProvider);
      expect(unplanned.total, 1100); // 700 + 400
      expect(unplanned.items, hasLength(2));
      // Sorted by amount desc.
      expect(unplanned.items[0].categoryName, 'Empréstimo');
      expect(unplanned.items[0].amount, 700);
      expect(unplanned.items[0].txCount, 2);
      expect(unplanned.items[1].categoryName, 'Pneu');
      expect(unplanned.items[1].amount, 400);
      expect(unplanned.items[1].txCount, 1);
    });

    test('activeWindowIncome sums only in-window income', () {
      final container = _container(
        summaries: const [],
        txs: [
          _tx('Salário', 6000, DateTime(2026, 6, 1),
              type: TransactionType.income),
          _tx('Extra', 500, DateTime(2026, 6, 15),
              type: TransactionType.income),
          _tx('Salário', 6000, DateTime(2026, 5, 1),
              type: TransactionType.income), // prev month → excluded
          _tx('Feira', 200, DateTime(2026, 6, 3)), // expense → excluded
        ],
      );
      expect(container.read(activeWindowIncomeProvider), 6500);
    });

    test('monthCloseout combines summaries + unplanned + income', () {
      final container = _container(
        summaries: [
          _summary('Feira', 1000, 1200),
          _summary('Transporte', 1000, 600),
        ],
        txs: [
          _tx('Pneu', 400, DateTime(2026, 6, 10)),
          _tx('Empréstimo', 700, DateTime(2026, 6, 12)),
          _tx('Salário', 6000, DateTime(2026, 6, 1),
              type: TransactionType.income),
        ],
      );
      final c = container.read(monthCloseoutProvider);
      expect(c.overspend, 200);
      expect(c.availableRoom, 400);
      expect(c.unplannedTotal, 1100);
      expect(c.totalForaDoPlano, 1300);
      expect(c.income, 6000);
      // 6000 − (1600 + 200 + 1100)
      expect(c.projectedResult, 3100);
    });
  });

  group('unplannedSpendingProvider (quarterly window)', () {
    test('includes the whole quarter, excludes other quarters', () {
      final container = _container(
        viewMode: BudgetPeriod.quarterly,
        month: DateTime(2026, 6, 1), // Q2 = Apr–Jun
        summaries: const [],
        txs: [
          _tx('Pneu', 100, DateTime(2026, 4, 15)), // Q2 → included
          _tx('Pneu', 50, DateTime(2026, 6, 30)), // Q2 → included
          _tx('Pneu', 200, DateTime(2026, 3, 31)), // Q1 → excluded
          _tx('Pneu', 300, DateTime(2026, 7, 1)), // Q3 → excluded
        ],
      );
      final unplanned = container.read(unplannedSpendingProvider);
      expect(unplanned.total, 150);
      expect(unplanned.items.single.txCount, 2);
    });
  });
}
