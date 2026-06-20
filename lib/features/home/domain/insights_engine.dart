import '../../budget/domain/entities/budget_entity.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import 'insight.dart';

/// Builds the list of actionable insights shown on the dashboard.
///
/// Pure function: every input is injected so it can be unit-tested without a
/// running app. Currency formatting is delegated to [fmt] to keep the engine
/// free of presentation concerns.
///
/// Produces three families of insight, deduplicated so a category never appears
/// twice:
///  - **Budget alerts** — already over, near the limit (≥ 80%), or on pace to
///    exceed by month-end at the current rate.
///  - **Spending spikes** — a category whose month-to-date spend jumped vs. the
///    same day-window of the previous month (apples-to-apples).
List<Insight> generateInsights({
  required List<BudgetSummary> budgetSummaries,
  required List<TransactionEntity> allTxs,
  required DateTime selectedMonth,
  required DateTime now,
  required String Function(double) fmt,
}) {
  final insights = <Insight>[];
  final isCurrentMonth =
      selectedMonth.year == now.year && selectedMonth.month == now.month;
  final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
  final today = now.day;

  // Categories already flagged by a budget alert — keeps spikes from repeating
  // a category we already warned about.
  final flagged = <String>{};

  // ── Budget alerts (monthly budgets only) ──
  for (final s in budgetSummaries) {
    if (s.budget.period != BudgetPeriod.monthly || s.budget.isAnnual) continue;
    final cat = s.budget.categoryName;
    final limit = s.budget.limitAmount;
    if (limit <= 0) continue;
    final pct = s.percentage; // can exceed 100

    if (s.isOverBudget) {
      flagged.add(cat);
      insights.add(Insight(
        kind: InsightKind.budgetOverrun,
        severity: InsightSeverity.critical,
        title: cat,
        message: 'Estourou o orçamento: ${fmt(s.spentAmount)} de ${fmt(limit)} '
            '(${pct.round()}%).',
        categoryName: cat,
      ));
      continue;
    }

    if (pct >= 80) {
      flagged.add(cat);
      insights.add(Insight(
        kind: InsightKind.budgetNear,
        severity: InsightSeverity.warning,
        title: cat,
        message: 'Já usou ${pct.round()}% do orçamento — '
            '${fmt(s.spentAmount)} de ${fmt(limit)}.',
        categoryName: cat,
      ));
      continue;
    }

    // Pace projection — only the current month and once enough days have
    // elapsed for the extrapolation to be meaningful.
    if (isCurrentMonth && today >= 5) {
      final projectedSpend = s.spentAmount / (today / daysInMonth);
      if (projectedSpend > limit * 1.05) {
        flagged.add(cat);
        insights.add(Insight(
          kind: InsightKind.budgetPace,
          severity: InsightSeverity.warning,
          title: cat,
          message: 'No ritmo atual deve fechar o mês em ~${fmt(projectedSpend)}, '
              'acima do orçamento de ${fmt(limit)}.',
          categoryName: cat,
        ));
      }
    }
  }

  // ── Spending spikes vs. the same window of the previous month ──
  final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
  final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
  // Equal windows: day 1..cutoff in each month (clamped to the prev month length).
  final cutoff = isCurrentMonth ? today : daysInMonth;
  final prevCutoff = cutoff > daysInPrevMonth ? daysInPrevMonth : cutoff;

  final currentByCat = <String, double>{};
  final priorByCat = <String, double>{};
  for (final t in allTxs) {
    if (!t.isExpense || t.isTransfer) continue;
    if (t.date.year == selectedMonth.year &&
        t.date.month == selectedMonth.month &&
        t.date.day <= cutoff) {
      currentByCat[t.category] = (currentByCat[t.category] ?? 0) + t.amount;
    } else if (t.date.year == prevMonth.year &&
        t.date.month == prevMonth.month &&
        t.date.day <= prevCutoff) {
      priorByCat[t.category] = (priorByCat[t.category] ?? 0) + t.amount;
    }
  }

  final spikes = <({String cat, double current, double prior})>[];
  currentByCat.forEach((cat, current) {
    if (flagged.contains(cat)) return; // already covered by a budget alert
    final prior = priorByCat[cat] ?? 0;
    if (prior < 50 || current < 100) return; // ignore tiny / no baseline
    if (current - prior < 80) return; // ignore small absolute jumps
    if (current / prior < 1.5) return; // need at least +50%
    spikes.add((cat: cat, current: current, prior: prior));
  });
  spikes.sort((a, b) => (b.current - b.prior).compareTo(a.current - a.prior));

  for (final s in spikes.take(2)) {
    final ratio = s.current / s.prior;
    final pctUp = ((ratio - 1) * 100).round();
    insights.add(Insight(
      kind: InsightKind.spendingSpike,
      severity: InsightSeverity.info,
      title: s.cat,
      message: ratio >= 2
          ? 'Mais que dobrou vs. mês passado: ${fmt(s.current)} '
              '(era ${fmt(s.prior)}).'
          : 'Subiu $pctUp% vs. mês passado: ${fmt(s.current)} '
              '(era ${fmt(s.prior)}).',
      categoryName: s.cat,
    ));
  }

  // Most severe first; cap the list so the dashboard stays scannable.
  int rank(InsightSeverity sev) => switch (sev) {
        InsightSeverity.critical => 0,
        InsightSeverity.warning => 1,
        InsightSeverity.info => 2,
        InsightSeverity.positive => 3,
      };
  insights.sort((a, b) => rank(a.severity).compareTo(rank(b.severity)));
  return insights.take(5).toList();
}
