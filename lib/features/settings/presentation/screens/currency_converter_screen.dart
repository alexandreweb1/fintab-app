import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/services/exchange_rate_service.dart';
import '../../../../core/utils/currency_formatter.dart';

/// A live currency converter between the app's supported currencies, using
/// real exchange-rate quotes (Pro feature).
class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState
    extends ConsumerState<CurrencyConverterScreen> {
  final _controller = TextEditingController(text: '1');
  late AppCurrency _from;
  late AppCurrency _to;
  bool _initialized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final rates = ref.watch(exchangeRatesProvider);
    final convert = ref.watch(currencyConverterProvider);

    if (!_initialized) {
      _from = ref.read(appSettingsProvider).currency;
      _to = _from == AppCurrency.usd ? AppCurrency.brl : AppCurrency.usd;
      _initialized = true;
    }

    final amount =
        double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
    final converted = convert(amount, _from, _to);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.currencyConverter),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: l10n.currencyRefreshRates,
            onPressed: () =>
                ref.read(exchangeRatesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.amount,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.attach_money_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CurrencyDropdown(
                  label: l10n.currencyFrom,
                  value: _from,
                  onChanged: (c) => setState(() => _from = c),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: l10n.currencySwap,
                onPressed: () => setState(() {
                  final tmp = _from;
                  _from = _to;
                  _to = tmp;
                }),
              ),
              Expanded(
                child: _CurrencyDropdown(
                  label: l10n.currencyTo,
                  value: _to,
                  onChanged: (c) => setState(() => _to = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
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
              children: [
                Text(
                  '${_fmt(amount, _from)} =',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  converted != null ? _fmt(converted, _to) : '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (converted != null && amount > 0)
            Center(
              child: Text(
                '1 ${_from.code} = ${_fmt(convert(1, _from, _to) ?? 0, _to)}',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              rates.updatedAt != null
                  ? '${l10n.currencyRatesUpdatedAt}: ${DateFormat('dd/MM HH:mm').format(rates.updatedAt!)}'
                  : l10n.currencyRatesLoading,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double amount, AppCurrency currency) =>
      CurrencyFormatter.format(amount, currency);
}

class _CurrencyDropdown extends StatelessWidget {
  final String label;
  final AppCurrency value;
  final ValueChanged<AppCurrency> onChanged;

  const _CurrencyDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AppCurrency>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: AppCurrency.values
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text('${c.code} ${c.symbol}',
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (c) {
        if (c != null) onChanged(c);
      },
    );
  }
}
