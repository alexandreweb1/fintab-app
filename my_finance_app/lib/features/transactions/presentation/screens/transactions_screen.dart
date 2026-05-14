import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/widgets/pro_gate_widget.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../wallets/presentation/widgets/wallet_buckets_widgets.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transactions_provider.dart';
import '../widgets/transaction_list_tile.dart';
import '../widgets/transaction_table.dart';

// Number of months to show in the quick picker
const _kPickerMonths = 24;

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  late final TabController _tabController;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _selectedTab = _tabController.index);
      if (_tabController.index != 0 && _isSearching) _closeSearch();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
    Future.microtask(() => _searchFocus.requestFocus());
  }

  void _closeSearch() {
    setState(() => _isSearching = false);
    _searchController.clear();
    ref.read(statementSearchQueryProvider.notifier).state = '';
    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(currencyFormatterProvider);
    final dateLoc = ref.watch(dateLocaleProvider);
    final selectedMonth = ref.watch(transactionsSelectedMonthProvider);
    final isAnnual = ref.watch(statementIsAnnualProvider);
    final dateRange = ref.watch(statementDateRangeProvider);
    final hasFilters = ref.watch(statementHasFiltersProvider);
    final activeFilterCount = ref.watch(statementActiveFilterCountProvider);
    final searchQuery = ref.watch(statementSearchQueryProvider);

    final income = ref.watch(statementDisplayIncomeProvider);
    final expense = ref.watch(statementDisplayExpenseProvider);
    final balance = income - expense;
    final txs = ref.watch(statementDisplayTransactionsProvider);

    // Label: full year in annual mode, month+year in monthly mode
    final periodLabel = isAnnual
        ? selectedMonth.year.toString()
        : DateFormat('MMMM yyyy', dateLoc).format(selectedMonth).capitalizeMonth();

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStatement),
        centerTitle: false,
        actions: _selectedTab == 0
            ? [
                IconButton(
                  tooltip: 'Pesquisar lançamento',
                  icon: Icon(
                    _isSearching ? Icons.search_off : Icons.search,
                    color: _isSearching ? cs.primary : null,
                  ),
                  onPressed: _isSearching ? _closeSearch : _openSearch,
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: l10n.moreOptions,
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'dateRange':
                            _showDateRangePicker(context, ref);
                          case 'annual':
                            if (!isAnnual && !ref.read(isProProvider)) {
                              showProGateBottomSheet(
                                context,
                                featureName: 'Visão Anual',
                                featureDescription:
                                    'Analise todas as suas transações do ano de uma vez.',
                                featureIcon: Icons.calendar_month_rounded,
                              );
                              return;
                            }
                            ref.read(statementIsAnnualProvider.notifier).state =
                                !isAnnual;
                          case 'filters':
                            _showFilterSheet(context);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'dateRange',
                          child: _MenuItemRow(
                            icon: Icons.date_range_rounded,
                            label: l10n.customPeriod,
                            active: dateRange != null,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'annual',
                          enabled: dateRange == null,
                          child: _MenuItemRow(
                            icon: isAnnual
                                ? Icons.calendar_view_day_outlined
                                : Icons.calendar_month_outlined,
                            label: isAnnual ? l10n.monthlyView : l10n.annualView,
                            disabled: dateRange != null,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'filters',
                          child: _MenuItemRow(
                            icon: Icons.tune_rounded,
                            label: l10n.filterTitle,
                            active: hasFilters,
                            badge: hasFilters ? '$activeFilterCount' : null,
                          ),
                        ),
                      ],
                    ),
                    if (hasFilters || dateRange != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IgnorePointer(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Quando a tela é larga o suficiente, distribui as 4 abas
              // ocupando toda a largura. Em telas menores, vira rolável
              // para evitar quebra/overflow do texto.
              final fits = constraints.maxWidth >= 380;
              return TabBar(
                controller: _tabController,
                isScrollable: !fits,
                tabAlignment:
                    fits ? TabAlignment.fill : TabAlignment.center,
                labelPadding: fits
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [
                  Tab(text: 'Extrato'),
                  Tab(text: 'Reservas'),
                  Tab(text: 'Investimentos'),
                  Tab(text: 'Patrimônio'),
                ],
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Extrato ─────────────────────────────────────────────
          Column(
            children: [
              // ── Search bar ─────────────────────────────────────────────
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar por título...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(statementSearchQueryProvider.notifier)
                                    .state = '';
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      ref.read(statementSearchQueryProvider.notifier).state =
                          value;
                    },
                  ),
                ),

              // ── Period selector OR active date-range chip ───────────────
              if (dateRange != null)
                _DateRangeBar(dateRange: dateRange, dateLoc: dateLoc)
              else
                _PeriodSelector(
                  label: periodLabel,
                  isAnnual: isAnnual,
                  month: selectedMonth,
                  dateLoc: dateLoc,
                  onPrev: () => ref
                      .read(transactionsSelectedMonthProvider.notifier)
                      .state = DateTime(
                          selectedMonth.year, selectedMonth.month - 1, 1),
                  onNext: () => ref
                      .read(transactionsSelectedMonthProvider.notifier)
                      .state = DateTime(
                          selectedMonth.year, selectedMonth.month + 1, 1),
                  onPickMonth: () => _showMonthPicker(context, ref, dateLoc),
                ),

              // ── Summary card ────────────────────────────────────────────
              _SummaryCard(
                balance: balance,
                income: income,
                expense: expense,
                fmt: fmt,
              ),

              // ── Transaction list / table ─────────────────────────────────
              Expanded(
                child: txs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 56,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            const SizedBox(height: 12),
                            Text(
                              l10n.noTransactions,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 720) {
                            return TransactionTable(transactions: txs);
                          }
                          final items = _buildGroupedItems(txs);
                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: items.length,
                            itemBuilder: (ctx, i) {
                              final item = items[i];
                              if (item is _DayHeaderItem) {
                                return _DaySectionHeader(
                                  day: item.day,
                                  isFirst: i == 0,
                                );
                              }
                              return TransactionListTile(
                                transaction: (item as _TxItem).transaction,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),

          // ── Tab 1: Reservas ────────────────────────────────────────────
          const TypedWalletsTab(type: WalletType.reserve),

          // ── Tab 2: Investimentos ───────────────────────────────────────
          const TypedWalletsTab(type: WalletType.investment),

          // ── Tab 3: Patrimônio ──────────────────────────────────────────
          const _PatrimonioTab(),
        ],
      ),
    );
  }

  void _showDateRangePicker(BuildContext context, WidgetRef ref) {
    if (!ref.read(isProProvider)) {
      showProGateBottomSheet(
        context,
        featureName: 'Período Personalizado',
        featureDescription:
            'Filtre suas transações por qualquer intervalo de datas.',
        featureIcon: Icons.date_range_rounded,
      );
      return;
    }

    final current = ref.read(statementDateRangeProvider);
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: current != null
          ? DateTimeRange(start: current.$1, end: current.$2)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    ).then((picked) {
      if (picked != null) {
        ref.read(statementDateRangeProvider.notifier).state =
            (picked.start, picked.end);
      }
    });
  }

  void _showMonthPicker(
      BuildContext context, WidgetRef ref, String dateLoc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MonthPickerSheet(dateLoc: dateLoc),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }
}

