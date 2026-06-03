import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_settings_provider.dart';

extension StringMonthCapitalize on String {
  /// Capitalizes the first letter of every alphabetic word in the string.
  /// Example: "março 2025" → "Março 2025", "1 mar 25" → "1 Mar 25".
  String capitalizeMonth() => replaceAllMapped(
        RegExp(r'[a-zA-ZÀ-ú]+'),
        (m) => m[0]![0].toUpperCase() + m[0]!.substring(1),
      );
}

class CurrencyFormatter {
  /// Format using a specific [AppCurrency].
  static String format(double amount, AppCurrency currency) =>
      NumberFormat.currency(locale: currency.locale, symbol: currency.symbol)
          .format(amount);

  /// Legacy BRL — kept for contexts without a Ref.
  static String formatBRL(double amount) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(amount);

  static String formatDate(DateTime date, [String locale = 'pt_BR']) =>
      DateFormat('dd/MM/yyyy', locale).format(date);

  static String formatMonthYear(DateTime date, [String locale = 'pt_BR']) =>
      DateFormat('MMMM yyyy', locale).format(date).capitalizeMonth();

  static String formatMonthShort(DateTime date, [String locale = 'pt_BR']) =>
      DateFormat('MMM', locale).format(date).capitalizeMonth();
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a function that formats [double] as currency using the current
/// app currency setting. Use via: `ref.watch(currencyFormatterProvider)(amount)`.
final currencyFormatterProvider = Provider<String Function(double)>((ref) {
  final currency = ref.watch(appSettingsProvider).currency;
  final fmt =
      NumberFormat.currency(locale: currency.locale, symbol: currency.symbol);
  return fmt.format;
});

/// Returns the locale string for [DateFormat] based on the current language
/// (e.g. 'pt_BR', 'en_US', 'es_ES').
final dateLocaleProvider = Provider<String>((ref) {
  switch (ref.watch(appSettingsProvider).language.locale.languageCode) {
    case 'en':
      return 'en_US';
    case 'es':
      return 'es_ES';
    default:
      return 'pt_BR';
  }
});
