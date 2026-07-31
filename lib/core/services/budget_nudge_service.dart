import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's "não mostrar de novo" choice for the post-save budget
/// nudge. Two independent switches so opting out of the free upsell doesn't
/// silence the Pro "create a budget" prompt (and vice-versa).
///
/// The nudge fires on every out-of-plan expense (product decision) UNTIL the
/// user disables it here — there is no time throttle by design.
class BudgetNudgeService {
  BudgetNudgeService._();
  static final BudgetNudgeService instance = BudgetNudgeService._();

  static const _kCreateDisabledKey = 'budget_nudge_create_disabled';
  static const _kUpsellDisabledKey = 'budget_nudge_upsell_disabled';

  String _keyFor(bool isUpsell) =>
      isUpsell ? _kUpsellDisabledKey : _kCreateDisabledKey;

  /// Whether the nudge should still be shown for this variant.
  Future<bool> shouldShow({required bool isUpsell}) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_keyFor(isUpsell)) ?? false);
  }

  /// Stops showing this nudge variant on this device.
  Future<void> disable({required bool isUpsell}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(isUpsell), true);
  }
}
