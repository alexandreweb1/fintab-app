import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/services/bank_filter_provider.dart';
import '../../../../core/utils/animated_dialog.dart';
import '../../../notification_backlog/presentation/providers/backlog_provider.dart';
import '../../../../core/services/app_update_service.dart';
import '../../../../core/services/in_app_update_service.dart';
import '../../../../core/services/notification_listener_service.dart';
import '../../../../core/services/notification_permission_dialog.dart';
import '../../../../core/services/home_widget_service.dart';
import '../providers/dashboard_provider.dart';
import '../../../../core/services/notification_providers.dart';
import '../../../../core/services/notification_suggestion.dart';
import '../../../budget/presentation/screens/planning_screen.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../transactions/presentation/screens/transactions_screen.dart';
import '../../../transactions/presentation/widgets/add_transaction_dialog.dart';
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
  double _tabOpacity = 1.0;
  bool _tabAnimating = false;
  StreamSubscription<NotificationSuggestion>? _notifSub;

  Future<void> _changeTab(int newIndex) async {
    if (newIndex == _currentIndex || _tabAnimating) return;
    _tabAnimating = true;
    setState(() => _tabOpacity = 0.0);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) { _tabAnimating = false; return; }
    setState(() {
      _currentIndex = newIndex;
      _tabOpacity = 1.0;
    });
    ref.read(mainTabIndexProvider.notifier).state = newIndex;
    _tabAnimating = false;
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
    _initNotificationFeature();
    _initInAppUpdate();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _notifSub = null;
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
    }
  }

  Future<void> _initInAppUpdate() async {
    await InAppUpdateService.instance.checkAndPrompt();
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

    // 2. Start listening if detection is already enabled
    _syncNotificationListening();

    // 3. Check if the app was opened via a native notification tap
    await _checkIntentSuggestion();

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
            if (mounted && _notifSub == null &&
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
            if (mounted && _notifSub == null &&
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

  void _handleSuggestion(NotificationSuggestion suggestion) {
    debugPrint('[Notif] Received: amount=${suggestion.amount}, '
        'type=${suggestion.type?.name}, source=${suggestion.sourceApp}');

    // Check app filter — skip if this app is not in the allowed list
    final allowed = ref.read(allowedAppPackagesProvider);
    if (!allowed.contains(suggestion.sourceApp)) {
      debugPrint('[Notif] Not in allowed list: ${suggestion.sourceApp}');
      return;
    }

    // Backlog: persist EVERY detected notification (fire-and-forget)
    final userId = ref.read(effectiveUserIdProvider);
    if (userId.isNotEmpty) {
      ref.read(backlogNotifierProvider.notifier).addFromSuggestion(suggestion);
    } else {
      debugPrint('[Notif] Skipping backlog — userId not available yet');
    }

    // Native Android notification is already shown by NotificationMonitorService
    // (works even when app is closed). No need for flutter_local_notifications here.

    // Auto-save as pending transaction if enabled (needs userId)
    if (ref.read(notificationAutoSaveProvider) && userId.isNotEmpty) {
      _autoSaveTransaction(suggestion);
    }
  }

  Future<void> _autoSaveTransaction(NotificationSuggestion suggestion) async {
    try {
      final type = suggestion.type ?? TransactionType.expense;
      await ref.read(transactionsNotifierProvider.notifier).add(
        title: suggestion.rawText.length > 60
            ? suggestion.rawText.substring(0, 60)
            : suggestion.rawText,
        amount: suggestion.amount,
        type: type,
        category: 'A categorizar',
        date: DateTime.now(),
        description: 'Via ${suggestion.sourceApp}',
        isPending: true,
      );
      debugPrint('[Notif] Auto-saved transaction: ${suggestion.amount}');
    } catch (e) {
      debugPrint('[Notif] Auto-save failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(categoriesSeedProvider);
    ref.watch(walletsSeedProvider);
    ref.watch(iapInitProvider); // inicializa IAP e restaura compras ao logar
    ref.watch(recurringGeneratorProvider); // gera transações de recorrências pendentes

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
      final recurrences = ref.watch(activeRecurrencesProvider);
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

      final upcoming = <Map<String, dynamic>>[];
      for (final r in recurrences) {
        final next = r.nextOccurrence(
            afterDate: now.subtract(const Duration(days: 1)));
        if (next != null) {
          upcoming.add({
            'title': r.title,
            'amount': r.amount,
            'isIncome': r.isIncome,
            'date': next.toIso8601String(),
          });
        }
      }
      upcoming.sort((a, b) =>
          (a['date'] as String).compareTo(b['date'] as String));

      HomeWidgetService.updateAll(
        balance: balance,
        monthIncome: monthIncome,
        monthExpense: monthExpense,
        monthLabel: '${now.month}/${now.year}',
        recentTransactions: recent,
        upcomingRecurring: upcoming.take(5).toList(),
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
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _tabOpacity,
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOut,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _webScreens,
                      ),
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
            child: AnimatedOpacity(
              opacity: _tabOpacity,
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              child: IndexedStack(
                index: _currentIndex,
                children: _mobileScreens,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => const AddTransactionDialog(),
        ),
        backgroundColor: _kGreen,
        tooltip: l10n.newTransaction,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 85,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Theme.of(context).colorScheme.surface,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: l10n.navHome,
              index: 0,
              currentIndex: _currentIndex,
              onTap: _changeTab,
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: l10n.navStatement,
              index: 1,
              currentIndex: _currentIndex,
              onTap: _changeTab,
            ),
            const SizedBox(width: 56),
            _NavItem(
              icon: Icons.pie_chart_outline,
              activeIcon: Icons.pie_chart_rounded,
              label: l10n.navPlanning,
              index: 2,
              currentIndex: _currentIndex,
              onTap: _changeTab,
            ),
            _NavItem(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: l10n.navReports,
              index: 3,
              currentIndex: _currentIndex,
              onTap: _changeTab,
            ),
          ],
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = isActive ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final screenW = MediaQuery.of(context).size.width;
    final compact = screenW < 360;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: color,
                size: compact ? 20 : 24,
              ),
            ),
            const SizedBox(height: 2),
            if (!compact)
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isActive ? 16 : 0,
              decoration: BoxDecoration(
                color: _kGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
