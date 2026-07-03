import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../data/investment_quote_service.dart';
import '../../domain/investment_asset.dart';
import '../widgets/add_to_portfolio_dialog.dart';
import '../widgets/asset_price_chart.dart';
import 'investments_screen.dart' show fmtNative;

const _kGreen = Color(0xFF00A86B);

/// Read-only preview of an asset the user is considering (before it's in the
/// portfolio): live quote, price chart with period filters and factual data,
/// plus an "add to portfolio" action.
class AssetPreviewScreen extends StatefulWidget {
  final String ticker;
  final String quoteSymbol;
  final String name;
  final AssetKind kind;
  const AssetPreviewScreen({
    super.key,
    required this.ticker,
    required this.quoteSymbol,
    required this.name,
    required this.kind,
  });

  @override
  State<AssetPreviewScreen> createState() => _AssetPreviewScreenState();
}

class _AssetPreviewScreenState extends State<AssetPreviewScreen> {
  bool _loading = true;
  AssetQuote? _quote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final q = widget.kind.isCrypto
        ? (await InvestmentQuoteService.fetchCrypto([widget.quoteSymbol]))[
            widget.quoteSymbol]
        : await InvestmentQuoteService.fetchStock(widget.quoteSymbol);
    if (!mounted) return;
    setState(() {
      _quote = q;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddToPortfolioDialog(
        ticker: widget.ticker,
        quoteSymbol: widget.quoteSymbol,
        name: widget.name,
        kind: widget.kind,
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final cur = widget.kind.currency;
    final q = _quote;
    final dayPct = q?.dayChangePercent;

    return Scaffold(
      appBar: AppBar(title: Text(widget.ticker)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(l10n.investAddToPortfolio),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(widget.name,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                  height: 30,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(strokeWidth: 2)))),
            )
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(q != null ? fmtNative(q.price, cur) : l10n.investNoQuote,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.bold)),
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

          // ── Price chart with period selector ──
          AssetPriceChart(
              quoteSymbol: widget.quoteSymbol, isCrypto: widget.kind.isCrypto),
          const SizedBox(height: 16),

          // ── Factual data ──
          if (q != null)
            _Card(children: [
              if (q.week52Low != null && q.week52High != null)
                _row(
                    l10n.investWeek52,
                    '${fmtNative(q.week52Low!, cur)} – ${fmtNative(q.week52High!, cur)}',
                    cs),
              if (q.dayLow != null && q.dayHigh != null)
                _row(
                    l10n.investDayRange,
                    '${fmtNative(q.dayLow!, cur)} – ${fmtNative(q.dayHigh!, cur)}',
                    cs),
              _row('Moeda', cur, cs),
            ]),
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
