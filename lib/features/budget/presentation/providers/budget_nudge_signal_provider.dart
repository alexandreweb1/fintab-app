import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The three post-save budget nudge situations.
enum BudgetNudgeKind {
  /// Free user (Orçamentos is Pro) — show the educational sheet → paywall.
  freeEducational,

  /// Pro user WITH budgets logged an expense in an unbudgeted category —
  /// offer to create a budget for that category.
  createForCategory,

  /// Pro user with NO budgets yet — offer to start budgeting from a model.
  startBudgets,
}

/// Payload that drives the bottom sheet shown by `MainScreen`.
class BudgetNudgePayload {
  final BudgetNudgeKind kind;

  /// The category just logged ('' when not relevant).
  final String categoryName;

  /// Suggested budget amount (the amount just spent) — only for
  /// [BudgetNudgeKind.createForCategory].
  final double suggested;

  /// Amount the user is currently spending outside any plan — used to
  /// personalise the free educational copy.
  final double foraDoPlano;

  const BudgetNudgePayload._(
    this.kind,
    this.categoryName,
    this.suggested,
    this.foraDoPlano,
  );

  const BudgetNudgePayload.freeEducational({
    required String category,
    double foraDoPlano = 0,
  }) : this._(BudgetNudgeKind.freeEducational, category, 0, foraDoPlano);

  const BudgetNudgePayload.createForCategory({
    required String category,
    required double suggested,
  }) : this._(BudgetNudgeKind.createForCategory, category, suggested, 0);

  const BudgetNudgePayload.startBudgets({required String category})
      : this._(BudgetNudgeKind.startBudgets, category, 0, 0);

  /// Whether this nudge is an upsell (free user) vs. an in-product create
  /// prompt (Pro). Drives which "não mostrar de novo" flag it toggles.
  bool get isUpsell => kind == BudgetNudgeKind.freeEducational;
}

/// What the Planning screen should open once it's the active tab.
enum BudgetDialogKind { create, templateChooser }

class BudgetDialogRequest {
  final BudgetDialogKind kind;
  final String categoryName;
  final double suggested;

  const BudgetDialogRequest.create({
    required this.categoryName,
    required this.suggested,
  }) : kind = BudgetDialogKind.create;

  const BudgetDialogRequest.templateChooser()
      : kind = BudgetDialogKind.templateChooser,
        categoryName = '',
        suggested = 0;
}

/// Set by the add-transaction flow, consumed by `MainScreen` to present the
/// nudge sheet from a still-mounted ancestor (mirrors [pendingSuggestionProvider]).
final pendingBudgetNudgeProvider =
    StateProvider<BudgetNudgePayload?>((ref) => null);

/// Set by the nudge sheet's CTA, consumed by `PlanningScreen` to open the
/// pre-filled budget dialog / template chooser once the Orçamentos tab is up.
final pendingBudgetDialogProvider =
    StateProvider<BudgetDialogRequest?>((ref) => null);
