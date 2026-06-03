import '../../budget/domain/entities/budget_entity.dart';
import '../../goals/domain/entities/goal_entity.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import '../domain/financial_score.dart';

/// Pure, side-effect-free score computation. All inputs are explicit so
/// the calculator can be unit tested without Riverpod or Firebase.
class FinancialScoreCalculator {
  /// Number of days used to derive averages and ratios.
  static const int _windowDays = 90;

  FinancialScore calculate({
    required List<TransactionEntity> transactions,
    required List<BudgetSummary> currentMonthBudgets,
    required List<GoalEntity> goals,
    required Map<String, double> goalContributedAmounts,
    required double reserveBalance,
    required double investmentBalance,
    required Set<String> reserveWalletIds,
    required Set<String> investmentWalletIds,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final windowStart =
        reference.subtract(const Duration(days: _windowDays));
    final windowed = transactions
        .where((t) => !t.date.isBefore(windowStart) && !t.date.isAfter(reference))
        .toList();

    final factors = <ScoreFactor>[
      _savingsRate(windowed),
      _emergencyReserve(windowed, reserveBalance, reserveWalletIds),
      _budgetAdherence(currentMonthBudgets),
      _goalMomentum(goals, goalContributedAmounts, transactions, reference),
      _spendingConcentration(windowed),
      _investments(windowed, investmentBalance, investmentWalletIds, reference),
    ];

    final measured = factors.where((f) => f.measured).toList();
    final score = measured.isEmpty
        ? 0.0
        : (measured.fold<double>(0, (sum, f) => sum + f.value) /
                measured.length) *
            5; // 0..20 → 0..100

    return FinancialScore(
      score: score,
      level: _levelFor(score),
      factors: factors,
    );
  }

  // ── Factor 1: Savings rate ────────────────────────────────────────────────
  ScoreFactor _savingsRate(List<TransactionEntity> txs) {
    final income = txs
        .where((t) => t.isIncome)
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = txs
        .where((t) => t.isExpense)
        .fold<double>(0, (s, t) => s + t.amount);
    if (income <= 0) {
      return const ScoreFactor(
        kind: ScoreFactorKind.savingsRate,
        value: 0,
        measured: false,
        headline: 'Sem receitas registradas nos últimos 90 dias.',
      );
    }
    final rate = (income - expense) / income;
    final value = rate >= 0.30
        ? 20.0
        : rate >= 0.20
            ? 16.0
            : rate >= 0.10
                ? 12.0
                : rate >= 0
                    ? 6.0
                    : 0.0;
    final pct = (rate * 100).toStringAsFixed(0);
    return ScoreFactor(
      kind: ScoreFactorKind.savingsRate,
      value: value,
      measured: true,
      headline: 'Você poupou $pct% da renda nos últimos 90 dias.',
      hint: rate < 0.10
          ? 'Tente reservar pelo menos 10% da renda mensal.'
          : null,
    );
  }

  // ── Factor 2: Emergency reserve (months of expense covered) ───────────────
  // Now uses the SUM of reserve wallets balance, not total balance.
  ScoreFactor _emergencyReserve(
    List<TransactionEntity> txs,
    double reserveBalance,
    Set<String> reserveWalletIds,
  ) {
    final expense = txs
        .where((t) => t.isExpense)
        .fold<double>(0, (s, t) => s + t.amount);
    final monthlyExpense = expense / 3.0;
    if (reserveWalletIds.isEmpty) {
      return const ScoreFactor(
        kind: ScoreFactorKind.emergencyReserve,
        value: 0,
        measured: false,
        headline: 'Cadastre uma carteira de Reserva para medir sua cobertura.',
        hint: 'Crie uma carteira do tipo Reserva no Extrato.',
      );
    }
    if (monthlyExpense <= 0) {
      return const ScoreFactor(
        kind: ScoreFactorKind.emergencyReserve,
        value: 0,
        measured: false,
        headline: 'Sem despesas suficientes para estimar a reserva.',
      );
    }
    final months = reserveBalance / monthlyExpense;
    final value = months >= 6
        ? 20.0
        : months >= 3
            ? 16.0
            : months >= 1
                ? 10.0
                : months > 0
                    ? 5.0
                    : 0.0;
    return ScoreFactor(
      kind: ScoreFactorKind.emergencyReserve,
      value: value,
      measured: true,
      headline:
          'Sua reserva cobre ${months.clamp(-99, 99).toStringAsFixed(1)} meses de despesas.',
      hint: months < 3
          ? 'Trabalhe para alcançar pelo menos 3 meses de despesas guardados.'
          : null,
    );
  }

  // ── Factor 3: Budget adherence ───────────────────────────────────────────
  ScoreFactor _budgetAdherence(List<BudgetSummary> summaries) {
    if (summaries.isEmpty) {
      return const ScoreFactor(
        kind: ScoreFactorKind.budgetAdherence,
        value: 0,
        measured: false,
        headline: 'Crie orçamentos para medir sua disciplina mensal.',
      );
    }
    final ok = summaries.where((s) => !s.isOverBudget).length;
    final ratio = ok / summaries.length;
    final value = ratio >= 1
        ? 20.0
        : ratio >= 0.80
            ? 16.0
            : ratio >= 0.60
                ? 12.0
                : ratio >= 0.40
                    ? 8.0
                    : 0.0;
    return ScoreFactor(
      kind: ScoreFactorKind.budgetAdherence,
      value: value,
      measured: true,
      headline:
          '$ok de ${summaries.length} orçamentos dentro do limite neste mês.',
      hint: ratio < 0.80
          ? 'Revise os orçamentos estourados e ajuste limites ou hábitos.'
          : null,
    );
  }

  // ── Factor 4: Goal momentum (active goals receiving contributions) ───────
  ScoreFactor _goalMomentum(
    List<GoalEntity> goals,
    Map<String, double> contributed,
    List<TransactionEntity> allTxs,
    DateTime reference,
  ) {
    final active = goals
        .where((g) => !g.isCompleted(contributed[g.id] ?? 0))
        .toList();
    if (active.isEmpty) {
      return const ScoreFactor(
        kind: ScoreFactorKind.goalMomentum,
        value: 0,
        measured: false,
        headline: 'Crie uma meta para acompanhar seu progresso.',
      );
    }
    final cutoff = reference.subtract(const Duration(days: 30));
    final goalsWithRecentDeposit = active.where((g) {
      return allTxs.any((t) =>
          t.goalId == g.id && !t.date.isBefore(cutoff));
    }).length;
    final ratio = goalsWithRecentDeposit / active.length;
    final value = ratio >= 0.80
        ? 20.0
        : ratio >= 0.60
            ? 16.0
            : ratio >= 0.40
                ? 12.0
                : ratio >= 0.20
                    ? 6.0
                    : 0.0;
    return ScoreFactor(
      kind: ScoreFactorKind.goalMomentum,
      value: value,
      measured: true,
      headline:
          '$goalsWithRecentDeposit de ${active.length} metas receberam aporte nos últimos 30 dias.',
      hint: ratio < 0.60
          ? 'Faça um aporte recorrente nas metas ativas para manter o ritmo.'
          : null,
    );
  }

  // ── Factor 5: Spending concentration ─────────────────────────────────────
  ScoreFactor _spendingConcentration(List<TransactionEntity> txs) {
    final byCategory = <String, double>{};
    double total = 0;
    for (final t in txs.where((t) => t.isExpense)) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      total += t.amount;
    }
    if (total <= 0) {
      return const ScoreFactor(
        kind: ScoreFactorKind.spendingConcentration,
        value: 0,
        measured: false,
        headline: 'Sem despesas suficientes para medir a concentração.',
      );
    }
    final topEntry = byCategory.entries
        .reduce((a, b) => a.value >= b.value ? a : b);
    final share = topEntry.value / total;
    final value = share < 0.30
        ? 20.0
        : share < 0.45
            ? 16.0
            : share < 0.60
                ? 10.0
                : share < 0.75
                    ? 5.0
                    : 0.0;
    final pct = (share * 100).toStringAsFixed(0);
    return ScoreFactor(
      kind: ScoreFactorKind.spendingConcentration,
      value: value,
      measured: true,
      headline:
          '"${topEntry.key}" concentra $pct% das suas despesas.',
      hint: share >= 0.45
          ? 'Diversifique seus gastos ou avalie cortes nesta categoria.'
          : null,
    );
  }

