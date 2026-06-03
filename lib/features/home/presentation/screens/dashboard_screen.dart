import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/dashboard_config_provider.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../budget/domain/entities/budget_entity.dart';
import '../../../sharing/domain/entities/invitation_entity.dart';
import '../../../sharing/presentation/providers/sharing_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_extra_cards.dart';
import '../../../../core/providers/navigation_provider.dart';

// ─── Color palette ────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF1A2B4A);
const _kGreen = Color(0xFF00D887);
const _kLightBg = Color(0xFFF4F6FA);

// ─── Number of months shown in the chart ─────────────────────────────────────
const _kChartMonths = 24;
const _kMonthColWidth = 56.0;

// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final balance = ref.watch(balanceProvider);
    final income = ref.watch(dashboardMonthIncomeProvider);
    final expense = ref.watch(dashboardMonthExpenseProvider);
    final visibleTxs = ref.watch(visibleTransactionsProvider);
    final budgetSummaries = ref.watch(dashboardBudgetSummaryProvider);
    final selectedMonth = ref.watch(dashboardSelectedMonthProvider);
    final config = ref.watch(dashboardConfigProvider);

    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    final name = user?.displayName?.split(' ').first ?? l10n.hello;
    final greeting = _greeting(l10n);
    final initials = _initials(user?.displayName);

    final monthLabel =
        DateFormat('MMM yyyy', dateLoc).format(selectedMonth).capitalizeMonth();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : _kLightBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _DarkHeader(
            name: name,
            greeting: greeting,
            balance: balance,
            transactions: visibleTxs,
            userInitials: initials,
            userPhotoUrl: user?.photoUrl,
            onSettingsTap: () {
              if (kIsWeb) {
                ref.read(mainTabIndexProvider.notifier).state = 4;
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                );
              }
            },
            onCustomizeTap: () => _showCustomizeSheet(context),
          ),

          const SizedBox(height: 20),

          // ── Seções dinâmicas ordenadas pelo usuário ──
          for (final section in config.visibleSections) ...[
            if (section == DashboardSection.incomeExpense) ...[
              _IncomeExpenseRow(income: income, expense: expense),
              const SizedBox(height: 24),
            ],
            if (section == DashboardSection.financialHealth) ...[
              const DashboardFinancialHealthCard(),
              const SizedBox(height: 24),
            ],
            if (section == DashboardSection.budgets &&
                budgetSummaries.isNotEmpty) ...[
              _SectionHeader(title: l10n.budgets, subtitle: monthLabel),
              const SizedBox(height: 8),
              _DashboardBudgetSummary(summaries: budgetSummaries),
              const SizedBox(height: 24),
            ],
            if (section == DashboardSection.wallets) ...[
              const _SectionHeader(title: 'Saldo por carteira', subtitle: ''),
              const SizedBox(height: 8),
              const _WalletBalancesSection(),
              const SizedBox(height: 24),
            ],
            if (section == DashboardSection.recentTransactions) ...[
              const _SectionHeader(
                  title: 'Últimas Transações', subtitle: ''),
              const SizedBox(height: 8),
              const DashboardRecentTransactions(),
              const SizedBox(height: 24),
            ],
            if (section == DashboardSection.upcomingRecurring) ...[
              const _SectionHeader(
                  title: 'Próximas Recorrências', subtitle: ''),
              const SizedBox(height: 8),
              const DashboardUpcomingRecurring(),
              const SizedBox(height: 24),
            ],
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showCustomizeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomizeDashboardSheet(),
    );
  }

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 18) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  static String _initials(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return '?';
    final parts = displayName.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

// ─── Dark Header ──────────────────────────────────────────────────────────────
class _DarkHeader extends ConsumerWidget {
  final String name;
  final String greeting;
  final double balance;
  final List<TransactionEntity> transactions;
  final String userInitials;
  final String? userPhotoUrl;
  final VoidCallback onSettingsTap;
  final VoidCallback onCustomizeTap;

  const _DarkHeader({
    required this.name,
    required this.greeting,
    required this.balance,
    required this.transactions,
    required this.userInitials,
    this.userPhotoUrl,
    required this.onSettingsTap,
    required this.onCustomizeTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFormatterProvider);
    final l10n = AppLocalizations.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.of(context).size.width;
    final compact = screenW < 340;
    final pendingInvites = ref.watch(pendingInvitationsProvider).value ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: topPad + 8),

          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$greeting, $name!',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onCustomizeTap,
                  child: Tooltip(
                    message: 'Personalizar dashboard',
                    child: Icon(
                      Icons.tune_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (pendingInvites.isNotEmpty) ...[
                  _NotificationBell(count: pendingInvites.length),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: onSettingsTap,
                  child: UserAvatar(
                    photoUrl: userPhotoUrl,
                    initials: userInitials,
                    radius: 18,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 18 : 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: compact ? 10 : 16),

          // Balance
          Text(
            l10n.totalBalance,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                fmt(balance),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 28 : 38,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          SizedBox(height: compact ? 12 : 20),

          // Chart — hidden on very narrow screens
          if (screenW >= 300) _SparklineChart(transactions: transactions),

          SizedBox(height: compact ? 12 : 20),
        ],
      ),
    );
  }
}

// ─── Sparkline Chart (scrollable, 12 months, selectable) ─────────────────────
class _SparklineChart extends ConsumerStatefulWidget {
  final List<TransactionEntity> transactions;

  const _SparklineChart({required this.transactions});

  @override
  ConsumerState<_SparklineChart> createState() => _SparklineChartState();
}

class _SparklineChartState extends ConsumerState<_SparklineChart> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll to the rightmost (most-recent) month after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Returns the list of months shown in the chart (oldest → newest).
  List<DateTime> _months() {
    final now = DateTime.now();
    return List.generate(_kChartMonths, (i) {
      return DateTime(now.year, now.month - (_kChartMonths - 1 - i));
    });
  }

  List<double> _monthlyIncome(List<DateTime> months) {
    return months.map((month) {
      double total = 0;
      for (final t in widget.transactions) {
        if (t.date.year == month.year &&
            t.date.month == month.month &&
            t.isIncome) {
          total += t.amount;
        }
      }
      return total;
    }).toList();
  }

  List<double> _monthlyExpenses(List<DateTime> months) {
    return months.map((month) {
      double total = 0;
      for (final t in widget.transactions) {
        if (t.date.year == month.year &&
            t.date.month == month.month &&
            !t.isIncome) {
          total += t.amount;
        }
      }
      return total;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dateLoc = ref.watch(dateLocaleProvider);
    final selectedMonth = ref.watch(dashboardSelectedMonthProvider);
    final months = _months();
    final rawIncome = _monthlyIncome(months);
    final rawExpenses = _monthlyExpenses(months);
    final allZero =
        rawIncome.every((v) => v == 0) && rawExpenses.every((v) => v == 0);
    final incomeData = allZero
        ? [40.0, 80.0, 60.0, 120.0, 100.0, 200.0, 180.0, 250.0, 220.0,
           300.0, 350.0, 400.0]
        : rawIncome;
    final expenseData = allZero
        ? [20.0, 40.0, 90.0, 50.0, 140.0, 80.0, 220.0, 100.0, 180.0,
           150.0, 200.0, 250.0]
        : rawExpenses;

    // Index of the selected month within our months list (-1 if not found).
    final selectedIdx = months.indexWhere((m) =>
        m.year == selectedMonth.year && m.month == selectedMonth.month);

    const totalWidth = _kChartMonths * _kMonthColWidth;

    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.08, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: SizedBox(
              height: 80 + 6 + 44, // chart + gap + labels
              child: Stack(
                children: [
                  // Chart area (not interactive, sits behind)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        incomeData: incomeData,
                        expenseData: expenseData,
                        selectedIndex: selectedIdx,
                      ),
                      size: const Size(totalWidth, 80),
                    ),
                  ),
                  // Full-height touch columns (chart + labels)
                  Row(
                    children: List.generate(months.length, (i) {
                      final month = months[i];
                      final isSelected = i == selectedIdx;
                      final label = DateFormat('MMM', dateLoc).format(month).capitalizeMonth();
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          ref
                              .read(dashboardSelectedMonthProvider.notifier)
                              .state = month;
                        },
                        child: SizedBox(
                          width: _kMonthColWidth,
                          height: 80 + 6 + 44, // full height
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.45),
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _kGreen
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> incomeData;
  final List<double> expenseData;
  final int selectedIndex;

  static const _kRed = Color(0xFFE05252);

  const _SparklinePainter({
    required this.incomeData,
    required this.expenseData,
    required this.selectedIndex,
  });

  List<Offset> _toPoints(List<double> data, double minV, double maxV, Size size) {
    final range = (maxV - minV).abs();
    final effectiveRange = range < 1 ? 1.0 : range;
    return List.generate(data.length, (i) {
      final x = i / (data.length - 1) * size.width;
      final norm = range < 1 ? 0.5 : (data[i] - minV) / effectiveRange;
      final y = size.height - (norm * size.height * 0.75) - size.height * 0.1;
      return Offset(x, y);
    });
  }

  void _drawSeries(Canvas canvas, Size size, List<Offset> points, Color color) {
    // Area fill
    final fill = Path()..moveTo(0, size.height);
    fill.lineTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cx = (points[i - 1].dx + points[i].dx) / 2;
      fill.cubicTo(cx, points[i - 1].dy, cx, points[i].dy, points[i].dx, points[i].dy);
    }
    fill.lineTo(size.width, size.height);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final cx = (points[i - 1].dx + points[i].dx) / 2;
      line.cubicTo(cx, points[i - 1].dy, cx, points[i].dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (incomeData.length < 2 || expenseData.length < 2) return;

    // Shared scale across both series so lines are comparable
    final allValues = [...incomeData, ...expenseData];
    final minV = allValues.reduce(math.min);
    final maxV = allValues.reduce(math.max);

    final incomePoints = _toPoints(incomeData, minV, maxV, size);
    final expensePoints = _toPoints(expenseData, minV, maxV, size);

    // Selected month highlight column
    if (selectedIndex >= 0 && selectedIndex < incomeData.length) {
      final colW = size.width / incomeData.length;
      final colX = selectedIndex * colW;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(colX, 0, colW, size.height),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.08),
      );
    }

    // Draw expense (red) first so income (green) renders on top
    _drawSeries(canvas, size, expensePoints, _kRed);
    _drawSeries(canvas, size, incomePoints, _kGreen);

    // Dots on selected month (or last point)
    final dotIdx = selectedIndex >= 0 && selectedIndex < incomePoints.length
        ? selectedIndex
        : incomePoints.length - 1;

    // Expense dot
    canvas.drawCircle(expensePoints[dotIdx], 4, Paint()..color = _kRed);
    canvas.drawCircle(expensePoints[dotIdx], 2.5, Paint()..color = Colors.white);

    // Income dot
    canvas.drawCircle(incomePoints[dotIdx], 5, Paint()..color = _kGreen);
    canvas.drawCircle(incomePoints[dotIdx], 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.incomeData != incomeData ||
      old.expenseData != expenseData ||
      old.selectedIndex != selectedIndex;
}

// ─── Income / Expense Row ─────────────────────────────────────────────────────
class _IncomeExpenseRow extends ConsumerWidget {
  final double income;
  final double expense;

  const _IncomeExpenseRow({required this.income, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(currencyFormatterProvider);
    final typeFilter = ref.watch(statementTypeFilterProvider);

    void onTapType(TransactionType type) {
      // Toggle: tapping the same type clears the filter
      ref.read(statementTypeFilterProvider.notifier).state =
          typeFilter == type ? null : type;
      // Navigate to the statement tab (index 1)
      ref.read(mainTabIndexProvider.notifier).state = 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _MiniStatCard(
              label: l10n.income,
              value: fmt(income),
              icon: Icons.arrow_downward_rounded,
              iconColor: _kGreen,
              valueColor: _kGreen,
              isActive: typeFilter == TransactionType.income,
              onTap: () => onTapType(TransactionType.income),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _MiniStatCard(
              label: l10n.expenses,
              value: fmt(expense),
              icon: Icons.arrow_upward_rounded,
              iconColor: const Color(0xFFE05252),
              valueColor: const Color(0xFFE05252),
              isActive: typeFilter == TransactionType.expense,
              onTap: () => onTapType(TransactionType.expense),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;
  final bool isActive;
  final VoidCallback? onTap;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: isActive ? Border.all(color: iconColor, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isActive ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: valueColor,
                      ),
                    ),
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

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─── Dashboard Budget Summary ─────────────────────────────────────────────────
class _DashboardBudgetSummary extends ConsumerWidget {
  final List<BudgetSummary> summaries;

  const _DashboardBudgetSummary({required this.summaries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFormatterProvider);
    final l10n = AppLocalizations.of(context);

    final totalPlanned =
        summaries.fold(0.0, (sum, s) => sum + s.budget.limitAmount);
    final totalSpent = summaries.fold(0.0, (sum, s) => sum + s.spentAmount);
    final remaining = totalPlanned - totalSpent;
    final isOver = totalSpent > totalPlanned;
    final progress =
        totalPlanned > 0 ? (totalSpent / totalPlanned).clamp(0.0, 1.0) : 0.0;
    final progressColor =
        isOver ? const Color(0xFFE05252) : _kGreen;

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: progressColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BudgetStatColumn(
                  label: l10n.budgetPlanned,
                  value: fmt(totalPlanned),
                ),
              ),
              Expanded(
                child: _BudgetStatColumn(
                  label: l10n.spent,
                  value: fmt(totalSpent),
                  valueColor: progressColor,
                ),
              ),
              Expanded(
                child: _BudgetStatColumn(
                  label: isOver ? l10n.budgetExceeded : l10n.budgetRemaining,
                  value: fmt(remaining.abs()),
                  valueColor: isOver ? const Color(0xFFE05252) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetStatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _BudgetStatColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Wallet Balances Section ──────────────────────────────────────────────────

class _WalletBalancesSection extends ConsumerWidget {
  const _WalletBalancesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsStreamProvider).value ?? [];
    final balances = ref.watch(walletBalancesProvider);
    final fmt = ref.watch(currencyFormatterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Include "Geral" bucket (walletId == '') if it has transactions
    final hasGeral = balances.containsKey('');

    if (wallets.isEmpty && !hasGeral) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Nenhuma carteira encontrada',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
      );
    }

    final items = <Widget>[];

    for (int i = 0; i < wallets.length; i++) {
      final w = wallets[i];
      final balance = balances[w.id] ?? 0;
      if (i > 0) {
        items.add(Divider(
          height: 1,
          indent: 56,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ));
      }
      items.add(_WalletBalanceTile(
        icon: categoryIcon(w.iconCodePoint),
        color: Color(w.colorValue),
        name: w.name,
        balance: balance,
        fmt: fmt,
      ));
    }

    if (hasGeral) {
      if (items.isNotEmpty) {
        items.add(Divider(
          height: 1,
          indent: 56,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ));
      }
      items.add(_WalletBalanceTile(
        icon: Icons.account_balance_wallet_outlined,
        color: Colors.grey,
        name: 'Geral',
        balance: balances[''] ?? 0,
        fmt: fmt,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: items),
      ),
    );
  }
}

class _WalletBalanceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final double balance;
  final String Function(double) fmt;

  const _WalletBalanceTile({
    required this.icon,
    required this.color,
    required this.name,
    required this.balance,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final balanceColor =
        isPositive ? const Color(0xFF10B981) : const Color(0xFFE05252);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmt(balance.abs()),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: balanceColor,
                ),
              ),
              Text(
                isPositive ? 'Positivo' : 'Negativo',
                style: TextStyle(
                  fontSize: 11,
                  color: balanceColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Notification Bell ────────────────────────────────────────────────────────
class _NotificationBell extends StatelessWidget {
  final int count;

  const _NotificationBell({required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _InvitationsSheet(),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.notifications_rounded,
            color: Colors.white,
            size: 26,
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFE05252),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Invitations Bottom Sheet ─────────────────────────────────────────────────
class _InvitationsSheet extends ConsumerWidget {
  const _InvitationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations = ref.watch(pendingInvitationsProvider).value ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(pendingInvitationsProvider, (_, next) {
      if ((next.value ?? []).isEmpty && context.mounted) {
        Navigator.of(context).pop();
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                'Convites pendentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Alguém quer compartilhar as finanças com você.',
            style:
                TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...invitations.map((inv) => _InvitationCard(invitation: inv)),
        ],
      ),
    );
  }
}

// ─── Single Invitation Card ───────────────────────────────────────────────────
class _InvitationCard extends ConsumerStatefulWidget {
  final InvitationEntity invitation;

  const _InvitationCard({required this.invitation});

  @override
  ConsumerState<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<_InvitationCard> {
  bool _loading = false;

  Future<void> _respond(bool accept) async {
    setState(() => _loading = true);
    final notifier = ref.read(sharingNotifierProvider.notifier);
    final error = accept
        ? await notifier.acceptInvitation(widget.invitation)
        : await notifier.declineInvitation(widget.invitation.id);
    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inv = widget.invitation;
    final displayName =
        inv.masterName.isNotEmpty ? inv.masterName : inv.masterEmail;
    final initial = displayName[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade300.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    const Color(0xFF7E57C2).withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF7E57C2),
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (inv.masterName.isNotEmpty)
                      Text(
                        inv.masterEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$displayName quer compartilhar as finanças com você.',
            style:
                TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    onPressed: () => _respond(false),
                    child: Text(AppLocalizations.of(context).decline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _respond(true),
                    child: Text(AppLocalizations.of(context).accept),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Customize Dashboard Bottom Sheet ────────────────────────────────────────

class _CustomizeDashboardSheet extends ConsumerStatefulWidget {
  const _CustomizeDashboardSheet();

  @override
  ConsumerState<_CustomizeDashboardSheet> createState() =>
      _CustomizeDashboardSheetState();
}

class _CustomizeDashboardSheetState
    extends ConsumerState<_CustomizeDashboardSheet> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(dashboardConfigProvider);
    final notifier = ref.read(dashboardConfigProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Personalizar Dashboard',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    notifier.reset();
                  },
                  child: const Text('Resetar'),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Arraste para reordenar • Toque no olho para mostrar/ocultar',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),

          // Reorderable list
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) =>
                notifier.reorder(oldIndex, newIndex),
            children: [
              for (final section in config.order)
                _SectionTile(
                  key: ValueKey(section),
                  section: section,
                  isVisible: config.isVisible(section),
                  onToggle: () => notifier.toggle(section),
                ),
            ],
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Pronto'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final DashboardSection section;
  final bool isVisible;
  final VoidCallback onToggle;

  const _SectionTile({
    super.key,
    required this.section,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(
        _sectionIcon(section),
        color: isVisible ? cs.primary : cs.onSurfaceVariant,
        size: 22,
      ),
      title: Text(
        section.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isVisible ? cs.onSurface : cs.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        section.description,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              isVisible
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: isVisible ? cs.primary : cs.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.drag_handle_rounded,
              color: cs.onSurfaceVariant, size: 22),
        ],
      ),
    );
  }

  IconData _sectionIcon(DashboardSection s) {
    switch (s) {
      case DashboardSection.incomeExpense:
        return Icons.swap_vert_rounded;
      case DashboardSection.financialHealth:
        return Icons.monitor_heart_outlined;
      case DashboardSection.budgets:
        return Icons.pie_chart_outline_rounded;
      case DashboardSection.wallets:
        return Icons.account_balance_wallet_outlined;
      case DashboardSection.recentTransactions:
        return Icons.receipt_long_outlined;
      case DashboardSection.upcomingRecurring:
        return Icons.repeat_rounded;
    }
  }
}
