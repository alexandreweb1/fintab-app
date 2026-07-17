import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/money_input_formatter.dart';
import '../../domain/bank_brands.dart';
import '../../domain/entities/wallet_entity.dart';
import '../providers/wallets_provider.dart';

/// Creates a credit-card wallet: pick a bank/network brand (drives the color +
/// avatar), set a name, credit limit and the closing/due days. Returns `true`.
class AddCardDialog extends ConsumerStatefulWidget {
  const AddCardDialog({super.key});

  @override
  ConsumerState<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends ConsumerState<AddCardDialog> {
  BankBrand _brand = kBankBrands.first;
  final _name = TextEditingController(text: kBankBrands.first.name);
  bool _nameEdited = false;
  final _limit = TextEditingController();
  int _closingDay = 1;
  int _dueDay = 10;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _pickBrand(BankBrand b) {
    setState(() {
      _brand = b;
      // Keep the name in sync with the brand until the user edits it manually.
      if (!_nameEdited && b.id != 'other') _name.text = b.name;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cardName)));
      return;
    }
    final uid = ref.read(ledgerOwnerIdProvider);
    if (uid.isEmpty) return;
    setState(() => _loading = true);
    final ok = await ref.read(walletsNotifierProvider.notifier).add(
          userId: uid,
          name: name,
          iconCodePoint: 0xe870, // credit_card
          colorValue: _brand.colorValue,
          type: WalletType.creditCard,
          creditLimit: moneyTextToDouble(_limit.text),
          closingDay: _closingDay,
          dueDay: _dueDay,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final symbol = ref.watch(currencySymbolProvider);
    final br = kBankBrands.where((b) => !b.international && b.id != 'other');
    final intl = kBankBrands.where((b) => b.international);
    final other = kBankBrands.firstWhere((b) => b.id == 'other');

    return AlertDialog(
      title: Text(l10n.newCard),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.selectBank,
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              _label(l10n.banksBrazil, cs),
              _brandWrap(br),
              const SizedBox(height: 10),
              _label(l10n.banksIntl, cs),
              _brandWrap(intl),
              const SizedBox(height: 10),
              _brandWrap([other]),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => _nameEdited = true,
                decoration: InputDecoration(
                    labelText: l10n.cardName,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _limit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                    labelText: '${l10n.creditLimit} (${l10n.optional})',
                    prefixText: '$symbol ',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _dayDropdown(
                        l10n.closingDay, _closingDay,
                        (v) => setState(() => _closingDay = v))),
                const SizedBox(width: 12),
                Expanded(
                    child: _dayDropdown(l10n.dueDay, _dueDay,
                        (v) => setState(() => _dueDay = v))),
              ]),
            ],
          ),
        ),
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

  Widget _label(String t, ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant)),
      );

  Widget _brandWrap(Iterable<BankBrand> brands) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: brands.map((b) {
        final selected = b.id == _brand.id;
        return GestureDetector(
          onTap: () => _pickBrand(b),
          child: SizedBox(
            width: 58,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? cs.primary : Colors.transparent,
                        width: 2.5),
                  ),
                  child: BankAvatar(brand: b, size: 42),
                ),
                const SizedBox(height: 3),
                Text(b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? cs.primary : cs.onSurfaceVariant)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dayDropdown(String label, int value, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()),
      items: [
        for (var d = 1; d <= 31; d++)
          DropdownMenuItem(value: d, child: Text('$d')),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
