import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../budget/presentation/providers/budget_provider.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../data/financial_score_calculator.dart';
import '../../domain/financial_score.dart';

/// Composes existing providers and runs the calculator. The score
/// rebuilds whenever transactions, budgets, goals, reserves or
/// investments change.
final financialScoreProvider = Provider<FinancialScore>((ref) {
  // Score deve refletir a saúde financeira real do usuário,
  // independente de carteiras ocultas dos totais visuais.
  final transactions = ref.watch(transactionsStreamProvider).value ?? const [];
  final budgetSummaries = ref.watch(budgetSummaryProvider);
  final goals = ref.watch(goalsStreamProvider).value ?? [];
  final balances = ref.watch(walletAllBalancesProvider);
  final reserveWallets = ref.watch(reserveWalletsProvider);
  final investmentWallets = ref.watch(investmentWalletsProvider);

  final goalContribs = <String, double>{};
  for (final t in transactions) {
    final id = t.goalId;
    if (id == null || id.isEmpty) continue;
    goalContribs[id] = (goalContribs[id] ?? 0) + t.amount;
  }

  final reserveBalance = reserveWallets.fold<double>(
      0, (s, w) => s + (balances[w.id] ?? 0));
  final investmentBalance = investmentWallets.fold<double>(
      0, (s, w) => s + (balances[w.id] ?? 0));

  return FinancialScoreCalculator().calculate(
    transactions: transactions,
    currentMonthBudgets: budgetSummaries,
    goals: goals,
    goalContributedAmounts: goalContribs,
    reserveBalance: reserveBalance,
    investmentBalance: investmentBalance,
    reserveWalletIds: reserveWallets.map((w) => w.id).toSet(),
    investmentWalletIds: investmentWallets.map((w) => w.id).toSet(),
  );
});
