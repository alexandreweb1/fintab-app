import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/l10n/app_localizations.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/utils/firebase_options.dart';
import 'features/app_lock/presentation/widgets/app_lock_gate.dart';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/main_screen.dart';
import 'features/onboarding/presentation/screens/literacy_onboarding_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Initialise date formatting for all supported locales.
  await Future.wait([
    initializeDateFormatting('pt_BR', null),
    initializeDateFormatting('en_US', null),
    initializeDateFormatting('es_ES', null),
  ]);

  // Detect device language for first-launch locale defaulting.
  final deviceLanguageCode =
      binding.platformDispatcher.locale.languageCode;

  // Load persisted settings (currency + language) before first frame.
  final settings =
      await AppSettingsNotifier.load(deviceLanguageCode: deviceLanguageCode);

  runApp(ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(
        (ref) => AppSettingsNotifier(settings),
      ),
    ],
    child: const FirebaseInitializer(),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase initializer
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseInitializer extends StatefulWidget {
  const FirebaseInitializer({super.key});

  @override
  State<FirebaseInitializer> createState() => _FirebaseInitializerState();
}

class _FirebaseInitializerState extends State<FirebaseInitializer> {
  late final Future<FirebaseApp> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const MyFinanceApp();
        }
        if (snapshot.hasError) {
          return _AppShell(
            child: _FirebaseErrorScreen(error: snapshot.error.toString()),
          );
        }
        return const _AppShell(child: _SplashScreen());
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main app — watches locale reactively so language changes take effect live.
// ─────────────────────────────────────────────────────────────────────────────

class MyFinanceApp extends ConsumerWidget {
  const MyFinanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'Fintab',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: settings.themeMode.flutterThemeMode,
      locale: settings.language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Clamp the OS-level text scaling so very large system font sizes
      // don't break tight layouts (tabs, summary cards, buttons). Up to
      // 1.3x still helps accessibility users without clipping the UI.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child!,
        );
      },
      home: const AppRouter(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppRouter
// ─────────────────────────────────────────────────────────────────────────────

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    // Pop all pushed routes when the user signs out so the login screen
    // becomes visible immediately instead of leaving settings/other screens
    // sitting on top of the navigation stack.
    ref.listen<AsyncValue<UserEntity?>>(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user == null) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    });

    return authAsync.when(
      data: (UserEntity? user) => user != null
          ? const AppLockGate(child: _LiteracyOnboardingGate(child: MainScreen()))
          : const LoginScreen(),
      loading: () => const _SplashScreen(),
      error: (error, _) => _FirebaseErrorScreen(error: error.toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding gate — pergunta o nível de familiaridade financeira
// uma única vez, na 1ª abertura após login/cadastro.
// ─────────────────────────────────────────────────────────────────────────────

class _LiteracyOnboardingGate extends ConsumerStatefulWidget {
  final Widget child;
  const _LiteracyOnboardingGate({required this.child});

  @override
  ConsumerState<_LiteracyOnboardingGate> createState() =>
      _LiteracyOnboardingGateState();
}

class _LiteracyOnboardingGateState
    extends ConsumerState<_LiteracyOnboardingGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  void _maybeShow() {
    if (!mounted || _showing) return;
    final level = ref.read(appSettingsProvider).literacyLevel;
    if (level == FinancialLiteracyLevel.unset) {
      _showing = true;
      LiteracyOnboardingDialog.show(context).whenComplete(() {
        _showing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Caso o nível mude para `unset` em runtime (ex.: usuário trocou de conta),
    // re-exibe o onboarding.
    ref.listen<FinancialLiteracyLevel>(
      appSettingsProvider.select((s) => s.literacyLevel),
      (prev, next) {
        if (next == FinancialLiteracyLevel.unset) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _maybeShow());
        }
      },
    );
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

final _lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
  useMaterial3: true,
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
  cardTheme: const CardThemeData(
    elevation: 4,
    shadowColor: Colors.black38,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      side: BorderSide(color: Color(0xFFC4CDD8), width: 1),
    ),
  ),
);

final _darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E88E5),
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// Shell / Splash / Error
// ─────────────────────────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      home: child,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              size: 80,
              color: Color(0xFF1E88E5),
            ),
            const SizedBox(height: 24),
            Text(
              'Fintab',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _FirebaseErrorScreen extends StatelessWidget {
  final String error;
  const _FirebaseErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 72, color: Colors.red.shade400),
                const SizedBox(height: 20),
                Text(
                  'Falha ao inicializar o Firebase',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Verifique se as credenciais em firebase_options.dart\n'
                  'foram preenchidas, ou execute:\n\n'
                  'flutterfire configure',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: SelectableText(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
