import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/credit_card_invoice.dart';
import '../../domain/entities/wallet_entity.dart';
import 'wallets_provider.dart';

/// All credit-card wallets.
final creditCardWalletsProvider = Provider<List<WalletEntity>>((ref) {
  final all = ref.watch(walletsStreamProvider).value ?? const [];
  return all.where((w) => w.isCreditCard).toList();
});

/// Invoices (faturas) computed for a given credit-card wallet id.
final cardInvoicesProvider =
    Provider.family<List<CardInvoice>, String>((ref, walletId) {
  final all = ref.watch(walletsStreamProvider).value ?? const [];
  WalletEntity? card;
  for (final w in all) {
    if (w.id == walletId) {
      card = w;
      break;
    }
  }
  if (card == null || !card.isCreditCard) return const [];
  final txs = ref.watch(transactionsStreamProvider).value ?? const [];
  final cardTxs = txs.where((t) => t.walletId == walletId);
  return computeCardInvoices(card, cardTxs);
});

/// Total currently owed on a credit card (sum of unpaid invoice remainders).
final cardOwedProvider = Provider.family<double, String>((ref, walletId) {
  final invoices = ref.watch(cardInvoicesProvider(walletId));
  return invoices.fold<double>(0, (sum, inv) => sum + inv.remaining);
});
