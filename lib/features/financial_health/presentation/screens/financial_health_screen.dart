import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../budget/domain/ideal_budget.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/financial_score.dart';
import '../providers/financial_health_provider.dart';

class FinancialHealthScreen extends ConsumerWidget {
  const FinancialHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final score = ref.watch(financialScoreProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.financialHealthTitle),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.health_and_safety_outlined), text: 'Score'),
              Tab(icon: Icon(Icons.compare_arrows_rounded), text: 'Comparativo'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // ── Tab 1: Score ───────────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ScoreHero(score: score),
                    const SizedBox(height: 20),
                    Text(l10n.financialHealthFactors,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...score.factors.map((f) => _FactorTile(factor: f)),
                    if (score.recommendations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(l10n.financialHealthRecommendations,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _RecommendationsCard(items: score.recommendations),
                    ],
                  ],
                ),
              ),
              // ── Tab 2: Comparativo ─────────────────────────────────────
              const _ComparativeAnalysisTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comparative Analysis Tab — your spending vs an "ideal budget" derived from
// the current month's income (50/30/20 template).
// ─────────────────────────────────────────────────────────────────────────────

class _ComparativeAnalysisTab extends ConsumerWidget {
  const _ComparativeAnalysisTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final allTxs = ref.watch(visibleTransactionsProvider);

    final now = DateTime.now();
    final monthTxs = allTxs.where((t) =>
        t.date.year == now.year && t.date.month == now.month).toList();

    final income =
        monthTxs.where((t) => t.isIncome).fold<double>(0, (s, t) => s + t.amount);
    final totalExpenses = monthTxs
        .where((t) => t.isExpense)
        .fold<double>(0, (s, t) => s + t.amount);

    // Build map of actual spending per category
    final actualByCategory = <String, double>{};
    for (final t in monthTxs.where((t) => t.isExpense)) {
      actualByCategory[t.category.toLowerCase().trim()] =
          (actualByCategory[t.category.toLowerCase().trim()] ?? 0) + t.amount;
    }

    if (income <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compare_arrows_rounded,
                  size: 56, color: cs.outlineVariant),
              const SizedBox(height: 16),
              Text(
                'Sem receita registrada neste mês',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Registre suas receitas para comparar seus gastos com um orçamento ideal.',
                style: TextStyle(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Build comparison rows
    final rows = kIdealBudgetTemplate.map((item) {
      final ideal = item.amountFor(income);
      final actual = actualByCategory[item.categoryName.toLowerCase().trim()] ?? 0.0;
      final diff = actual - ideal;
      return _ComparisonRow(
        category: item.categoryName,
        group: item.group,
        ideal: ideal,
        actual: actual,
        diff: diff,
      );
    }).toList();

    final totalIdealExpenses = income * kIdealBudgetTotalPercent / 100;
    final totalDiff = totalExpenses - totalIdealExpenses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Header summary ──
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.compare_arrows_rounded, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Análise comparativa',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Comparando seus gastos do mês com o orçamento ideal '
                  'baseado na regra 50/30/20.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                _SummaryRow(
                  label: 'Receita do mês',
                  value: fmt(income),
                  color: cs.primary,
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Gasto total',
                  value: fmt(totalExpenses),
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Gasto ideal (70% da receita)',
                  value: fmt(totalIdealExpenses),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Icon(
                      totalDiff <= 0
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: totalDiff <= 0
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        totalDiff <= 0
                            ? 'Você está dentro do limite ideal! Sobrando ${fmt(totalDiff.abs())}.'
                            : 'Você está ${fmt(totalDiff)} acima do gasto ideal.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: totalDiff <= 0
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Por categoria',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...rows.map((r) => _ComparisonTile(row: r, fmt: fmt)),
      ],
    );
  }
}

