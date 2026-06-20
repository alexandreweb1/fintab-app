/// Severity drives the visual accent (color + icon) of an insight card.
enum InsightSeverity { positive, info, warning, critical }

/// The kind of insight — used for icon selection, grouping and analytics.
enum InsightKind {
  /// A budget whose spending already exceeded its limit this month.
  budgetOverrun,

  /// A budget close to its limit (≥ 80% used) but not yet over.
  budgetNear,

  /// A budget on pace to exceed its limit by month-end at the current rate.
  budgetPace,

  /// A category whose month-to-date spending jumped vs. the same window of the
  /// previous month.
  spendingSpike,
}

/// A single actionable insight surfaced on the dashboard.
///
/// Pure data: holds no Flutter types so it can be produced and unit-tested
/// without a running app. The presentation layer maps [severity]/[kind] to the
/// icon and color. [message] is already formatted for display (currency
/// included) by the engine.
class Insight {
  final InsightKind kind;
  final InsightSeverity severity;

  /// Short headline — typically the category name.
  final String title;

  /// One-line explanation, ready to display.
  final String message;

  /// Category this insight refers to, when applicable (context / navigation).
  final String? categoryName;

  const Insight({
    required this.kind,
    required this.severity,
    required this.title,
    required this.message,
    this.categoryName,
  });
}
