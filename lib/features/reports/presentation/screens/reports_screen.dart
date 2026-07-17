import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../recurring/presentation/providers/recurring_provider.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';

// ─── Colour palette ────────────────────────────────────────────────────────────
const _kChartColors = [
  Color(0xFF6366F1),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
];

const _kIncomeColor = Color(0xFF10B981);
const _kExpenseColor = Color(0xFFEF4444);
const _kLineColor = Color(0xFF00BCD4);

// ─── Screen ────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _mainTab = 0; // 0=pie  1=line  2=bar  3=cashflow
  int _pieSubTab = 0; // 0=expense/cat  1=expense/wallet  2=income/cat
  int _lineSubTab = 1; // 0=semana  1=mês  2=ano
  int _barSubTab = 0; // 0=balanço mensal  1=fluxo anual  2=dia semana

  // Bar "Balanço mensal" window end (shows 3 months ending here)
  late DateTime _barPeriodEnd;
  // Line "week" view window start
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _barPeriodEnd = DateTime(now.year, now.month, 1);
    _weekStart = _computeWeekStart(now);
  }

  static DateTime _computeWeekStart(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final allTxs = ref.watch(visibleTransactionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────
          SliverAppBar(
            title: Text(l10n.navReports),
            pinned: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
          ),

          // ── Top icon tab bar ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _IconTab(
                      icon: Icons.donut_large_rounded,
                      label: 'Categorias',
                      isSelected: _mainTab == 0,
                      onTap: () => setState(() => _mainTab = 0),
                    ),
                    _IconTab(
                      icon: Icons.show_chart_rounded,
                      label: 'Evolução',
                      isSelected: _mainTab == 1,
                      onTap: () => setState(() => _mainTab = 1),
                    ),
                    _IconTab(
                      icon: Icons.bar_chart_rounded,
                      label: 'Comparar',
                      isSelected: _mainTab == 2,
                      onTap: () => setState(() => _mainTab = 2),
                    ),
                    _IconTab(
                      icon: Icons.waterfall_chart_rounded,
                      label: 'Fluxo',
                      isSelected: _mainTab == 3,
                      onTap: () => setState(() => _mainTab = 3),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Tab content ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildTabContent(context, allTxs, fmt, dateLoc, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    ColorScheme cs,
  ) {
    switch (_mainTab) {
      case 0:
        return _buildPieTab(context, allTxs, fmt, dateLoc, cs);
      case 1:
        return _buildLineTab(context, allTxs, fmt, dateLoc, cs);
      case 2:
        return _buildBarTab(context, allTxs, fmt, dateLoc, cs);
      case 3:
        return _buildCashFlowTab(context, allTxs, fmt, dateLoc, cs);
      default:
        return const SizedBox.shrink();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PIE TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPieTab(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    ColorScheme cs,
  ) {
    final selectedMonth = ref.watch(transactionsSelectedMonthProvider);
    final isCurrentMonth = selectedMonth.year == DateTime.now().year &&
        selectedMonth.month == DateTime.now().month;
    final monthTxs = allTxs
        .where((t) =>
            t.date.year == selectedMonth.year &&
            t.date.month == selectedMonth.month)
        .toList();
    final periodLabel =
        DateFormat('MMMM yyyy', dateLoc).format(selectedMonth).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubTabsRow(
          ['Despesas por categoria', 'Despesas por conta', 'Receitas por categoria'],
          _pieSubTab,
          (i) => setState(() => _pieSubTab = i),
        ),
        _buildPeriodNav(
          label: periodLabel,
          onPrev: () => ref
              .read(transactionsSelectedMonthProvider.notifier)
              .state = DateTime(selectedMonth.year, selectedMonth.month - 1, 1),
          onNext: isCurrentMonth
              ? null
              : () => ref
                  .read(transactionsSelectedMonthProvider.notifier)
                  .state =
                  DateTime(selectedMonth.year, selectedMonth.month + 1, 1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          child: _buildPieChartContent(context, monthTxs, fmt),
        ),
      ],
    );
  }

  Widget _buildPieChartContent(
    BuildContext context,
    List<TransactionEntity> monthTxs,
    String Function(double) fmt,
  ) {
    final Map<String, double> byGroup = {};
    final Map<String, int> countByGroup = {};

    if (_pieSubTab == 0) {
      for (final t in monthTxs.where((t) => t.isExpense)) {
        byGroup[t.category] = (byGroup[t.category] ?? 0) + t.amount;
        countByGroup[t.category] = (countByGroup[t.category] ?? 0) + 1;
      }
    } else if (_pieSubTab == 1) {
      final wallets = ref.watch(walletsStreamProvider).value ?? [];
      final walletMap = {for (final w in wallets) w.id: w.name};
      for (final t in monthTxs.where((t) => t.isExpense)) {
        final name =
            t.walletId.isEmpty ? 'Geral' : (walletMap[t.walletId] ?? 'Geral');
        byGroup[name] = (byGroup[name] ?? 0) + t.amount;
        countByGroup[name] = (countByGroup[name] ?? 0) + 1;
      }
    } else {
      for (final t in monthTxs.where((t) => t.isIncome)) {
        byGroup[t.category] = (byGroup[t.category] ?? 0) + t.amount;
        countByGroup[t.category] = (countByGroup[t.category] ?? 0) + 1;
      }
    }

    final entries = byGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    if (total == 0) {
      return _emptyState(context, Icons.pie_chart_outline);
    }

    final slices = entries.asMap().entries
        .map((e) => _PieSlice(
              category: e.value.key,
              amount: e.value.value,
              percentage: e.value.value / total,
              color: _kChartColors[e.key % _kChartColors.length],
              count: countByGroup[e.value.key] ?? 0,
            ))
        .toList();

    return _CategoryChart(slices: slices, fmt: fmt, total: total);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LINE TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLineTab(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    ColorScheme cs,
  ) {
    final selectedMonth = ref.watch(transactionsSelectedMonthProvider);
    final isCurrentMonth = selectedMonth.year == DateTime.now().year &&
        selectedMonth.month == DateTime.now().month;

    final now = DateTime.now();
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final isCurrentWeek = weekEnd.isAfter(now) ||
        (weekEnd.year == now.year &&
            weekEnd.month == now.month &&
            weekEnd.day == now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubTabsRow(
          ['Despesas da semana', 'Despesas do mês', 'Despesas por ano'],
          _lineSubTab,
          (i) => setState(() => _lineSubTab = i),
        ),
        if (_lineSubTab == 0)
          _buildPeriodNav(
            label: _weekRangeLabel(_weekStart, dateLoc),
            onPrev: () => setState(() =>
                _weekStart = _weekStart.subtract(const Duration(days: 7))),
            onNext: isCurrentWeek
                ? null
                : () => setState(() =>
                    _weekStart = _weekStart.add(const Duration(days: 7))),
          )
        else if (_lineSubTab == 1)
          _buildPeriodNav(
            label: DateFormat('MMMM yyyy', dateLoc)
                .format(selectedMonth)
                .toUpperCase(),
            onPrev: () => ref
                .read(transactionsSelectedMonthProvider.notifier)
                .state =
                DateTime(selectedMonth.year, selectedMonth.month - 1, 1),
            onNext: isCurrentMonth
                ? null
                : () => ref
                    .read(transactionsSelectedMonthProvider.notifier)
                    .state =
                    DateTime(selectedMonth.year, selectedMonth.month + 1, 1),
          )
        else
          _buildPeriodNav(
            label: selectedMonth.year.toString(),
            onPrev: () => ref
                .read(transactionsSelectedMonthProvider.notifier)
                .state = DateTime(selectedMonth.year - 1, selectedMonth.month, 1),
            onNext: selectedMonth.year >= DateTime.now().year
                ? null
                : () => ref
                    .read(transactionsSelectedMonthProvider.notifier)
                    .state =
                    DateTime(selectedMonth.year + 1, selectedMonth.month, 1),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          child: _buildLineChartContent(
              context, allTxs, fmt, dateLoc, selectedMonth, cs),
        ),
      ],
    );
  }

  Widget _buildLineChartContent(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    DateTime selectedMonth,
    ColorScheme cs,
  ) {
    late List<_ChartPoint> points;

    if (_lineSubTab == 0) {
      // Week: 7 days
      points = List.generate(7, (i) {
        final day = _weekStart.add(Duration(days: i));
        final sum = allTxs
            .where((t) =>
                t.isExpense &&
                t.date.year == day.year &&
                t.date.month == day.month &&
                t.date.day == day.day)
            .fold<double>(0, (s, t) => s + t.amount);
        final label = DateFormat('E', dateLoc).format(day).toUpperCase();
        return _ChartPoint(label: label, value: sum);
      });
    } else if (_lineSubTab == 1) {
      // Month: day by day
      final daysInMonth =
          DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);
      points = List.generate(daysInMonth, (i) {
        final day = i + 1;
        final sum = allTxs
            .where((t) =>
                t.isExpense &&
                t.date.year == selectedMonth.year &&
                t.date.month == selectedMonth.month &&
                t.date.day == day)
            .fold<double>(0, (s, t) => s + t.amount);
        final showLabel = (i % 5 == 0 || i == daysInMonth - 1);
        final label = showLabel
            ? '${day.toString().padLeft(2, '0')} '
                '${DateFormat('MMM', dateLoc).format(selectedMonth).toUpperCase()}.'
            : '';
        return _ChartPoint(label: label, value: sum);
      });
    } else {
      // Year: 12 months
      points = List.generate(12, (i) {
        final month = i + 1;
        final sum = allTxs
            .where((t) =>
                t.isExpense &&
                t.date.year == selectedMonth.year &&
                t.date.month == month)
            .fold<double>(0, (s, t) => s + t.amount);
        final label = DateFormat('MMM', dateLoc)
            .format(DateTime(selectedMonth.year, month))
            .toUpperCase()
            .substring(0, 3);
        return _ChartPoint(label: label, value: sum);
      });
    }

    final total = points.fold<double>(0, (s, p) => s + p.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: _AreaChart(points: points, color: _kLineColor, fmt: fmt),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Total  ',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            Text(
              fmt(total),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BAR TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBarTab(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    ColorScheme cs,
  ) {
    final selectedMonth = ref.watch(transactionsSelectedMonthProvider);
    final isCurrentMonth = selectedMonth.year == DateTime.now().year &&
        selectedMonth.month == DateTime.now().month;
    final isCurrentYear = selectedMonth.year == DateTime.now().year;

    // Can we advance the bar period further?
    final now = DateTime.now();
    final barCanGoNext = _barPeriodEnd.year < now.year ||
        (_barPeriodEnd.year == now.year && _barPeriodEnd.month < now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubTabsRow(
          ['Balanço mensal', 'Fluxo de caixa anual', 'Despesas x dia semana'],
          _barSubTab,
          (i) => setState(() => _barSubTab = i),
        ),
        if (_barSubTab == 0)
          _buildPeriodNav(
            label: _monthRangeLabel(_barPeriodEnd, dateLoc),
            onPrev: () => setState(() => _barPeriodEnd =
                DateTime(_barPeriodEnd.year, _barPeriodEnd.month - 3, 1)),
            onNext: barCanGoNext
                ? () => setState(() => _barPeriodEnd =
                    DateTime(_barPeriodEnd.year, _barPeriodEnd.month + 3, 1))
                : null,
          )
        else if (_barSubTab == 1)
          _buildPeriodNav(
            label: selectedMonth.year.toString(),
            onPrev: () => ref
                .read(transactionsSelectedMonthProvider.notifier)
                .state =
                DateTime(selectedMonth.year - 1, selectedMonth.month, 1),
            onNext: isCurrentYear
                ? null
                : () => ref
                    .read(transactionsSelectedMonthProvider.notifier)
                    .state =
                    DateTime(selectedMonth.year + 1, selectedMonth.month, 1),
          )
        else
          _buildPeriodNav(
            label: DateFormat('MMMM yyyy', dateLoc)
                .format(selectedMonth)
                .toUpperCase(),
            onPrev: () => ref
                .read(transactionsSelectedMonthProvider.notifier)
                .state =
                DateTime(selectedMonth.year, selectedMonth.month - 1, 1),
            onNext: isCurrentMonth
                ? null
                : () => ref
                    .read(transactionsSelectedMonthProvider.notifier)
                    .state =
                    DateTime(selectedMonth.year, selectedMonth.month + 1, 1),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          child: _buildBarChartContent(
              context, allTxs, fmt, dateLoc, selectedMonth, cs),
        ),
      ],
    );
  }

  Widget _buildBarChartContent(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    DateTime selectedMonth,
    ColorScheme cs,
  ) {
    if (_barSubTab == 0) {
      // Monthly balance: 3 months
      final months = List.generate(
          3, (i) => DateTime(_barPeriodEnd.year, _barPeriodEnd.month - 2 + i, 1));
      final groups = months.map((m) {
        final label =
            DateFormat('MMM. yyyy', dateLoc).format(m).toUpperCase();
        final income = allTxs
            .where((t) =>
                t.isIncome &&
                t.date.year == m.year &&
                t.date.month == m.month)
            .fold<double>(0, (s, t) => s + t.amount);
        final expense = allTxs
            .where((t) =>
                t.isExpense &&
                t.date.year == m.year &&
                t.date.month == m.month)
            .fold<double>(0, (s, t) => s + t.amount);
        return _BarGroup(label: label, values: [income, expense]);
      }).toList();

      return _BarChartWidget(
        groups: groups,
        colors: const [_kIncomeColor, _kExpenseColor],
        legendLabels: const ['Receitas', 'Despesas'],
        fmt: fmt,
      );
    } else if (_barSubTab == 1) {
      // Annual cashflow: aggregated totals for the year
      final yearIncome = allTxs
          .where((t) => t.isIncome && t.date.year == selectedMonth.year)
          .fold<double>(0, (s, t) => s + t.amount);
      final yearExpense = allTxs
          .where((t) => t.isExpense && t.date.year == selectedMonth.year)
          .fold<double>(0, (s, t) => s + t.amount);

      if (yearIncome == 0 && yearExpense == 0) {
        return _emptyState(context, Icons.bar_chart_rounded);
      }

      return _AnnualSummaryView(
        year: selectedMonth.year,
        income: yearIncome,
        expense: yearExpense,
        fmt: fmt,
      );
    } else {
      // Weekday expenses
      const weekdayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      final monthExpenses = allTxs
          .where((t) =>
              t.isExpense &&
              t.date.year == selectedMonth.year &&
              t.date.month == selectedMonth.month)
          .toList();
      final groups = List.generate(7, (i) {
        final weekday = i + 1; // 1=Mon … 7=Sun
        final sum = monthExpenses
            .where((t) => t.date.weekday == weekday)
            .fold<double>(0, (s, t) => s + t.amount);
        return _BarGroup(label: weekdayNames[i], values: [sum]);
      });

      return _BarChartWidget(
        groups: groups,
        colors: const [_kExpenseColor],
        legendLabels: const ['Despesas'],
        fmt: fmt,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CASH FLOW TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCashFlowTab(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    ColorScheme cs,
  ) {
    final selectedMonth = ref.watch(transactionsSelectedMonthProvider);
    final isCurrentMonth = selectedMonth.year == DateTime.now().year &&
        selectedMonth.month == DateTime.now().month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeriodNav(
          label: DateFormat('MMMM yyyy', dateLoc)
              .format(selectedMonth)
              .toUpperCase(),
          onPrev: () => ref
              .read(transactionsSelectedMonthProvider.notifier)
              .state = DateTime(selectedMonth.year, selectedMonth.month - 1, 1),
          onNext: isCurrentMonth
              ? null
              : () => ref
                  .read(transactionsSelectedMonthProvider.notifier)
                  .state =
                  DateTime(selectedMonth.year, selectedMonth.month + 1, 1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          child: _buildCashFlowContent(
              context, allTxs, fmt, dateLoc, selectedMonth, cs),
        ),
      ],
    );
  }

  Widget _buildCashFlowContent(
    BuildContext context,
    List<TransactionEntity> allTxs,
    String Function(double) fmt,
    String dateLoc,
    DateTime selectedMonth,
    ColorScheme cs,
  ) {
    final now = DateTime.now();
    final isCurrentMonth = selectedMonth.year == now.year &&
        selectedMonth.month == now.month;
    final daysInMonth =
        DateUtils.getDaysInMonth(selectedMonth.year, selectedMonth.month);

    // Saldo acumulado até o início do mês (histórico real). Ignora
    // transferências (movimentos entre carteiras do usuário não alteram saldo).
    final balanceBeforeMonth = allTxs
        .where((t) =>
            !t.isTransfer &&
            t.date.isBefore(DateTime(selectedMonth.year, selectedMonth.month, 1)))
        .fold<double>(0, (s, t) => t.isIncome ? s + t.amount : s - t.amount);

    // Pontos reais: saldo acumulado dia a dia dentro do mês
    final int lastRealDay = isCurrentMonth ? now.day : daysInMonth;
    final realPoints = <_CashFlowPoint>[];
    double runningBalance = balanceBeforeMonth;
    for (int d = 1; d <= lastRealDay; d++) {
      for (final t in allTxs.where((t) =>
          !t.isTransfer &&
          t.date.year == selectedMonth.year &&
          t.date.month == selectedMonth.month &&
          t.date.day == d)) {
        runningBalance += t.isIncome ? t.amount : -t.amount;
      }
      final showLabel = (d == 1 || d % 7 == 0 || d == lastRealDay);
      realPoints.add(_CashFlowPoint(
        day: d,
        balance: runningBalance,
        label: showLabel ? '$d' : '',
        isProjected: false,
      ));
    }

    // Pontos projetados: usa recorrências ativas
    final recurrences = ref.watch(activeRecurrencesProvider);
    final projectedPoints = <_CashFlowPoint>[];
    if (isCurrentMonth && lastRealDay < daysInMonth) {
      double projBalance = runningBalance;
      for (int d = lastRealDay + 1; d <= daysInMonth; d++) {
        final dayDate = DateTime(selectedMonth.year, selectedMonth.month, d);
        for (final r in recurrences) {
          final next = r.nextOccurrence(afterDate: dayDate.subtract(const Duration(days: 1)));
          if (next != null &&
              next.year == dayDate.year &&
              next.month == dayDate.month &&
              next.day == dayDate.day) {
            projBalance += r.isIncome ? r.amount : -r.amount;
          }
        }
        final showLabel = (d % 7 == 0 || d == daysInMonth);
        projectedPoints.add(_CashFlowPoint(
          day: d,
          balance: projBalance,
          label: showLabel ? '$d' : '',
          isProjected: true,
        ));
      }
    }

    final allPoints = [...realPoints, ...projectedPoints];
    if (allPoints.isEmpty) {
      return _emptyState(context, Icons.waterfall_chart_rounded);
    }

    // KPIs
    final currentBalance = realPoints.isNotEmpty
        ? realPoints.last.balance
        : balanceBeforeMonth;
    final projectedEnd = projectedPoints.isNotEmpty
        ? projectedPoints.last.balance
        : currentBalance;

    final monthIncome = allTxs
        .where((t) =>
            t.isIncome &&
            t.date.year == selectedMonth.year &&
            t.date.month == selectedMonth.month)
        .fold<double>(0, (s, t) => s + t.amount);
    final monthExpense = allTxs
        .where((t) =>
            t.isExpense &&
            t.date.year == selectedMonth.year &&
            t.date.month == selectedMonth.month)
        .fold<double>(0, (s, t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── KPI cards ──
        Row(
          children: [
            Expanded(
              child: _CashFlowKpiCard(
                icon: Icons.account_balance_wallet_outlined,
                label: isCurrentMonth ? 'Saldo atual' : 'Saldo final',
                value: fmt(currentBalance),
                color: currentBalance >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 8),
            if (isCurrentMonth && projectedPoints.isNotEmpty) ...[
              Expanded(
                child: _CashFlowKpiCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Projetado fim mês',
                  value: fmt(projectedEnd),
                  color: projectedEnd >= 0
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _CashFlowKpiCard(
                icon: Icons.swap_vert_rounded,
                label: 'Fluxo líquido',
                value: fmt(monthIncome - monthExpense),
                color: monthIncome >= monthExpense
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ── Gráfico ──
        SizedBox(
          height: 260,
          child: _CashFlowChart(
            points: allPoints,
            fmt: fmt,
          ),
        ),
        const SizedBox(height: 12),
        // ── Legenda ──
        Row(
          children: [
            const _LegendDot(color: Color(0xFF6366F1), label: 'Saldo real'),
            const SizedBox(width: 16),
            if (projectedPoints.isNotEmpty)
              _LegendDot(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  label: 'Projeção',
                  dashed: true),
          ],
        ),
        const SizedBox(height: 20),
        // ── Receita / Despesa do mês ──
        _CashFlowIncomeExpenseRow(
          income: monthIncome,
          expense: monthExpense,
          fmt: fmt,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Shared helpers
  // ══════════════════════════════════════════════════════════════════════════

  String _weekRangeLabel(DateTime start, String dateLoc) {
    final end = start.add(const Duration(days: 6));
    final df = DateFormat('d MMM', dateLoc);
    return '${df.format(start).toUpperCase()} - ${df.format(end).toUpperCase()}';
  }

  String _monthRangeLabel(DateTime end, String dateLoc) {
    final start = DateTime(end.year, end.month - 2, 1);
    final df = DateFormat('MMM. yyyy', dateLoc);
    return '${df.format(start).toUpperCase()} - ${df.format(end).toUpperCase()}';
  }

  Widget _buildSubTabsRow(
    List<String> labels,
    int selected,
    ValueChanged<int> onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: labels.asMap().entries.map((e) {
            final isSelected = e.key == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary
                        : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: isSelected
                          ? cs.onPrimary
                          : cs.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPeriodNav({
    required String label,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: onPrev,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onNext,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: onNext == null ? cs.outlineVariant : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Sem transações',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Icon Tab Button ──────────────────────────────────────────────────────────

class _IconTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category Chart (Donut) ───────────────────────────────────────────────────

class _CategoryChart extends StatefulWidget {
  final List<_PieSlice> slices;
  final String Function(double) fmt;
  final double total;

  const _CategoryChart({
    required this.slices,
    required this.fmt,
    required this.total,
  });

  @override
  State<_CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<_CategoryChart> {
  int? _selected;

  static const _donutSize = 220.0;

  @override
  void didUpdateWidget(_CategoryChart old) {
    super.didUpdateWidget(old);
    if (_selected != null && _selected! >= widget.slices.length) {
      _selected = null;
    }
  }

  int? _hitSliceAt(Offset pos) {
    const center = Offset(_donutSize / 2, _donutSize / 2);
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    const outerR = _donutSize / 2;
    const innerR = outerR * 0.55;
    if (dist < innerR || dist > outerR) return null;

    // atan2 returns angle from +X axis; donut starts at -π/2 (top)
    var angle = math.atan2(dy, dx) - (-math.pi / 2);
    if (angle < 0) angle += 2 * math.pi;

    double cumulative = 0;
    for (int i = 0; i < widget.slices.length; i++) {
      final sweep = widget.slices[i].percentage * 2 * math.pi;
      if (angle >= cumulative && angle < cumulative + sweep) {
        return i;
      }
      cumulative += sweep;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Donut chart
        Center(
          child: SizedBox(
            width: _donutSize,
            height: _donutSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final hit = _hitSliceAt(d.localPosition);
                setState(() {
                  _selected = (hit == null || hit == _selected) ? null : hit;
                });
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(_donutSize, _donutSize),
                    painter: _DonutPainter(
                      slices: widget.slices,
                      selected: _selected,
                    ),
                  ),
                  if (_selected == null)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.fmt(widget.total),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    )
                  else
                    _SelectedSliceCenter(
                      slice: widget.slices[_selected!],
                      fmt: widget.fmt,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Category rows
        ...widget.slices.asMap().entries.map(
          (e) {
            final i = e.key;
            final s = e.value;
            final isSelected = _selected == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _selected = isSelected ? null : i;
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.category,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${s.count} lançamento${s.count != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(s.percentage * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.fmt(s.amount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s.percentage,
                        backgroundColor: s.color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(s.color),
                        minHeight: isSelected ? 8 : 6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// Center label shown when a donut slice is selected.
class _SelectedSliceCenter extends StatelessWidget {
  final _PieSlice slice;
  final String Function(double) fmt;

  const _SelectedSliceCenter({required this.slice, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slice.category,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt(slice.amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: slice.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '${(slice.percentage * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Area / Line Chart ────────────────────────────────────────────────────────

class _ChartPoint {
  final String label;
  final double value;
  const _ChartPoint({required this.label, required this.value});
}

class _AreaChart extends StatefulWidget {
  final List<_ChartPoint> points;
  final Color color;
  final String Function(double) fmt;

  const _AreaChart({
    required this.points,
    required this.color,
    required this.fmt,
  });

  @override
  State<_AreaChart> createState() => _AreaChartState();
}

class _AreaChartState extends State<_AreaChart> {
  int? _selected;

  int? _hitPointAt(Offset pos, Size size) {
    if (widget.points.isEmpty) return null;
    final chartW = size.width - _AreaPainter.leftPad - _AreaPainter.rightPad;
    final chartH =
        size.height - _AreaPainter.topPad - _AreaPainter.bottomPad;
    if (chartW <= 0 || chartH <= 0) return null;

    final n = widget.points.length;
    if (pos.dx < _AreaPainter.leftPad ||
        pos.dx > size.width - _AreaPainter.rightPad) {
      return null;
    }
    final dx = chartW / (n == 1 ? 1 : n - 1);
    final relX = pos.dx - _AreaPainter.leftPad;
    final i = n == 1 ? 0 : (relX / dx).round().clamp(0, n - 1);
    return i;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final hit = _hitPointAt(d.localPosition, size);
            setState(() {
              if (hit == null) {
                _selected = null;
              } else if (_selected == hit) {
                _selected = null;
              } else {
                _selected = hit;
              }
            });
          },
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: CustomPaint(
              painter: _AreaPainter(
                points: widget.points,
                color: widget.color,
                fmt: widget.fmt,
                selected: _selected,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// Extracts the currency symbol from a formatter closure so compact axis labels
/// follow the user's selected currency (e.g. "R$ 0,00" → "R$", "0,00 €" → "€",
/// "US$ 0.00" → "US$"). Works whether the symbol is a prefix or a suffix.
String _symbolFromFmt(String Function(double) fmt) {
  final m = RegExp(r'[^\d\s.,\-]+').firstMatch(fmt(0));
  return m?.group(0) ?? '';
}

class _AreaPainter extends CustomPainter {
  final List<_ChartPoint> points;
  final Color color;
  final String Function(double) fmt;
  final int? selected;

  const _AreaPainter({
    required this.points,
    required this.color,
    required this.fmt,
    this.selected,
  });

  static const double leftPad = 68;
  static const double rightPad = 12;
  static const double topPad = 12;
  static const double bottomPad = 32;
  static const int _yDivisions = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    if (chartW <= 0 || chartH <= 0) return;

    final maxVal = points.map((p) => p.value).fold<double>(0, math.max);
    final effectiveMax = maxVal == 0 ? 1.0 : _niceMax(maxVal);

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.12)
      ..strokeWidth = 0.8;

    final labelStyle = TextStyle(fontSize: 9, color: Colors.grey.shade500);

    // ── Y grid lines + labels ──────────────────────────────────────────
    for (int i = 0; i <= _yDivisions; i++) {
      final frac = i / _yDivisions;
      final y = topPad + chartH * (1 - frac);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
      final val = effectiveMax * frac;
      _drawText(
        canvas,
        _compactFmt(val),
        Offset(0, y - 6),
        leftPad - 4,
        labelStyle,
        TextAlign.right,
      );
    }

    if (maxVal == 0) return;

    // ── Point helper ───────────────────────────────────────────────────
    final n = points.length;
    final dx = chartW / (n == 1 ? 1 : n - 1);

    Offset pt(int i) => Offset(
          leftPad + (n == 1 ? chartW / 2 : i * dx),
          topPad + chartH * (1 - points[i].value / effectiveMax),
        );

    // ── Smooth bezier path ─────────────────────────────────────────────
    final linePath = Path();
    final fillPath = Path();

    final baseY = topPad + chartH;
    linePath.moveTo(pt(0).dx, pt(0).dy);
    fillPath.moveTo(pt(0).dx, baseY);
    fillPath.lineTo(pt(0).dx, pt(0).dy);

    for (int i = 1; i < n; i++) {
      final prev = pt(i - 1);
      final curr = pt(i);
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
      fillPath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }

    fillPath.lineTo(pt(n - 1).dx, baseY);
    fillPath.close();

    // Fill gradient
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH)),
    );

    // Line stroke
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots at non-zero points (small, filled)
    final dotFill = Paint()..color = color..style = PaintingStyle.fill;
    final dotBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      if (points[i].value <= 0) continue;
      final o = pt(i);
      // Only draw dots when there aren't too many points
      if (n <= 14) {
        canvas.drawCircle(o, 4.5, dotBorder);
        canvas.drawCircle(o, 3, dotFill);
      }
    }

    // ── X labels ──────────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      if (points[i].label.isEmpty) continue;
      final x = pt(i).dx;
      final y = baseY + 5;
      _drawText(
        canvas,
        points[i].label,
        Offset(x - 26, y),
        52,
        labelStyle,
        TextAlign.center,
      );
    }

    // ── Selected point: highlight + tooltip ────────────────────────────
    if (selected != null && selected! >= 0 && selected! < n) {
      final i = selected!;
      final o = pt(i);

      // Vertical guide line
      canvas.drawLine(
        Offset(o.dx, topPad),
        Offset(o.dx, baseY),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );

      // Highlighted dot
      canvas.drawCircle(o, 7, Paint()..color = Colors.white);
      canvas.drawCircle(o, 5.5, Paint()..color = color);

      // Tooltip
      final value = points[i].value;
      final label = points[i].label.trim();
      final tooltipText = label.isNotEmpty ? '$label\n${fmt(value)}' : fmt(value);
      _drawTooltip(canvas, size, tooltipText, o, color);
    }
  }

  void _drawTooltip(
    Canvas canvas,
    Size size,
    String text,
    Offset anchor,
    Color tooltipColor,
  ) {
    const textStyle = TextStyle(
      fontSize: 11,
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    const padH = 8.0;
    const padV = 5.0;
    const gap = 8.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;

    double left = anchor.dx - w / 2;
    if (left < leftPad) left = leftPad;
    if (left + w > size.width - rightPad) {
      left = size.width - rightPad - w;
    }

    double top = anchor.dy - h - gap;
    if (top < 0) top = anchor.dy + gap;

    final rect = Rect.fromLTWH(left, top, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(rrect, Paint()..color = tooltipColor);
    tp.paint(canvas, Offset(left + padH, top + padV));
  }

  // Round up to a "nice" max value
  double _niceMax(double val) {
    final magnitude = math.pow(10, (math.log(val) / math.ln10).floor());
    final normalized = val / magnitude;
    double nice;
    if (normalized <= 1) {
      nice = 1;
    } else if (normalized <= 2) {
      nice = 2;
    } else if (normalized <= 5) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude * 1.0;
  }

  String _compactFmt(double val) {
    final s = _symbolFromFmt(fmt);
    if (val >= 1000000) return '$s${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '$s${(val / 1000).toStringAsFixed(0)}K';
    return '$s${val.toStringAsFixed(0)}';
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double maxWidth,
    TextStyle style,
    TextAlign align,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.points != points ||
      old.color != color ||
      old.selected != selected;
}

// ─── Grouped Bar Chart ────────────────────────────────────────────────────────

class _BarGroup {
  final String label;
  final List<double> values;
  const _BarGroup({required this.label, required this.values});
}

class _BarChartWidget extends StatefulWidget {
  final List<_BarGroup> groups;
  final List<Color> colors;
  final List<String> legendLabels;
  final String Function(double) fmt;

  const _BarChartWidget({
    required this.groups,
    required this.colors,
    required this.legendLabels,
    required this.fmt,
  });

  @override
  State<_BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<_BarChartWidget> {
  ({int group, int series})? _selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: LayoutBuilder(
            builder: (ctx, c) {
              final size = Size(c.maxWidth, 240);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final layout = _BarLayout.compute(
                    size,
                    widget.groups,
                    widget.colors.length,
                  );
                  final hit = layout.hitTest(details.localPosition);
                  setState(() {
                    if (hit == null) {
                      _selected = null;
                    } else if (_selected != null &&
                        _selected!.group == hit.group &&
                        _selected!.series == hit.series) {
                      _selected = null;
                    } else {
                      _selected = hit;
                    }
                  });
                },
                child: CustomPaint(
                  painter: _BarPainter(
                    groups: widget.groups,
                    colors: widget.colors,
                    fmt: widget.fmt,
                    selected: _selected,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(widget.colors.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.colors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.legendLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Computes the layout (rects + scaling) of the grouped bar chart so that
/// painter and tap hit-test stay perfectly in sync.
class _BarLayout {
  static const double leftPad = 68;
  static const double rightPad = 8;
  static const double topPad = 8;
  static const double bottomPad = 32;
  static const double groupGap = 8;
  static const double barGap = 2;

  final Size size;
  final double effectiveMax;
  final double chartW;
  final double chartH;

  /// barRects[group][series] — full-height hit area for tap detection.
  /// Tapping anywhere in the column counts as a hit for that bar.
  final List<List<Rect>> barRects;

  const _BarLayout._({
    required this.size,
    required this.effectiveMax,
    required this.chartW,
    required this.chartH,
    required this.barRects,
  });

  factory _BarLayout.compute(
    Size size,
    List<_BarGroup> groups,
    int seriesCount,
  ) {
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    double maxVal = 0;
    for (final g in groups) {
      for (final v in g.values) {
        if (v > maxVal) maxVal = v;
      }
    }
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal * 1.1;

    final n = groups.length;
    final groupW = n > 0 ? (chartW - groupGap * (n - 1)) / n : chartW;
    final barW = seriesCount > 1
        ? (groupW - barGap * (seriesCount - 1)) / seriesCount
        : groupW * 0.7;

    final rects = <List<Rect>>[];
    for (int gi = 0; gi < n; gi++) {
      final gx = leftPad + gi * (groupW + groupGap);
      final groupRects = <Rect>[];
      for (int si = 0;
          si < seriesCount && si < groups[gi].values.length;
          si++) {
        final bx = seriesCount > 1
            ? gx + si * (barW + barGap)
            : gx + (groupW - barW) / 2;
        groupRects.add(Rect.fromLTWH(bx, topPad, barW, chartH));
      }
      rects.add(groupRects);
    }

    return _BarLayout._(
      size: size,
      effectiveMax: effectiveMax,
      chartW: chartW,
      chartH: chartH,
      barRects: rects,
    );
  }

  ({int group, int series})? hitTest(Offset offset) {
    for (int g = 0; g < barRects.length; g++) {
      for (int s = 0; s < barRects[g].length; s++) {
        if (barRects[g][s].contains(offset)) {
          return (group: g, series: s);
        }
      }
    }
    return null;
  }
}

class _BarPainter extends CustomPainter {
  final List<_BarGroup> groups;
  final List<Color> colors;
  final String Function(double) fmt;
  final ({int group, int series})? selected;

  const _BarPainter({
    required this.groups,
    required this.colors,
    required this.fmt,
    this.selected,
  });

  static const int _yDivisions = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (groups.isEmpty) return;

    final layout = _BarLayout.compute(size, groups, colors.length);
    final chartH = layout.chartH;
    final effectiveMax = layout.effectiveMax;
    const leftPad = _BarLayout.leftPad;
    const topPad = _BarLayout.topPad;
    const rightPad = _BarLayout.rightPad;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      fontSize: 9,
      color: Colors.grey.shade500,
    );

    // ── Y grid + labels ──────────────────────────────────────────────────
    for (int i = 0; i <= _yDivisions; i++) {
      final frac = i / _yDivisions;
      final y = topPad + chartH * (1 - frac);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
      final val = effectiveMax * frac;
      _drawText(
        canvas,
        _compact(val),
        Offset(0, y - 6),
        leftPad - 4,
        labelStyle,
        TextAlign.right,
      );
    }

    // ── Bars ─────────────────────────────────────────────────────────────
    for (int gi = 0; gi < layout.barRects.length; gi++) {
      final groupRects = layout.barRects[gi];
      final hitRect =
          groupRects.isNotEmpty ? groupRects.first : Rect.zero;
      final groupLeft = hitRect.left;
      final groupRight = groupRects.isNotEmpty
          ? groupRects.last.right
          : groupLeft;

      for (int si = 0; si < groupRects.length; si++) {
        final val = groups[gi].values[si];
        if (val <= 0) continue;

        final barH = (val / effectiveMax) * chartH;
        final col = groupRects[si];
        final by = topPad + chartH - barH;

        final isSelected =
            selected != null && selected!.group == gi && selected!.series == si;

        final rrect = RRect.fromRectAndCorners(
          Rect.fromLTWH(col.left, by, col.width, barH),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(
          rrect,
          Paint()..color = colors[si],
        );

        // Highlight stroke for selected bar
        if (isSelected) {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = Colors.black.withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }

      // X label
      final labelX = (groupLeft + groupRight) / 2;
      _drawText(
        canvas,
        groups[gi].label,
        Offset(labelX - 28, topPad + chartH + 6),
        56,
        labelStyle,
        TextAlign.center,
      );
    }

    // ── Tooltip on selected bar ─────────────────────────────────────────
    if (selected != null) {
      final g = selected!.group;
      final s = selected!.series;
      if (g < groups.length && s < groups[g].values.length) {
        final val = groups[g].values[s];
        final col = layout.barRects[g][s];
        final barH = (val / effectiveMax) * chartH;
        final barTop = topPad + chartH - barH;

        _drawTooltip(
          canvas,
          size,
          fmt(val),
          Offset(col.left + col.width / 2, barTop),
          colors[s],
        );
      }
    }
  }

  void _drawTooltip(
    Canvas canvas,
    Size size,
    String text,
    Offset anchor,
    Color color,
  ) {
    const textStyle = TextStyle(
      fontSize: 11,
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 8.0;
    const padV = 5.0;
    const gap = 6.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;

    double left = anchor.dx - w / 2;
    if (left < _BarLayout.leftPad) left = _BarLayout.leftPad;
    if (left + w > size.width - _BarLayout.rightPad) {
      left = size.width - _BarLayout.rightPad - w;
    }

    double top = anchor.dy - h - gap;
    if (top < 0) top = anchor.dy + gap;

    final rect = Rect.fromLTWH(left, top, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(
      rrect,
      Paint()..color = color,
    );
    tp.paint(canvas, Offset(left + padH, top + padV));
  }

  String _compact(double val) {
    if (val >= 1000000) return 'R\$${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return 'R\$${(val / 1000).toStringAsFixed(0)}K';
    return 'R\$${val.toStringAsFixed(0)}';
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double maxWidth,
    TextStyle style,
    TextAlign align,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.groups != groups ||
      old.colors != colors ||
      old.selected != selected;
}

// ─── Annual Summary (totals for the year) ─────────────────────────────────────

class _AnnualSummaryView extends StatelessWidget {
  final int year;
  final double income;
  final double expense;
  final String Function(double) fmt;

  const _AnnualSummaryView({
    required this.year,
    required this.income,
    required this.expense,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final balance = income - expense;
    final isPositive = balance >= 0;
    final maxVal = math.max(income, expense);
    final incomeFraction = maxVal > 0 ? income / maxVal : 0.0;
    final expenseFraction = maxVal > 0 ? expense / maxVal : 0.0;
    final savingsRate = income > 0 ? (balance / income) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total acumulado de $year',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          _AnnualBarRow(
            icon: Icons.arrow_downward_rounded,
            label: 'Receitas',
            value: fmt(income),
            color: _kIncomeColor,
            fraction: incomeFraction,
          ),
          const SizedBox(height: 16),
          _AnnualBarRow(
            icon: Icons.arrow_upward_rounded,
            label: 'Despesas',
            value: fmt(expense),
            color: _kExpenseColor,
            fraction: expenseFraction,
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (isPositive ? _kIncomeColor : _kExpenseColor)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isPositive ? _kIncomeColor : _kExpenseColor)
                    .withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive
                      ? Icons.savings_rounded
                      : Icons.warning_amber_rounded,
                  size: 20,
                  color: isPositive ? _kIncomeColor : _kExpenseColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPositive ? 'Saldo do ano' : 'Déficit do ano',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isPositive ? '+' : '-'}${fmt(balance.abs())}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPositive ? _kIncomeColor : _kExpenseColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (income > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isPositive ? 'Taxa de poupança' : 'Sobre receita',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${savingsRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPositive ? _kIncomeColor : _kExpenseColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnualBarRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double fraction;

  const _AnnualBarRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _PieSlice {
  final String category;
  final double amount;
  final double percentage;
  final Color color;
  final int count;

  const _PieSlice({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.count,
  });
}

// ─── Donut Painter ────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final List<_PieSlice> slices;
  final int? selected;

  const _DonutPainter({required this.slices, this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseOuter = math.min(size.width, size.height) / 2;
    final baseInner = baseOuter * 0.55;
    const gapAngle = 0.025;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final isSelected = selected == i;
      final outerRadius = isSelected ? baseOuter : baseOuter - 4;
      final innerRadius = baseInner;

      final sweepAngle = slice.percentage * 2 * math.pi - gapAngle;

      final path = Path();
      final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
      final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

      path.arcTo(outerRect, startAngle, sweepAngle, false);
      path.arcTo(innerRect, startAngle + sweepAngle, -sweepAngle, false);
      path.close();

      final paint = Paint()
        ..color = (selected != null && !isSelected)
            ? slice.color.withValues(alpha: 0.35)
            : slice.color
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      startAngle += slice.percentage * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.selected != selected;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cash Flow — Data & Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CashFlowPoint {
  final int day;
  final double balance;
  final String label;
  final bool isProjected;

  const _CashFlowPoint({
    required this.day,
    required this.balance,
    required this.label,
    required this.isProjected,
  });
}

// ── KPI Card ──────────────────────────────────────────────────────────────────

class _CashFlowKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CashFlowKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Income / Expense summary row ──────────────────────────────────────────────

class _CashFlowIncomeExpenseRow extends StatelessWidget {
  final double income;
  final double expense;
  final String Function(double) fmt;

  const _CashFlowIncomeExpenseRow({
    required this.income,
    required this.expense,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _IncExpItem(
              icon: Icons.arrow_downward_rounded,
              label: 'Receitas',
              value: fmt(income),
              color: const Color(0xFF10B981),
            ),
          ),
          Container(width: 1, height: 36, color: cs.outlineVariant),
          Expanded(
            child: _IncExpItem(
              icon: Icons.arrow_upward_rounded,
              label: 'Despesas',
              value: fmt(expense),
              color: const Color(0xFFEF4444),
            ),
          ),
          Container(width: 1, height: 36, color: cs.outlineVariant),
          Expanded(
            child: _IncExpItem(
              icon: Icons.account_balance_outlined,
              label: 'Resultado',
              value: fmt((income - expense).abs()),
              color: income >= expense
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              prefix: income >= expense ? '+' : '-',
            ),
          ),
        ],
      ),
    );
  }
}

class _IncExpItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String prefix;

  const _IncExpItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          '$prefix$value',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Legend Dot ─────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(24, 3),
          painter: _LineSamplePainter(color: color, dashed: dashed),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _LineSamplePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LineSamplePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), paint);
    } else {
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, size.height / 2),
            Offset(math.min(x + 4, size.width), size.height / 2), paint);
        x += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_LineSamplePainter old) =>
      old.color != color || old.dashed != dashed;
}

// ── Cash Flow Chart ────────────────────────────────────────────────────────────

class _CashFlowChart extends StatefulWidget {
  final List<_CashFlowPoint> points;
  final String Function(double) fmt;

  const _CashFlowChart({required this.points, required this.fmt});

  @override
  State<_CashFlowChart> createState() => _CashFlowChartState();
}

class _CashFlowChartState extends State<_CashFlowChart> {
  int? _selected;

  int? _hitPointAt(Offset pos, Size size) {
    if (widget.points.isEmpty) return null;
    final chartW =
        size.width - _CashFlowPainter.leftPad - _CashFlowPainter.rightPad;
    if (chartW <= 0) return null;

    final n = widget.points.length;
    if (pos.dx < _CashFlowPainter.leftPad ||
        pos.dx > size.width - _CashFlowPainter.rightPad) {
      return null;
    }
    final dx = chartW / (n == 1 ? 1 : n - 1);
    final relX = pos.dx - _CashFlowPainter.leftPad;
    final i = n == 1 ? 0 : (relX / dx).round().clamp(0, n - 1);
    return i;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (ctx, c) {
        final size = Size(c.maxWidth, 260);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final hit = _hitPointAt(d.localPosition, size);
            setState(() {
              if (hit == null || hit == _selected) {
                _selected = null;
              } else {
                _selected = hit;
              }
            });
          },
          child: CustomPaint(
            size: Size(c.maxWidth, 260),
            painter: _CashFlowPainter(
              points: widget.points,
              labelColor: cs.onSurfaceVariant,
              zeroLineColor: cs.outlineVariant,
              fmt: widget.fmt,
              selected: _selected,
            ),
          ),
        );
      },
    );
  }
}

class _CashFlowPainter extends CustomPainter {
  final List<_CashFlowPoint> points;
  final Color labelColor;
  final Color zeroLineColor;
  final String Function(double) fmt;
  final int? selected;

  static const _lineColor = Color(0xFF6366F1);
  static const _projColor = Color(0x666366F1);
  static const _posAreaColor = Color(0x196366F1);
  static const _negAreaColor = Color(0x19EF4444);

  static const double topPad = 24;
  static const double bottomPad = 28;
  static const double leftPad = 56;
  static const double rightPad = 12;

  const _CashFlowPainter({
    required this.points,
    required this.labelColor,
    required this.zeroLineColor,
    required this.fmt,
    this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    final values = points.map((p) => p.balance).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);

    final range = (maxVal - minVal).abs();
    final pad = range == 0 ? 100.0 : range * 0.15;
    final yMin = minVal - pad;
    final yMax = maxVal + pad;
    final yRange = yMax - yMin;

    double toX(int i) =>
        leftPad + (points.length == 1 ? chartW / 2 : (i / (points.length - 1)) * chartW);
    double toY(double v) =>
        topPad + chartH - ((v - yMin) / yRange) * chartH;

    // Zero line
    if (yMin < 0 && yMax > 0) {
      final zy = toY(0);
      canvas.drawLine(
        Offset(leftPad, zy),
        Offset(leftPad + chartW, zy),
        Paint()
          ..color = zeroLineColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    final realPts = points.where((p) => !p.isProjected).toList();
    final projPts = points.where((p) => p.isProjected).toList();

    List<Offset> toOffsets(List<_CashFlowPoint> pts) => pts
        .map((p) => Offset(toX(points.indexOf(p)), toY(p.balance)))
        .toList();

    void drawAreaLine(List<Offset> offsets, Color lineColor, Color areaPos,
        Color areaNeg) {
      if (offsets.length < 2) return;

      final posPath = Path()..moveTo(offsets.first.dx, toY(0));
      for (final o in offsets) {
        posPath.lineTo(o.dx, o.dy);
      }
      posPath.lineTo(offsets.last.dx, toY(math.max(0, yMin)));
      posPath.close();

      final negPath = Path()..moveTo(offsets.first.dx, toY(0));
      for (final o in offsets) {
        negPath.lineTo(o.dx, o.dy);
      }
      negPath.lineTo(offsets.last.dx, toY(math.min(0, yMax)));
      negPath.close();

      canvas.drawPath(posPath, Paint()..color = areaPos);
      canvas.drawPath(negPath, Paint()..color = areaNeg);

      final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        linePath.lineTo(offsets[i].dx, offsets[i].dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawAreaLine(toOffsets(realPts), _lineColor, _posAreaColor, _negAreaColor);

    if (projPts.isNotEmpty) {
      final joinOffsets = [
        if (realPts.isNotEmpty) toOffsets(realPts).last,
        ...toOffsets(projPts),
      ];
      drawAreaLine(
        joinOffsets,
        _projColor,
        _posAreaColor.withValues(alpha: 0.06),
        _negAreaColor.withValues(alpha: 0.06),
      );
    }

    // Y-axis labels
    final labelStyle = TextStyle(fontSize: 10, color: labelColor);
    for (int i = 0; i <= 4; i++) {
      final v = yMin + (yRange * i / 4);
      final y = toY(v);
      _drawText(canvas, _compact(v), Offset(0, y - 6), leftPad - 4,
          labelStyle, TextAlign.right);
    }

    // X-axis labels
    for (final p in points) {
      if (p.label.isEmpty) continue;
      final idx = points.indexOf(p);
      _drawText(
        canvas,
        p.label,
        Offset(toX(idx) - 12, topPad + chartH + 5),
        24,
        labelStyle,
        TextAlign.center,
      );
    }

    // Today dot
    if (realPts.isNotEmpty) {
      final last = toOffsets(realPts).last;
      canvas.drawCircle(last, 5, Paint()..color = _lineColor);
      canvas.drawCircle(last, 3, Paint()..color = Colors.white);
    }

    // Selected point: highlight + tooltip
    if (selected != null && selected! >= 0 && selected! < points.length) {
      final i = selected!;
      final p = points[i];
      final o = Offset(toX(i), toY(p.balance));
      final markerColor = p.isProjected ? _projColor : _lineColor;

      // Vertical guide
      canvas.drawLine(
        Offset(o.dx, topPad),
        Offset(o.dx, topPad + chartH),
        Paint()
          ..color = markerColor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );

      // Highlighted dot
      canvas.drawCircle(o, 7, Paint()..color = Colors.white);
      canvas.drawCircle(o, 5.5, Paint()..color = markerColor);

      // Tooltip
      final dayLabel = 'Dia ${p.day}${p.isProjected ? ' (proj.)' : ''}';
      final tooltipText = '$dayLabel\n${fmt(p.balance)}';
      _drawTooltip(canvas, size, tooltipText, o, markerColor);
    }
  }

  void _drawTooltip(
    Canvas canvas,
    Size size,
    String text,
    Offset anchor,
    Color tooltipColor,
  ) {
    const textStyle = TextStyle(
      fontSize: 11,
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    const padH = 8.0;
    const padV = 5.0;
    const gap = 8.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;

    double left = anchor.dx - w / 2;
    if (left < leftPad) left = leftPad;
    if (left + w > size.width - rightPad) {
      left = size.width - rightPad - w;
    }

    double top = anchor.dy - h - gap;
    if (top < 0) top = anchor.dy + gap;

    final rect = Rect.fromLTWH(left, top, w, h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    canvas.drawRRect(rrect, Paint()..color = tooltipColor);
    tp.paint(canvas, Offset(left + padH, top + padV));
  }

  String _compact(double val) {
    if (val.abs() >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val.abs() >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
    return val.toStringAsFixed(0);
  }

  void _drawText(Canvas canvas, String text, Offset offset, double maxWidth,
      TextStyle style, TextAlign align) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_CashFlowPainter old) =>
      old.points != points || old.selected != selected;
}
