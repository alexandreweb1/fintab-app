/// Severity buckets the score is classified into.
enum HealthLevel { critical, attention, fair, good, excellent }

/// Inputs that compose the overall score.
enum ScoreFactorKind {
  savingsRate,
  emergencyReserve,
  budgetAdherence,
  goalMomentum,
  spendingConcentration,
  investments,
}

/// Result of evaluating one factor. `value` is in the 0–20 range when
/// [measured] is true; when false, there wasn't enough data and the
/// factor is excluded from the average.
class ScoreFactor {
  final ScoreFactorKind kind;
  final double value;
  final bool measured;
  final String headline;
  final String? hint;

  const ScoreFactor({
    required this.kind,
    required this.value,
    required this.measured,
    required this.headline,
    this.hint,
  });

  static const double maxValue = 20;

  double get percentage => measured ? (value / maxValue) * 100 : 0;
}

class FinancialScore {
  /// Composite score in the 0–100 range.
  final double score;
  final HealthLevel level;
  final List<ScoreFactor> factors;

  const FinancialScore({
    required this.score,
    required this.level,
    required this.factors,
  });

  int get scoreRounded => score.round();

  /// Tips derived from factors that scored below 15/20.
  List<String> get recommendations =>
      factors.where((f) => f.measured && f.value < 15).map((f) {
        return f.hint ?? f.headline;
      }).toList();
}
