import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/subscription/presentation/providers/subscription_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../features/wallets/presentation/providers/wallets_provider.dart';
import '../services/exchange_rate_service.dart';
import 'app_settings_provider.dart';

/// True when the user holds wallets in more than one currency (so a consolidated
/// total needs FX conversion to be meaningful).
final hasMultipleCurrenciesProvider = Provider<bool>((ref) {
  final appCode = ref.watch(appSettingsProvider).currency.code;
  final wallets = ref.watch(walletsStreamProvider).value ?? const [];
  final codes = <String>{};
  for (final w in wallets) {
    codes.add(w.currencyCode.isEmpty ? appCode : w.currencyCode);
  }
  return codes.length > 1;
});

/// Total balance consolidated into the app currency.
///
/// For single-currency users this is identical to [balanceProvider] (the common
/// case, untouched). When the user is Pro, holds wallets in multiple currencies
/// and live rates are available, each wallet's balance is converted to the app
/// currency before summing. If a rate is missing for some wallet, that wallet
/// falls back to its raw value — so the result is never worse than the raw sum.
final convertedBalanceProvider = Provider<double>((ref) {
  final raw = ref.watch(balanceProvider);
  final isPro = ref.watch(isProProvider);
  final rates = ref.watch(exchangeRatesProvider);
  if (!isPro || rates.isEmpty) return raw;

  final appCode = ref.watch(appSettingsProvider).currency.code;
  final wallets = ref.watch(walletsStreamProvider).value ?? const [];
  if (wallets.isEmpty) return raw;

  // walletId → currency code.
  final walletCurrency = <String, String>{};
  var multi = false;
  for (final w in wallets) {
    final code = w.currencyCode.isEmpty ? appCode : w.currencyCode;
    walletCurrency[w.id] = code;
    if (code != appCode) multi = true;
  }
  if (!multi) return raw; // all wallets already in the app currency

  final balances = ref.watch(walletBalancesProvider);
  var total = 0.0;
  balances.forEach((walletId, bal) {
    final code = walletCurrency[walletId] ?? appCode; // '' (Geral) → app code
    total += rates.convert(bal, code, appCode) ?? bal;
  });
  return total;
});
