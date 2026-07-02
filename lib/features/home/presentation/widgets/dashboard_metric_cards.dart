import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../bills/presentation/screens/bills_screen.dart';
import '../../../bills/presentation/providers/bills_provider.dart';
import '../providers/money_metrics_provider.dart';

const _kGreen = Color(0xFF00A86B);

BoxDecoration _cardDeco(ColorScheme cs) => BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
    );

// ── Safe to Spend ────────────────────────────────────────────────────────────

class SafeToSpendCard extends ConsumerWidget {
  const SafeToSpendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final s = ref.watch(safeToSpendProvider);
    final positive = s.total > 0;
    final accent = positive ? _kGreen : cs.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(cs),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(Icons.savings_outlined, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pode gastar até o fim do mês',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(fmt(positive ? s.total : 0),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: accent)),
                const SizedBox(height: 2),
                Text(
                  positive
                      ? '≈ ${fmt(s.perDay)}/dia · ${s.remainingDays} dias restantes'
                      : 'Contas previstas superam o saldo disponível',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Net worth (current + 6-month sparkline + Age of Money) ──────────────────

class NetWorthCard extends ConsumerWidget {
  const NetWorthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final current = ref.watch(netWorthProvider);
    final history = ref.watch(netWorthHistoryProvider);
    final age = ref.watch(ageOfMoneyProvider);

    double? delta;
    if (history.length >= 2) {
      delta = history.last.value - history[history.length - 2].value;
    }
    final up = (delta ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patrimônio',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(fmt(current),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    if (delta != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 13, color: up ? _kGreen : cs.error),
                        const SizedBox(width: 2),
                        Text('${fmt(delta.abs())} vs. mês anterior',
                            style: TextStyle(
                                fontSize: 11,
                                color: up ? _kGreen : cs.error)),
                      ]),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 96,
                height: 44,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: history.map((p) => p.value).toList(),
                    color: up ? _kGreen : cs.error,
                  ),
                ),
              ),
            ],
          ),
          if (age != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.hourglass_bottom_rounded,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Idade do dinheiro: $age dias',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}

// ── Upcoming bills summary ───────────────────────────────────────────────────

class BillsSummaryCard extends ConsumerWidget {
  const BillsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final upcoming = ref.watch(upcomingBillsProvider);
    final overdue = ref.watch(overdueBillsProvider);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BillsScreen()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(cs),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: Icon(Icons.event_note_outlined, color: cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.bills,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  if (upcoming.isEmpty)
                    Text('Tudo em dia 🎉',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant))
                  else ...[
                    Text(
                      overdue.isNotEmpty
                          ? '${overdue.length} vencida(s) · próxima ${CurrencyFormatter.formatDate(upcoming.first.dueDate, dateLoc)}'
                          : 'Próxima: ${upcoming.first.title} · ${CurrencyFormatter.formatDate(upcoming.first.dueDate, dateLoc)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: overdue.isNotEmpty
                              ? cs.error
                              : cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${upcoming.length} conta(s) · ${fmt(upcoming.fold<double>(0, (s, b) => s + b.amount))}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
