import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../financial_health/domain/financial_score.dart';
import '../../../financial_health/presentation/providers/financial_health_provider.dart';
import '../../../financial_health/presentation/screens/financial_health_screen.dart';
import '../../../recurring/domain/entities/recurring_transaction_entity.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

// ─── Recent Transactions Card ─────────────────────────────────────────────────

class DashboardRecentTransactions extends ConsumerWidget {
  const DashboardRecentTransactions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final txs = ref.watch(visibleTransactionsProvider);
    final cs = Theme.of(context).colorScheme;

    // Last 5 transactions sorted by date desc
    final recent = [...txs]
      ..sort((a, b) => b.date.compareTo(a.date));
    final slice = recent.take(5).toList();

    if (slice.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (int i = 0; i < slice.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 52,
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            _RecentTile(tx: slice[i], fmt: fmt, dateLoc: dateLoc),
          ],
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final dynamic tx;
  final String Function(double) fmt;
  final String dateLoc;

  const _RecentTile({
    required this.tx,
    required this.fmt,
    required this.dateLoc,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isIncome = tx.isIncome as bool;
    final color = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final sign = isIncome ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title as String,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tx.category as String,
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
                '$sign${fmt(tx.amount as double)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM', dateLoc).format(tx.date as DateTime),
                style: TextStyle(
                    fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Upcoming Recurring Card ──────────────────────────────────────────────────

class DashboardUpcomingRecurring extends ConsumerWidget {
  const DashboardUpcomingRecurring({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final recurrences = ref.watch(activeRecurrencesProvider);
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();

    // Collect next occurrences for each active recurrence
    final upcoming = <({RecurringTransactionEntity r, DateTime date})>[];
    for (final r in recurrences) {
      final next = r.nextOccurrence(afterDate: now.subtract(const Duration(days: 1)));
      if (next != null) {
        upcoming.add((r: r, date: next));
      }
    }
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    final slice = upcoming.take(5).toList();

    if (slice.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                'Nenhuma recorrência ativa',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
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
          children: [
            for (int i = 0; i < slice.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              _RecurringTile(
                item: slice[i],
                fmt: fmt,
                dateLoc: dateLoc,
                now: now,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final ({RecurringTransactionEntity r, DateTime date}) item;
  final String Function(double) fmt;
  final String dateLoc;
  final DateTime now;

  const _RecurringTile({
    required this.item,
    required this.fmt,
    required this.dateLoc,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final r = item.r;
    final date = item.date;
    final cs = Theme.of(context).colorScheme;
    final isIncome = r.isIncome;
    final color = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final daysUntil = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final String dateLabel;
    if (daysUntil == 0) {
      dateLabel = 'Hoje';
    } else if (daysUntil == 1) {
      dateLabel = 'Amanhã';
    } else {
      dateLabel = 'Em $daysUntil dias';
    }

    final urgent = daysUntil <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.repeat_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: urgent
                          ? const Color(0xFFF59E0B)
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$dateLabel · ${DateFormat('dd/MM', dateLoc).format(date)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: urgent
                            ? const Color(0xFFF59E0B)
                            : cs.onSurfaceVariant,
                        fontWeight: urgent ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${fmt(r.amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Financial Health Card (compact) ──────────────────────────────────────────

class DashboardFinancialHealthCard extends ConsumerWidget {
  const DashboardFinancialHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!isPro) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: InkWell(
          onTap: () => showProGateBottomSheet(
            context,
            featureName: l10n.financialHealthTitle,
            featureDescription: l10n.financialHealthSubtitle,
            featureIcon: Icons.monitor_heart_outlined,
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFA726).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA726).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Color(0xFFFFA726), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.financialHealthTitle,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(l10n.financialHealthSubtitle,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    final score = ref.watch(financialScoreProvider);
    final color = _healthColor(score.level);
    final label = _healthLabel(score.level, l10n);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FinancialHealthScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _MiniGaugePainter(
                    progress: (score.score / 100).clamp(0.0, 1.0),
                    color: color,
                    trackColor: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                  child: Center(
                    child: Text(
                      '${score.scoreRounded}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${score.scoreRounded}/100',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      score.recommendations.isNotEmpty
                          ? score.recommendations.first
                          : l10n.financialHealthSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _MiniGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final center = (Offset.zero & size).center;
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

    const startAngle = 0.75 * math.pi * 2 - math.pi; // 135°
    const sweepAll = 1.5 * math.pi; // 270°
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAll, false, track);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAll * progress, false, fill);
  }

  @override
  bool shouldRepaint(covariant _MiniGaugePainter old) =>
      old.progress != progress || old.color != color;
}

Color _healthColor(HealthLevel level) {
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

String _healthLabel(HealthLevel level, AppLocalizations l10n) {
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
