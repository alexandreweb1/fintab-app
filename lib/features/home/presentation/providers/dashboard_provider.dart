import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/providers/selected_month_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budget/domain/entities/budget_entity.dart';
import '../../../budget/domain/usecases/get_budgets_usecase.dart';
import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

// ─── Selected month (shared across all tabs) ──────────────────────────────────

// ignore: non_constant_identifier_names
final dashboardSelectedMonthProvider = selectedMonthProvider;

// ─── Budget stream for the dashboard's selected month ─────────────────────────
final dashboardBudgetsStreamProvider =
    StreamProvider<List<BudgetEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  final month = ref.watch(dashboardSelectedMonthProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(getBudgetsUseCaseProvider)
          .call(GetBudgetsParams(userId: effectiveUserId, month: month))
          .map((either) => either.getOrElse(() => []));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// ─── Budget summaries (budgets + transaction spending) for the dashboard month ─
final dashboardBudgetSummaryProvider = Provider<List<BudgetSummary>>((ref) {
  final budgets = ref.watch(dashboardBudgetsStreamProvider).value ?? [];
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(dashboardSelectedMonthProvider);

  return budgets.map((budget) {
    final spent = transactions
        .where((t) =>
            t.isExpense &&
            t.category == budget.categoryName &&
            t.date.year == month.year &&
            t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.amount);
    return BudgetSummary(budget: budget, spentAmount: spent);
  }).toList();
});

// ─── Per-month income / expense for the dashboard selected month ──────────────
final dashboardMonthIncomeProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(dashboardSelectedMonthProvider);
  return transactions
      .where((t) =>
          t.isIncome &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0.0, (sum, t) => sum + t.amount);
});

final dashboardMonthExpenseProvider = Provider<double>((ref) {
  final transactions = ref.watch(visibleTransactionsProvider);
  final month = ref.watch(dashboardSelectedMonthProvider);
  return transactions
      .where((t) =>
          t.isExpense &&
          t.date.year == month.year &&
          t.date.month == month.month)
      .fold(0.0, (sum, t) => sum + t.amount);
});
