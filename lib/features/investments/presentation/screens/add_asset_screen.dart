import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../data/investment_quote_service.dart';
import '../../domain/investment_asset.dart';
import '../widgets/add_to_portfolio_dialog.dart';
import 'asset_preview_screen.dart';

/// Resolved asset target: what to fetch quotes for and how to label it.
typedef _Target = ({
  String ticker,
  String quoteSymbol,
  String name,
  AssetKind kind,
});

class AddAssetScreen extends ConsumerStatefulWidget {
  const AddAssetScreen({super.key});
  @override
  ConsumerState<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends ConsumerState<AddAssetScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  AssetKind _kind = AssetKind.stockBr;
  bool _loading = false;
  List<AssetSearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    setState(() {}); // refresh manual tile
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    final res = _kind == AssetKind.crypto
        ? await InvestmentQuoteService.searchCrypto(q)
        : await InvestmentQuoteService.searchStocks(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  // ── Target resolution ──────────────────────────────────────────────────────

  _Target _fromResult(AssetSearchResult r) {
    if (r.kind == 'crypto') {
      final m = RegExp(r'\(([^)]+)\)').firstMatch(r.name);
      return (
        ticker: m != null ? m.group(1)! : r.symbol.toUpperCase(),
        quoteSymbol: r.symbol,
        name: r.name,
        kind: AssetKind.crypto,
      );
    }
    if (r.symbol.endsWith('.SA')) {
      return (
        ticker: r.symbol.replaceAll('.SA', ''),
        quoteSymbol: r.symbol,
        name: r.name,
        kind: AssetKind.stockBr,
      );
    }
    return (
      ticker: r.symbol,
      quoteSymbol: r.symbol,
      name: r.name,
      kind: AssetKind.stockUs,
    );
  }

  _Target? _fromManual() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return null;
    switch (_kind) {
      case AssetKind.stockBr:
        final t = raw.toUpperCase();
        return (ticker: t, quoteSymbol: '$t.SA', name: t, kind: _kind);
      case AssetKind.stockUs:
        final t = raw.toUpperCase();
        return (ticker: t, quoteSymbol: t, name: t, kind: _kind);
      case AssetKind.crypto:
        // For manual crypto the user types the CoinGecko id (e.g. bitcoin).
        return (
          ticker: raw.toUpperCase(),
          quoteSymbol: raw.toLowerCase(),
          name: raw,
          kind: _kind,
        );
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Tapping the name → open the asset preview (quote + chart + filters).
  Future<void> _openPreview(_Target t) async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AssetPreviewScreen(
        ticker: t.ticker,
        quoteSymbol: t.quoteSymbol,
        name: t.name,
        kind: t.kind,
      ),
    ));
    if (added == true && mounted) Navigator.of(context).pop();
  }

  /// Tapping the + → open the add dialog (quantity/price) directly.
  Future<void> _openAddDialog(_Target t) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddToPortfolioDialog(
        ticker: t.ticker,
        quoteSymbol: t.quoteSymbol,
        name: t.name,
        kind: t.kind,
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final typed = _ctrl.text.trim();
    // Keep search results relevant to the selected kind.
    final results = _kind == AssetKind.crypto
        ? _results.where((r) => r.kind == 'crypto').toList()
        : _results
            .where((r) => r.kind == 'stock' &&
                (_kind == AssetKind.stockBr
                    ? r.symbol.endsWith('.SA')
                    : !r.symbol.endsWith('.SA')))
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.investAddAsset)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SegmentedButton<AssetKind>(
                  segments: [
                    ButtonSegment(
                        value: AssetKind.stockBr,
                        label: Text(l10n.investKindStockBr)),
                    ButtonSegment(
                        value: AssetKind.stockUs,
                        label: Text(l10n.investKindStockUs)),
                    ButtonSegment(
                        value: AssetKind.crypto,
                        label: Text(l10n.investKindCrypto)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) {
                    setState(() {
                      _kind = s.first;
                      _results = const [];
                    });
                    _search(_ctrl.text);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: _kind == AssetKind.crypto
                        ? 'bitcoin, ethereum…'
                        : _kind == AssetKind.stockBr
                            ? 'PETR4, VALE3, HGLG11…'
                            : 'AAPL, TSLA, MSFT…',
                    labelText: l10n.investSearch,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Toque no nome para ver detalhes e gráfico · toque em + para adicionar',
                    style: TextStyle(
                        fontSize: 11.5, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                // Manual-add option — always available (works even if search
                // is blocked, e.g. CORS on web).
                if (typed.isNotEmpty)
                  ListTile(
                    leading: Icon(Icons.trending_up_rounded, color: cs.primary),
                    title: Text(typed.toUpperCase()),
                    subtitle: Text(_kind == AssetKind.crypto
                        ? 'Cripto (id CoinGecko)'
                        : _kind == AssetKind.stockBr
                            ? '${typed.toUpperCase()}.SA · B3'
                            : '${typed.toUpperCase()} · EUA'),
                    onTap: () {
                      final t = _fromManual();
                      if (t != null) _openPreview(t);
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.add_circle, color: cs.primary),
                      tooltip: l10n.investAddToPortfolio,
                      onPressed: () {
                        final t = _fromManual();
                        if (t != null) _openAddDialog(t);
                      },
                    ),
                  ),
                if (results.isNotEmpty) const Divider(height: 1),
                ...results.map((r) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primary.withValues(alpha: 0.12),
                        child: Icon(Icons.trending_up_rounded,
                            size: 18, color: cs.primary),
                      ),
                      title: Text(r.symbol.replaceAll('.SA', '')),
                      subtitle: Text('${r.name} · ${r.exchange}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _openPreview(_fromResult(r)),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: l10n.investAddToPortfolio,
                        onPressed: () => _openAddDialog(_fromResult(r)),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
