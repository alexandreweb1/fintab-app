/// Suggested expense allocation as a percentage of monthly income,
/// based on the 50/30/20 rule (50% needs, 30% wants, 20% savings)
/// adapted to common Brazilian household categories.
///
/// Total adds up to 70% — the remaining 30% is reserved for savings
/// and investments (not represented as expense budgets).
class IdealBudgetItem {
  final String categoryName;
  final double percentage;
  final String group;

  const IdealBudgetItem({
    required this.categoryName,
    required this.percentage,
    required this.group,
  });

  double amountFor(double income) => income * percentage / 100.0;
}

const List<IdealBudgetItem> kIdealBudgetTemplate = [
  // ── Necessidades (50%) ──────────────────────────────────────────────
  IdealBudgetItem(categoryName: 'Moradia',     percentage: 25, group: 'Necessidades'),
  IdealBudgetItem(categoryName: 'Alimentação', percentage: 12, group: 'Necessidades'),
  IdealBudgetItem(categoryName: 'Transporte',  percentage: 8,  group: 'Necessidades'),
  IdealBudgetItem(categoryName: 'Saúde',       percentage: 5,  group: 'Necessidades'),
  // ── Desejos (30%) ───────────────────────────────────────────────────
  IdealBudgetItem(categoryName: 'Lazer',       percentage: 7,  group: 'Desejos'),
  IdealBudgetItem(categoryName: 'Educação',    percentage: 5,  group: 'Desejos'),
  IdealBudgetItem(categoryName: 'Vestuário',   percentage: 3,  group: 'Desejos'),
  IdealBudgetItem(categoryName: 'Outros',      percentage: 5,  group: 'Desejos'),
];

/// Sum of all expense percentages (the rest goes to savings/investments).
double get kIdealBudgetTotalPercent =>
    kIdealBudgetTemplate.fold(0.0, (sum, item) => sum + item.percentage);

/// Reserved percentage for savings/investments — the gap to 100%.
double get kIdealSavingsPercent => 100.0 - kIdealBudgetTotalPercent;
