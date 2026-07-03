import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/investment_asset.dart';
import '../../domain/investment_trade.dart';
import '../providers/investments_provider.dart';

/// Dialog to add a position for an asset that may not exist in the portfolio yet.
///
/// On save it reuses an existing asset with the same [quoteSymbol] (or creates
/// one), records the buy/sell, refreshes the quote, and pops with `true`.
class AddToPortfolioDialog extends ConsumerStatefulWidget {
  final String ticker;
  final String quoteSymbol;
  final String name;
  final AssetKind kind;
  const AddToPortfolioDialog({
    super.key,
    required this.ticker,
    required this.quoteSymbol,
    required this.name,
    required this.kind,
  });

  @override
  ConsumerState<AddToPortfolioDialog> createState() =>
      _AddToPortfolioDialogState();
}

class _AddToPortfolioDialogState extends ConsumerState<AddToPortfolioDialog> {
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _fees = TextEditingController();
  TradeSide _side = TradeSide.buy;
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _fetchingQuote = false;

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _fees.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _fetchCurrentQuote() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetchingQuote = true);
    await ref.read(investmentQuotesProvider.notifier).refresh([
      InvestmentAsset(
        id: '',
        userId: '',
        ticker: widget.ticker,
        quoteSymbol: widget.quoteSymbol,
        name: widget.name,
        kind: widget.kind,
        createdAt: _date,
      ),
    ]);
    final quote = ref.read(investmentQuotesProvider).bySymbol[widget.quoteSymbol];
    if (!mounted) return;
    setState(() => _fetchingQuote = false);
    if (quote == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.investFetchQuoteError)));
      return;
    }
    final isCrypto = widget.kind.isCrypto;
    var text = quote.price.toStringAsFixed(isCrypto ? 8 : 2);
    if (isCrypto) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    setState(() => _price.text = text.replaceAll('.', ','));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final qty = _num(_qty);
    final price = _num(_price);
    if (qty <= 0 || price <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
      return;
    }
    setState(() => _loading = true);
    final notifier = ref.read(investmentsNotifierProvider.notifier);

    // Reuse an existing asset with the same quote symbol, else create it.
    final assets = ref.read(investmentAssetsStreamProvider).value ?? const [];
    final matches = assets.where((a) => a.quoteSymbol == widget.quoteSymbol);
    String? assetId = matches.isEmpty ? null : matches.first.id;
    assetId ??= await notifier.addAsset(
      ticker: widget.ticker,
      quoteSymbol: widget.quoteSymbol,
      name: widget.name,
      kind: widget.kind,
    );
    if (assetId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
      return;
    }

    final ok = await notifier.addTrade(
      assetId: assetId,
      side: _side,
      quantity: qty,
      unitPrice: price,
      fees: _num(_fees),
      date: _date,
    );

    // Fetch the quote so the new position shows a market value immediately.
    await ref.read(investmentQuotesProvider.notifier).refresh([
      InvestmentAsset(
        id: assetId,
        userId: '',
        ticker: widget.ticker,
        quoteSymbol: widget.quoteSymbol,
        name: widget.name,
        kind: widget.kind,
        createdAt: _date,
      ),
    ]);

    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dateLoc = ref.watch(dateLocaleProvider);
    const numType = TextInputType.numberWithOptions(decimal: true);
    final inputFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    return AlertDialog(
      title: Text('${l10n.investAddToPortfolio} · ${widget.ticker}'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.name,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 12),
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
            autofocus: true,
            keyboardType: numType,
            inputFormatters: inputFmt,
            decoration: InputDecoration(
                labelText: l10n.investQuantity,
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _price,
            keyboardType: numType,
            inputFormatters: inputFmt,
            decoration: InputDecoration(
                labelText: '${l10n.investUnitPrice} (${widget.kind.currency})',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l10n.investFetchQuote,
                  icon: _fetchingQuote
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                  onPressed: _fetchingQuote ? null : _fetchCurrentQuote,
                )),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _fees,
            keyboardType: numType,
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
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel)),
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