  // ── Factor 6: Investments (taxa de aporte vs renda) ──────────────────────
  // Mede quanto da renda dos últimos 90 dias virou aporte em carteiras
  // de investimento.
  ScoreFactor _investments(
    List<TransactionEntity> txs,
    double investmentBalance,
    Set<String> investmentWalletIds,
    DateTime reference,
  ) {
    if (investmentWalletIds.isEmpty) {
      return const ScoreFactor(
        kind: ScoreFactorKind.investments,
        value: 0,
        measured: false,
        headline: 'Cadastre uma carteira de Investimento para começar.',
        hint: 'Crie uma carteira do tipo Investimento no Extrato.',
      );
    }
    final income = txs
        .where((t) => t.isIncome)
        .fold<double>(0, (s, t) => s + t.amount);
    if (income <= 0) {
      return const ScoreFactor(
        kind: ScoreFactorKind.investments,
        value: 0,
        measured: false,
        headline: 'Sem receitas registradas para comparar com aportes.',
      );
    }
    // Net flow into investment wallets in the window: aportes − resgates.
    double netInvested = 0;
    for (final t in txs.where((t) => t.isTransfer)) {
      final intoInvestment = investmentWalletIds.contains(t.walletId);
      final outOfInvestment =
          t.sourceWalletId != null && investmentWalletIds.contains(t.sourceWalletId);
      if (intoInvestment) netInvested += t.amount;
      if (outOfInvestment) netInvested -= t.amount;
    }
    final rate = netInvested / income;
    final value = rate >= 0.20
        ? 20.0
        : rate >= 0.10
            ? 16.0
            : rate >= 0.05
                ? 12.0
                : rate > 0
                    ? 6.0
                    : 0.0;
    final pct = (rate * 100).toStringAsFixed(0);
    final headline = netInvested > 0
        ? 'Você investiu $pct% da renda nos últimos 90 dias.'
        : 'Nenhum aporte líquido em investimentos nos últimos 90 dias.';
    return ScoreFactor(
      kind: ScoreFactorKind.investments,
      value: value,
      measured: true,
      headline: headline,
      hint: rate < 0.05
          ? 'Aporte regularmente para fazer seu patrimônio crescer.'
          : null,
    );
  }

  HealthLevel _levelFor(double score) {
    if (score >= 86) return HealthLevel.excellent;
    if (score >= 71) return HealthLevel.good;
    if (score >= 51) return HealthLevel.fair;
    if (score >= 31) return HealthLevel.attention;
    return HealthLevel.critical;
  }
}
