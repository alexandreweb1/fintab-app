import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/insight.dart';
import '../../domain/month_projection.dart';

const _kGreen = Color(0xFF10B981);
const _kRed = Color(0xFFEF4444);
const _kAmber = Color(0xFFF59E0B);
const _kIndigo = Color(0xFF6366F1);

/// Dashboard section combining the end-of-month projection headline with the
/// list of actionable insights (budget alerts + spending spikes).
class DashboardInsightsCard extends ConsumerWidget {
  final List<Insight> insights;
  final MonthProjection projection;

  /// Capitalized month name (e.g. "Junho") for the projection headline.
  final String monthName;

  const DashboardInsightsCard({
    super.key,
    required this.insights,
    required this.projection,
    required this.monthName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFormatterProvider);
    final cs = Theme.of(context).colorScheme;

    final rows = <Widget>[];
    if (projection.showProjection) {
      rows.add(_ProjectionHeader(
        projection: projection,
        monthName: monthName,
        fmt: fmt,
      ));
    }
    for (final insight in insights) {
      if (rows.isNotEmpty) {
        rows.add(Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)));
      }
      rows.add(_InsightRow(insight: insight));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _ProjectionHeader extends StatelessWidget {
  final MonthProjection projection;
  final String monthName;
  final String Function(double) fmt;

  const _ProjectionHeader({
    required this.projection,
    required this.monthName,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final net = projection.projectedNet;
    final positive = net >= 0;
    final accent = positive ? _kGreen : _kRed;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No ritmo atual, $monthName fecha '
                  '${positive ? 'positivo' : 'no vermelho'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${positive ? '+' : '−'}${fmt(net.abs())}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Saldo projetado no fim do mês: '
                  '${fmt(projection.projectedEndBalance)}'
                  '${projection.daysRemaining > 0 ? ' · faltam ${projection.daysRemaining} dia${projection.daysRemaining == 1 ? '' : 's'}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final Insight insight;

  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _color(insight.severity);
    final icon = _icon(insight);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _color(InsightSeverity severity) {
    switch (severity) {
      case InsightSeverity.critical:
        return _kRed;
      case InsightSeverity.warning:
        return _kAmber;
      case InsightSeverity.info:
        return _kIndigo;
      case InsightSeverity.positive:
        return _kGreen;
    }
  }

  IconData _icon(Insight insight) {
    switch (insight.kind) {
      case InsightKind.budgetOverrun:
        return Icons.error_outline_rounded;
      case InsightKind.budgetNear:
        return Icons.warning_amber_rounded;
      case InsightKind.budgetPace:
        return Icons.speed_rounded;
      case InsightKind.spendingSpike:
        return Icons.trending_up_rounded;
    }
  }
}
