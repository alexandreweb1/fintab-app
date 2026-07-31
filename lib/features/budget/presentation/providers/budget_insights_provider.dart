import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/selected_month_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/month_closeout.dart';
import 'budget_provider.dart';

/// [start, end) window covered by the active view mode for [selectedMonth].
/// Mirrors the math already inline in [activeBudgetsProvider].
({DateTime start, DateTime end}) _activeWindow(
    BudgetPeriod viewMode, DateTime selectedMonth) {
  if (viewMode == BudgetPeriod.monthly) {
    return (
      start: DateTime(selectedMonth.year, selectedMonth.month, 1),
      end: DateTime(selectedMonth.year, selectedMonth.month + 1, 1),
    );
  }
  final start = normalizePeriodStart(selectedMonth, viewMode);
  final end = DateTime(start.year, start.month + viewMode.monthSpan, 1);
  return (start: start, end: end);
}

/// Normalised set of category names that DO have a budget in the active view.
/// Derived from [activeBudgetSummariesProvider] so it inherits period-window
/// correctness (incl. synthetic aggregated period budgets) and workspace scope.
final _budgetedCategoryNamesProvider = Provider<Set<String>>((ref) {
  final summaries = ref.watch(activeBudgetSummariesProvider);
  return summaries
      .map((s) => s.budget.categoryName.toLowerCase().trim())
      .toSet();
});

/// Expenses that fell in categories with NO budget for the active period,
/// grouped by category and totalled. This is the "Não planejados" bucket.
final unplannedSpendingProvider = Provider<UnplannedSpending>((ref) {
  final viewMode = ref.watch(budgetViewModeProvider);
  final month = ref.watch(selectedMonthProvider);
  final w = _activeWindow(viewMode, month);
  final budgeted = ref.watch(_budgetedCategoryNamesProvider);
  final txs = ref.watch(visibleTransactionsProvider);

  final amounts = <String, double>{};
  final counts = <String, int>{};
  for (final t in txs) {
    if (!t.isExpense) continue;
    if (t.date.isBefore(w.start) || !t.date.isBefore(w.end)) continue;
    if (budgeted.contains(t.category.toLowerCase().trim())) continue;
    // Key by the raw display name so the user's own casing is preserved.
    amounts[t.category] = (amounts[t.category] ?? 0) + t.amount;
    counts[t.category] = (counts[t.category] ?? 0) + 1;
  }

  final items = amounts.entries
      .map((e) => UnplannedCategorySpend(
            categoryName: e.key,
            amount: e.value,
            txCount: counts[e.key] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final total = items.fold<double>(0, (s, i) => s + i.amount);
  return UnplannedSpending(items: items, total: total);
});

/// Total income registered within the active view window. Unlike
/// [statementMonthIncomeProvider] (month-only) this respects the current view
/// mode, so the fechamento projection works for quarterly / annual views too.
final activeWindowIncomeProvider = Provider<double>((ref) {
  final viewMode = ref.watch(budgetViewModeProvider);
  final month = ref.watch(selectedMonthProvider);
  final w = _activeWindow(viewMode, month);
  final txs = ref.watch(visibleTransactionsProvider);
  var total = 0.0;
  for (final t in txs) {
    if (!t.isIncome) continue;
    if (t.date.isBefore(w.start) || !t.date.isBefore(w.end)) continue;
    total += t.amount;
  }
  return total;
});

/// The "como vou fechar o mês" model for the active period: plan totals,
/// overspend, folga, não-planejados and — factoring income in — the projected
/// month-end surplus/deficit.
final monthCloseoutProvider = Provider<MonthCloseout>((ref) {
  final summaries = ref.watch(activeBudgetSummariesProvider);
  final unplannedTotal = ref.watch(unplannedSpendingProvider).total;
  final income = ref.watch(activeWindowIncomeProvider);
  return computeCloseout(
    summaries: summaries,
    unplannedTotal: unplannedTotal,
    income: income,
  );
});
