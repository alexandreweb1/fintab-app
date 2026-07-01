import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/subscription_detector.dart';

const _kDismissedKey = 'dismissed_subscriptions';

/// Normalized keys of subscriptions the user chose to ignore. Persisted in
/// SharedPreferences so dismissed items don't reappear.
final dismissedSubscriptionsProvider =
    StateNotifierProvider<DismissedSubscriptionsNotifier, Set<String>>(
  (ref) => DismissedSubscriptionsNotifier(),
);

class DismissedSubscriptionsNotifier extends StateNotifier<Set<String>> {
  DismissedSubscriptionsNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_kDismissedKey) ?? const []).toSet();
  }

  Future<void> dismiss(String key) async {
    final next = {...state, key};
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDismissedKey, next.toList());
  }

  Future<void> restore(String key) async {
    final next = {...state}..remove(key);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDismissedKey, next.toList());
  }
}

/// Subscriptions inferred from the transaction history, excluding dismissed.
final detectedSubscriptionsProvider =
    Provider<List<DetectedSubscription>>((ref) {
  final txs = ref.watch(visibleTransactionsProvider);
  final dismissed = ref.watch(dismissedSubscriptionsProvider);
  return detectSubscriptions(txs, dismissed: dismissed);
});

/// Sum of the detected subscriptions' monthly amounts.
final subscriptionsMonthlyTotalProvider = Provider<double>((ref) {
  final subs = ref.watch(detectedSubscriptionsProvider);
  return subs.fold<double>(0, (sum, s) => sum + s.monthlyAmount);
});
