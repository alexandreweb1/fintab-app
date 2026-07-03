import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/investment_asset.dart';
import '../../domain/investment_trade.dart';
import '../providers/investments_provider.dart';
import 'investments_screen.dart' show fmtNative;

const _kGreen = Color(0xFF00A86B);

class AssetDetailScreen extends ConsumerWidget {
  final String assetId;
  const AssetDetailScreen({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);

    final positions = ref.watch(investmentPositionsProvider);
    final pos = positions.where((p) => p.asset.id == assetId).firstOrNull;
    if (pos == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox());
    }
    final asset = pos.asset;
    final q = pos.quote;
    final trades = ref.watch(tradesForAssetProvider(assetId));
    final cur = asset.kind.currency;
    final up = pos.unrealizedNative >= 0;
    final dayPct = pos.dayChangePct;

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.ticker),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(l10n.investRemoveAsset),
                    content: Text('${asset.ticker} — ${asset.name}'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(l10n.cancel)),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: cs.error),
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(l10n.delete)),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref
                      .read(investmentsNotifierProvider.notifier)
                      .deleteAsset(assetId);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'delete', child: Text(l10n.investRemoveAsset)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _AddTradeDialog(asset: asset),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.investAddTrade),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(asset.name,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(q != null ? fmtNative(q.price, cur) : '—',
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            if (dayPct != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${dayPct >= 0 ? '+' : ''}${dayPct.toStringAsFixed(2)}%',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: dayPct >= 0 ? _kGreen : cs.error),
                ),
              ),
          ]),
          const SizedBox(height: 16),

          // ── Position ──
          if (pos.summary.hasHoldings)
            _Card(children: [
              _row(l10n.investMarketValue, fmt(pos.marketValueBrl), cs),
              _row(l10n.investQuantity,
                  pos.summary.quantity.toStringAsFixed(asset.kind.isCrypto ? 6 : 0), cs),
              _row(l10n.investAvgCost, fmtNative(pos.summary.avgCost, cur), cs),
              _rowColored(l10n.investUnrealized,
                  '${up ? '+' : ''}${fmt(pos.unrealizedBrl)} (${pos.unrealizedPct.toStringAsFixed(2)}%)',
                  up ? _kGreen : cs.error),
              if (pos.summary.realizedPnl.abs() > 0.001)
                _rowColored(l10n.investRealized, fmt(pos.realizedBrl),
                    pos.realizedBrl >= 0 ? _kGreen : cs.error),
            ]),
          const SizedBox(height: 12),

          // ── Factual data ──
          if (q != null)
            _Card(children: [
              if (q.week52Low != null && q.week52High != null)
                _row(l10n.investWeek52,
                    '${fmtNative(q.week52Low!, cur)} – ${fmtNative(q.week52High!, cur)}', cs),
              if (q.dayLow != null && q.dayHigh != null)
                _row(l10n.investDayRange,
                    '${fmtNative(q.dayLow!, cur)} – ${fmtNative(q.dayHigh!, cur)}', cs),
              _row('Moeda', cur, cs),
            ]),
          const SizedBox(height: 16),

          // ── Trades ──
          Text(l10n.investTradesHistory,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          if (trades.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.investNoTrades,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            )
          else
            ...trades.map((t) => _TradeTile(trade: t, currency: cur, dateLoc: dateLoc)),

          const SizedBox(height: 20),
          Text(l10n.investDisclaimer,
              style: TextStyle(
                  fontSize: 10.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _row(String k, String v, ColorScheme cs) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _rowColored(String k, String v, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(fontSize: 13)),
          Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(children: children),
    );
  }
}

class _TradeTile extends ConsumerWidget {
  final InvestmentTrade trade;
  final String currency;
  final String dateLoc;
  const _TradeTile(
      {required this.trade, required this.currency, required this.dateLoc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final buy = trade.isBuy;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
          buy ? Icons.add_circle_outline : Icons.remove_circle_outline,
          color: buy ? _kGreen : cs.error),
      title: Text('${buy ? l10n.investBuy : l10n.investSell} · '
          '${trade.quantity.toStringAsFixed(trade.quantity % 1 == 0 ? 0 : 6)} × ${fmtNative(trade.unitPrice, currency)}'),
      subtitle: Text(CurrencyFormatter.formatDate(trade.date, dateLoc),
          style: const TextStyle(fontSize: 11)),
      trailing: IconButton(
        icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
        onPressed: () =>
            ref.read(investmentsNotifierProvider.notifier).deleteTrade(trade.id),
      ),
    );
  }
}

// ── Add trade dialog ─────────────────────────────────────────────────────────

class _AddTradeDialog extends ConsumerStatefulWidget {
  final InvestmentAsset asset;
  const _AddTradeDialog({required this.asset});
  @override
  ConsumerState<_AddTradeDialog> createState() => _AddTradeDialogState();
}

class _AddTradeDialogState extends ConsumerState<_AddTradeDialog> {
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _fees = TextEditingController();
  TradeSide _side = TradeSide.buy;
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _fees.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final qty = _num(_qty);
    final price = _num(_price);
    if (qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
      return;
    }
    setState(() => _loading = true);
    final ok = await ref.read(investmentsNotifierProvider.notifier).addTrade(
          assetId: widget.asset.id,
          side: _side,
          quantity: qty,
          unitPrice: price,
          fees: _num(_fees),
          date: _date,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    const numFmt = [
      TextInputType.numberWithOptions(decimal: true)
    ];
    final inputFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return AlertDialog(
      title: Text(l10n.investAddTrade),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<TradeSide>(
            segments: [
              ButtonSegment(value: TradeSide.buy, label: Text(l10n.investBuy)),
              ButtonSegment(value: TradeSide.sell, label: Text(l10n.investSell)),
            ],
            selected: {_side},
            onSelectionChanged: (s) => setState(() => _side = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            keyboardType: numFmt.first,
            inputFormatters: inputFmt,
            decoration: InputDecoration(
                labelText: l10n.investQuantity,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _price,
            keyboardType: numFmt.first,
            inputFormatters: inputFmt,
            decoration: InputDecoration(
                labelText:
                    '${l10n.investUnitPrice} (${widget.asset.kind.currency})',
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fees,
            keyboardType: numFmt.first,
            inputFormatters: inputFmt,
            decoration: InputDecoration(
                labelText: '${l10n.investFees} (${l10n.optional})',
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (p != null) setState(() => _date = p);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: l10n.date, border: const OutlineInputBorder()),
              child: Text(CurrencyFormatter.formatDate(_date, dateLoc)),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
