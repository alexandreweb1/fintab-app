import 'entities/budget_entity.dart';

/// Expense in a single category that has NO budget for the active period.
class UnplannedCategorySpend {
  final String categoryName;
  final double amount;
  final int txCount;

  const UnplannedCategorySpend({
    required this.categoryName,
    required this.amount,
    required this.txCount,
  });
}

/// All spending that fell outside the plan (categories the user never budgeted),
/// grouped by category and totalled.
class UnplannedSpending {
  final List<UnplannedCategorySpend> items;
  final double total;

  const UnplannedSpending({required this.items, required this.total});

  static const empty = UnplannedSpending(items: [], total: 0);

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
}

/// "Como vou fechar o mês" — the aggregate view of the plan for a given period.
///
/// Pure value object (no Riverpod / Flutter) so it can be unit-tested in
/// isolation. Built by [computeCloseout] from the same [BudgetSummary]s the
/// Planning screen already renders, plus the unbudgeted total and the period's
/// income.
class MonthCloseout {
  /// Σ effectiveLimit over budgeted categories (rollover-aware).
  final double totalPlanned;

  /// Σ min(spent, effectiveLimit) — the part of the spend that stayed inside
  /// the limits. Together with [overspend] this equals Σ spent.
  final double spentWithinPlan;

  /// Σ max(0, spent − effectiveLimit) — the slice that burst the limits.
  final double overspend;

  /// Σ max(0, effectiveLimit − spent) — unused room in under-budget
  /// categories, available to remanage/rebalance.
  final double availableRoom;

  /// Total spent in categories with no budget this period.
  final double unplannedTotal;

  /// Income registered in the period (0 when income isn't factored in).
  final double income;

  const MonthCloseout({
    required this.totalPlanned,
    required this.spentWithinPlan,
    required this.overspend,
    required this.availableRoom,
    required this.unplannedTotal,
    required this.income,
  });

  /// How much the user is beyond the plan: overspent categories + unplanned.
  double get totalForaDoPlano => overspend + unplannedTotal;

  /// Projected month-end result: income minus every expense (in-plan + burst +
  /// unplanned). Positive = surplus, negative = deficit.
  double get projectedResult =>
      income - (spentWithinPlan + overspend + unplannedTotal);

  /// True when the unused room in other budgets is enough to absorb everything
  /// that fell outside the plan (the user can rebalance without spending more).
  bool get canRebalance => availableRoom >= totalForaDoPlano;
}

/// Builds a [MonthCloseout] from budget summaries + the unbudgeted total.
///
/// Uses [BudgetSummary.effectiveLimit] (rollover carry-in included) so the math
/// is consistent with the per-category cards. The identity
/// `spentWithinPlan + overspend == Σ spent` always holds.
MonthCloseout computeCloseout({
  required List<BudgetSummary> summaries,
  required double unplannedTotal,
  double income = 0,
}) {
  var totalPlanned = 0.0;
  var spentWithinPlan = 0.0;
  var overspend = 0.0;
  var availableRoom = 0.0;

  for (final s in summaries) {
    final limit = s.effectiveLimit;
    final spent = s.spentAmount;
    totalPlanned += limit;
    if (spent >= limit) {
      spentWithinPlan += limit;
      overspend += spent - limit;
    } else {
      spentWithinPlan += spent;
      availableRoom += limit - spent;
    }
  }

  return MonthCloseout(
    totalPlanned: totalPlanned,
    spentWithinPlan: spentWithinPlan,
    overspend: overspend,
    availableRoom: availableRoom,
    unplannedTotal: unplannedTotal,
    income: income,
  );
}
