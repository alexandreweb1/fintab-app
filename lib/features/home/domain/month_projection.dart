import '../../recurring/domain/entities/recurring_transaction_entity.dart';
import '../../transactions/domain/entities/transaction_entity.dart';

/// Forward-looking cash-flow outlook for a single month.
///
/// Derived from realized transactions plus the active recurrences expected for
/// the rest of the month. Mirrors the math used by the "Fluxo" report tab so
/// the dashboard headline and the report stay consistent.
class MonthProjection {
  /// Accumulated, all-time balance as of "today" (or month-end for past
  /// months), ignoring transfers between the user's own wallets.
  final double currentBalance;

  /// Accumulated balance projected to the last day of the month, adding the
  /// recurrences expected between today and month-end.
  final double projectedEndBalance;

  /// Net cash flow expected for the whole month (income − expense), realized so
  /// far plus projected recurrences. Negative means the month closes in the red.
  final double projectedNet;

  /// Realized income so far this month (excludes transfers).
  final double realizedIncome;

  /// Realized expense so far this month (excludes transfers).
  final double realizedExpense;

  /// Whether a forward projection was actually computed — true only for the
  /// current month while days remain. When false the dashboard headline hides.
  final bool hasProjection;

  /// Days still remaining in the month (0 for past months).
  final int daysRemaining;

  const MonthProjection({
    required this.currentBalance,
    required this.projectedEndBalance,
    required this.projectedNet,
    required this.realizedIncome,
    required this.realizedExpense,
    required this.hasProjection,
    required this.daysRemaining,
  });

  /// Whether the month has cash-flow activity worth projecting — suppresses an
  /// empty "+R$ 0,00" headline for new or idle accounts.
  bool get hasActivity =>
      realizedIncome != 0 ||
      realizedExpense != 0 ||
      projectedEndBalance != currentBalance;

  /// True only when a forward projection exists *and* there is activity to show.
  bool get showProjection => hasProjection && hasActivity;
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Computes the [MonthProjection] for [selectedMonth] from all visible
/// [allTxs] and the currently [recurrences] active. [now] is injected so the
/// function stays pure and unit-testable.
MonthProjection computeMonthProjection({
  required List<TransactionEntity> allTxs,
  required List<RecurringTransactionEntity> recurrences,
  required DateTime selectedMonth,
  required DateTime now,
}) {
  final isCurrentMonth =
      selectedMonth.year == now.year && selectedMonth.month == now.month;
  final monthStart = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final isPastMonth = monthStart.isBefore(DateTime(now.year, now.month, 1));
  final daysInMonth = _daysInMonth(selectedMonth.year, selectedMonth.month);

  // Accumulated balance up to the start of the month (ignores transfers, since
  // moving money between the user's own wallets is balance-neutral).
  final balanceBeforeMonth = allTxs
      .where((t) => !t.isTransfer && t.date.isBefore(monthStart))
      .fold<double>(0, (s, t) => t.isIncome ? s + t.amount : s - t.amount);

  // How far into the month realized data goes: today for the current month, the
  // whole month for a past month, nothing for a future month.
  final int lastRealDay = isCurrentMonth
      ? now.day
      : (isPastMonth ? daysInMonth : 0);

  // Realized running balance + realized income/expense within the month.
  double runningBalance = balanceBeforeMonth;
  double realizedIncome = 0;
  double realizedExpense = 0;
  for (final t in allTxs) {
    if (t.isTransfer) continue;
    if (t.date.year != selectedMonth.year ||
        t.date.month != selectedMonth.month ||
        t.date.day > lastRealDay) {
      continue;
    }
    if (t.isIncome) {
      runningBalance += t.amount;
      realizedIncome += t.amount;
    } else if (t.isExpense) {
      runningBalance -= t.amount;
      realizedExpense += t.amount;
    }
  }

  // Project the remaining days from the active recurrences (current month only).
  final hasProjection = isCurrentMonth && lastRealDay < daysInMonth;
  double projBalance = runningBalance;
  if (hasProjection) {
    for (int d = lastRealDay + 1; d <= daysInMonth; d++) {
      final dayDate = DateTime(selectedMonth.year, selectedMonth.month, d);
      for (final r in recurrences) {
        final next =
            r.nextOccurrence(afterDate: dayDate.subtract(const Duration(days: 1)));
        if (next != null &&
            next.year == dayDate.year &&
            next.month == dayDate.month &&
            next.day == dayDate.day) {
          projBalance += r.isIncome ? r.amount : -r.amount;
        }
      }
    }
  }

  return MonthProjection(
    currentBalance: runningBalance,
    projectedEndBalance: projBalance,
    // Net of the whole month = change in accumulated balance over the month.
    projectedNet: projBalance - balanceBeforeMonth,
    realizedIncome: realizedIncome,
    realizedExpense: realizedExpense,
    hasProjection: hasProjection,
    daysRemaining: isCurrentMonth ? daysInMonth - lastRealDay : 0,
  );
}
