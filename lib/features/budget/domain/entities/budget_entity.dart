import 'package:equatable/equatable.dart';

enum BudgetPeriod {
  monthly,
  quarterly,
  semestral,
  annual;

  static BudgetPeriod fromKey(String? key) {
    switch (key) {
      case 'quarterly':
        return BudgetPeriod.quarterly;
      case 'semestral':
        return BudgetPeriod.semestral;
      case 'annual':
        return BudgetPeriod.annual;
      default:
        return BudgetPeriod.monthly;
    }
  }

  String get key => name;

  int get monthSpan {
    switch (this) {
      case BudgetPeriod.monthly:
        return 1;
      case BudgetPeriod.quarterly:
        return 3;
      case BudgetPeriod.semestral:
        return 6;
      case BudgetPeriod.annual:
        return 12;
    }
  }
}

/// Returns the first day of the period that contains [date] given [period].
DateTime normalizePeriodStart(DateTime date, BudgetPeriod period) {
  switch (period) {
    case BudgetPeriod.monthly:
      return DateTime(date.year, date.month, 1);
    case BudgetPeriod.quarterly:
      final qStartMonth = ((date.month - 1) ~/ 3) * 3 + 1;
      return DateTime(date.year, qStartMonth, 1);
    case BudgetPeriod.semestral:
      final sStartMonth = date.month <= 6 ? 1 : 7;
      return DateTime(date.year, sStartMonth, 1);
    case BudgetPeriod.annual:
      return DateTime(date.year, 1, 1);
  }
}

class BudgetEntity extends Equatable {
  final String id;
  final String userId;
  final String categoryId;
  final String categoryName;
  final double limitAmount;

  /// First day of the budget period (e.g. 2025-01-01 for an annual / Q1 / S1
  /// budget of 2025, or 2025-08-01 for a monthly budget of August 2025).
  final DateTime month;
  /// When true, the budget represents the limit for the whole year and
  /// `month` is January 1st of that year.
  final bool isAnnual;

  /// The kind of period this budget covers. Defaults to monthly for
  /// backward compatibility with documents that don't have the field.
  final BudgetPeriod period;

  /// When a budget was created as a monthly replica of a period budget
  /// (annual / semestral / quarterly), this holds the id of the parent
  /// period budget so the relationship can be tracked.
  final String? parentBudgetId;

  /// When true, the leftover (or overspend) of the previous period is carried
  /// into this period's effective limit. Only meaningful for monthly budgets.
  final bool rollover;

  /// Workspace (Carteira PF/PJ) this doc belongs to. Null = legacy
  /// pre-migration doc (treated as the default workspace).
  final String? workspaceId;

  const BudgetEntity({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.limitAmount,
    required this.month,
    this.isAnnual = false,
    this.period = BudgetPeriod.monthly,
    this.parentBudgetId,
    this.rollover = false,
    this.workspaceId,
  });

  /// First day of the budget period (alias of [month]).
  DateTime get periodStart => month;

  /// First day AFTER the budget period (exclusive end).
  DateTime get periodEnd =>
      DateTime(month.year, month.month + period.monthSpan, 1);

  @override
  List<Object?> get props => [
        id,
        userId,
        categoryId,
        categoryName,
        limitAmount,
        month,
        isAnnual,
        period,
        parentBudgetId,
        rollover,
        workspaceId,
      ];
}

/// View-model combining a budget with its computed spent amount.
class BudgetSummary {
  final BudgetEntity budget;
  final double spentAmount;

  /// Amount carried into this period from the previous one (rollover). Can be
  /// negative when the previous period was overspent. Zero when rollover is off.
  final double carryIn;

  const BudgetSummary({
    required this.budget,
    required this.spentAmount,
    this.carryIn = 0,
  });

  /// The limit actually available this period, including any rollover carry-in.
  double get effectiveLimit => budget.limitAmount + carryIn;

  /// Visual progress for the bar — capped at 1.0 so the indicator
  /// doesn't overflow.
  double get progress => effectiveLimit > 0
      ? (spentAmount / effectiveLimit).clamp(0.0, 1.0)
      : 0.0;

  /// Real percentage of the budget consumed — can exceed 100% when
  /// the user has spent more than the limit.
  double get percentage =>
      effectiveLimit > 0 ? (spentAmount / effectiveLimit) * 100 : 0.0;

  bool get isOverBudget => spentAmount > effectiveLimit;

  double get remaining => effectiveLimit - spentAmount;
}
