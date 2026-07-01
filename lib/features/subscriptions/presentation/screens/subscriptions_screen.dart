import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../recurring/domain/entities/recurring_transaction_entity.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/subscription_detector.dart';
import '../providers/subscriptions_provider.dart';

/// Lists subscriptions inferred from the transaction history and lets the user
/// turn each one into a recurring transaction or dismiss it.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final subs = ref.watch(detectedSubscriptionsProvider);
    final total = ref.watch(subscriptionsMonthlyTotalProvider);
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptions)),
      body: subs.isEmpty
          ? _EmptyState(l10n: l10n)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Monthly total header ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.14),
                        cs.primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.subscriptionsMonthlyTotal,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fmt(total),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.subscriptionsDesc,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...subs.map((s) => _SubscriptionCard(
                      sub: s,
                      fmt: fmt,
                      dateLoc: dateLoc,
                    )),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.subscriptions_outlined,
                size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              l10n.subscriptionsEmpty,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.subscriptionsEmptyDesc,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  final DetectedSubscription sub;
  final String Function(double) fmt;
  final String dateLoc;

  const _SubscriptionCard({
    required this.sub,
    required this.fmt,
    required this.dateLoc,
  });

  Future<void> _createRecurring(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(recurringNotifierProvider.notifier).add(
          title: sub.name,
          amount: sub.monthlyAmount,
          type: TransactionType.expense,
          category: sub.category,
          walletId: sub.walletId,
          frequency: RecurrenceFrequency.monthly,
          dayOfRecurrence: sub.nextEstimatedDate.day,
          startDate: sub.nextEstimatedDate,
        );
    if (ok) {
      // Turning it into a recurrence means we don't need to keep suggesting it.
      await ref.read(dismissedSubscriptionsProvider.notifier).dismiss(sub.key);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.subscriptionRecurringCreated)),
      );
    }
  }

  Future<void> _ignore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(dismissedSubscriptionsProvider.notifier).dismiss(sub.key);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.subscriptionIgnored),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => ref
              .read(dismissedSubscriptionsProvider.notifier)
              .restore(sub.key),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.autorenew_rounded,
                      size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sub.category} · ${l10n.subscriptionOccurrences(sub.occurrences)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  fmt(sub.monthlyAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.event_repeat_outlined,
                    size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${l10n.subscriptionNextCharge}: ${CurrencyFormatter.formatDate(sub.nextEstimatedDate, dateLoc)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _ignore(context, ref),
                  icon: const Icon(Icons.visibility_off_outlined, size: 16),
                  label: Text(l10n.subscriptionIgnore),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: () => _createRecurring(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l10n.subscriptionCreateRecurring),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
