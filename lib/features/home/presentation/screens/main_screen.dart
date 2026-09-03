import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/providers/workspace_migration_provider.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/review_prompt_service.dart';
import '../../../app_lock/presentation/providers/app_lock_provider.dart';
import '../../../../core/services/bank_filter_provider.dart';
import '../../../../core/utils/animated_dialog.dart';
import '../../../notification_backlog/presentation/providers/backlog_provider.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/services/in_app_update_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/notification_listener_service.dart';
import '../../../../core/services/notification_permission_dialog.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../investments/presentation/providers/price_alerts_provider.dart';
import '../../../investments/presentation/screens/price_alerts_screen.dart';
import '../providers/dashboard_provider.dart';
import '../../../../core/services/notification_providers.dart';
import '../../../../core/services/notification_suggestion.dart';
import '../../../../core/services/transaction_text_parser.dart';
import '../../../budget/presentation/providers/budget_nudge_signal_provider.dart';
import '../../../budget/presentation/screens/planning_screen.dart';
import '../../../budget/presentation/widgets/budget_nudge_sheet.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../category_rules/domain/category_rule_matcher.dart';
import '../../../category_rules/presentation/providers/category_rules_provider.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../financial_health/presentation/providers/financial_health_provider.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/presentation/screens/transactions_screen.dart';
import '../../../transactions/presentation/widgets/add_transaction_dialog.dart';
import '../widgets/review_prompt_dialog.dart';
import '../widgets/update_banner.dart';
import 'dashboard_screen.dart';
import '../../../../core/providers/effective_user_provider.dart';

