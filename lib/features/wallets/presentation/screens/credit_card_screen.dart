import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/credit_card_invoice.dart';
import '../../domain/entities/wallet_entity.dart';
import '../providers/credit_card_provider.dart';
import '../providers/wallets_provider.dart';

/// Shows a credit card's invoices (faturas) with status, totals and a
/// "pay invoice" action that records a transfer from a chosen wallet.
class CreditCardScreen extends ConsumerWidget {
  final String walletId;
  const CreditCardScreen({super.key, required this.walletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);

    final wallets = ref.watch(walletsStreamProvider).value ?? const [];
    WalletEntity? card;
    for (final w in wallets) {
      if (w.id == walletId) card = w;
    }
    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.creditCard)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final invoices = ref.watch(cardInvoicesProvider(walletId));
    final owed = ref.watch(cardOwedProvider(walletId));
    final available = card.creditLimit - owed;
    final cardColor = Color(card.colorValue);
    final theCard = card;

    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.cardOptions,
            onSelected: (v) {
              switch (v) {
                case 'due':
                  _showChangeDueDateDialog(context, ref, theCard);
                case 'delete':
                  _showDeleteCardDialog(context, ref, theCard);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'due',
                child: Row(children: [
                  const Icon(Icons.event_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text(l10n.changeDueDate),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 20, color: cs.error),
                  const SizedBox(width: 12),
                  Text(l10n.deleteCard, style: TextStyle(color: cs.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Card header ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor, cardColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(kCategoryIconMap[card.iconCodePoint] ?? Icons.credit_card,
                        color: Colors.white),
                    const SizedBox(width: 8),
                    Text(card.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 18),
                Text(l10n.invoiceRemaining,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12)),
                Text(fmt(owed),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26)),
                const SizedBox(height: 8),
                if (card.creditLimit > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: card.creditLimit > 0
                          ? (owed / card.creditLimit).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.availableLimit}: ${fmt(available < 0 ? 0 : available)} / ${fmt(card.creditLimit)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.invoices,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...invoices.map((inv) => _InvoiceCard(
                card: card!,
                invoice: inv,
                fmt: fmt,
                cs: cs,
              )),
        ],
      ),
    );
  }

  Future<void> _showChangeDueDateDialog(
      BuildContext context, WidgetRef ref, WalletEntity card) async {
    final l10n = AppLocalizations.of(context);
    int day = card.dueDay.clamp(1, 31);
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.changeDueDate),
        content: StatefulBuilder(
          builder: (c, setSt) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.invoiceDue} '),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: day,
                items: [
                  for (var d = 1; d <= 31; d++)
                    DropdownMenuItem(value: d, child: Text('$d')),
                ],
                onChanged: (v) => setSt(() => day = v ?? day),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(l10n.save)),
        ],
      ),
    );
    if (saved != true) return;
    await ref
        .read(walletsNotifierProvider.notifier)
        .update(card.copyWith(dueDay: day));
  }

  Future<void> _showDeleteCardDialog(
      BuildContext context, WidgetRef ref, WalletEntity card) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${l10n.deleteCard}: ${card.name}'),
        content: Text(l10n.deleteCardKeepTxWarning),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final done =
        await ref.read(walletsNotifierProvider.notifier).delete(card.id);
    if (done) {
      navigator.pop(); // leave the (now-deleted) card screen
      messenger.showSnackBar(SnackBar(content: Text(l10n.cardDeleted)));
    }
  }
}

class _InvoiceCard extends ConsumerWidget {
  final WalletEntity card;
  final CardInvoice invoice;
  final String Function(double) fmt;
  final ColorScheme cs;

  const _InvoiceCard({
    required this.card,
    required this.invoice,
    required this.fmt,
    required this.cs,
  });

