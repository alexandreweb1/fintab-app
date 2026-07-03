import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/add_transaction_dialog.dart';
import '../../domain/bank_brands.dart';
import '../../domain/credit_card_invoice.dart';
import '../../domain/entities/wallet_entity.dart';
import '../providers/credit_card_provider.dart';
import '../widgets/add_card_dialog.dart';
import 'credit_card_screen.dart';

/// Standalone screen wrapper around [CardsView].
class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).cards)),
      body: const CardsView(),
    );
  }
}

/// Credit-card management — reused inside the Extrato tab and as a standalone
/// screen. Lists the user's cards with the current invoice, lets them log a
/// purchase and pay (dar baixa) the invoice.
class CardsView extends ConsumerWidget {
  const CardsView({super.key});

  Future<void> _addCard(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (_) => const AddCardDialog(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(currencyFormatterProvider);
    final cards = ref.watch(creditCardWalletsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
          child: Row(
            children: [
              Text(l10n.cards,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addCard(context),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.newCard),
              ),
            ],
          ),
        ),
        Expanded(
          child: cards.isEmpty
              ? _Empty(onAdd: () => _addCard(context))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  children: [
                    _TotalOwed(cards: cards, fmt: fmt),
                    const SizedBox(height: 8),
                    ...cards.map((c) => _CardTile(card: c, fmt: fmt)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TotalOwed extends ConsumerWidget {
  final List<WalletEntity> cards;
  final String Function(double) fmt;
  const _TotalOwed({required this.cards, required this.fmt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    var owed = 0.0;
    for (final c in cards) {
      owed += ref.watch(cardOwedProvider(c.id));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(l10n.cardsTotalOwed,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(fmt(owed),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

class _CardTile extends ConsumerWidget {
  final WalletEntity card;
  final String Function(double) fmt;
  const _CardTile({required this.card, required this.fmt});

  BankBrand get _brand =>
      bankBrandByColor(card.colorValue) ??
      const BankBrand(
          id: 'other', name: 'Outro', colorValue: 0xFF546E7A, shortLabel: '••');

  Future<void> _launchPurchase(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => AddTransactionDialog(
          initialType: TransactionType.expense,
          initialWalletId: card.id,
        ),
      );

  void _openInvoices(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => CreditCardScreen(walletId: card.id)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dateLoc = ref.watch(dateLocaleProvider);
    final invoices = ref.watch(cardInvoicesProvider(card.id));
    final owed = ref.watch(cardOwedProvider(card.id));
    final available = card.creditLimit - owed;
    final brand = _brand;
    final color = brand.color;

    CardInvoice? current;
    for (final i in invoices) {
      if (i.isOpen) {
        current = i;
        break;
      }
    }
    current ??= invoices.isNotEmpty ? invoices.first : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () => _openInvoices(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Brand banner ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BankAvatar(brand: brand, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(card.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: brand.onColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(l10n.invoiceRemaining,
                              style: TextStyle(
                                  color:
                                      brand.onColor.withValues(alpha: 0.85),
                                  fontSize: 10)),
                          Text(fmt(owed),
                              style: TextStyle(
                                  color: brand.onColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                  if (card.creditLimit > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (owed / card.creditLimit).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: brand.onColor.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation(brand.onColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.availableLimit}: ${fmt(available < 0 ? 0 : available)} / ${fmt(card.creditLimit)}',
                      style: TextStyle(
                          color: brand.onColor.withValues(alpha: 0.85),
                          fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            // ── Current invoice + actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                children: [
                  if (current != null)
                    Row(
                      children: [
                        Text('${l10n.currentInvoice}: ',
                            style: TextStyle(
                                fontSize: 12.5, color: cs.onSurfaceVariant)),
                        Text(fmt(current.total),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Icon(Icons.event_outlined,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(
                          '${l10n.invoiceDue} ${CurrencyFormatter.formatDate(current.dueDate, dateLoc)}',
                          style: TextStyle(
                              fontSize: 11.5, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _launchPurchase(context),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: Text(l10n.addCardPurchase),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openInvoices(context),
                          icon: const Icon(Icons.receipt_long_outlined,
                              size: 18),
                          label: Text(owed > 0
                              ? l10n.payInvoice
                              : l10n.viewInvoices),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.credit_card_outlined,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(l10n.noCards,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l10n.noCardsDesc,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.newCard),
          ),
        ]),
      ),
    );
  }
}
