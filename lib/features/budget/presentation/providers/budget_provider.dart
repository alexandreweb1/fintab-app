import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/effective_user_provider.dart';
import '../../../../core/providers/selected_month_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/transactions/domain/entities/transaction_entity.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../data/datasources/budget_remote_datasource.dart';
import '../../data/repositories/budget_repository_impl.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/usecases/delete_budget_usecase.dart';
import '../../domain/usecases/get_budgets_usecase.dart';
import '../../domain/usecases/set_budget_usecase.dart';

// --- Infrastructure ---

final budgetDataSourceProvider = Provider<BudgetRemoteDataSource>(
  (ref) => BudgetRemoteDataSourceImpl(ref.watch(firestoreProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepositoryImpl(ref.watch(budgetDataSourceProvider)),
);

// --- Use Cases ---

final getBudgetsUseCaseProvider = Provider(
  (ref) => GetBudgetsUseCase(ref.watch(budgetRepositoryProvider)),
);

final setBudgetUseCaseProvider = Provider(
  (ref) => SetBudgetUseCase(ref.watch(budgetRepositoryProvider)),
);

final deleteBudgetUseCaseProvider = Provider(
  (ref) => DeleteBudgetUseCase(ref.watch(budgetRepositoryProvider)),
);

// --- View mode (monthly / quarterly / semestral / annual) ---

/// Currently selected budget view mode in the Planning screen.
final budgetViewModeProvider =
    StateProvider<BudgetPeriod>((ref) => BudgetPeriod.monthly);

// --- Stream Providers ---

/// All MONTHLY budgets for the currently selected month. Used by callers
/// that need a per-month view (financial health, dashboard helpers).
final budgetsStreamProvider = StreamProvider<List<BudgetEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  final month = ref.watch(selectedMonthProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(getBudgetsUseCaseProvider)
          .call(GetBudgetsParams(userId: effectiveUserId, month: month))
          .map((either) => either
              .getOrElse(() => [])
              .where((b) => b.period == BudgetPeriod.monthly)
              .toList());
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// All budgets stored in the calendar year of [selectedMonthProvider].
/// Used by the period views (quarterly / semestral / annual).
final budgetsByYearStreamProvider = StreamProvider<List<BudgetEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  final month = ref.watch(selectedMonthProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(budgetRepositoryProvider)
          .watchBudgetsByYear(effectiveUserId, month.year)
          .map((either) => either.getOrElse(() => []));
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Prefix used to mark a [BudgetEntity] as a synthetic view-only aggregation
/// of standalone monthly budgets. Cards with this id can't be edited or
/// deleted directly — the user manages the underlying monthly budgets.
const String kSyntheticBudgetIdPrefix = 'synthetic_';

/// Whether the budget is a synthetic aggregation built by the period views
/// from existing monthly budgets (not persisted in Firestore).
bool isSyntheticBudget(BudgetEntity b) =>
    b.id.startsWith(kSyntheticBudgetIdPrefix);

/// Budgets currently visible on the Planning screen given the active view
/// mode.
///
/// - **Monthly view**: budgets for [selectedMonthProvider].
/// - **Period views** (quarterly / semestral / annual): every explicit
///   period budget in the active window, *plus* a synthetic aggregated
///   period budget per category that only has standalone monthly budgets
///   inside the window — its limit is the sum of those monthly limits.
///   This lets the user see e.g. an annual total in May even when no
///   explicit annual budget exists, summing the monthly limits already
///   defined.
final activeBudgetsProvider = Provider<List<BudgetEntity>>((ref) {
  final viewMode = ref.watch(budgetViewModeProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);

  if (viewMode == BudgetPeriod.monthly) {
    return ref.watch(budgetsStreamProvider).value ?? [];
  }

  final periodStart = normalizePeriodStart(selectedMonth, viewMode);
  final periodEnd = DateTime(
      periodStart.year, periodStart.month + viewMode.monthSpan, 1);
  final all = ref.watch(budgetsByYearStreamProvider).value ?? [];

  // Explicit period budgets for the current window.
  final periodBudgets = all
      .where((b) =>
          b.period == viewMode &&
          b.parentBudgetId == null &&
          b.month.year == periodStart.year &&
          b.month.month == periodStart.month)
      .toList();

  // Categories already represented by an explicit period budget — we don't
  // synthesise on top of those.
  final coveredCategories =
      periodBudgets.map((b) => b.categoryId).toSet();

  // Standalone monthly budgets inside the active window, excluding the
  // automatic monthly replicas (parentBudgetId != null) which are already
  // accounted for via their parent period budget.
  final monthlyWithin = all.where((b) =>
      b.period == BudgetPeriod.monthly &&
      b.parentBudgetId == null &&
      !b.month.isBefore(periodStart) &&
      b.month.isBefore(periodEnd) &&
      !coveredCategories.contains(b.categoryId));

  final aggregates = <String, BudgetEntity>{};
  for (final b in monthlyWithin) {
    final existing = aggregates[b.categoryId];
    if (existing == null) {
      aggregates[b.categoryId] = BudgetEntity(
        id: '$kSyntheticBudgetIdPrefix${b.categoryId}_'
            '${periodStart.year}-${periodStart.month}_${viewMode.key}',
        userId: b.userId,
        categoryId: b.categoryId,
        categoryName: b.categoryName,
        limitAmount: b.limitAmount,
        month: periodStart,
        period: viewMode,
      );
    } else {
      aggregates[b.categoryId] = BudgetEntity(
        id: existing.id,
        userId: existing.userId,
        categoryId: existing.categoryId,
        categoryName: existing.categoryName,
        limitAmount: existing.limitAmount + b.limitAmount,
        month: existing.month,
        period: existing.period,
      );
    }
  }

  return [...periodBudgets, ...aggregates.values];
});

/// Budgets for any specific month (used for month-picker based copy/spending).
final budgetsForMonthProvider =
    StreamProvider.family<List<BudgetEntity>, DateTime>((ref, month) {
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  if (effectiveUserId.isEmpty) return const Stream.empty();
  return ref
      .watch(getBudgetsUseCaseProvider)
      .call(GetBudgetsParams(userId: effectiveUserId, month: month))
      .map((result) => result
          .getOrElse(() => [])
          .where((b) => b.period == BudgetPeriod.monthly)
          .toList());
});

/// Annual budgets (`isAnnual == true`) for the year of the selected month.
final annualBudgetsForYearProvider =
    StreamProvider<List<BudgetEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  final month = ref.watch(selectedMonthProvider);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(budgetRepositoryProvider)
          .watchBudgetsByYear(effectiveUserId, month.year)
          .map((either) =>
              either.getOrElse(() => []).where((b) => b.isAnnual).toList());
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

/// Budgets from the month immediately before [selectedMonthProvider].
final previousMonthBudgetsProvider = StreamProvider<List<BudgetEntity>>((ref) {
  final authState = ref.watch(authStateProvider);
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  final month = ref.watch(selectedMonthProvider);
  final prevMonth = DateTime(month.year, month.month - 1, 1);
  return authState.when(
    data: (user) {
      if (user == null || effectiveUserId.isEmpty) return const Stream.empty();
      return ref
          .watch(getBudgetsUseCaseProvider)
          .call(GetBudgetsParams(userId: effectiveUserId, month: prevMonth))
          .map((either) => either
              .getOrElse(() => [])
              .where((b) => b.period == BudgetPeriod.monthly)
              .toList());
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

// --- Budget Summary Providers (budgets + transaction spending) ---

double _spentForBudget(
    BudgetEntity budget, Iterable<TransactionEntity> transactions) {
  final start = budget.periodStart;
  final end = budget.periodEnd;
  return transactions
      .where((t) =>
          t.isExpense &&
          t.category == budget.categoryName &&
          !t.date.isBefore(start) &&
          t.date.isBefore(end))
      .fold<double>(0.0, (sum, t) => sum + t.amount);
}

/// Summaries for the MONTHLY budgets of [selectedMonthProvider]. Kept stable
/// across view-mode changes so callers like financial health behave as
/// before.
final budgetSummaryProvider = Provider<List<BudgetSummary>>((ref) {
  final monthlyBudgets = (ref.watch(budgetsStreamProvider).value ?? [])
      .where((b) => !b.isAnnual)
      .toList();
  final annualBudgets = ref.watch(annualBudgetsForYearProvider).value ?? [];
  final budgets = [...monthlyBudgets, ...annualBudgets];
  final transactions = ref.watch(visibleTransactionsProvider);
  return budgets
      .map((b) => BudgetSummary(
            budget: b,
            spentAmount: _spentForBudget(b, transactions),
          ))
      .toList();
});

/// Rollover carry-in for a monthly budget: the leftover (or overspend) of the
/// same category's budget in the immediately preceding month. Positive when
/// the previous month was under budget, negative when overspent. Returns 0 when
/// rollover is off, the budget isn't monthly, or there was no previous budget.
double _carryInFor(
  BudgetEntity b,
  List<BudgetEntity> previousBudgets,
  Iterable<TransactionEntity> transactions,
) {
  if (!b.rollover || b.period != BudgetPeriod.monthly) return 0;
  final prev = previousBudgets
      .where((p) => p.categoryId == b.categoryId && p.period == BudgetPeriod.monthly)
      .toList();
  if (prev.isEmpty) return 0;
  final prevBudget = prev.first;
  final prevSpent = _spentForBudget(prevBudget, transactions);
  return prevBudget.limitAmount - prevSpent;
}

/// Summaries for the budgets currently displayed on the Planning screen,
/// based on the active view mode. Spent amount is summed across the budget's
/// full period. Monthly budgets with rollover enabled also carry the previous
/// month's leftover into their effective limit.
final activeBudgetSummariesProvider = Provider<List<BudgetSummary>>((ref) {
  final budgets = ref.watch(activeBudgetsProvider);
  final transactions = ref.watch(visibleTransactionsProvider);
  final viewMode = ref.watch(budgetViewModeProvider);
  final previousBudgets = viewMode == BudgetPeriod.monthly
      ? (ref.watch(previousMonthBudgetsProvider).value ?? const [])
      : const <BudgetEntity>[];
  return budgets
      .map((b) => BudgetSummary(
            budget: b,
            spentAmount: _spentForBudget(b, transactions),
            carryIn: _carryInFor(b, previousBudgets, transactions),
          ))
      .toList();
});

// --- Notifier ---

class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  final SetBudgetUseCase _setBudget;
  final DeleteBudgetUseCase _deleteBudget;
  final String _userId;

  BudgetNotifier(this._setBudget, this._deleteBudget, this._userId)
      : super(const AsyncValue.data(null));

  String _budgetId({
    required String categoryId,
    required DateTime periodStart,
    required BudgetPeriod period,
  }) {
    final mm = periodStart.month.toString().padLeft(2, '0');
    final suffix =
        period == BudgetPeriod.monthly ? '' : '_${period.key}';
    return '${_userId}_${categoryId}_${periodStart.year}-$mm$suffix';
  }

  /// Sets (creates or updates) a budget for a specific period. The [month]
  /// argument can be any date inside the desired period; it is normalised to
  /// the period's first day.
  Future<bool> set({
    required String categoryId,
    required String categoryName,
    required double limitAmount,
    required DateTime month,
    BudgetPeriod period = BudgetPeriod.monthly,
    bool isAnnual = false,
    String? parentBudgetId,
    bool rollover = false,
  }) async {
    state = const AsyncValue.loading();
    final periodStart = normalizePeriodStart(month, period);
    final id = _budgetId(
      categoryId: categoryId,
      periodStart: periodStart,
      period: period,
    );
    final budget = BudgetEntity(
      id: id,
      userId: _userId,
      categoryId: categoryId,
      categoryName: categoryName,
      limitAmount: limitAmount,
      month: periodStart,
      isAnnual: isAnnual,
      period: period,
      parentBudgetId: parentBudgetId,
      rollover: rollover,
    );
    final result = await _setBudget(SetBudgetParams(budget: budget));
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }

  /// Creates a period budget (annual / semestral / quarterly) and, when
  /// [createMonthlyReplicas] is true, also creates one monthly budget per
  /// month covered, dividing [limitAmount] evenly across them.
  ///
  /// For annual budgets, [startMonth] lets the caller cover only part of the
  /// year (e.g. "rest of year" mode starts at the current month instead of
  /// January). The amount is split across the actual covered months.
  Future<bool> createPeriodBudget({
    required String categoryId,
    required String categoryName,
    required double limitAmount,
    required int year,
    required BudgetPeriod period,
    required DateTime startMonth,
    bool createMonthlyReplicas = true,
  }) async {
    final periodStart = normalizePeriodStart(startMonth, period);
    final coveredMonths = period == BudgetPeriod.annual
        ? 12 - periodStart.month + 1
        : period.monthSpan;

    final parentOk = await set(
      categoryId: categoryId,
      categoryName: categoryName,
      limitAmount: limitAmount,
      month: periodStart,
      period: period,
    );
    if (!parentOk) return false;

    if (!createMonthlyReplicas || coveredMonths <= 0) return true;

    final parentId = _budgetId(
      categoryId: categoryId,
      periodStart: periodStart,
      period: period,
    );
    final perMonth = limitAmount / coveredMonths;

    for (var i = 0; i < coveredMonths; i++) {
      final monthDate = DateTime(periodStart.year, periodStart.month + i, 1);
      final ok = await set(
        categoryId: categoryId,
        categoryName: categoryName,
        limitAmount: perMonth,
        month: monthDate,
        period: BudgetPeriod.monthly,
        parentBudgetId: parentId,
      );
      if (!ok) return false;
    }
    return true;
  }

  Future<bool> copyFromPreviousMonth({
    required List<BudgetEntity> previousBudgets,
    required DateTime targetMonth,
  }) async {
    if (previousBudgets.isEmpty) return false;
    state = const AsyncValue.loading();
    final firstOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    for (final budget in previousBudgets) {
      final ok = await set(
        categoryId: budget.categoryId,
        categoryName: budget.categoryName,
        limitAmount: budget.limitAmount,
        month: firstOfMonth,
        period: BudgetPeriod.monthly,
      );
      if (!ok) return false;
    }
    state = const AsyncValue.data(null);
    return true;
  }

  Future<bool> delete(String budgetId) async {
    state = const AsyncValue.loading();
    final result =
        await _deleteBudget(DeleteBudgetParams(budgetId: budgetId));
    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        return true;
      },
    );
  }
}

final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<void>>((ref) {
  final effectiveUserId = ref.watch(effectiveUserIdProvider);
  return BudgetNotifier(
    ref.watch(setBudgetUseCaseProvider),
    ref.watch(deleteBudgetUseCaseProvider),
    effectiveUserId,
  );
});
