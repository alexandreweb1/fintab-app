import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../data/investment_quote_service.dart';
import '../../domain/investment_asset.dart';
import '../providers/investments_provider.dart';

class AddAssetScreen extends ConsumerStatefulWidget {
  const AddAssetScreen({super.key});
  @override
  ConsumerState<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends ConsumerState<AddAssetScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _crypto = false;
  bool _loading = false;
  List<AssetSearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    final res = _crypto
        ? await InvestmentQuoteService.searchCrypto(q)
        : await InvestmentQuoteService.searchStocks(q);
    if (!mounted) return;
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  Future<void> _add(AssetSearchResult r) async {
    final AssetKind kind;
    final String ticker;
    if (r.kind == 'crypto') {
      kind = AssetKind.crypto;
      final m = RegExp(r'\(([^)]+)\)').firstMatch(r.name);
      ticker = m != null ? m.group(1)! : r.symbol.toUpperCase();
    } else if (r.symbol.endsWith('.SA')) {
      kind = AssetKind.stockBr;
      ticker = r.symbol.replaceAll('.SA', '');
    } else {
      kind = AssetKind.stockUs;
      ticker = r.symbol;
    }
    await ref.read(investmentsNotifierProvider.notifier).addAsset(
          ticker: ticker,
          quoteSymbol: r.symbol,
          name: r.name,
          kind: kind,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.investAddAsset)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.show_chart_rounded, size: 18),
                        label: Text('${l10n.investKindStockBr} / ${l10n.investKindStockUs}')),
                    ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.currency_bitcoin_rounded, size: 18),
                        label: Text(l10n.investKindCrypto)),
                  ],
                  selected: {_crypto},
                  onSelectionChanged: (s) {
                    setState(() {
                      _crypto = s.first;
                      _results = const [];
                    });
                    _search(_ctrl.text);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: _crypto
                        ? 'bitcoin, ethereum…'
                        : 'PETR4, VALE3, AAPL…',
                    labelText: l10n.investSearch,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = _results[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      (r.kind == 'crypto'
                              ? (RegExp(r'\(([^)]+)\)').firstMatch(r.name)?.group(1) ?? r.symbol)
                              : r.symbol.replaceAll('.SA', ''))
                          .characters
                          .take(2)
                          .toString(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.primary),
                    ),
                  ),
                  title: Text(r.symbol.replaceAll('.SA', '')),
                  subtitle: Text('${r.name} · ${r.exchange}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _add(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
