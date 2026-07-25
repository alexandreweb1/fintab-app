import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/price_alert.dart';
import '../providers/price_alerts_provider.dart';
import '../widgets/price_alert_dialog.dart';
import 'investments_screen.dart' show fmtNative;

const _kGreen = Color(0xFF00A86B);

/// Lists the user's price alerts (active and triggered) with re-arm/delete.
class PriceAlertsScreen extends ConsumerWidget {
  const PriceAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final alerts = ref.watch(priceAlertsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.investAlerts)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openPriceAlertDialog(context, ref),
        icon: const Icon(Icons.add_alert_rounded),
        label: Text(l10n.investCreateAlert),
      ),
      body: alerts.isEmpty
          ? _Empty(l10n: l10n)
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                ...alerts.map((a) => _AlertTile(alert: a)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(l10n.investDisclaimer,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  final AppLocalizations l10n;
  const _Empty({required this.l10n});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(l10n.investAlertsEmpty,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.investAlertsEmptyDesc,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  final PriceAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dateLoc = ref.watch(dateLocaleProvider);
    final up = alert.condition == AlertCondition.above;
    final condLabel =
        up ? l10n.investAlertCondAbove : l10n.investAlertCondBelow;
    final statusColor = alert.active ? _kGreen : cs.tertiary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Icon(
            up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: up ? _kGreen : cs.error),
        title: Text(
          '${alert.ticker} · $condLabel ${fmtNative(alert.targetPrice, alert.currency)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          alert.active
              ? l10n.investAlertActive
              : alert.triggeredAt != null
                  ? '${l10n.investAlertTriggered} · '
                      '${CurrencyFormatter.formatDate(alert.triggeredAt!, dateLoc)}'
                      '${alert.triggeredPrice != null ? ' · ${fmtNative(alert.triggeredPrice!, alert.currency)}' : ''}'
                  : l10n.investAlertTriggered,
          style: TextStyle(fontSize: 11.5, color: statusColor),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            final notifier = ref.read(priceAlertsNotifierProvider.notifier);
            if (v == 'rearm') notifier.rearm(alert.id);
            if (v == 'delete') notifier.delete(alert.id);
          },
          itemBuilder: (_) => [
            if (!alert.active)
              PopupMenuItem(
                value: 'rearm',
                child: Row(children: [
                  const Icon(Icons.restart_alt_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.investAlertRearm),
                ]),
              ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                const SizedBox(width: 10),
                Text(l10n.investAlertDelete),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