  ({Color color, String label}) _statusChip(AppLocalizations l10n) {
    switch (invoice.status) {
      case InvoiceStatus.open:
        return (color: const Color(0xFF2196F3), label: l10n.invoiceOpen);
      case InvoiceStatus.closed:
        return (color: const Color(0xFFFF9800), label: l10n.invoiceClosed);
      case InvoiceStatus.paid:
        return (color: const Color(0xFF00A86B), label: l10n.invoicePaid);
      case InvoiceStatus.overdue:
        return (color: cs.error, label: l10n.invoiceOverdue);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    final chip = _statusChip(l10n);
    final canPay = invoice.remaining > 0 &&
        invoice.status != InvoiceStatus.open &&
        invoice.total > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  CurrencyFormatter.formatMonthYear(invoice.closingDate, dateLoc),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chip.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(chip.label,
                    style: TextStyle(
                        color: chip.color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(fmt(invoice.effectiveTotal),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                    if (invoice.isManual) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.edit_note_rounded,
                          size: 14, color: cs.primary),
                    ],
                    const SizedBox(width: 10),
                    Icon(Icons.event_outlined,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        '${l10n.invoiceDue} ${CurrencyFormatter.formatDate(invoice.dueDate, dateLoc)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                if (invoice.isManual)
                  Text(
                    '${l10n.invoiceComputed}: ${fmt(invoice.total)}',
                    style: TextStyle(
                        fontSize: 10.5, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          children: [
            if (invoice.transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.noInvoiceTransactions,
                    style:
                        TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              )
            else
              ...invoice.transactions.map((t) => _TxRow(
                    tx: t,
                    fmt: fmt,
                    dateLoc: dateLoc,
                    cs: cs,
                    onTap: () {
                      focusTransactionInStatement(ref, t);
                      Navigator.of(context).pop(); // reveal the Extrato
                    },
                  )),
            if (invoice.paidAmount > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.invoicePaid,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant)),
                  Text('- ${fmt(invoice.paidAmount)}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00A86B))),
                ],
              ),
            ],
            // Manually set the closed-invoice amount for this cycle (only once
            // the fatura is no longer open/accumulating).
            if (invoice.status != InvoiceStatus.open) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showSetInvoiceValueDialog(context, ref),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(invoice.isManual
                      ? l10n.editInvoiceValue
                      : l10n.setInvoiceValue),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
            if (canPay) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openPayDialog(context, ref),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text('${l10n.payInvoice} · ${fmt(invoice.remaining)}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openPayDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PayInvoiceDialog(card: card, invoice: invoice),
    );
  }

  Future<void> _showSetInvoiceValueDialog(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final key = cardInvoiceCycleKey(invoice.closingDate);
    final ctrl = TextEditingController(
        text: invoice.isManual ? _fmtEdit(invoice.manualTotal!) : '');

    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.setInvoiceValue),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.setInvoiceValueHint,
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('${l10n.invoiceComputed}: ${fmt(invoice.total)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                labelText: l10n.setInvoiceValue,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          if (invoice.isManual)
            TextButton(
              onPressed: () async {
                final map = Map<String, double>.from(card.closedInvoiceAmounts)
                  ..remove(key);
                Navigator.pop(c);
                await ref
                    .read(walletsNotifierProvider.notifier)
                    .update(card.copyWith(closedInvoiceAmounts: map));
              },
              child: Text(l10n.clearInvoiceValue),
            ),
          TextButton(
              onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              final v = _parseMoney(ctrl.text);
              if (v == null) return; // invalid → keep dialog open
              final map = Map<String, double>.from(card.closedInvoiceAmounts)
                ..[key] = v;
              Navigator.pop(c);
              await ref
                  .read(walletsNotifierProvider.notifier)
                  .update(card.copyWith(closedInvoiceAmounts: map));
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// Formats a value for the money TextField (pt-BR-ish "1234,56").
String _fmtEdit(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// Parses a user-typed money string ("1.842,00", "1842.00", "1842") to a finite
/// double, or null when it isn't a usable number (guards NaN/Infinity).
double? _parseMoney(String s) {
  var t = s.trim().replaceAll(RegExp(r'[^\d,.\-]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',') && t.contains('.')) {
    // pt-BR: '.' thousands, ',' decimal.
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (t.contains(',')) {
    t = t.replaceAll(',', '.');
  }
  final v = double.tryParse(t);
  if (v == null || !v.isFinite || v < 0) return null;
  return v;
}

class _TxRow extends StatelessWidget {
  final TransactionEntity tx;
  final String Function(double) fmt;
  final String dateLoc;
  final ColorScheme cs;
  final VoidCallback? onTap;

  const _TxRow({
    required this.tx,
    required this.fmt,
    required this.dateLoc,
    required this.cs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRefund = tx.isIncome;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  Text(
                    '${tx.category} · ${CurrencyFormatter.formatDate(tx.date, dateLoc)}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '${isRefund ? '- ' : ''}${fmt(tx.amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isRefund ? const Color(0xFF00A86B) : cs.onSurface,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayInvoiceDialog extends ConsumerStatefulWidget {
  final WalletEntity card;
  final CardInvoice invoice;

  const _PayInvoiceDialog({required this.card, required this.invoice});

  @override
  ConsumerState<_PayInvoiceDialog> createState() => _PayInvoiceDialogState();
}

class _PayInvoiceDialogState extends ConsumerState<_PayInvoiceDialog> {
  String? _sourceWalletId;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(currencyFormatterProvider);
    final wallets = ref.watch(walletsStreamProvider).value ?? const [];
    // Sources: any non-credit wallet, plus the implicit "Geral" bucket.
    final sources = wallets.where((w) => !w.isCreditCard).toList();

    return AlertDialog(
      title: Text(l10n.payInvoice),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l10n.invoiceRemaining}: ${fmt(widget.invoice.remaining)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(l10n.payInvoiceFrom,
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _sourceWalletId,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            hint: Text(l10n.creditCardNoWallet),
            items: [
              const DropdownMenuItem(value: '', child: Text('Geral')),
              ...sources.map((w) =>
                  DropdownMenuItem(value: w.id, child: Text(w.name))),
            ],
            onChanged: (v) => setState(() => _sourceWalletId = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_sourceWalletId == null || _loading) ? null : _pay,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.payInvoice),
        ),
      ],
    );
  }

  Future<void> _pay() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    // Payment = transfer from the chosen wallet into the credit card.
    final ok = await ref.read(transactionsNotifierProvider.notifier).add(
          title: '${l10n.payInvoice} · ${widget.card.name}',
          amount: widget.invoice.remaining,
          type: TransactionType.transfer,
          category: l10n.payInvoice,
          date: DateTime.now(),
          walletId: widget.card.id,
          sourceWalletId: _sourceWalletId!.isEmpty ? null : _sourceWalletId,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.invoicePaidSuccess)),
      );
    }
  }
}
