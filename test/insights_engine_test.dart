import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/budget/domain/entities/budget_entity.dart';
import 'package:my_finance_app/features/home/domain/insight.dart';
import 'package:my_finance_app/features/home/domain/insights_engine.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';

/// Reference "now": June 15th 2026 → today=15, 30 days in the month.
final _now = DateTime(2026, 6, 15);
final _month = DateTime(2026, 6, 1);

String _fmt(double v) => 'R\$ ${v.toStringAsFixed(0)}';

BudgetSummary _budget(
  String cat,
  double limit,
  double spent, {
  BudgetPeriod period = BudgetPeriod.monthly,
  bool isAnnual = false,
}) =>
    BudgetSummary(
      budget: BudgetEntity(
        id: cat,
        userId: 'u',
        categoryId: cat,
        categoryName: cat,
        limitAmount: limit,
        month: _month,
        period: period,
        isAnnual: isAnnual,
      ),
      spentAmount: spent,
    );

TransactionEntity _expense(String category, double amount, DateTime date) =>
    TransactionEntity(
      id: 'tx',
      userId: 'u',
      title: category,
      amount: amount,
      type: TransactionType.expense,
      category: category,
      date: date,
    );

List<Insight> _run({
  List<BudgetSummary> budgets = const [],
  List<TransactionEntity> txs = const [],
  DateTime? now,
}) =>
    generateInsights(
      budgetSummaries: budgets,
      allTxs: txs,
      selectedMonth: _month,
      now: now ?? _now,
      fmt: _fmt,
    );

void main() {
  group('budget alerts', () {
    test('flags an over-budget category as critical', () {
      final insights = _run(budgets: [_budget('Carro', 1000, 1200)]);
      expect(insights, hasLength(1));
      expect(insights.single.kind, InsightKind.budgetOverrun);
      expect(insights.single.severity, InsightSeverity.critical);
      expect(insights.single.categoryName, 'Carro');
      expect(insights.single.message, contains('120%'));
    });

    test('flags a near-limit category (>= 80%) as warning', () {
      final insights = _run(budgets: [_budget('Saúde', 1000, 850)]);
      expect(insights.single.kind, InsightKind.budgetNear);
      expect(insights.single.severity, InsightSeverity.warning);
      expect(insights.single.message, contains('85%'));
    });

    test('warns when on pace to exceed even if under 80% now', () {
      // 600 spent by day 15 of 30 → projected ~1200 > 1000.
      final insights = _run(budgets: [_budget('Lazer', 1000, 600)]);
      expect(insights.single.kind, InsightKind.budgetPace);
      expect(insights.single.severity, InsightSeverity.warning);
    });

    test('no pace alert when projection stays within the limit', () {
      // 400 by day 15 → projected ~800 < 1000.
      final insights = _run(budgets: [_budget('Casa', 1000, 400)]);
      expect(insights, isEmpty);
    });

    test('suppresses pace alerts in the first days of the month', () {
      final insights = _run(
        budgets: [_budget('Lazer', 1000, 600)],
        now: DateTime(2026, 6, 3), // today < 5 → not enough data
      );
      expect(insights, isEmpty);
    });

    test('ignores non-monthly / annual budgets', () {
      final insights = _run(
        budgets: [
          _budget('Viagem', 12000, 15000,
              period: BudgetPeriod.annual, isAnnual: true),
        ],
      );
      expect(insights, isEmpty);
    });
  });

  group('spending spikes', () {
    test('flags a category that more than doubled vs. last month', () {
      final insights = _run(txs: [
        _expense('Mercado', 200, DateTime(2026, 5, 5)), // prior window
        _expense('Mercado', 500, DateTime(2026, 6, 4)), // current window
      ]);
      expect(insights.single.kind, InsightKind.spendingSpike);
      expect(insights.single.severity, InsightSeverity.info);
      expect(insights.single.categoryName, 'Mercado');
      expect(insights.single.message, contains('dobrou'));
    });

    test('compares equal day-windows: spend after today is excluded', () {
      final insights = _run(txs: [
        _expense('Mercado', 200, DateTime(2026, 5, 5)),
        _expense('Mercado', 500, DateTime(2026, 6, 20)), // day 20 > today 15
      ]);
      expect(insights, isEmpty);
    });

    test('ignores tiny baselines and small absolute jumps', () {
      final insights = _run(txs: [
        // Baseline below R$50.
        _expense('Café', 40, DateTime(2026, 5, 1)),
        _expense('Café', 90, DateTime(2026, 6, 1)),
        // +50% but absolute jump < R$80.
        _expense('Banca', 100, DateTime(2026, 5, 1)),
        _expense('Banca', 150, DateTime(2026, 6, 1)),
      ]);
      expect(insights, isEmpty);
    });

    test('does not repeat a category already covered by a budget alert', () {
      final insights = _run(
        budgets: [_budget('Mercado', 300, 400)], // over budget
        txs: [
          _expense('Mercado', 150, DateTime(2026, 5, 5)),
          _expense('Mercado', 400, DateTime(2026, 6, 4)),
        ],
      );
      expect(insights, hasLength(1));
      expect(insights.single.kind, InsightKind.budgetOverrun);
    });
  });

  group('ordering & capping', () {
    test('sorts most-severe first and caps at five', () {
      final insights = _run(
        budgets: [
          _budget('Carro', 1000, 1200), // critical
          _budget('Saúde', 1000, 850), // warning (near)
          _budget('Lazer', 1000, 600), // warning (pace)
        ],
        txs: [
          _expense('Mercado', 200, DateTime(2026, 5, 5)),
          _expense('Mercado', 500, DateTime(2026, 6, 4)), // info spike
          _expense('Farmácia', 100, DateTime(2026, 5, 5)),
          _expense('Farmácia', 300, DateTime(2026, 6, 4)), // info spike
        ],
      );
      expect(insights.length, lessThanOrEqualTo(5));
      expect(insights.first.severity, InsightSeverity.critical);
      // Info-level spikes must never outrank a warning.
      final firstInfo = insights.indexWhere(
          (i) => i.severity == InsightSeverity.info);
      final lastWarning = insights.lastIndexWhere(
          (i) => i.severity == InsightSeverity.warning);
      expect(firstInfo, greaterThan(lastWarning));
    });
  });
}
