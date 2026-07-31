import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/budget/domain/entities/budget_entity.dart';
import 'package:my_finance_app/features/budget/domain/month_closeout.dart';

final _month = DateTime(2026, 6, 1);

BudgetSummary _summary(
  String cat,
  double limit,
  double spent, {
  double carryIn = 0,
}) =>
    BudgetSummary(
      budget: BudgetEntity(
        id: cat,
        userId: 'u',
        categoryId: cat,
        categoryName: cat,
        limitAmount: limit,
        month: _month,
      ),
      spentAmount: spent,
      carryIn: carryIn,
    );

void main() {
  group('computeCloseout', () {
    test('overspends a single category (1000 → 1200)', () {
      final c = computeCloseout(
        summaries: [_summary('Feira', 1000, 1200)],
        unplannedTotal: 0,
      );
      expect(c.totalPlanned, 1000);
      expect(c.spentWithinPlan, 1000);
      expect(c.overspend, 200);
      expect(c.availableRoom, 0);
      expect(c.totalForaDoPlano, 200);
    });

    test('under-budget category contributes folga (availableRoom)', () {
      final c = computeCloseout(
        summaries: [
          _summary('Feira', 1000, 1200), // over by 200
          _summary('Transporte', 1000, 600), // 400 folga
        ],
        unplannedTotal: 0,
      );
      expect(c.overspend, 200);
      expect(c.availableRoom, 400);
      expect(c.canRebalance, isTrue); // 400 >= 200
    });

    test('unplannedTotal feeds totalForaDoPlano and can break rebalance', () {
      final c = computeCloseout(
        summaries: [
          _summary('Feira', 1000, 1200), // over by 200
          _summary('Transporte', 1000, 600), // 400 folga
        ],
        unplannedTotal: 1050, // pneu + empréstimo
      );
      expect(c.totalForaDoPlano, 200 + 1050);
      expect(c.availableRoom, 400);
      expect(c.canRebalance, isFalse); // 400 < 1250
    });

    test('projectedResult = income − all expenses', () {
      final c = computeCloseout(
        summaries: [
          _summary('Feira', 1000, 1200),
          _summary('Transporte', 1000, 600),
        ],
        unplannedTotal: 1050,
        income: 6000,
      );
      // 6000 − (spentWithinPlan 1600 + overspend 200 + unplanned 1050) = 3150
      expect(c.projectedResult, 3150);
    });

    test('deficit when expenses exceed income', () {
      final c = computeCloseout(
        summaries: [_summary('Feira', 1000, 1200)],
        unplannedTotal: 500,
        income: 1000,
      );
      // 1000 − (1000 + 200 + 500) = −700
      expect(c.projectedResult, -700);
    });

    test('identity: spentWithinPlan + overspend == Σ spent', () {
      final summaries = [
        _summary('A', 300, 500),
        _summary('B', 800, 200),
        _summary('C', 100, 100),
      ];
      final c = computeCloseout(summaries: summaries, unplannedTotal: 0);
      final totalSpent = summaries.fold<double>(0, (s, x) => s + x.spentAmount);
      expect(c.spentWithinPlan + c.overspend, totalSpent);
    });

    test('rollover carry-in is respected via effectiveLimit', () {
      // limit 1000 + carryIn 200 = effectiveLimit 1200; spent 1100 → under.
      final c = computeCloseout(
        summaries: [_summary('Feira', 1000, 1100, carryIn: 200)],
        unplannedTotal: 0,
      );
      expect(c.totalPlanned, 1200);
      expect(c.overspend, 0);
      expect(c.availableRoom, 100);
    });

    test('empty plan with only unplanned spending', () {
      final c = computeCloseout(
        summaries: const [],
        unplannedTotal: 800,
        income: 2000,
      );
      expect(c.totalPlanned, 0);
      expect(c.totalForaDoPlano, 800);
      expect(c.projectedResult, 1200);
    });
  });
}
