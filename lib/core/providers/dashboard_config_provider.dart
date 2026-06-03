import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Section enum ─────────────────────────────────────────────────────────────

enum DashboardSection {
  incomeExpense,
  financialHealth,
  budgets,
  wallets,
  recentTransactions,
  upcomingRecurring;

  String get id => name;

  String get label {
    switch (this) {
      case DashboardSection.incomeExpense:
        return 'Receitas & Despesas';
      case DashboardSection.financialHealth:
        return 'Saúde Financeira';
      case DashboardSection.budgets:
        return 'Resumo de Orçamentos';
      case DashboardSection.wallets:
        return 'Saldo por Carteira';
      case DashboardSection.recentTransactions:
        return 'Últimas Transações';
      case DashboardSection.upcomingRecurring:
        return 'Próximas Recorrências';
    }
  }

  String get description {
    switch (this) {
      case DashboardSection.incomeExpense:
        return 'Cards de receita e despesa do mês';
      case DashboardSection.financialHealth:
        return 'Score de 0 a 100 com seu nível atual';
      case DashboardSection.budgets:
        return 'Barra de progresso dos orçamentos';
      case DashboardSection.wallets:
        return 'Saldo individual por carteira';
      case DashboardSection.recentTransactions:
        return 'Últimas 5 transações realizadas';
      case DashboardSection.upcomingRecurring:
        return 'Próximos lançamentos automáticos';
    }
  }

  static DashboardSection? fromId(String id) {
    for (final s in DashboardSection.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

// ─── Config model ──────────────────────────────────────────────────────────────

class DashboardConfig {
  /// Ordered list of all sections; hidden ones are excluded from the view.
  final List<DashboardSection> order;

  /// Sections that are hidden (not rendered).
  final Set<DashboardSection> hidden;

  const DashboardConfig({
    required this.order,
    required this.hidden,
  });

  static const DashboardConfig defaultConfig = DashboardConfig(
    order: DashboardSection.values,
    hidden: {},
  );

  bool isVisible(DashboardSection s) => !hidden.contains(s);

  List<DashboardSection> get visibleSections =>
      order.where(isVisible).toList();

  DashboardConfig copyWith({
    List<DashboardSection>? order,
    Set<DashboardSection>? hidden,
  }) {
    return DashboardConfig(
      order: order ?? this.order,
      hidden: hidden ?? this.hidden,
    );
  }

  Map<String, dynamic> toJson() => {
        'order': order.map((s) => s.id).toList(),
        'hidden': hidden.map((s) => s.id).toList(),
      };

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    final orderIds = (json['order'] as List<dynamic>?)?.cast<String>() ?? [];
    final hiddenIds = (json['hidden'] as List<dynamic>?)?.cast<String>() ?? [];

    // Build order from stored IDs, appending any new sections not yet persisted.
    final orderedSections = <DashboardSection>[];
    for (final id in orderIds) {
      final s = DashboardSection.fromId(id);
      if (s != null) orderedSections.add(s);
    }
    for (final s in DashboardSection.values) {
      if (!orderedSections.contains(s)) orderedSections.add(s);
    }

    final hiddenSections = hiddenIds
        .map(DashboardSection.fromId)
        .whereType<DashboardSection>()
        .toSet();

    return DashboardConfig(order: orderedSections, hidden: hiddenSections);
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

const _kPrefKey = 'dashboard_config_v1';

class DashboardConfigNotifier extends Notifier<DashboardConfig> {
  @override
  DashboardConfig build() {
    _load();
    return DashboardConfig.defaultConfig;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefKey);
    if (raw != null) {
      try {
        final config = DashboardConfig.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
        state = config;
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, jsonEncode(state.toJson()));
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state.order];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(order: list);
    _save();
  }

  void toggle(DashboardSection section) {
    final hidden = {...state.hidden};
    if (hidden.contains(section)) {
      hidden.remove(section);
    } else {
      hidden.add(section);
    }
    state = state.copyWith(hidden: hidden);
    _save();
  }

  void reset() {
    state = DashboardConfig.defaultConfig;
    _save();
  }
}

final dashboardConfigProvider =
    NotifierProvider<DashboardConfigNotifier, DashboardConfig>(
        DashboardConfigNotifier.new);
