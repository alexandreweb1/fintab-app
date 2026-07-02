import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/consolidated_balance_provider.dart';
import '../../../bills/presentation/providers/bills_provider.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../domain/money_metrics.dart';

/// Current net worth (all wallets, multi-currency aware via the consolidated
/// balance). Same value shown as the dashboard total.
final netWorthProvider = Provider<double>((ref) =>
    ref.watch(convertedBalanceProvider));

/// Net worth at the end of each of the last 6 months (oldest → newest).
final netWorthHistoryProvider = Provider<List<NetWorthPoint>>((ref) {
  final txs = ref.watch(visibleTransactionsProvider);
  return computeNetWorthHistory(txs, months: 6);
});

/// Age of Money (days) or null when insufficient history.
final ageOfMoneyProvider = Provider<int?>((ref) {
  final txs = ref.watch(visibleTransactionsProvider);
  return computeAgeOfMoney(txs);
});

/// Cash actually available to spend: sum of regular wallets + the "Geral"
/// bucket. Excludes reserves, investments and credit cards.
final spendableBalanceProvider = Provider<double>((ref) {
  final balances = ref.watch(walletBalancesProvider);
  final wallets = ref.watch(walletsStreamProvider).value ?? const [];
  final typeById = {for (final w in wallets) w.id: w.type};
  var sum = 0.0;
  balances.forEach((id, bal) {
    final t = typeById[id];
    if (id.isEmpty || t == WalletType.regular || t == null) sum += bal;
  });
  return sum;
});

typedef SafeToSpend = ({double total, double perDay, int remainingDays});

/// "Safe to Spend" for the rest of the current month: spendable cash minus the
/// outflows still committed this month (unpaid payable bills due + upcoming
/// recurring expenses).
final safeToSpendProvider = Provider<SafeToSpend>((ref) {
  final now = DateTime.now();
  final spendable = ref.watch(spendableBalanceProvider);
  final committedBills = ref.watch(committedBillsThisMonthProvider);

  final endOfMonth = DateTime(now.year, now.month + 1, 0);
  final today = DateTime(now.year, now.month, now.day);
  var recurringOut = 0.0;
  for (final r in ref.watch(activeRecurrencesProvider)) {
    if (!r.isExpense) continue;
    final next = r.nextOccurrence(afterDate: today);
    if (next != null && !next.isAfter(endOfMonth)) recurringOut += r.amount;
  }

  final total = spendable - committedBills - recurringOut;
  final remainingDays = (endOfMonth.day - now.day + 1).clamp(1, 31);
  final perDay = total > 0 ? total / remainingDays : 0.0;
  return (total: total, perDay: perDay, remainingDays: remainingDays);
});
