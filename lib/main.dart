import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/l10n/app_localizations.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/providers/effective_user_provider.dart';
import 'core/services/analytics_service.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/utils/firebase_options.dart';
import 'features/app_lock/presentation/widgets/app_lock_gate.dart';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/main_screen.dart';
import 'features/onboarding/presentation/providers/onboarding_provider.dart';
import 'features/onboarding/presentation/screens/onboarding_flow_screen.dart';

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
  final deviceLanguageCode = binding.platformDispatcher.locale.languageCode;

  // Load persisted settings (currency + language) before first frame.
  final settings =
      await AppSettingsNotifier.load(deviceLanguageCode: deviceLanguageCode);

  runApp(ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(
        (ref) => AppSettingsNotifier(settings),
      ),
    ],
    child: FirebaseInitializer(telemetryEnabled: settings.telemetryEnabled),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase initializer
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseInitializer extends StatefulWidget {
  final bool telemetryEnabled;
  const FirebaseInitializer({super.key, required this.telemetryEnabled});

  @override
  State<FirebaseInitializer> createState() => _FirebaseInitializerState();
}

class _FirebaseInitializerState extends State<FirebaseInitializer> {
  late final Future<FirebaseApp> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initFirebase();
  }

  /// Initializes Firebase and enables Firestore offline persistence so the app
  /// keeps working (read + queued writes) without connectivity. On mobile this
  /// is on by default; setting it explicitly also covers web.
  Future<FirebaseApp> _initFirebase() async {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (_) {
      // Settings can only be applied once; ignore if already configured.
    }
    // Route uncaught errors to Crashlytics, then apply the user's telemetry
    // consent to BOTH Crashlytics and Analytics (opt-out silences both).
    CrashReportingService.instance.install();
    await CrashReportingService.instance.setEnabled(widget.telemetryEnabled);
    await AnalyticsService.instance.setEnabled(widget.telemetryEnabled);
    return app;
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
      navigatorObservers: [AnalyticsService.instance.navigatorObserver],
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

    // Pop all pushed routes on ANY user transition (login, logout, account
    // switch): auth screens pushed over the pre-auth onboarding — and any
    // stale route — must clear so the new home takes over. Guarded by uid
    // change so mid-session re-emissions never yank the user out of a screen.
    ref.listen<AsyncValue<UserEntity?>>(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (previous?.value?.id != user?.id) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    });

    return authAsync.when(
      data: (UserEntity? user) => user != null
          ? const AppLockGate(child: _OnboardingGate(child: MainScreen()))
          : const _PreAuthGate(),
      loading: () => const _SplashScreen(),
      error: (error, _) => _FirebaseErrorScreen(error: error.toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pré-cadastro — a pesquisa de onboarding roda ANTES da criação da conta;
// a conta entra na ponte "salve seu plano". Uma vez por aparelho.
// ─────────────────────────────────────────────────────────────────────────────

class _PreAuthGate extends ConsumerWidget {
  const _PreAuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final stashAsync = ref.watch(onboardingStashProvider);

    return stashAsync.when(
      loading: () => const _SplashScreen(),
      error: (_, __) => const LoginScreen(),
      data: (stash) {
        // Pesquisa concluída mas conta ainda não criada → direto na ponte.
        if (stash?['surveyDone'] == true) {
          return OnboardingFlowScreen(
            mode: OnboardingFlowMode.preAuth,
            initialData: stash,
            startAtBridge: true,
          );
        }
        // Aparelho que já passou pela pesquisa (ou já teve login) → login.
        if (settings.preAuthOnboardingDone) return const LoginScreen();
        // Primeiro uso neste aparelho → pesquisa (retomando respostas
        // parciais de uma sessão interrompida, se houver).
        return OnboardingFlowScreen(
          mode: OnboardingFlowMode.preAuth,
          initialData: stash,
          resuming: stash != null,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding gate — abre o fluxo de primeiro uso (pesquisa → plano →
// compromisso → paywall) uma única vez após login/cadastro. Substitui o
// antigo LiteracyOnboardingDialog: a pergunta de nível de familiaridade
// agora é a 4ª do fluxo e grava o mesmo AppSettings.literacyLevel.
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingGate extends ConsumerStatefulWidget {
  final Widget child;
  const _OnboardingGate({required this.child});

  @override
  ConsumerState<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<_OnboardingGate> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Há uma conta neste aparelho — a pesquisa pré-cadastro nunca mais
      // deve abrir sozinha aqui.
      if (mounted && !ref.read(appSettingsProvider).preAuthOnboardingDone) {
        ref.read(appSettingsProvider.notifier).setPreAuthOnboardingDone();
      }
      _maybeShow();
    });
  }

  void _maybeShow() {
    if (!mounted || _showing) return;
    // Tri-state: null = perfil/stash ainda carregando (o listener abaixo
    // dispara de novo quando o valor definitivo chegar).
    if (ref.read(needsOnboardingProvider) != true) return;

    // Telas de auth ainda na pilha (o pop pós-cadastro do AppRouter/registro
    // está em andamento): abrir agora deixaria o fluxo ser varrido pelo
    // popUntil — foi exatamente o bug do "sumiu em 1 segundo". Reagenda.
    if (ModalRoute.of(context)?.isCurrent != true) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _maybeShow();
      });
      return;
    }
    _showing = true;

    final onb = ref.read(userProfileStreamProvider).value?['onboardingProfile']
        as Map<String, dynamic>?;
    final stash = ref.read(onboardingStashProvider).value;
    ref.read(onboardingFlowProvider.notifier).maybeLogAbandoned(onb);

    final Widget screen;
    if (stash?['surveyDone'] == true) {
      // Pesquisa respondida antes do cadastro → grava as respostas na conta
      // e segue direto para compromisso + paywall.
      screen = OnboardingFlowScreen(
        mode: OnboardingFlowMode.postAuthContinue,
        initialData: stash,
        persistOnStart: true,
      );
    } else if (onb?['archetype'] != null) {
      // Pesquisa concluída numa sessão anterior → retoma no compromisso.
      screen = OnboardingFlowScreen(
        mode: OnboardingFlowMode.postAuthContinue,
        initialData: onb,
      );
    } else {
      // Fallback: conta criada sem passar pela pesquisa (ou abandono no
      // meio dela) → fluxo completo, com respostas parciais pré-marcadas.
      screen = OnboardingFlowScreen(
        mode: OnboardingFlowMode.postAuthFull,
        initialData: onb,
        resuming: onb?['startedAt'] != null,
      );
    }

    Navigator.of(context)
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => screen,
        ))
        .whenComplete(() => _showing = false);
  }

  @override
  Widget build(BuildContext context) {
    // Reavalia quando o perfil termina de carregar ou quando o usuário
    // troca de conta (needsOnboarding volta a true).
    ref.listen<bool?>(needsOnboardingProvider, (prev, next) {
      if (next == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
      }
    });
    return widget.child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

// Smooth horizontal slide for pushed routes on EVERY platform (Android's
// default Zoom transition felt abrupt) — consistent "transições suaves".
const _iosPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
  },
);

final _lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
  useMaterial3: true,
  appBarTheme: const AppBarTheme(centerTitle: true),
  pageTransitionsTheme: _iosPageTransitions,
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
  appBarTheme: const AppBarTheme(centerTitle: true),
  pageTransitionsTheme: _iosPageTransitions,
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
