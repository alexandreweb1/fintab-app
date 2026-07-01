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

    return Scaffold(
      appBar: AppBar(title: Text(card.name)),
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
            child: Row(
              children: [
                Text(fmt(invoice.total),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                const SizedBox(width: 10),
                Icon(Icons.event_outlined,
                    size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 2),
                Text(
                  '${l10n.invoiceDue} ${CurrencyFormatter.formatDate(invoice.dueDate, dateLoc)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
}

class _TxRow extends StatelessWidget {
  final TransactionEntity tx;
  final String Function(double) fmt;
  final String dateLoc;
  final ColorScheme cs;

  const _TxRow({
    required this.tx,
    required this.fmt,
    required this.dateLoc,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isRefund = tx.isIncome;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
        ],
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