// ─── Grouping helpers (statement list by day) ─────────────────────────────────
sealed class _ListItem {
  const _ListItem();
}

class _DayHeaderItem extends _ListItem {
  final DateTime day;
  const _DayHeaderItem(this.day);
}

class _TxItem extends _ListItem {
  final TransactionEntity transaction;
  const _TxItem(this.transaction);
}

List<_ListItem> _buildGroupedItems(List<TransactionEntity> txs) {
  // Sort newest first, then group by calendar day.
  final sorted = [...txs]..sort((a, b) => b.date.compareTo(a.date));
  final items = <_ListItem>[];
  DateTime? currentDay;
  for (final t in sorted) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      items.add(_DayHeaderItem(day));
    }
    items.add(_TxItem(t));
  }
  return items;
}

// ─── Day Section Header ───────────────────────────────────────────────────────
class _DaySectionHeader extends StatelessWidget {
  final DateTime day;
  final bool isFirst;

  const _DaySectionHeader({
    required this.day,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final dayStr = DateFormat('dd/MM').format(day);
    String prefix;
    if (day == today) {
      prefix = 'HOJE';
    } else if (day == yesterday) {
      prefix = 'ONTEM';
    } else {
      prefix = '';
    }

    final label = prefix.isEmpty ? dayStr : '$prefix · $dayStr';
    final isHighlight = prefix.isNotEmpty;

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 390;
    final hMargin = isCompact ? 12.0 : 20.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        hMargin,
        isFirst ? 4 : 12,
        hMargin,
        6,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isHighlight ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─── Popup Menu Item Row ───────────────────────────────────────────────────────
class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool disabled;
  final String? badge;

  const _MenuItemRow({
    required this.icon,
    required this.label,
    this.active = false,
    this.disabled = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = disabled
        ? cs.onSurface.withValues(alpha: 0.38)
        : active
            ? cs.primary
            : cs.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: disabled ? cs.onSurface.withValues(alpha: 0.38) : null,
            ),
          ),
        ),
        if (active && badge == null)
          Icon(Icons.check_rounded, size: 16, color: cs.primary),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 10,
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Active Date Range Bar ─────────────────────────────────────────────────────
class _DateRangeBar extends ConsumerWidget {
  final (DateTime, DateTime) dateRange;
  final String dateLoc;

  const _DateRangeBar({required this.dateRange, required this.dateLoc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (start, end) = dateRange;
    final fmt = DateFormat('d MMM yy', dateLoc);
    final label = '${fmt.format(start).capitalizeMonth()} – ${fmt.format(end).capitalizeMonth()}';
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.date_range_rounded,
              size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () =>
                ref.read(statementDateRangeProvider.notifier).state = null,
            icon: const Icon(Icons.close, size: 16),
            label: Text(AppLocalizations.of(context).clear, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Period Selector Bar ──────────────────────────────────────────────────────
class _PeriodSelector extends ConsumerWidget {
  final String label;
  final bool isAnnual;
  final DateTime month;
  final String dateLoc;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickMonth;

  const _PeriodSelector({
    required this.label,
    required this.isAnnual,
    required this.month,
    required this.dateLoc,
    required this.onPrev,
    required this.onNext,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isAnnual) {
      // Annual mode: single row with year navigation
      final isCurrentYear = month.year == DateTime.now().year;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => ref
                  .read(transactionsSelectedMonthProvider.notifier)
                  .state = DateTime(month.year - 1, month.month, 1),
            ),
            SizedBox(
              width: 72,
              child: Center(
                child: Text(
                  month.year.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: isCurrentYear ? null : () => ref
                  .read(transactionsSelectedMonthProvider.notifier)
                  .state = DateTime(month.year + 1, month.month, 1),
            ),
          ],
        ),
      );
    }

    // Monthly mode: prev / tap-to-pick / next
    final isCurrentMonth = month.year == DateTime.now().year &&
        month.month == DateTime.now().month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          InkWell(
            onTap: onPickMonth,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isCurrentMonth ? null : onNext,
          ),
        ],
      ),
    );
  }
}

// ─── Month Picker Bottom Sheet ────────────────────────────────────────────────
class _MonthPickerSheet extends ConsumerWidget {
  final String dateLoc;

