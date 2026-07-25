import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../settings/presentation/screens/currency_converter_screen.dart';
import '../providers/investments_provider.dart';
import 'add_asset_screen.dart';
import 'asset_detail_screen.dart';
import 'price_alerts_screen.dart';

const _kGreen = Color(0xFF00A86B);

String fmtNative(double v, String currency) => NumberFormat.currency(
      locale: currency == 'USD' ? 'en_US' : 'pt_BR',
      symbol: currency == 'USD' ? 'US\$' : 'R\$',
    ).format(v);

/// Standalone screen wrapper around [InvestmentsView].
class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).investments)),
      body: const InvestmentsView(),
    );
  }
}

/// The investments portfolio content — reused inside the Extrato tab and as a
/// standalone screen.
class InvestmentsView extends ConsumerStatefulWidget {
  const InvestmentsView({super.key});
  @override
  ConsumerState<InvestmentsView> createState() => _InvestmentsViewState();
}

class _InvestmentsViewState extends ConsumerState<InvestmentsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final assets = ref.read(investmentAssetsStreamProvider).value ?? const [];
    await ref.read(investmentQuotesProvider.notifier).refresh(assets);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final positions = ref.watch(investmentPositionsProvider);
    final holdings = positions.where((p) => p.summary.hasHoldings).toList();
    final total = ref.watch(portfolioTotalProvider);
    final quotes = ref.watch(investmentQuotesProvider);

    ref.listen(investmentAssetsStreamProvider, (_, next) {
      final list = next.value ?? const [];
      if (list.isNotEmpty) {
        ref.read(investmentQuotesProvider.notifier).refresh(list);
      }
    });

    return Column(
      children: [
        // ── Action row (refresh · add · overflow[converter]) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
          child: Row(
            children: [
              Text(l10n.investments,
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddAssetScreen())),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.investAddAsset),
              ),
              IconButton(
                tooltip: l10n.investAlerts,
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PriceAlertsScreen())),
              ),
              IconButton(
                tooltip: l10n.currencyRefreshRates,
                icon: quotes.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                onPressed: quotes.loading ? null : _refresh,
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'converter') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CurrencyConverterScreen()));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'converter',
                    child: Row(children: [
                      const Icon(Icons.currency_exchange_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(l10n.currencyConverter),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: positions.isEmpty
              ? _Empty(l10n: l10n)
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    children: [
                      _TotalHeader(total: total, fmt: fmt),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          quotes.updatedAt != null
                              ? '${l10n.investQuotesUpdated} ${DateFormat('HH:mm').format(quotes.updatedAt!)} · ${l10n.investDisclaimer}'
                              : l10n.investDisclaimer,
                          style: TextStyle(
                              fontSize: 10.5,
                              color:
                                  cs.onSurfaceVariant.withValues(alpha: 0.8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...holdings.map((p) => _PositionTile(pos: p, fmt: fmt)),
                    ],
                  ),
                ),
        ),
      ],
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
          Icon(Icons.candlestick_chart_outlined,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(l10n.investEmpty,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.investEmptyDesc,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _TotalHeader extends StatelessWidget {
  final PortfolioTotal total;
  final String Function(double) fmt;
  const _TotalHeader({required this.total, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final up = total.unrealized >= 0;
    final accent = up ? _kGreen : cs.error;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.14), accent.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.portfolioValue,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(fmt(total.marketValue),
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16, color: accent),
            const SizedBox(width: 4),
            Text(
              '${up ? '+' : ''}${fmt(total.unrealized)} (${total.unrealizedPct.toStringAsFixed(2)}%)',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: accent, fontSize: 14),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _MiniStat(label: l10n.investToday, value: fmt(total.dayChange),
                positive: total.dayChange >= 0),
            const SizedBox(width: 20),
            _MiniStat(
                label: l10n.investRealized, value: fmt(total.realized),
                positive: total.realized >= 0),
          ]),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool positive;
  const _MiniStat(
      {required this.label, required this.value, required this.positive});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: positive ? _kGreen : cs.error)),
      ],
    );
  }
}

class _PositionTile extends StatelessWidget {
  final PositionView pos;
  final String Function(double) fmt;
  const _PositionTile({required this.pos, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final up = pos.unrealizedNative >= 0;
    final hasQuote = pos.price != null;
    final dayPct = pos.dayChangePct;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AssetDetailScreen(assetId: pos.asset.id))),
        title: Row(children: [
          Text(pos.asset.ticker,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (dayPct != null)
            Text('${dayPct >= 0 ? '+' : ''}${dayPct.toStringAsFixed(2)}%',
                style: TextStyle(
                    fontSize: 11,
                    color: dayPct >= 0 ? _kGreen : cs.error)),
        ]),
        subtitle: Text(
          '${pos.summary.quantity.toStringAsFixed(pos.asset.kind.isCrypto ? 6 : 0)} · ${AppLocalizations.of(context).investAvgCost} ${fmtNative(pos.summary.avgCost, pos.asset.kind.currency)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(fmt(pos.marketValueBrl),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hasQuote)
              Text(
                '${up ? '+' : ''}${fmt(pos.unrealizedBrl)} (${pos.unrealizedPct.toStringAsFixed(1)}%)',
                style: TextStyle(
                    fontSize: 11, color: up ? _kGreen : cs.error),
              )
            else
              Text(AppLocalizations.of(context).investNoQuote,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