class _ComparisonRow {
  final String category;
  final String group;
  final double ideal;
  final double actual;
  final double diff;
  const _ComparisonRow({
    required this.category,
    required this.group,
    required this.ideal,
    required this.actual,
    required this.diff,
  });
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SummaryRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color ?? cs.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ComparisonTile extends StatelessWidget {
  final _ComparisonRow row;
  final String Function(double) fmt;
  const _ComparisonTile({required this.row, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final overspent = row.diff > 0;
    final progress =
        row.ideal > 0 ? (row.actual / row.ideal).clamp(0.0, 1.5) : 0.0;
    final progressColor = overspent
        ? (progress > 1.2 ? Colors.red.shade600 : Colors.orange.shade700)
        : Colors.green.shade600;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            row.category,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              row.group,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ideal: ${fmt(row.ideal)}',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt(row.actual),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      overspent
                          ? '+${fmt(row.diff)}'
                          : row.diff < 0
                              ? '-${fmt(row.diff.abs())}'
                              : '—',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: overspent
                            ? Colors.red.shade600
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (progress / 1.5).clamp(0.0, 1.0),
                backgroundColor: progressColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card with the circular gauge
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreHero extends StatelessWidget {
  final FinancialScore score;
  const _ScoreHero({required this.score});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = _colorFor(score.level);
    final label = _labelFor(score.level, l10n);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(
                painter: _GaugePainter(
                  progress: (score.score / 100).clamp(0.0, 1.0),
                  color: color,
                  trackColor:
                      Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(score.scoreRounded.toString(),
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      Text('/ 100',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.financialHealthSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) / 2) - stroke / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Sweep from 135° (lower-left) clockwise to 45° (lower-right) → 270° arc.
    const startAngle = 0.75 * math.pi * 2 - math.pi; // = 135°
    const sweepAll = 1.5 * math.pi; // 270°
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAll, false, track);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAll * progress, false, fill);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Factor breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _FactorTile extends StatelessWidget {
  final ScoreFactor factor;
  const _FactorTile({required this.factor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = factor.measured
        ? _factorColor(factor.value)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = _iconFor(factor.kind);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_titleFor(factor.kind, l10n),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                  factor.measured
                      ? '${factor.value.round()} / 20'
                      : '—',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: factor.measured
                    ? (factor.value / ScoreFactor.maxValue).clamp(0.0, 1.0)
                    : 0,
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(factor.headline,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  final List<String> items;
  const _RecommendationsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates_outlined,
                        size: 18, color: Color(0xFFFFA726)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(tip,
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _colorFor(HealthLevel level) {
  switch (level) {
    case HealthLevel.excellent:
      return const Color(0xFF2E7D32);
    case HealthLevel.good:
      return const Color(0xFF66BB6A);
    case HealthLevel.fair:
      return const Color(0xFFFFA726);
    case HealthLevel.attention:
      return const Color(0xFFEF6C00);
    case HealthLevel.critical:
      return const Color(0xFFC62828);
  }
}

String _labelFor(HealthLevel level, AppLocalizations l10n) {
  switch (level) {
    case HealthLevel.excellent:
      return l10n.financialHealthLevelExcellent;
    case HealthLevel.good:
      return l10n.financialHealthLevelGood;
    case HealthLevel.fair:
      return l10n.financialHealthLevelFair;
    case HealthLevel.attention:
      return l10n.financialHealthLevelAttention;
    case HealthLevel.critical:
      return l10n.financialHealthLevelCritical;
  }
}

Color _factorColor(double value) {
  if (value >= 16) return const Color(0xFF2E7D32);
  if (value >= 12) return const Color(0xFF66BB6A);
  if (value >= 8) return const Color(0xFFFFA726);
  if (value >= 4) return const Color(0xFFEF6C00);
  return const Color(0xFFC62828);
}

IconData _iconFor(ScoreFactorKind kind) {
  switch (kind) {
    case ScoreFactorKind.savingsRate:
      return Icons.savings_outlined;
    case ScoreFactorKind.emergencyReserve:
      return Icons.shield_outlined;
    case ScoreFactorKind.budgetAdherence:
      return Icons.track_changes_outlined;
    case ScoreFactorKind.goalMomentum:
      return Icons.flag_outlined;
    case ScoreFactorKind.spendingConcentration:
      return Icons.donut_large_outlined;
    case ScoreFactorKind.investments:
      return Icons.trending_up_rounded;
  }
}

String _titleFor(ScoreFactorKind kind, AppLocalizations l10n) {
  switch (kind) {
    case ScoreFactorKind.savingsRate:
      return l10n.financialFactorSavingsRate;
    case ScoreFactorKind.emergencyReserve:
      return l10n.financialFactorEmergencyReserve;
    case ScoreFactorKind.budgetAdherence:
      return l10n.financialFactorBudgetAdherence;
    case ScoreFactorKind.goalMomentum:
      return l10n.financialFactorGoalMomentum;
    case ScoreFactorKind.spendingConcentration:
      return l10n.financialFactorSpendingConcentration;
    case ScoreFactorKind.investments:
      return 'Investimentos';
  }
}
