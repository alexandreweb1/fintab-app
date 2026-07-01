import '../../transactions/domain/entities/transaction_entity.dart';

/// A recurring charge inferred from the transaction history (e.g. Netflix,
/// Spotify, gym, insurance). Detected heuristically — the user confirms it by
/// turning it into a real recurring transaction or dismissing it.
class DetectedSubscription {
  /// Normalized merchant key used for grouping and dismissal.
  final String key;

  /// Best-effort human-readable name (the most representative raw title).
  final String name;

  /// The category most transactions of this group used.
  final String category;

  /// The most recent charge amount (what the user likely pays now).
  final double monthlyAmount;

  /// Number of charges detected.
  final int occurrences;

  /// Date of the most recent charge.
  final DateTime lastDate;

  /// Estimated date of the next charge (last date + typical interval).
  final DateTime nextEstimatedDate;

  /// Wallet the charges came from (most common). Empty = "Geral".
  final String walletId;

  const DetectedSubscription({
    required this.key,
    required this.name,
    required this.category,
    required this.monthlyAmount,
    required this.occurrences,
    required this.lastDate,
    required this.nextEstimatedDate,
    required this.walletId,
  });
}

/// Merchants/keywords that strongly indicate a subscription. When a title
/// matches one of these we accept it as a subscription with as few as two
/// charges (real subscriptions are unmistakable even early on).
const List<String> _kSubscriptionKeywords = [
  'netflix', 'spotify', 'amazon prime', 'prime video', 'disney', 'hbo', 'max',
  'youtube', 'globoplay', 'deezer', 'icloud', 'google one', 'dropbox',
  'microsoft', 'office', 'adobe', 'canva', 'paramount', 'telecine', 'star',
  'gympass', 'smartfit', 'smart fit', 'uber one', 'linkedin', 'chatgpt',
  'openai', 'notion', 'playstation', 'xbox', 'game pass', 'twitch', 'patreon',
  'apple', 'crunchyroll', 'kindle', 'audible', 'mercado livre', 'meli',
  'assinatura', 'mensalidade', 'plano', 'seguro', 'academia',
];

/// Normalizes a transaction title for grouping: lowercase, accents/letters
/// only, digits and punctuation collapsed to spaces.
String normalizeSubscriptionTitle(String s) {
  var t = s.toLowerCase();
  t = t.replaceAll(RegExp(r'[0-9]'), ' ');
  // Keep letters (incl. accented) and spaces; drop everything else.
  t = t.replaceAll(RegExp(r'[^a-zà-ÿ ]'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

bool _hasKnownKeyword(String normalized) =>
    _kSubscriptionKeywords.any((k) => normalized.contains(k));

/// Median of a list of ints.
double _median(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid].toDouble();
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

/// Detects likely subscriptions from [transactions].
///
/// A group of same-merchant expenses is considered a subscription when either
/// it recurs on a roughly monthly cadence with ≥3 charges, or it matches a
/// well-known subscription merchant with ≥2 charges. [dismissed] keys are
/// excluded.
List<DetectedSubscription> detectSubscriptions(
  Iterable<TransactionEntity> transactions, {
  Set<String> dismissed = const {},
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();

  // Group eligible expenses by normalized title.
  final groups = <String, List<TransactionEntity>>{};
  for (final t in transactions) {
    if (!t.isExpense || t.isPending) continue;
    final key = normalizeSubscriptionTitle(t.title);
    if (key.length < 3) continue;
    (groups[key] ??= []).add(t);
  }

  final results = <DetectedSubscription>[];
  groups.forEach((key, txs) {
    if (dismissed.contains(key)) return;
    if (txs.length < 2) return;

    txs.sort((a, b) => a.date.compareTo(b.date));

    // Gaps in days between consecutive charges.
    final gaps = <int>[];
    for (var i = 1; i < txs.length; i++) {
      gaps.add(txs[i].date.difference(txs[i - 1].date).inDays);
    }
    final medianGap = _median(gaps);
    final knownKeyword = _hasKnownKeyword(key);

    // Monthly-ish cadence (also accepts slightly irregular billing).
    final monthlyLike = medianGap >= 20 && medianGap <= 45;
    // Annual-ish cadence for known merchants (e.g. yearly plans).
    final annualLike = medianGap >= 330 && medianGap <= 400;

    final accepted = (txs.length >= 3 && monthlyLike) ||
        (knownKeyword && txs.length >= 2 && (monthlyLike || annualLike));
    if (!accepted) return;

    // Amount stability: require reasonably stable amounts unless it's a
    // well-known merchant (some raise prices over time).
    final amounts = txs.map((t) => t.amount).toList();
    final avg = amounts.reduce((a, b) => a + b) / amounts.length;
    if (!knownKeyword && avg > 0) {
      final maxDev =
          amounts.map((a) => (a - avg).abs()).reduce((a, b) => a > b ? a : b);
      if (maxDev / avg > 0.35) return; // too volatile to be a subscription
    }

    final last = txs.last;
    final intervalDays = (medianGap >= 1 ? medianGap : 30).round();
    final nextEstimated = last.date.add(Duration(days: intervalDays));

    // Skip charges that look long-abandoned (last charge older than ~2 typical
    // intervals before now) — likely a canceled subscription.
    if (reference.difference(last.date).inDays > intervalDays * 2 + 15) return;

    // Most common category & wallet.
    final category = _mostCommon(txs.map((t) => t.category)) ?? last.category;
    final walletId = _mostCommon(txs.map((t) => t.walletId)) ?? last.walletId;

    results.add(DetectedSubscription(
      key: key,
      name: _bestName(txs),
      category: category,
      monthlyAmount: last.amount,
      occurrences: txs.length,
      lastDate: last.date,
      nextEstimatedDate: nextEstimated,
      walletId: walletId,
    ));
  });

  results.sort((a, b) => b.monthlyAmount.compareTo(a.monthlyAmount));
  return results;
}

/// Returns the most frequent value in [values], or null when empty.
String? _mostCommon(Iterable<String> values) {
  final counts = <String, int>{};
  for (final v in values) {
    counts[v] = (counts[v] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  String? best;
  int bestCount = -1;
  counts.forEach((k, c) {
    if (c > bestCount) {
      bestCount = c;
      best = k;
    }
  });
  return best;
}

/// Picks the most representative raw title (the most frequent; ties broken by
/// the longer, more descriptive one).
String _bestName(List<TransactionEntity> txs) {
  final counts = <String, int>{};
  for (final t in txs) {
    final title = t.title.trim();
    if (title.isEmpty) continue;
    counts[title] = (counts[title] ?? 0) + 1;
  }
  if (counts.isEmpty) return txs.last.title;
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return b.key.length.compareTo(a.key.length);
    });
  return entries.first.key;
}
