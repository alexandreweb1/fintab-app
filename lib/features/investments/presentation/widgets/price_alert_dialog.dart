import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../../domain/investment_asset.dart';
import '../../domain/price_alert.dart';
import '../providers/investments_provider.dart';
import '../providers/price_alerts_provider.dart';

/// Opens the create-alert dialog, Pro-gated. When [asset] is given the alert
/// targets it; otherwise the user picks one of the portfolio assets.
Future<void> openPriceAlertDialog(
  BuildContext context,
  WidgetRef ref, {
  InvestmentAsset? asset,
}) {
  final l10n = AppLocalizations.of(context);
  if (!ref.read(isProProvider)) {
    showProGateBottomSheet(
      context,
      featureName: l10n.investAlerts,
      featureDescription: l10n.investAlertsDesc,
      featureIcon: Icons.notifications_active_rounded,
    );
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    builder: (_) => PriceAlertDialog(asset: asset),
  );
}

class PriceAlertDialog extends ConsumerStatefulWidget {
  final InvestmentAsset? asset;
  const PriceAlertDialog({super.key, this.asset});

  @override
  ConsumerState<PriceAlertDialog> createState() => _PriceAlertDialogState();
}

class _PriceAlertDialogState extends ConsumerState<PriceAlertDialog> {
  final _price = TextEditingController();
  AlertCondition _condition = AlertCondition.above;
  InvestmentAsset? _selected;
  bool _loading = false;
  bool _fetchingQuote = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.asset;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  double get _target =>
      double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _fetchCurrentQuote() async {
    final asset = _selected;
    if (asset == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetchingQuote = true);
    await ref.read(investmentQuotesProvider.notifier).refresh([asset]);
    final quote =
        ref.read(investmentQuotesProvider).bySymbol[asset.quoteSymbol];
    if (!mounted) return;
    setState(() => _fetchingQuote = false);
    if (quote == null) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.investFetchQuoteError)));
      return;
    }
    final isCrypto = asset.kind.isCrypto;
    var text = quote.price.toStringAsFixed(isCrypto ? 8 : 2);
    if (isCrypto) {
      text =
          text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    setState(() => _price.text = text.replaceAll('.', ','));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final asset = _selected;
    if (asset == null) return;
    if (_target <= 0) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
      return;
    }
    setState(() => _loading = true);

    // An alert whose condition is already satisfied would fire on the very
    // next check — require the target on the far side of the current quote.
    var quote =
        ref.read(investmentQuotesProvider).bySymbol[asset.quoteSymbol];
    if (quote == null) {
      await ref.read(investmentQuotesProvider.notifier).refresh([asset]);
      quote = ref.read(investmentQuotesProvider).bySymbol[asset.quoteSymbol];
      if (!mounted) return;
    }
    if (quote != null) {
      final above = _condition == AlertCondition.above;
      if (above ? _target <= quote.price : _target >= quote.price) {
        setState(() => _loading = false);
        messenger.showSnackBar(SnackBar(
            content: Text(above
                ? l10n.investAlertTargetAboveError
                : l10n.investAlertTargetBelowError)));
        return;
      }
    }
    final ok = await ref.read(priceAlertsNotifierProvider.notifier).add(
          ticker: asset.ticker,
          quoteSymbol: asset.quoteSymbol,
          name: asset.name,
          kind: asset.kind,
          condition: _condition,
          targetPrice: _target,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.investAlertSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fixedAsset = widget.asset != null;
    final portfolio = ref.watch(investmentAssetsStreamProvider).value ?? const [];
    final canPick = fixedAsset || portfolio.isNotEmpty;
    final cur = _selected?.kind.currency;

    return AlertDialog(
      title: Text(fixedAsset
          ? '${l10n.investCreateAlert} · ${widget.asset!.ticker}'
          : l10n.investCreateAlert),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (fixedAsset)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.asset!.name,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            )
          else if (portfolio.isEmpty)
            Text(l10n.investAlertNeedAsset,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))
          else
            DropdownButtonFormField<InvestmentAsset>(
              initialValue: _selected,
              decoration: InputDecoration(
                  labelText: l10n.investAlertAsset,
                  border: const OutlineInputBorder()),
              items: [
                for (final a in portfolio)
                  DropdownMenuItem(value: a, child: Text(a.ticker)),
              ],
              onChanged: (a) => setState(() => _selected = a),
            ),
          const SizedBox(height: 12),
          SegmentedButton<AlertCondition>(
            segments: [
              ButtonSegment(
                  value: AlertCondition.above,
                  icon: const Icon(Icons.trending_up_rounded, size: 16),
                  label: Text(l10n.investAlertCondAbove)),
              ButtonSegment(
                  value: AlertCondition.below,
                  icon: const Icon(Icons.trending_down_rounded, size: 16),
                  label: Text(l10n.investAlertCondBelow)),
            ],
            selected: {_condition},
            onSelectionChanged: (s) => setState(() => _condition = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            autofocus: fixedAsset,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration: InputDecoration(
                labelText: cur != null
                    ? '${l10n.investAlertTargetPrice} ($cur)'
                    : l10n.investAlertTargetPrice,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l10n.investFetchQuote,
                  icon: _fetchingQuote
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync_rounded),
                  onPressed: (_fetchingQuote || _selected == null)
                      ? null
                      : _fetchCurrentQuote,
                )),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.investAlertsDesc,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: (_loading || !canPick || _selected == null) ? null : _save,
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
