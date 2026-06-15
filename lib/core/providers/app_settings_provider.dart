import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Currency
// ─────────────────────────────────────────────────────────────────────────────

enum AppCurrency {
  brl(code: 'BRL', symbol: 'R\$', locale: 'pt_BR', label: 'Real Brasileiro (BRL)'),
  usd(code: 'USD', symbol: 'US\$', locale: 'en_US', label: 'Dólar Americano (USD)'),
  eur(code: 'EUR', symbol: '€', locale: 'de_DE', label: 'Euro (EUR)'),
  gbp(code: 'GBP', symbol: '£', locale: 'en_GB', label: 'Libra Esterlina (GBP)'),
  ars(code: 'ARS', symbol: '\$', locale: 'es_AR', label: 'Peso Argentino (ARS)'),
  mxn(code: 'MXN', symbol: '\$', locale: 'es_MX', label: 'Peso Mexicano (MXN)'),
  clp(code: 'CLP', symbol: '\$', locale: 'es_CL', label: 'Peso Chileno (CLP)'),
  cop(code: 'COP', symbol: '\$', locale: 'es_CO', label: 'Peso Colombiano (COP)'),
  pen(code: 'PEN', symbol: 'S/', locale: 'es_PE', label: 'Sol Peruano (PEN)'),
  uyu(code: 'UYU', symbol: '\$', locale: 'es_UY', label: 'Peso Uruguaio (UYU)'),
  cad(code: 'CAD', symbol: 'CA\$', locale: 'en_CA', label: 'Dólar Canadense (CAD)'),
  aud(code: 'AUD', symbol: 'A\$', locale: 'en_AU', label: 'Dólar Australiano (AUD)'),
  chf(code: 'CHF', symbol: 'CHF', locale: 'de_CH', label: 'Franco Suíço (CHF)'),
  jpy(code: 'JPY', symbol: '¥', locale: 'ja_JP', label: 'Iene Japonês (JPY)'),
  cny(code: 'CNY', symbol: '¥', locale: 'zh_CN', label: 'Yuan Chinês (CNY)'),
  inr(code: 'INR', symbol: '₹', locale: 'hi_IN', label: 'Rupia Indiana (INR)'),
  krw(code: 'KRW', symbol: '₩', locale: 'ko_KR', label: 'Won Coreano (KRW)'),
  btc(code: 'BTC', symbol: '₿', locale: 'en_US', label: 'Bitcoin (BTC)');