const _kGreen = Color(0xFF00D887);

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _tabAnimating = false;
  final PageController _pageController = PageController();
  StreamSubscription<NotificationSuggestion>? _notifSub;

  /// Last clipboard text already offered as a suggestion — avoids re-prompting
  /// for the same copy every time the app resumes.
  String? _lastClipboardText;

  /// Subscription to text/links shared into the app (iOS Share Extension and
  /// Android share sheet) while it is running.
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  Future<void> _changeTab(int newIndex) async {
    if (newIndex == _currentIndex || _tabAnimating) return;
    _tabAnimating = true;
    setState(() => _currentIndex = newIndex);
    ref.read(mainTabIndexProvider.notifier).state = newIndex;
    // Horizontal slide between tabs while keeping every tab's state alive.
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
    _tabAnimating = false;
  }

  void _onPageSettled(int i) {
    if (_currentIndex == i) return;
    setState(() => _currentIndex = i);
    ref.read(mainTabIndexProvider.notifier).state = i;
  }

  static const _mobileScreens = [
    DashboardScreen(),
    TransactionsScreen(),
    PlanningScreen(),
    ReportsScreen(),
  ];

  static const _webScreens = [
    DashboardScreen(),
    TransactionsScreen(),
    PlanningScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLocalNotifications();
    _initNotificationFeature();
    _initShareIntent();
    _initQuickActions();
    _initInAppUpdate();
    _initReviewPrompt();
    _initPriceAlerts();
  }

  /// Boots the local-notifications plugin: timezone DB (bill reminders depend
  /// on it), tap routing and the POST_NOTIFICATIONS / iOS permission request.
  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    await LocalNotificationService.instance.init(
      onSuggestionTap: (s) {
        if (mounted) ref.read(pendingSuggestionProvider.notifier).state = s;
      },
      onPriceAlertTap: () {
        if (mounted) {
          ref.read(pendingPriceAlertTapProvider.notifier).state = true;
        }
      },
    );
  }

  /// Registers for FCM pushes (scheduled price-alert checks) and runs the
  /// on-open alert check once the startup prompts have settled.
  Future<void> _initPriceAlerts() async {
    if (kIsWeb) return;
    await Future<void>.delayed(const Duration(seconds: 6));
    if (!mounted) return;
    final uid = ref.read(authStateProvider).value?.id ?? '';
    if (uid.isEmpty) return;
    await PushNotificationService.instance.init(
      uid: uid,
      onAlertTap: () {
        if (mounted) {
          ref.read(pendingPriceAlertTapProvider.notifier).state = true;
        }
      },
    );
    await ref.read(priceAlertCheckerProvider).checkNow(force: true);
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _notifSub = null;
    _shareSub?.cancel();
    _shareSub = null;
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      final enabled = ref.read(notificationDetectionEnabledProvider);
      if (enabled && _notifSub == null) {
        debugPrint('[Notif] Resuming — restarting stream');
        _startListening();
      }
      // Check if the user tapped a native notification while app was in background
      _checkIntentSuggestion();
      _checkOpenAddDialogIntent();
      // Offer to launch a transaction copied to the clipboard (opt-in).
      _checkClipboardSuggestion();
      // Kick the outbox sync in case items piled up while the app was killed.
      ref.read(backlogSyncWorkerProvider).tickNow();
      // Re-evaluate price alerts (throttled internally to every 10 min).
      ref.read(priceAlertCheckerProvider).checkNow();
    }
  }

  /// When clipboard capture is enabled, parses the clipboard text and, if it
  /// looks like a transaction, shows a non-blocking prompt to launch it
  /// pre-filled. Works on iOS and Android with no special permission.
  Future<void> _checkClipboardSuggestion() async {
    if (kIsWeb) return;
    if (!ref.read(clipboardCaptureEnabledProvider)) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || text == _lastClipboardText) return;

      final suggestion =
          TransactionTextParser.parse(text, sourceApp: 'clipboard');
      if (suggestion == null) return;

      // Mark handled even after parsing so an unrelated copy isn't re-checked.
      _lastClipboardText = text;
      if (!mounted) return;

      final amountStr =
          suggestion.amount.toStringAsFixed(2).replaceAll('.', ',');
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('💰 Detectamos R\$ $amountStr no texto copiado'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Lançar',
            onPressed: () =>
                ref.read(pendingSuggestionProvider.notifier).state = suggestion,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Clipboard] check error: $e');
    }
  }

  // ── Shared text (iOS Share Extension / Android share sheet) ────────────────

  /// Listens for text/links shared into the app and, when one parses into a
  /// transaction, opens the AddTransactionDialog pre-filled. Handles both the
  /// app-already-running case (stream) and the launched-from-share case.
  void _initShareIntent() {
    if (kIsWeb) return;
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(
          _handleSharedFiles,
          onError: (Object e) => debugPrint('[Share] stream error: $e'),
        );
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _handleSharedFiles(files);
      // Tell the plugin we consumed the initial share so it isn't redelivered.
      ReceiveSharingIntent.instance.reset();
    });
  }

  // ── Home-screen quick action ───────────────────────────────────────────────

  /// Registers a long-press app-icon shortcut ("Novo lançamento") that opens
  /// the AddTransactionDialog. Works on iOS and Android, configured from Dart.
  void _initQuickActions() {
    if (kIsWeb) return;
    const quickActions = QuickActions();
    quickActions.initialize((shortcutType) {
      if (shortcutType != 'new_transaction') return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAnimatedDialog<void>(
          context: context,
          builder: (_) => const AddTransactionDialog(),
        );
      });
    });
    quickActions.setShortcutItems(const [
      ShortcutItem(type: 'new_transaction', localizedTitle: 'Novo lançamento'),
    ]);
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (!mounted || files.isEmpty) return;
    // For text/url shares the shared string is carried in `path`.
    final shared = files.firstWhere(
      (f) => f.type == SharedMediaType.text || f.type == SharedMediaType.url,
      orElse: () => files.first,
    );
    final text = shared.path.trim();
    if (text.isEmpty) return;

    final suggestion = TransactionTextParser.parse(text, sourceApp: 'share');
    if (suggestion != null) {
      // Opens the pre-filled dialog via the existing pendingSuggestion listener.
      ref.read(pendingSuggestionProvider.notifier).state = suggestion;
    } else {
      // The user shared into Fintab on purpose — open an empty entry dialog so
      // they can fill it in, rather than silently dropping the share.
      showAnimatedDialog<void>(
        context: context,
        builder: (_) => const AddTransactionDialog(),
      );
    }
  }

  Future<void> _initInAppUpdate() async {
    await InAppUpdateService.instance.checkAndPrompt();
  }

  /// Store-review nudge: on every open (until the user rates), suggest rating
  /// the app — waiting out the app lock and the other startup prompts.
  Future<void> _initReviewPrompt() async {
    if (!await ReviewPromptService.instance.registerOpenAndShouldPrompt()) {
      return;
    }
    // Let the startup prompts land first (notification permission fires at
    // ~2s; share/quick-action/widget intents open the transaction dialog).
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    // Never cover the PIN/biometric lock screen — MainScreen stays mounted
    // beneath it, so wait for the unlock instead of skipping the open.
    if (ref.read(appLockProvider).locked) {
      final unlocked = Completer<void>();
      final sub = ref.listenManual(
        appLockProvider.select((s) => s.locked),
        (_, locked) {
          if (!locked && !unlocked.isCompleted) unlocked.complete();
        },
      );
      await unlocked.future;
      sub.close();
      if (!mounted) return;
    }

    // First-run onboarding still pending — don't stack on top of it.
    if (ref.read(appSettingsProvider).literacyLevel ==
        FinancialLiteracyLevel.unset) {
      return;
    }
    // A captured transaction is about to open its own dialog.
    if (ref.read(pendingSuggestionProvider) != null) return;
    // A forced update takes priority over everything.
    if (ref.read(appUpdateProvider).value?.forceUpdate == true) return;
    // Some other dialog/sheet already sits on top of the home.
    if (ModalRoute.of(context)?.isCurrent != true) return;

    AnalyticsService.instance.logEvent('review_prompt_shown');
    await showReviewPromptDialog(context);
  }

  // ── Notification pipeline ──────────────────────────────────────────────────

  bool _notifInitDone = false;

  Future<void> _initNotificationFeature() async {
    if (kIsWeb) return;

    // 1. Wait for preferences to load from disk
    try {
      await ref.read(notificationDetectionEnabledProvider.notifier).loaded;
      await ref.read(allowedAppPackagesProvider.notifier).loaded;
    } catch (e) {
      debugPrint('[Notif] Failed to load prefs: $e');
    }
    if (!mounted) return;

    _notifInitDone = true;

    // Boot the outbox sync worker — uploads any locally-queued backlog items
    // that didn't reach Firestore in a previous session.
    ref.read(backlogSyncWorkerProvider);

    // 2. Start listening if detection is already enabled
    _syncNotificationListening();

    // 3. Check if the app was opened via a native notification tap
    await _checkIntentSuggestion();
    await _checkOpenAddDialogIntent();

    // 4. Show permission dialog if needed (non-blocking for the pipeline)
    if (ref.read(notificationDetectionEnabledProvider)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) {
        await showNotificationPermissionDialogIfNeeded(context);
      }
    }
  }

  /// Checks if the app was opened/resumed via a native notification tap
  /// and opens the AddTransactionDialog with pre-filled data.
  Future<void> _checkIntentSuggestion() async {
    try {
      final suggestion =
          await NotificationListenerBridge.consumeIntentSuggestion();
      if (suggestion != null && mounted) {
        debugPrint('[Notif] Opening dialog from intent suggestion');
        ref.read(pendingSuggestionProvider.notifier).state = suggestion;
      }
    } catch (e) {
      debugPrint('[Notif] checkIntentSuggestion error: $e');
    }
  }

  /// Checks whether the app was opened via the home-screen "+" widget
  /// and, if so, opens the AddTransactionDialog.
  Future<void> _checkOpenAddDialogIntent() async {
    if (kIsWeb) return;
    try {
      final shouldOpen = await HomeWidgetService.consumeOpenAddDialogIntent();
      if (shouldOpen && mounted) {
        await showAnimatedDialog<void>(
          context: context,
          builder: (_) => const AddTransactionDialog(),
        );
      }
    } catch (e) {
      debugPrint('[Widget] checkOpenAddDialogIntent error: $e');
    }
  }

  /// Starts or stops the notification stream based on the current toggle.
  /// Only subscribes to EventChannel when userId is available, so that
  /// buffered events flushed by the native side are properly saved to
  /// backlog and auto-saved as pending transactions.
  void _syncNotificationListening() {
    if (kIsWeb || !_notifInitDone) return;
    final enabled = ref.read(notificationDetectionEnabledProvider);
    final userId = ref.read(effectiveUserIdProvider);
    debugPrint('[Notif] syncListening: enabled=$enabled, '
        'userId=${userId.isNotEmpty}, sub=${_notifSub != null}');
    if (enabled && _notifSub == null && userId.isNotEmpty) {
      _startListening();
    } else if (!enabled && _notifSub != null) {
      _notifSub?.cancel();
      _notifSub = null;
      debugPrint('[Notif] Stopped listening (detection disabled)');
    }
  }

  void _startListening() {
    _notifSub?.cancel();
    _notifSub = null;

    debugPrint('[Notif] Starting stream subscription...');

    _notifSub = NotificationListenerBridge.suggestionStream.listen(
      (suggestion) {
        if (!mounted) return;
        if (!ref.read(notificationDetectionEnabledProvider)) return;
        _handleSuggestion(suggestion);
      },
      onError: (error) {
        debugPrint('[Notif] Stream error: $error — will retry in 3s');
        _notifSub?.cancel();
        _notifSub = null;
        NotificationListenerBridge.resetStream();
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted &&
                _notifSub == null &&
                ref.read(notificationDetectionEnabledProvider)) {
              debugPrint('[Notif] Retrying stream subscription...');
              _startListening();
            }
          });
        }
      },
      onDone: () {
        debugPrint('[Notif] Stream completed — will retry in 3s');
        _notifSub = null;
        NotificationListenerBridge.resetStream();
        if (mounted) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted &&
                _notifSub == null &&
                ref.read(notificationDetectionEnabledProvider)) {
              debugPrint('[Notif] Retrying stream subscription...');
              _startListening();
            }
          });
        }
      },
    );

    debugPrint('[Notif] Listening started');
  }

  Future<void> _handleSuggestion(NotificationSuggestion suggestion) async {
    debugPrint('[Notif] Received: amount=${suggestion.amount}, '
        'type=${suggestion.type?.name}, source=${suggestion.sourceApp}');

    // Check app filter — skip if this app is not in the allowed list
    final allowed = ref.read(allowedAppPackagesProvider);
    if (!allowed.contains(suggestion.sourceApp)) {
      debugPrint('[Notif] Not in allowed list: ${suggestion.sourceApp}');
      return;
    }

    final userId = ref.read(effectiveUserIdProvider);
    if (userId.isEmpty) {
      debugPrint('[Notif] Skipping — userId not available yet');
      return;
    }

    // 1. Persist to local outbox (always succeeds — uploaded to Firestore by the
    //    sync worker). Returns a localId so we can update the same item later.
    final backlogId = await ref
        .read(backlogNotifierProvider.notifier)
        .addFromSuggestion(suggestion);

    // 2. If auto-save is enabled, create the transaction and link it to the
    //    backlog item. If transaction creation fails, the backlog item stays
    //    in `pending` status so the user can import it manually later.
    if (backlogId != null && ref.read(notificationAutoSaveProvider)) {
      final txId = await _autoSaveTransaction(suggestion);
      if (txId != null) {
        await ref
            .read(backlogNotifierProvider.notifier)
            .markAutoImported(backlogId, transactionId: txId);
      }
    }
  }

  Future<String?> _autoSaveTransaction(
      NotificationSuggestion suggestion) async {
    try {
      final type = suggestion.type ?? TransactionType.expense;
      // Auto-categorization rules: if the notification text matches a
      // user-defined rule, pre-fill its category instead of "A categorizar".
      // The item stays pending so the user can still review it.
      final matchedCategory = matchCategory(
        text: suggestion.rawText,
        rules: ref.read(categoryRulesProvider),
        type: suggestion.type,
      );
      final id =
          await ref.read(transactionsNotifierProvider.notifier).addAndReturnId(
                title: suggestion.rawText.length > 60
                    ? suggestion.rawText.substring(0, 60)
                    : suggestion.rawText,
                amount: suggestion.amount,
                type: type,
                category: matchedCategory ?? 'A categorizar',
                date: DateTime.now(),
                description: 'Via ${suggestion.sourceApp}',
                isPending: true,
                // Background capture always lands in the DEFAULT Carteira of the
                // account it is homed to (own default; the master's default for a
                // legacy collaborator), regardless of which one is active on screen.
                workspaceIdOverride: ref.read(captureWorkspaceIdProvider),
                userIdOverride: ref.read(effectiveUserIdProvider),
              );
      debugPrint('[Notif] Auto-saved transaction id=$id');
      return id;
    } catch (e) {
      debugPrint('[Notif] Auto-save failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(categoriesSeedProvider);
    ref.watch(walletsSeedProvider);
    // Owner-driven workspace ("Carteira") migration — idempotent no-op once done.
    ref.watch(workspaceMigrationProvider);
    // Keep the auto-categorization rules stream warm so they're available when
    // a bank notification is auto-saved in the background.
    ref.watch(categoryRulesStreamProvider);
    ref.watch(iapInitProvider); // inicializa IAP e restaura compras ao logar
    ref.watch(
        recurringGeneratorProvider); // gera transações de recorrências pendentes

    // React to detection toggle changes (start/stop listener dynamically)
    ref.listen<bool>(notificationDetectionEnabledProvider, (_, next) {
      _syncNotificationListening();
      if (next && !kIsWeb) {
        showNotificationPermissionDialogIfNeeded(context);
      }
    });

    // Start listening once userId becomes available (so buffered events
    // are properly saved to backlog + auto-saved as pending transactions)
    ref.listen<String>(effectiveUserIdProvider, (prev, next) {
      if ((prev == null || prev.isEmpty) && next.isNotEmpty) {
        _syncNotificationListening();
      }
    });

    // Sync home screen widgets whenever financial data changes
    if (!kIsWeb) {
      final balance = ref.watch(balanceProvider);
      final monthIncome = ref.watch(dashboardMonthIncomeProvider);
      final monthExpense = ref.watch(dashboardMonthExpenseProvider);
      final recentTxs = ref.watch(visibleTransactionsProvider);
      final isPro = ref.watch(isProProvider);
      final score = ref.watch(financialScoreProvider).scoreRounded;
      final now = DateTime.now();

      final recent = ([...recentTxs]..sort((a, b) => b.date.compareTo(a.date)))
          .take(5)
          .map((t) => {
                'title': t.title,
                'amount': t.amount,
                'isIncome': t.isIncome,
                'date': t.date.toIso8601String(),
              })
          .toList();

      HomeWidgetService.updateAll(
        balance: balance,
        monthIncome: monthIncome,
        monthExpense: monthExpense,
        monthLabel: '${now.month}/${now.year}',
        recentTransactions: recent,
        healthScore: score,
        isPro: isPro,
      );
    }
    final l10n = AppLocalizations.of(context);

    // Opção 2 — Firestore update check: força atualização via Play Store se necessário
    ref.listen<AsyncValue<AppUpdateInfo>>(appUpdateProvider, (_, next) {
      next.whenData((info) {
        if (info.forceUpdate) {
          InAppUpdateService.instance.checkAndPrompt(forceImmediate: true);
        }
      });
    });

    // Listen for external navigation (e.g. from dashboard cards)
    ref.listen<int>(mainTabIndexProvider, (_, next) {
      if (next != _currentIndex) _changeTab(next);
    });

    // Open the price-alerts screen when an alert notification is tapped
    ref.listen<bool>(pendingPriceAlertTapProvider, (_, fired) {
      if (!fired) return;
      ref.read(pendingPriceAlertTapProvider.notifier).state = false;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PriceAlertsScreen()));
    });

    // Open AddTransactionDialog when a notification suggestion is tapped
    ref.listen<NotificationSuggestion?>(pendingSuggestionProvider,
        (_, suggestion) {
      if (suggestion == null) return;
      ref.read(pendingSuggestionProvider.notifier).state = null;
      showAnimatedDialog<void>(
        context: context,
        builder: (_) => AddTransactionDialog(
          initialAmount: suggestion.amount,
          initialType: suggestion.type,
        ),
      );
    });

    // Show the post-save budget nudge (an expense fell outside the plan).
    ref.listen<BudgetNudgePayload?>(pendingBudgetNudgeProvider, (_, payload) {
      if (payload == null) return;
      ref.read(pendingBudgetNudgeProvider.notifier).state = null;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => BudgetNudgeSheet(payload: payload),
      );
    });

    // Reset transient statement filters when the active Carteira changes —
    // they can hold wallet/category/tag ids that don't exist in the new one.
    ref.listen<String?>(activeWorkspaceIdProvider, (prev, next) {
      if (prev == next) return;
      ref.invalidate(statementWalletFilterProvider);
      ref.invalidate(statementCategoryFilterProvider);
      ref.invalidate(statementTagFilterProvider);
    });

    if (kIsWeb) {
      return Scaffold(
        body: Column(
          children: [
            const UpdateBanner(),
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _changeTab,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FloatingActionButton(
                        onPressed: () => showAnimatedDialog(
                          context: context,
                          builder: (_) => const AddTransactionDialog(),
                        ),
                        backgroundColor: _kGreen,
                        tooltip: l10n.newTransaction,
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home_rounded),
                        label: Text(l10n.navHome),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.receipt_long_outlined),
                        selectedIcon: const Icon(Icons.receipt_long_rounded),
                        label: Text(l10n.navStatement),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.pie_chart_outline),
                        selectedIcon: const Icon(Icons.pie_chart_rounded),
                        label: Text(l10n.navPlanning),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.bar_chart_outlined),
                        selectedIcon: const Icon(Icons.bar_chart_rounded),
                        label: Text(l10n.navReports),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings_rounded),
                        label: Text(l10n.settings),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  // Web uses a side rail (no horizontal-slide requirement) — a
                  // plain IndexedStack keeps every tab (incl. Settings) mounted
                  // and avoids the PageView sweep that hung the web build.
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _webScreens,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile layout ────────────────────────────────────────────────────────
    return Scaffold(
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: _onPageSettled,
              children: [
                for (final s in _mobileScreens) _KeepAlivePage(child: s),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _MobileNav(
        currentIndex: _currentIndex,
        onTap: _changeTab,
        onAdd: (origin) => showAnimatedDialog(
          context: context,
          sourceRect: origin,
          builder: (_) => const AddTransactionDialog(),
        ),
        l10n: l10n,
      ),
    );
  }
}

