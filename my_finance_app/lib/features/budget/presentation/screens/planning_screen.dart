import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/providers/selected_month_provider.dart';
import '../../../../core/utils/animated_dialog.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/categories_provider.dart';
import '../../../../core/utils/money_input_formatter.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../recurring/presentation/screens/recurring_screen.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/entities/budget_entity.dart';
import '../providers/budget_provider.dart';

class PlanningScreen extends ConsumerWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final summaries = ref.watch(budgetSummaryProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    final sortedSummaries = [...summaries]
      ..sort((a, b) =>
          a.budget.categoryName.compareTo(b.budget.categoryName));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.planning),
          centerTitle: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Orçamentos'),
              Tab(text: 'Metas'),
              Tab(text: 'Recorrências'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ── Orçamentos tab ─────────────────────────────────────
            ProGateWidget(
              featureName: 'Orçamentos',
              featureDescription: 'Defina limites por categoria e controle seus gastos.',
              featureIcon: Icons.pie_chart_outline_rounded,
              child: Column(
                children: [
                  _MonthSelector(month: selectedMonth),
                  Expanded(
                    child: budgetsAsync.when(
                      data: (_) => sortedSummaries.isEmpty
                          ? _EmptyBudgets(month: selectedMonth)
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: sortedSummaries.length + 2,
                              itemBuilder: (ctx, i) {
                                if (i == 0) {
                                  return _AnimatedListItem(
                                    index: 0,
                                    child: _BudgetSummaryCard(
                                        summaries: sortedSummaries),
                                  );
                                }
                                if (i == sortedSummaries.length + 1) {
                                  return _AnimatedListItem(
                                    index: i,
                                    child: _AddBudgetButton(month: selectedMonth),
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
              featureDescription: 'Cadastre transações automáticas que se repetem todo mês.',
              featureIcon: Icons.repeat_rounded,
              child: RecurringScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  final DateTime month;

  const _MonthSelector({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLoc = ref.watch(dateLocaleProvider);
    final label = DateFormat('MMMM yyyy', dateLoc).format(month).capitalizeMonth();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1, 1),
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
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month + 1, 1),
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

  const _BudgetSummaryCard({required this.summaries});

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
              l10n.budgetSummaryTitle,
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

    // Try to find the category to get icon & color
    final categories = ref.watch(expenseCategoriesProvider);
    final cat = categories.cast<CategoryEntity?>().firstWhere(
          (c) => c!.id == budget.categoryId,
          orElse: () => null,
        );
    final catIcon =
        cat != null ? (kCategoryIconMap[cat.iconCodePoint] ?? Icons.category) : Icons.category;
    final catColor = cat != null ? Color(cat.colorValue) : cs.primary;

    // Count transactions for this category
    final allTransactions = ref.watch(transactionsStreamProvider).value ?? [];
    final monthTransactions = allTransactions
        .where((t) =>
            t.category == budget.categoryName &&
            t.date.year == budget.month.year &&
            t.date.month == budget.month.month &&
            t.isExpense)
        .length;

    void navigateToTransactions() {
      // Reset filters irrelevantes
      ref.read(statementTypeFilterProvider.notifier).state = null;
      ref.read(statementDateRangeProvider.notifier).state = null;
      ref.read(statementIsAnnualProvider.notifier).state = false;
      // Aplicar categoria e mês do orçamento
      ref.read(statementCategoryFilterProvider.notifier).state = {budget.categoryName};
      ref.read(selectedMonthProvider.notifier).state = budget.month;
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
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
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
                      child: Icon(catIcon, size: isCompact ? 17.0 : 20.0, color: catColor),
                    ),
                    SizedBox(width: iconSpacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget.categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: catFontSize),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${fmt(budget.limitAmount)} / ${fmt(summary.spentAmount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                          ),
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
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          color: cs.primary, size: 20),
                      onPressed: () => showAnimatedDialog(
                        context: context,
                        builder: (_) => _AddBudgetDialog(
                          month: budget.month,
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
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(ctx).colorScheme.error),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Excluir'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          ref.read(budgetNotifierProvider.notifier).delete(budget.id);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
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
                          '$monthTransactions lançamento${monthTransactions != 1 ? 's' : ''}',
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

  const _EmptyBudgets({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    final isLoading = ref.watch(budgetNotifierProvider).isLoading;
    final currentMonthLabel = DateFormat('MMMM yyyy', dateLoc).format(month).capitalizeMonth();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            '${l10n.noBudgetsForMonth}\n$currentMonthLabel',
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
                : () => _showCopyOptionsDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showCopyOptionsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.read(dateLocaleProvider);
    final currentMonthLabel = DateFormat('MMMM yyyy', dateLoc).format(month).capitalizeMonth();

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
        builder: (_) => _AddBudgetDialog(month: month),
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
              content: Text('Nenhum orçamento encontrado no mês selecionado.')),
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
    final years =
        List.generate(6, (i) => month.year - i);
    final monthNames = List.generate(
      12,
      (i) => DateFormat('MMMM', dateLoc).format(DateTime(2000, i + 1)).capitalizeMonth(),
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
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

  /// When provided the dialog opens in edit mode pre-filled with this budget.
  final BudgetEntity? budget;

  const _AddBudgetDialog({required this.month, this.budget});

  @override
  ConsumerState<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends ConsumerState<_AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  CategoryEntity? _selectedCategory;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _amountController.text = doubleToMoneyText(widget.budget!.limitAmount);
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
    final success =
        await ref.read(budgetNotifierProvider.notifier).delete(widget.budget!.id);
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
    bool success;

    if (_isEditing &&
        _selectedCategory!.id != widget.budget!.categoryId) {
      // Category changed — delete old budget then create new one.
      await notifier.delete(widget.budget!.id);
      success = await notifier.set(
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        limitAmount: amount,
        month: widget.month,
      );
    } else {
      // Create or update (upsert by categoryId+month key).
      success = await notifier.set(
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        limitAmount: amount,
        month: widget.month,
      );
    }

    if (!mounted) return;
    if (success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateLoc = ref.watch(dateLocaleProvider);
    final expenseCategories = ref.watch(expenseCategoriesProvider);
    final isLoading = ref.watch(budgetNotifierProvider).isLoading;

    // Pre-select the matching category when editing.
    if (_isEditing && _selectedCategory == null && expenseCategories.isNotEmpty) {
      _selectedCategory = expenseCategories.firstWhere(
        (c) => c.id == widget.budget!.categoryId,
        orElse: () => expenseCategories.first,
      );
    }

    final title = _isEditing
        ? l10n.editBudget
        : '${l10n.newBudget}${DateFormat('MMM yyyy', dateLoc).format(widget.month).capitalizeMonth()}';

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
                  labelText: l10n.limit,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.enterAmount;
                  if (moneyTextToDouble(v) <= 0) return l10n.invalidAmount;
                  return null;
                },
              ),
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
                  label: Text(AppLocalizations.of(context).deleteBudget),
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
// Add-budget button rendered at the bottom of the budget list
// ─────────────────────────────────────────────────────────────────────────────

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
  final double progress;    // 0.0–1.0 (clamped ratio)
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

  const _AddBudgetButton({required this.month});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: OutlinedButton.icon(
        onPressed: () => showAnimatedDialog(
          context: context,
          builder: (_) => _AddBudgetDialog(month: month),
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