  final String code;
  final String symbol;
  final String locale;
  final String label;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.label,
  });

  static AppCurrency fromCode(String code) =>
      AppCurrency.values.firstWhere(
        (c) => c.code == code,
        orElse: () => AppCurrency.brl,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Language / Locale
// ─────────────────────────────────────────────────────────────────────────────

enum AppLanguage {
  portuguese(locale: Locale('pt', 'BR'), label: 'Português', nativeLabel: 'Português'),
  english(locale: Locale('en', 'US'), label: 'English', nativeLabel: 'English'),
  spanish(locale: Locale('es', 'ES'), label: 'Español', nativeLabel: 'Español');

  final Locale locale;
  final String label;
  final String nativeLabel;

  const AppLanguage({
    required this.locale,
    required this.label,
    required this.nativeLabel,
  });

  static AppLanguage fromCode(String code) =>
      AppLanguage.values.firstWhere(
        (l) => l.locale.languageCode == code,
        orElse: () => AppLanguage.portuguese,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme mode
// ─────────────────────────────────────────────────────────────────────────────

enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get flutterThemeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  static AppThemeMode fromString(String value) =>
      AppThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => AppThemeMode.system,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Financial literacy level (controla a exibição das dicas "?")
// ─────────────────────────────────────────────────────────────────────────────

enum FinancialLiteracyLevel {
  /// Não respondeu ainda — onboarding deve ser exibido.
  unset,

  /// Mostra TODAS as dicas, inclusive básicas.
  beginner,

  /// Mostra apenas dicas marcadas como `intermediate` (conceitos não-triviais).
  intermediate,

  /// Oculta todas as dicas.
  advanced;

  static FinancialLiteracyLevel fromString(String? value) {
    if (value == null) return FinancialLiteracyLevel.unset;
    return FinancialLiteracyLevel.values.firstWhere(
      (l) => l.name == value,
      orElse: () => FinancialLiteracyLevel.unset,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings state
// ─────────────────────────────────────────────────────────────────────────────

class AppSettings {
  final AppCurrency currency;
  final AppLanguage language;
  final AppThemeMode themeMode;
  final Set<String> hiddenWalletIds;
  final FinancialLiteracyLevel literacyLevel;

  const AppSettings({
    this.currency = AppCurrency.brl,
    this.language = AppLanguage.portuguese,
    this.themeMode = AppThemeMode.system,
    this.hiddenWalletIds = const {},
    this.literacyLevel = FinancialLiteracyLevel.unset,
  });

  AppSettings copyWith({
    AppCurrency? currency,
    AppLanguage? language,
    AppThemeMode? themeMode,
    Set<String>? hiddenWalletIds,
    FinancialLiteracyLevel? literacyLevel,
  }) =>
      AppSettings(
        currency: currency ?? this.currency,
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        hiddenWalletIds: hiddenWalletIds ?? this.hiddenWalletIds,
        literacyLevel: literacyLevel ?? this.literacyLevel,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  static const _keyCurrency = 'app_currency';
  static const _keyLanguage = 'app_language';
  static const _keyThemeMode = 'app_theme_mode';
  static const _keyHiddenWallets = 'hidden_wallet_ids';
  static const _keyLiteracyLevel = 'app_literacy_level';

  AppSettingsNotifier(super.initial);

  Future<void> setCurrency(AppCurrency currency) async {
    state = state.copyWith(currency: currency);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrency, currency.code);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language.locale.languageCode);
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    state = state.copyWith(themeMode: themeMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, themeMode.name);
  }

  Future<void> setLiteracyLevel(FinancialLiteracyLevel level) async {
    state = state.copyWith(literacyLevel: level);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLiteracyLevel, level.name);
  }

  Future<void> toggleWalletVisibility(String walletId) async {
    final hidden = Set<String>.from(state.hiddenWalletIds);
    if (hidden.contains(walletId)) {
      hidden.remove(walletId);
    } else {
      hidden.add(walletId);
    }
    state = state.copyWith(hiddenWalletIds: hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyHiddenWallets, hidden.toList());
  }

  /// [deviceLanguageCode] is the system language code (e.g. 'pt', 'en', 'es'),
  /// passed from main() after WidgetsFlutterBinding.ensureInitialized().
  /// Used only when the user has never explicitly chosen a language.
  static Future<AppSettings> load({String? deviceLanguageCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final currencyCode = prefs.getString(_keyCurrency) ?? 'BRL';
    final savedLanguageCode = prefs.getString(_keyLanguage);
    final themeModeStr = prefs.getString(_keyThemeMode) ?? 'system';
    final hiddenList = prefs.getStringList(_keyHiddenWallets) ?? [];
    final literacyLevelStr = prefs.getString(_keyLiteracyLevel);

    final AppLanguage language;
    if (savedLanguageCode != null) {
      language = AppLanguage.fromCode(savedLanguageCode);
    } else if (deviceLanguageCode != null) {
      // No saved preference: default based on device locale.
      // Portuguese for pt devices, Spanish for es, English for everything else.
      if (deviceLanguageCode == 'pt') {
        language = AppLanguage.portuguese;
      } else if (deviceLanguageCode == 'es') {
        language = AppLanguage.spanish;
      } else {
        language = AppLanguage.english;
      }
    } else {
      language = AppLanguage.portuguese;
    }

    return AppSettings(
      currency: AppCurrency.fromCode(currencyCode),
      language: language,
      themeMode: AppThemeMode.fromString(themeModeStr),
      hiddenWalletIds: Set<String>.from(hiddenList),
      literacyLevel: FinancialLiteracyLevel.fromString(literacyLevelStr),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Loaded synchronously from SharedPreferences before the app starts.
/// Override this in main() with the persisted value.
final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(const AppSettings()),
);
