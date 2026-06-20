import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/insight.dart';
import '../../domain/insights_engine.dart';
import '../../domain/month_projection.dart';
import 'dashboard_provider.dart';

/// Forward-looking projection for the dashboard's selected month. Mirrors the
/// math behind the "Fluxo" report tab so both surfaces stay consistent.
final monthProjectionProvider = Provider<MonthProjection>((ref) {
  final allTxs = ref.watch(visibleTransactionsProvider);
  final recurrences = ref.watch(activeRecurrencesProvider);
  final month = ref.watch(dashboardSelectedMonthProvider);
  return computeMonthProjection(
    allTxs: allTxs,
    recurrences: recurrences,
    selectedMonth: month,
    now: DateTime.now(),
  );
});

/// Actionable insights (budget alerts + spending spikes) for the dashboard's
/// selected month.
final dashboardInsightsProvider = Provider<List<Insight>>((ref) {
  final summaries = ref.watch(dashboardBudgetSummaryProvider);
  final allTxs = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(dashboardSelectedMonthProvider);
  final fmt = ref.watch(currencyFormatterProvider);
  return generateInsights(
    budgetSummaries: summaries,
    allTxs: allTxs,
    selectedMonth: month,
    now: DateTime.now(),
    fmt: fmt,
  );
});
