import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/providers/selected_month_provider.dart';
import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/help_hint.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../../core/utils/money_input_formatter.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../recurring/presentation/screens/recurring_screen.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../../core/providers/workspace_provider.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../wallets/presentation/widgets/wallet_buckets_widgets.dart';
import '../../../workspaces/presentation/workspace_switcher.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/ideal_budget.dart';
import '../providers/budget_provider.dart';

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});

  @override
  ConsumerState<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends ConsumerState<PlanningScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index != _selectedTab) {
        setState(() => _selectedTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final viewMode = ref.watch(budgetViewModeProvider);
    final summaries = ref.watch(activeBudgetSummariesProvider);
    final budgetsAsync = viewMode == BudgetPeriod.monthly
        ? ref.watch(budgetsStreamProvider)
        : ref.watch(budgetsByYearStreamProvider);

    final sortedSummaries = [...summaries]
      ..sort((a, b) =>
          a.budget.categoryName.compareTo(b.budget.categoryName));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: CarteiraHeaderSelector(onDark: false),
        ),
        actions: _selectedTab == 0
            ? [
                _ViewModeMenu(viewMode: viewMode),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Orçamentos'),
                  const SizedBox(width: 4),
                  HelpHint(
                    title: l10n.hintBudgetTitle,
                    body: l10n.hintBudgetBody,
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Metas'),
                  const SizedBox(width: 4),
                  HelpHint(
                    title: l10n.hintGoalTitle,
                    body: l10n.hintGoalBody,
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Recorrências'),
                  const SizedBox(width: 4),
                  HelpHint(
                    title: l10n.hintRecurringTitle,
                    body: l10n.hintRecurringBody,
                  ),
                ],
              ),
            ),
            const Tab(text: 'Reservas'),
            const Tab(text: 'Patrimônio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Orçamentos tab ─────────────────────────────────────
          ProGateWidget(
            featureName: 'Orçamentos',
            featureDescription:
                'Defina limites por categoria e controle seus gastos.',
            featureIcon: Icons.pie_chart_outline_rounded,
            child: Column(
              children: [
                _PeriodSelector(month: selectedMonth, viewMode: viewMode),
                Expanded(
                  child: budgetsAsync.when(
                    data: (_) => sortedSummaries.isEmpty
                        ? _EmptyBudgets(
                            month: selectedMonth, viewMode: viewMode)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: sortedSummaries.length + 2,
                            itemBuilder: (ctx, i) {
                              if (i == 0) {
                                return _AnimatedListItem(
                                  index: 0,
                                  child: _BudgetSummaryCard(
                                    summaries: sortedSummaries,
                                    viewMode: viewMode,
                                  ),
                                );
                              }
                              if (i == sortedSummaries.length + 1) {
                                return _AnimatedListItem(
                                  index: i,
                                  child: _AddBudgetButton(
                                    month: selectedMonth,
                                    viewMode: viewMode,
                                  ),
                                );
                              }
                              return _AnimatedListItem(
                                index: i,
                                child: _BudgetCard(
                                    summary: sortedSummaries[i - 1]),
                              );
                            },
                          ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Erro: $e')),
                  ),
                ),
              ],
            ),
          ),
          // ── Metas tab ──────────────────────────────────────────
          const GoalsScreen(),
          // ── Recorrências tab ──────────────────────────────────
          const ProGateWidget(
            featureName: 'Recorrências',
            featureDescription:
                'Cadastre transações automáticas que se repetem todo mês.',
            featureIcon: Icons.repeat_rounded,
            child: RecurringScreen(),
          ),
          // ── Reservas tab ───────────────────────────────────────
          const TypedWalletsTab(type: WalletType.reserve),
          // ── Patrimônio tab ─────────────────────────────────────
          const PatrimonioTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View-mode helpers (labels / icons / period range descriptors)
// ─────────────────────────────────────────────────────────────────────────────

String _viewModeLabel(BudgetPeriod p) {
  switch (p) {
    case BudgetPeriod.monthly:
      return 'Mensal';
    case BudgetPeriod.quarterly:
      return 'Trimestral';
    case BudgetPeriod.semestral:
      return 'Semestral';
    case BudgetPeriod.annual:
      return 'Anual';
  }
}

IconData _viewModeIcon(BudgetPeriod p) {
  switch (p) {
    case BudgetPeriod.monthly:
      return Icons.calendar_view_month_outlined;
    case BudgetPeriod.quarterly:
      return Icons.calendar_view_week_outlined;
    case BudgetPeriod.semestral:
      return Icons.calendar_today_outlined;
    case BudgetPeriod.annual:
      return Icons.calendar_month_rounded;
  }
}

/// Short label for a period (e.g. "Janeiro 2025", "T1 2025", "S1 2025", "2025").
String _periodLabel(DateTime month, BudgetPeriod period, String dateLoc) {
  switch (period) {
    case BudgetPeriod.monthly:
      return DateFormat('MMMM yyyy', dateLoc).format(month).capitalizeMonth();
    case BudgetPeriod.quarterly:
      final start = normalizePeriodStart(month, period);
      final q = ((start.month - 1) ~/ 3) + 1;
      return 'T$q ${start.year}';
    case BudgetPeriod.semestral:
      final start = normalizePeriodStart(month, period);
      final s = start.month <= 6 ? 1 : 2;
      return 'S$s ${start.year}';
    case BudgetPeriod.annual:
      return month.year.toString();
  }
}

String _summaryTitleForPeriod(BudgetPeriod p) {
  switch (p) {
    case BudgetPeriod.monthly:
      return 'Resumo do mês';
    case BudgetPeriod.quarterly:
      return 'Resumo do trimestre';
    case BudgetPeriod.semestral:
      return 'Resumo do semestre';
    case BudgetPeriod.annual:
      return 'Resumo do ano';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-dot view-mode menu
// ─────────────────────────────────────────────────────────────────────────────

class _ViewModeMenu extends ConsumerWidget {
  final BudgetPeriod viewMode;

  const _ViewModeMenu({required this.viewMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<BudgetPeriod>(
      tooltip: l10n.moreOptions,
      icon: const Icon(Icons.more_vert),
      onSelected: (period) {
        ref.read(budgetViewModeProvider.notifier).state = period;
      },
      itemBuilder: (ctx) => BudgetPeriod.values
          .map(
            (p) => PopupMenuItem<BudgetPeriod>(
              value: p,
              child: _MenuItemRow(
                icon: _viewModeIcon(p),
                label: _viewModeLabel(p),
                active: viewMode == p,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? cs.primary : cs.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (active) Icon(Icons.check_rounded, size: 16, color: cs.primary),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Period selector — adapts to the active view mode
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodSelector extends ConsumerWidget {
  final DateTime month;
  final BudgetPeriod viewMode;

  const _PeriodSelector({required this.month, required this.viewMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLoc = ref.watch(dateLocaleProvider);
    final label = _periodLabel(month, viewMode, dateLoc);

    void shift(int direction) {
      DateTime next;
      switch (viewMode) {
        case BudgetPeriod.monthly:
          next = DateTime(month.year, month.month + direction, 1);
        case BudgetPeriod.quarterly:
          next = DateTime(month.year, month.month + (3 * direction), 1);
        case BudgetPeriod.semestral:
          next = DateTime(month.year, month.month + (6 * direction), 1);
        case BudgetPeriod.annual:
          next = DateTime(month.year + direction, month.month, 1);
      }
      ref.read(selectedMonthProvider.notifier).state = next;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => shift(-1),
          ),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => shift(1),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Summary Card (totals header)
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetSummaryCard extends ConsumerWidget {
  final List<BudgetSummary> summaries;
  final BudgetPeriod viewMode;

  const _BudgetSummaryCard({
    required this.summaries,
    required this.viewMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFormatterProvider);
    final l10n = AppLocalizations.of(context);

    final totalPlanned =
        summaries.fold(0.0, (sum, s) => sum + s.budget.limitAmount);
    final totalSpent = summaries.fold(0.0, (sum, s) => sum + s.spentAmount);
    final remaining = totalPlanned - totalSpent;
    final isOver = totalSpent > totalPlanned;

    final rawProgress = totalPlanned > 0 ? totalSpent / totalPlanned : 0.0;
    final progress = rawProgress.clamp(0.0, 1.0);
    final progressColor = _statusColor(progress, isOver);

    final cs = Theme.of(context).colorScheme;
    final pct = (rawProgress * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withValues(alpha: 0.35),
              cs.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          children: [
            // ── Título centralizado ──
            Text(
              _summaryTitleForPeriod(viewMode),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: cs.onSurface,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 14),
            // ── Barra de progresso gradiente + % ──
            Row(
              children: [
                Expanded(
                  child: _StatusProgressBar(
                    progress: progress,
                    isOverBudget: isOver,
                    height: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Três colunas com divisores ──
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryColumn(
                      icon: Icons.account_balance_wallet_outlined,
                      label: l10n.budgetPlanned,
                      value: fmt(totalPlanned),
                    ),
                  ),
                  VerticalDivider(
                      color: cs.outlineVariant, width: 1, thickness: 1),
                  Expanded(
                    child: _SummaryColumn(
                      icon: Icons.shopping_cart_outlined,
                      label: l10n.spent,
                      value: fmt(totalSpent),
                      valueColor: progressColor,
                    ),
                  ),
                  VerticalDivider(
                      color: cs.outlineVariant, width: 1, thickness: 1),
                  Expanded(
                    child: _SummaryColumn(
                      icon: isOver
                          ? Icons.warning_amber_rounded
                          : Icons.savings_outlined,
                      label: isOver
                          ? l10n.budgetExceeded
                          : l10n.budgetRemaining,
                      value: fmt(remaining.abs()),
                      valueColor: progressColor,
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

class _SummaryColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryColumn({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: valueColor ?? cs.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budget Card (individual row)
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetCard extends ConsumerWidget {
  final BudgetSummary summary;

  const _BudgetCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(currencyFormatterProvider);
    final budget = summary.budget;
    final cs = Theme.of(context).colorScheme;
    final pctColor = _statusColor(summary.progress, summary.isOverBudget);
    final isSynthetic = isSyntheticBudget(budget);

    // Try to find the category to get icon & color
    final categories = ref.watch(expenseCategoriesProvider);
    final cat = categories.cast<CategoryEntity?>().firstWhere(
          (c) => c!.id == budget.categoryId,
          orElse: () => null,
        );
    final catIcon = cat != null
        ? (kCategoryIconMap[cat.iconCodePoint] ?? Icons.category)
        : Icons.category;
    final catColor = cat != null ? Color(cat.colorValue) : cs.primary;

    // Count expense transactions for this category within the budget's
    // full period (works for monthly + quarterly / semestral / annual).
    final allTransactions = ref.watch(transactionsStreamProvider).value ?? [];
    final periodStart = budget.periodStart;
    final periodEnd = budget.periodEnd;
    final periodTransactions = allTransactions
        .where((t) =>
            t.isExpense &&
            t.category == budget.categoryName &&
            !t.date.isBefore(periodStart) &&
            t.date.isBefore(periodEnd))
        .length;

    void navigateToTransactions() {
      // Reset filters irrelevantes
      ref.read(statementTypeFilterProvider.notifier).state = null;
      ref.read(statementIsAnnualProvider.notifier).state = false;
      // Aplicar categoria
      ref.read(statementCategoryFilterProvider.notifier).state = {
        budget.categoryName
      };
      // For monthly budgets, clear range and set selected month.
      // For period budgets, set an explicit date range covering the period.
      if (budget.period == BudgetPeriod.monthly) {
        ref.read(statementDateRangeProvider.notifier).state = null;
        ref.read(selectedMonthProvider.notifier).state = budget.month;
      } else {
        final start = budget.periodStart;
        // periodEnd is exclusive (first day after period) — subtract 1 day for
        // an inclusive UI range.
        final end = budget.periodEnd.subtract(const Duration(days: 1));
        ref.read(statementDateRangeProvider.notifier).state = (start, end);
      }
      // Navegar para o Extrato (tab 1)
      ref.read(mainTabIndexProvider.notifier).state = 1;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 340;
          final iconSize = isCompact ? 32.0 : 38.0;
          final catFontSize = isCompact ? 13.0 : 15.0;
          final pctFontSize = isCompact ? 13.0 : 15.0;
          final hPad = isCompact ? 10.0 : 14.0;
          final rPad = isCompact ? 6.0 : 10.0;
          final iconSpacing = isCompact ? 8.0 : 12.0;

          return InkWell(
            onTap: navigateToTransactions,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              padding: EdgeInsets.fromLTRB(hPad, 14, rPad, 14),
              child: Column(
                children: [
                  // ── Header: icon + name + percentage + actions ──
                  Row(
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(catIcon,
                            size: isCompact ? 17.0 : 20.0, color: catColor),
                      ),
                      SizedBox(width: iconSpacing),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    budget.categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: catFontSize),
                                  ),
                                ),
                                if (isSynthetic) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message:
                                        'Soma dos orçamentos mensais existentes deste ano.',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: cs.outlineVariant),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.functions_rounded,
                                              size: 11,
                                              color: cs.onSurfaceVariant),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Mensal',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${fmt(summary.spentAmount)} / ${fmt(summary.effectiveLimit)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            if (summary.carryIn != 0) ...[
                              const SizedBox(height: 1),
                              Text(
                                AppLocalizations.of(context).budgetCarriedOver(
                                    fmt(summary.carryIn)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: summary.carryIn > 0
                                      ? const Color(0xFF00A86B)
                                      : cs.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${summary.percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: pctColor,
                          fontWeight: FontWeight.bold,
                          fontSize: pctFontSize,
                        ),
                      ),
                      if (!isSynthetic) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              color: cs.primary, size: 20),
                          onPressed: () => showAnimatedDialog(
                            context: context,
                            builder: (_) => _AddBudgetDialog(
                              month: budget.month,
                              period: budget.period,
                              budget: budget,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: cs.error, size: 20),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Excluir orçamento'),
                                content: Text(
                                    'Deseja excluir o orçamento de "${budget.categoryName}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Theme.of(ctx)
                                            .colorScheme
                                            .error),
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              ref
                                  .read(budgetNotifierProvider.notifier)
                                  .delete(budget.id);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // ── Status progress bar ──
                  _StatusProgressBar(
                    progress: summary.progress,
                    isOverBudget: summary.isOverBudget,
                    height: 10,
                  ),
                  const SizedBox(height: 8),
                  // ── Remaining label ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        summary.isOverBudget
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 14,
                        color: pctColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          summary.isOverBudget
                              ? '${l10n.budgetExceeded} ${fmt(summary.remaining.abs())}'
                              : '${l10n.budgetRemaining}: ${fmt(summary.remaining)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: pctColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$periodTransactions lançamento${periodTransactions != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Ver',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 14, color: cs.primary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyBudgets extends ConsumerWidget {
  final DateTime month;
  final BudgetPeriod viewMode;

  const _EmptyBudgets({required this.month, required this.viewMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    final isLoading = ref.watch(budgetNotifierProvider).isLoading;
    final periodLabel = _periodLabel(month, viewMode, dateLoc);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            '${l10n.noBudgetsForMonth}\n$periodLabel',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.post_add_outlined, size: 18),
            label: Text(l10n.createBudgets),
            onPressed: isLoading
                ? null
                : () => _onCreatePressed(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreatePressed(BuildContext context, WidgetRef ref) async {
    // For period views, jump straight to the add dialog: copy-from-previous
    // and base-on-spending are monthly-only flows.
    if (viewMode != BudgetPeriod.monthly) {
      await showAnimatedDialog(
        context: context,
        builder: (_) => _AddBudgetDialog(month: month, period: viewMode),
      );
      return;
    }
    await _showCopyOptionsDialog(context, ref);
  }

  Future<void> _showCopyOptionsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.read(dateLocaleProvider);
    final currentMonthLabel =
        DateFormat('MMMM yyyy', dateLoc).format(month).capitalizeMonth();

    final choice = await showAnimatedDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.createBudgetsFor} $currentMonthLabel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BudgetOptionTile(
              icon: Icons.copy_outlined,
              title: l10n.copyPrevLimits,
              subtitle: l10n.copyPrevLimitsDesc,
              onTap: () => Navigator.of(ctx).pop('copy'),
            ),
            const SizedBox(height: 8),
            _BudgetOptionTile(
              icon: Icons.insights_outlined,
              title: l10n.baseOnSpending,
              subtitle: l10n.baseOnSpendingDesc,
              onTap: () => Navigator.of(ctx).pop('spending'),
            ),
            const SizedBox(height: 8),
            _BudgetOptionTile(
              icon: Icons.auto_awesome_outlined,
              title: 'Orçamento ideal',
              subtitle: 'Sugestão baseada na sua receita (regra 50/30/20)',
              onTap: () => Navigator.of(ctx).pop('ideal'),
            ),
            const SizedBox(height: 8),
            _BudgetOptionTile(
              icon: Icons.add_circle_outline,
              title: l10n.createManually,
              subtitle: l10n.createManuallyDesc,
              onTap: () => Navigator.of(ctx).pop('manual'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'manual') {
      await showAnimatedDialog(
        context: context,
        builder: (_) => _AddBudgetDialog(month: month, period: viewMode),
      );
      return;
    }

    if (choice == 'ideal') {
      await showAnimatedDialog(
        context: context,
        builder: (_) => _IdealBudgetDialog(month: month),
      );
      return;
    }

    // Ask the user which month to use as reference
    final sourceMonth = await _pickSourceMonth(context, ref);
    if (sourceMonth == null || !context.mounted) return;

    if (choice == 'copy') {
      // Fetch budgets for the chosen source month
      final budgets =
          await ref.read(budgetsForMonthProvider(sourceMonth).future);
      if (!context.mounted) return;
      if (budgets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Nenhum orçamento encontrado no mês selecionado.')),
        );
        return;
      }
      final success = await ref
          .read(budgetNotifierProvider.notifier)
          .copyFromPreviousMonth(
            previousBudgets: budgets,
            targetMonth: month,
          );
      if (!context.mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorReplicating)),
        );
      }
    } else {
      // Build budgets from expense categories with spending in the chosen month
      final allTransactions = ref.read(visibleTransactionsProvider);
      final expenseCategories = ref.read(expenseCategoriesProvider);
      final spending = <String, double>{};
      for (final t in allTransactions) {
        if (t.isExpense &&
            t.date.year == sourceMonth.year &&
            t.date.month == sourceMonth.month) {
          spending[t.category] = (spending[t.category] ?? 0.0) + t.amount;
        }
      }
      final categoryByName = {for (final c in expenseCategories) c.name: c};
      final spendingBudgets = spending.entries
          .map((entry) {
            final category = categoryByName[entry.key];
            if (category == null) return null;
            return BudgetEntity(
              id: '',
              userId: '',
              categoryId: category.id,
              categoryName: category.name,
              limitAmount: entry.value,
              month: month,
            );
          })
          .whereType<BudgetEntity>()
          .toList();
      if (spendingBudgets.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorReplicating)),
          );
        }
        return;
      }
      final success = await ref
          .read(budgetNotifierProvider.notifier)
          .copyFromPreviousMonth(
            previousBudgets: spendingBudgets,
            targetMonth: month,
          );
      if (!context.mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorReplicating)),
        );
      }
    }
  }

  Future<DateTime?> _pickSourceMonth(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.read(dateLocaleProvider);

    // Default: previous month relative to target
    final prevMonth = DateTime(month.year, month.month - 1, 1);
    int selectedMonth = prevMonth.month;
    int selectedYear = prevMonth.year;

    // Year range: 5 years back from current target month year
    final years = List.generate(6, (i) => month.year - i);
    final monthNames = List.generate(
      12,
      (i) => DateFormat('MMMM', dateLoc)
          .format(DateTime(2000, i + 1))
          .capitalizeMonth(),
    );

    return showAnimatedDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.selectSourceMonth),
          content: Row(
            children: [
              // Month dropdown
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(monthNames[i]),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedMonth = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Year dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  items: years
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedYear = v);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(DateTime(selectedYear, selectedMonth, 1)),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Budget Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _AddBudgetDialog extends ConsumerStatefulWidget {
  final DateTime month;
  final BudgetPeriod period;

  /// When provided the dialog opens in edit mode pre-filled with this budget.
  final BudgetEntity? budget;

  const _AddBudgetDialog({
    required this.month,
    this.period = BudgetPeriod.monthly,
    this.budget,
  });

  @override
  ConsumerState<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends ConsumerState<_AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  CategoryEntity? _selectedCategory;
  bool _isAnnual = false;
  bool _rollover = false;

  /// For annual: true → apply to the full year (Jan–Dec). false → apply only
  /// from the current month forward.
  bool _annualFullYear = true;

  /// For quarterly / semestral: when true, replicate the same limit across
  /// the remaining periods of the same year after creation.
  bool _replicateToYear = false;

  bool get _isEditing => widget.budget != null;
  bool get _isMonthly => widget.period == BudgetPeriod.monthly;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _amountController.text = doubleToMoneyText(widget.budget!.limitAmount);
      _isAnnual = widget.budget!.isAnnual;
      _rollover = widget.budget!.rollover;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showAnimatedDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.deleteBudget),
          content: Text(l10n.deleteBudgetConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final success = await ref
        .read(budgetNotifierProvider.notifier)
        .delete(widget.budget!.id);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectCategory)),
      );
      return;
    }
    final amount = moneyTextToDouble(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidAmount)),
      );
      return;
    }

    final notifier = ref.read(budgetNotifierProvider.notifier);
    bool success = false;

    if (_isEditing) {
      // For edits, keep the period of the existing budget. If the user
      // changed the category, delete the old entry first.
      final old = widget.budget!;
      if (_selectedCategory!.id != old.categoryId) {
        await notifier.delete(old.id);
      }
      success = await notifier.set(
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        limitAmount: amount,
        month: old.month,
        period: old.period,
        isAnnual: old.isAnnual,
        parentBudgetId: old.parentBudgetId,
        rollover: old.period == BudgetPeriod.monthly && _rollover,
      );
    } else if (_isMonthly) {
      success = await notifier.set(
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        limitAmount: amount,
        month: widget.month,
        isAnnual: _isAnnual,
        rollover: _rollover,
      );
    } else {
      // Period budget creation (quarterly / semestral / annual).
      final period = widget.period;
      final periodStart = normalizePeriodStart(widget.month, period);
      final today = DateTime(DateTime.now().year, DateTime.now().month, 1);

      // For annual budgets, the user can choose to cover only the rest of
      // the year (starting at the current month) instead of the whole year.
      DateTime effectiveStart = periodStart;
      if (period == BudgetPeriod.annual && !_annualFullYear) {
        if (today.year == periodStart.year && today.month > periodStart.month) {
          effectiveStart = today;
        }
      }

      success = await notifier.createPeriodBudget(
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        limitAmount: amount,
        year: periodStart.year,
        period: period,
        startMonth: effectiveStart,
      );

      // Replicate to remaining periods of the same year on user request.
      if (success && _replicateToYear) {
        success = await _replicateAcrossYear(
          notifier: notifier,
          baseStart: periodStart,
          period: period,
          amount: amount,
        );
      }
    }

    if (!mounted) return;
    if (success) Navigator.of(context).pop();
  }

  Future<bool> _replicateAcrossYear({
    required dynamic notifier,
    required DateTime baseStart,
    required BudgetPeriod period,
    required double amount,
  }) async {
    final year = baseStart.year;
    final stepMonths = period.monthSpan;
    final firstStartMonth = period == BudgetPeriod.quarterly
        ? 1
        : period == BudgetPeriod.semestral
            ? 1
            : 1;

    for (var m = firstStartMonth; m <= 12; m += stepMonths) {
      if (m == baseStart.month) continue; // skip the one we just created
      final startMonth = DateTime(year, m, 1);
      final ok = await notifier.createPeriodBudget(
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        limitAmount: amount,
        year: year,
        period: period,
        startMonth: startMonth,
      );
      if (!(ok as bool)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    final expenseCategories = ref.watch(expenseCategoriesProvider);
    final isLoading = ref.watch(budgetNotifierProvider).isLoading;

    // Pre-select the matching category when editing.
    if (_isEditing &&
        _selectedCategory == null &&
        expenseCategories.isNotEmpty) {
      _selectedCategory = expenseCategories.firstWhere(
        (c) => c.id == widget.budget!.categoryId,
        orElse: () => expenseCategories.first,
      );
    }

    final periodLabel = _periodLabel(widget.month, widget.period, dateLoc);
    final title = _isEditing
        ? l10n.editBudget
        : '${l10n.newBudget}$periodLabel';

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CategoryEntity>(
                key: ValueKey(_selectedCategory?.id),
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: l10n.categoryField,
                  border: const OutlineInputBorder(),
                ),
                items: expenseCategories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) =>
                    v == null ? l10n.selectCategory : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                decoration: InputDecoration(
                  labelText: _isAnnual ? 'Limite anual' : l10n.limit,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.enterAmount;
                  if (moneyTextToDouble(v) <= 0) return l10n.invalidAmount;
                  return null;
                },
              ),
              if (widget.period == BudgetPeriod.monthly) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _rollover,
                  onChanged: (v) => setState(() => _rollover = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l10n.budgetRollover),
                  subtitle: Text(
                    l10n.budgetRolloverDesc,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
              if (!_isEditing && widget.period == BudgetPeriod.annual) ...[
                const SizedBox(height: 12),
                _AnnualScopeSelector(
                  fullYear: _annualFullYear,
                  onChanged: (v) => setState(() => _annualFullYear = v),
                ),
              ],
              if (!_isEditing &&
                  (widget.period == BudgetPeriod.quarterly ||
                      widget.period == BudgetPeriod.semestral)) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _replicateToYear,
                  onChanged: (v) =>
                      setState(() => _replicateToYear = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    widget.period == BudgetPeriod.quarterly
                        ? 'Aplicar aos demais trimestres do ano'
                        : 'Aplicar ao outro semestre do ano',
                  ),
                  subtitle: Text(
                    'Cria o mesmo limite para os demais períodos de ${widget.month.year}.',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
              if (_isEditing) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.error),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label:
                      Text(AppLocalizations.of(context).deleteBudget),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Annual-scope selector — "full year" vs "from now to the end of the year"
// ─────────────────────────────────────────────────────────────────────────────

class _AnnualScopeSelector extends StatelessWidget {
  final bool fullYear;
  final ValueChanged<bool> onChanged;

  const _AnnualScopeSelector({
    required this.fullYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Aplicar a',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ScopeChip(
                label: 'Ano inteiro',
                isSelected: fullYear,
                onTap: () => onChanged(true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScopeChip(
                label: 'Restante do ano',
                isSelected: !fullYear,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScopeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest,
          border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? cs.primary : cs.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option tile used inside the copy/spending choice dialog
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BudgetOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-Status Progress Bar — empty / green / red
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the status color for a budget item.
/// - Gray  → no spending yet
/// - Green → within budget
/// - Red   → over budget
Color _statusColor(double progress, bool isOverBudget) {
  if (progress <= 0.001) return Colors.grey.shade400;
  if (isOverBudget) return Colors.red.shade600;
  return Colors.green.shade500;
}

/// 3-state animated progress bar.
///
/// - **Empty**  (progress ≈ 0): shows only the gray track.
/// - **Green**  (progress > 0 and not over): green fill.
/// - **Red**    (isOverBudget): red fill (clamped to 100% visually).
class _StatusProgressBar extends StatelessWidget {
  final double progress; // 0.0–1.0 (clamped ratio)
  final bool isOverBudget;
  final double height;

  const _StatusProgressBar({
    required this.progress,
    required this.isOverBudget,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trackColor = cs.surfaceContainerHighest;
    final radius = BorderRadius.circular(height / 2);

    if (progress <= 0.001) {
      return Container(
        height: height,
        decoration: BoxDecoration(color: trackColor, borderRadius: radius),
      );
    }

    final fillColor =
        isOverBudget ? Colors.red.shade600 : Colors.green.shade500;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Container(
                height: height,
                width: double.infinity,
                color: trackColor,
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(height: height, color: fillColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Staggered list animation wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedListItem({required this.child, required this.index});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = Duration(milliseconds: 55 * widget.index.clamp(0, 8));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add-budget button rendered at the bottom of the budget list
// ─────────────────────────────────────────────────────────────────────────────

class _AddBudgetButton extends StatelessWidget {
  final DateTime month;
  final BudgetPeriod viewMode;

  const _AddBudgetButton({required this.month, required this.viewMode});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: OutlinedButton.icon(
        onPressed: () => showAnimatedDialog(
          context: context,
          builder: (_) => _AddBudgetDialog(month: month, period: viewMode),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.budget),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ideal Budget Dialog — generates budgets from monthly income (50/30/20-style)
// ─────────────────────────────────────────────────────────────────────────────

class _IdealBudgetDialog extends ConsumerStatefulWidget {
  final DateTime month;

  const _IdealBudgetDialog({required this.month});

  @override
  ConsumerState<_IdealBudgetDialog> createState() => _IdealBudgetDialogState();
}

class _IdealBudgetDialogState extends ConsumerState<_IdealBudgetDialog> {
  final _incomeCtrl = TextEditingController();
  bool _showPreview = false;
  bool _creating = false;

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  double get _income => moneyTextToDouble(_incomeCtrl.text);

  Future<void> _create() async {
    final income = _income;
    if (income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma receita válida.')),
      );
      return;
    }

    setState(() => _creating = true);

    final ownerId = ref.read(ledgerOwnerIdProvider);
    final existingCategories = ref.read(expenseCategoriesProvider);
    final categoriesByName = {
      for (final c in existingCategories) c.name.toLowerCase().trim(): c,
    };

    int created = 0;
    int failed = 0;

    for (final item in kIdealBudgetTemplate) {
      final lookup = item.categoryName.toLowerCase().trim();
      var category = categoriesByName[lookup];

      // If the category doesn't exist yet, create it.
      if (category == null) {
        final ok = await ref.read(categoriesNotifierProvider.notifier).add(
              userId: ownerId,
              name: item.categoryName,
              type: CategoryType.expense,
              iconCodePoint: _iconForCategory(item.categoryName).codePoint,
              colorValue: _colorForGroup(item.group),
            );
        if (!ok) {
          failed++;
          continue;
        }
        // Re-read categories after add
        final refreshed = ref.read(expenseCategoriesProvider);
        category = refreshed.firstWhere(
          (c) => c.name.toLowerCase().trim() == lookup,
          orElse: () => refreshed.last,
        );
      }

      final ok = await ref.read(budgetNotifierProvider.notifier).set(
            categoryId: category.id,
            categoryName: category.name,
            limitAmount: item.amountFor(income),
            month: widget.month,
          );
      if (ok) {
        created++;
      } else {
        failed++;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failed == 0
            ? '$created orçamentos criados com sucesso!'
            : '$created criados, $failed falharam.'),
        backgroundColor: failed == 0 ? Colors.green.shade700 : Colors.orange.shade800,
      ),
    );
  }

  static IconData _iconForCategory(String name) {
    switch (name.toLowerCase()) {
      case 'moradia':
        return Icons.home;
      case 'alimentação':
        return Icons.restaurant;
      case 'transporte':
        return Icons.directions_car;
      case 'saúde':
        return Icons.local_hospital;
      case 'lazer':
        return Icons.sports_esports;
      case 'educação':
        return Icons.school;
      case 'vestuário':
        return Icons.checkroom;
      default:
        return Icons.category;
    }
  }

  static int _colorForGroup(String group) {
    switch (group) {
      case 'Necessidades':
        return 0xFF4CAF50; // green
      case 'Desejos':
        return 0xFFFF9800; // orange
      default:
        return 0xFF607D8B; // grey-blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = ref.watch(currencyFormatterProvider);
    final income = _income;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Orçamento Ideal'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informe sua receita mensal e geraremos um orçamento ideal '
              'baseado na regra 50/30/20 (necessidades, desejos e poupança).',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _incomeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Receita mensal',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _showPreview = _income > 0),
            ),
            if (_showPreview && income > 0) ...[
              const SizedBox(height: 16),
              Text(
                'Distribuição sugerida',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...kIdealBudgetTemplate.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(_colorForGroup(item.group)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.categoryName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${item.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          fmt(item.amountFor(income)),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.savings_outlined, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Poupança/Investimentos',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${kIdealSavingsPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fmt(income * kIdealSavingsPercent / 100),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: (_creating || income <= 0) ? null : _create,
          icon: _creating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Criar'),
        ),
      ],
    );
  }
}