// ── Mobile bottom navigation bar ─────────────────────────────────────────────

class _MobileNav extends StatelessWidget {
  final int currentIndex;
  final Future<void> Function(int) onTap;

  /// Receives the on-screen rect of the "+" button so the dialog can grow out
  /// of it.
  final void Function(Rect? origin) onAdd;
  final AppLocalizations l10n;

  const _MobileNav({
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: l10n.navHome,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: l10n.navStatement,
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _AddNavButton(onTap: onAdd),
              _NavItem(
                icon: Icons.pie_chart_outline,
                activeIcon: Icons.pie_chart_rounded,
                label: l10n.navPlanning,
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: l10n.navReports,
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddNavButton extends StatefulWidget {
  final void Function(Rect? origin) onTap;

  const _AddNavButton({required this.onTap});

  @override
  State<_AddNavButton> createState() => _AddNavButtonState();
}

class _AddNavButtonState extends State<_AddNavButton> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: () {
            final box = _key.currentContext?.findRenderObject() as RenderBox?;
            final origin = (box != null && box.hasSize)
                ? box.localToGlobal(Offset.zero) & box.size
                : null;
            widget.onTap(origin);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            key: _key,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kGreen.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final Future<void> Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final cs = Theme.of(context).colorScheme;
    final color = isActive ? cs.primary : cs.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? cs.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab's state alive inside the [PageView] (scroll offsets, inner
/// TabControllers) — mirrors the old IndexedStack's always-mounted behavior so
/// switching tabs never rebuilds them from scratch.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
