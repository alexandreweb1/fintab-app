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
            child: results.isNotEmpty
                ? ListView(
                    children: results
                        .map((r) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.12),
                                child: Icon(Icons.trending_up_rounded,
                                    size: 18, color: cs.primary),
                              ),
                              title: Text(r.symbol.replaceAll('.SA', '')),
                              subtitle: Text('${r.name} · ${r.exchange}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () => _openPreview(_fromResult(r)),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: l10n.investAddToPortfolio,
                                onPressed: () => _openAddDialog(_fromResult(r)),
                              ),
                            ))
                        .toList(),
                  )
                : _EmptyState(
                    loading: _loading,
                    typed: typed,
                    kind: _kind,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the results list is empty: a prompt to type, or a clear "not
/// found" message so nothing unverified ever looks like a real asset.
class _EmptyState extends StatelessWidget {
  final bool loading;
  final String typed;
  final AssetKind kind;
  const _EmptyState(
      {required this.loading, required this.typed, required this.kind});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    late final IconData icon;
    late final String title;
    late final String desc;
    if (loading) {
      return const SizedBox.shrink();
    } else if (typed.length < 2) {
      icon = Icons.search_rounded;
      title = l10n.investSearch;
      desc = kind == AssetKind.crypto
          ? 'Ex.: bitcoin, ethereum, solana'
          : kind == AssetKind.stockBr
              ? 'Ex.: PETR4, VALE3, HGLG11'
              : 'Ex.: AAPL, TSLA, MSFT';
    } else {
      icon = Icons.search_off_rounded;
      title = 'Nenhuma ação encontrada para "${typed.toUpperCase()}"';
      desc =
          'Verifique o código/nome. Só listamos ativos reais encontrados na consulta.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