  const _MonthPickerSheet({required this.dateLoc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedMonth = ref.watch(transactionsSelectedMonthProvider);
    final now = DateTime.now();

    // Build list of months newest → oldest
    final months = List.generate(_kPickerMonths, (i) {
      return DateTime(now.year, now.month - i, 1);
    });

    // Group by year
    final Map<int, List<DateTime>> byYear = {};
    for (final m in months) {
      byYear.putIfAbsent(m.year, () => []).add(m);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  l10n.selectMonth,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Month grid scrollable
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: years.map((year) {
                final yearMonths = byYear[year]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: yearMonths.map((month) {
                        final isSelected =
                            month.year == selectedMonth.year &&
                                month.month == selectedMonth.month;
                        final isFuture = month.isAfter(DateTime(
                            now.year, now.month, now.day));
                        final label =
                            DateFormat('MMM', dateLoc).format(month).capitalizeMonth();

                        return _MonthChip(
                          label: label,
                          isSelected: isSelected,
                          isFuture: isFuture,
                          onTap: isFuture
                              ? null
                              : () {
                                  ref
                                      .read(
                                          transactionsSelectedMonthProvider
                                              .notifier)
                                      .state = month;
                                  Navigator.of(context).pop();
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback? onTap;

  const _MonthChip({
    required this.label,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primary
          : isFuture
              ? colorScheme.surfaceContainer
              : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? colorScheme.onPrimary
                  : isFuture
                      ? Colors.grey.shade400
                      : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────
class _SummaryCard extends ConsumerWidget {
  final double balance;
  final double income;
  final double expense;
  final String Function(double) fmt;

  const _SummaryCard({
    required this.balance,
    required this.income,
    required this.expense,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isPositive = balance >= 0;
    final typeFilter = ref.watch(statementTypeFilterProvider);

    void toggleFilter(TransactionType type) {
      ref.read(statementTypeFilterProvider.notifier).state =
          typeFilter == type ? null : type;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 320;
          final vPad = isCompact ? 14.0 : 20.0;
          final hPad = isCompact ? 14.0 : 20.0;

          return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: Column(
          children: [
            Text(l10n.totalBalance,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fmt(balance),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isPositive
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: l10n.income,
                    value: fmt(income),
                    color: Colors.green.shade700,
                    icon: Icons.arrow_upward,
                    isActive: typeFilter == TransactionType.income,
                    onTap: () => toggleFilter(TransactionType.income),
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: l10n.expenses,
                    value: fmt(expense),
                    color: Colors.red.shade700,
                    icon: Icons.arrow_downward,
                    isActive: typeFilter == TransactionType.expense,
                    onTap: () => toggleFilter(TransactionType.expense),
                  ),
                ),
              ],
            ),
            // Active filter hint
            if (typeFilter != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_list_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    typeFilter == TransactionType.income
                        ? 'Mostrando apenas receitas · toque para limpar'
                        : 'Mostrando apenas despesas · toque para limpar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              )
            : const BoxDecoration(),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold),
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

// ─── Patrimônio Tab ───────────────────────────────────────────────────────────
class _PatrimonioTab extends ConsumerWidget {
  const _PatrimonioTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(currencyFormatterProvider);
    final balances = ref.watch(walletBalancesProvider);
    final walletsAsync = ref.watch(walletsStreamProvider);
    final cs = Theme.of(context).colorScheme;

    final wallets = walletsAsync.value ?? [];

    // Build list of (wallet, balance) pairs; include "Geral" if needed
    final List<({String id, String name, int iconCodePoint, int colorValue, double balance})> entries = [];

    final knownIds = <String>{};
    for (final w in wallets) {
      knownIds.add(w.id);
      entries.add((
        id: w.id,
        name: w.name,
        iconCodePoint: w.iconCodePoint,
        colorValue: w.colorValue,
        balance: balances[w.id] ?? 0.0,
      ));
    }

    // Transactions without a wallet (walletId == '')
    final geralBalance = balances[''] ?? 0.0;
    if (geralBalance != 0.0 || wallets.isEmpty) {
      entries.add((
        id: '',
        name: 'Geral',
        iconCodePoint: Icons.account_balance_wallet_outlined.codePoint,
        colorValue: cs.primary.toARGB32(),
        balance: geralBalance,
      ));
    }

    // Orphan balances: walletIds em transações que não existem mais (ex.: carteira excluída).
    // Agregadas em "Outros" para que a soma exibida bata com o Patrimônio Total.
    final outrosBalance = balances.entries
        .where((e) => e.key.isNotEmpty && !knownIds.contains(e.key))
        .fold<double>(0.0, (a, e) => a + e.value);
    if (outrosBalance != 0.0) {
      entries.add((
        id: '__outros__',
        name: 'Outros',
        iconCodePoint: Icons.help_outline.codePoint,
        colorValue: cs.onSurfaceVariant.toARGB32(),
        balance: outrosBalance,
      ));
    }

    final totalPatrimonio = entries.fold<double>(0.0, (a, e) => a + e.balance);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // ── Total card ───────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                Text(
                  'Patrimônio Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  fmt(totalPatrimonio),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: totalPatrimonio >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saldo acumulado de todas as carteiras',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Section title ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Saldo por carteira',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),

        // ── Wallet rows ──────────────────────────────────────────────────
        if (walletsAsync.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Nenhuma carteira encontrada.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ...entries.map((e) => _WalletBalanceTile(entry: e, fmt: fmt)),
      ],
    );
  }
}

class _WalletBalanceTile extends StatelessWidget {
  final ({
    String id,
    String name,
    int iconCodePoint,
    int colorValue,
    double balance
  }) entry;
  final String Function(double) fmt;

  const _WalletBalanceTile({required this.entry, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(entry.colorValue);
    final isPositive = entry.balance >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            categoryIcon(entry.iconCodePoint),
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          entry.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Saldo final',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Text(
          fmt(entry.balance),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ),
    );
  }
}

// ─── Filter Sheet ─────────────────────────────────────────────────────────────
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TransactionType? _type;
  late Set<String> _categories;
  late Set<String> _wallets;
  late Set<String> _selectedTags;
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = ref.read(statementTypeFilterProvider);
    _categories = Set.from(ref.read(statementCategoryFilterProvider));
    _wallets = Set.from(ref.read(statementWalletFilterProvider));
    _selectedTags = Set.from(ref.read(statementTagFilterProvider));
    final min = ref.read(statementMinAmountFilterProvider);
    final max = ref.read(statementMaxAmountFilterProvider);
    if (min != null) _minCtrl.text = _fmt(min);
    if (max != null) _maxCtrl.text = _fmt(max);
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  bool get _hasLocalFilters =>
      _type != null ||
      _categories.isNotEmpty ||
      _wallets.isNotEmpty ||
      _selectedTags.isNotEmpty ||
      _minCtrl.text.isNotEmpty ||
      _maxCtrl.text.isNotEmpty;

  void _apply() {
    ref.read(statementTypeFilterProvider.notifier).state = _type;
    ref.read(statementCategoryFilterProvider.notifier).state = _categories;
    ref.read(statementWalletFilterProvider.notifier).state = _wallets;
    ref.read(statementTagFilterProvider.notifier).state = _selectedTags;
    ref.read(statementMinAmountFilterProvider.notifier).state =
        _parse(_minCtrl.text);
    ref.read(statementMaxAmountFilterProvider.notifier).state =
        _parse(_maxCtrl.text);
    Navigator.of(context).pop();
  }

  void _clearAll() {
    setState(() {
      _type = null;
      _categories = <String>{};
      _wallets = <String>{};
      _selectedTags = <String>{};
      _minCtrl.clear();
      _maxCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    // Unique categories from ALL visible transactions
    final allTxs = ref.watch(visibleTransactionsProvider);
    final availableCategories =
        allTxs.map((t) => t.category).toSet().toList()..sort();

    // Wallets list
    final wallets = ref.watch(walletsStreamProvider).value ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  l10n.filterTitle,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (_hasLocalFilters)
                  TextButton(
                    onPressed: _clearAll,
                    child: Text(l10n.filterClearAll),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable content
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // ── Tipo ──
                _FilterSection(
                  title: l10n.filterType,
                  child: _TypeSelector(
                    selected: _type,
                    allLabel: l10n.filterAll,
                    incomeLabel: l10n.filterIncome,
                    expenseLabel: l10n.filterExpenses,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                ),

                // ── Categorias ──
                if (availableCategories.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _FilterSection(
                    title: l10n.filterCategories,
                    child: _MultiSelectDropdown(
                      placeholder: l10n.filterCategories,
                      options: availableCategories
                          .map((c) => _SelectOption(id: c, label: c))
                          .toList(),
                      selected: _categories,
                      onChanged: (v) => setState(() => _categories = v),
                    ),
                  ),
                ],

                // ── Carteiras ──
                if (wallets.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _FilterSection(
                    title: l10n.wallets,
                    child: _MultiSelectDropdown(
                      placeholder: l10n.wallets,
                      options: wallets
                          .map((w) => _SelectOption(id: w.id, label: w.name))
                          .toList(),
                      selected: _wallets,
                      onChanged: (v) => setState(() => _wallets = v),
                      leadingIcon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                ],

                // ── Tags ──
                Builder(builder: (ctx) {
                  final availableTags = ref.watch(allTagsProvider);
                  if (availableTags.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _FilterSection(
                      title: 'Tags',
                      child: _MultiSelectDropdown(
                        placeholder: 'Tags',
                        options: availableTags
                            .map((t) => _SelectOption(id: t, label: t))
                            .toList(),
                        selected: _selectedTags,
                        onChanged: (v) => setState(() => _selectedTags = v),
                        leadingIcon: Icons.label_outline_rounded,
                      ),
                    ),
                  );
                }),

                // ── Faixa de valor ──
                const SizedBox(height: 20),
                _FilterSection(
                  title: l10n.filterAmountRange,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.filterMin,
                            prefixText: 'R\$ ',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: l10n.filterMax,
                            prefixText: 'R\$ ',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(l10n.filterApply),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Section Header ────────────────────────────────────────────────────
class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ─── Type Selector (Todos / Receitas / Despesas) ──────────────────────────────
class _TypeSelector extends StatelessWidget {
  final TransactionType? selected;
  final String allLabel;
  final String incomeLabel;
  final String expenseLabel;
  final ValueChanged<TransactionType?> onChanged;

  const _TypeSelector({
    required this.selected,
    required this.allLabel,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: allLabel,
          isSelected: selected == null,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: 8),
        _TypeChip(
          label: incomeLabel,
          isSelected: selected == TransactionType.income,
          color: Colors.green.shade600,
          onTap: () => onChanged(
              selected == TransactionType.income ? null : TransactionType.income),
        ),
        const SizedBox(width: 8),
        _TypeChip(
          label: expenseLabel,
          isSelected: selected == TransactionType.expense,
          color: Colors.red.shade600,
          onTap: () => onChanged(
              selected == TransactionType.expense
                  ? null
                  : TransactionType.expense),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.15)
              : cs.surfaceContainerHighest,
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? effectiveColor : cs.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Multi-Select Dropdown ────────────────────────────────────────────────────
class _SelectOption {
  final String id;
  final String label;

  const _SelectOption({required this.id, required this.label});
}

class _MultiSelectDropdown extends StatelessWidget {
  final String placeholder;
  final List<_SelectOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final IconData? leadingIcon;

  const _MultiSelectDropdown({
    required this.placeholder,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.leadingIcon,
  });

  String _buildLabel() {
    if (selected.isEmpty) return placeholder;
    final labels =
        options.where((o) => selected.contains(o.id)).map((o) => o.label);
    return labels.join(', ');
  }

  void _openSheet(BuildContext context) {
    // local copy so we can cancel
    Set<String> temp = Set.from(selected);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cs = Theme.of(ctx).colorScheme;
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.35,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollCtrl) => Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          placeholder,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (temp.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setSheetState(() => temp = {}),
                            child: Text(AppLocalizations.of(context).clear),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final opt = options[i];
                        final isChecked = temp.contains(opt.id);
                        return CheckboxListTile(
                          value: isChecked,
                          title: Row(
                            children: [
                              if (leadingIcon != null) ...[
                                Icon(leadingIcon,
                                    size: 18,
                                    color: isChecked
                                        ? cs.primary
                                        : cs.onSurfaceVariant),
                                const SizedBox(width: 8),
                              ],
                              Text(opt.label),
                            ],
                          ),
                          activeColor: cs.primary,
                          controlAffinity: ListTileControlAffinity.trailing,
                          onChanged: (v) {
                            setSheetState(() {
                              if (v == true) {
                                temp = {...temp, opt.id};
                              } else {
                                temp = temp
                                    .where((id) => id != opt.id)
                                    .toSet();
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  // Apply button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: FilledButton(
                      onPressed: () {
                        onChanged(temp);
                        Navigator.of(ctx).pop();
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text(AppLocalizations.of(ctx).confirm),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSelection = selected.isNotEmpty;

    return GestureDetector(
      onTap: () => _openSheet(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasSelection ? cs.primary : cs.outline,
            width: hasSelection ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: hasSelection
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : cs.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            if (hasSelection)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${selected.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                _buildLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasSelection ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight:
                      hasSelection ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: hasSelection ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
