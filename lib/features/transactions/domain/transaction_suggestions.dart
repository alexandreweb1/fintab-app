import 'dart:math' as math;

/// Pure, dependency-free engine for the "smart suggestions" shown while typing
/// a new transaction. It ranks the user's CATEGORIES by how well past
/// descriptions (of the same kind) match what's being typed, weighted by how
/// often that category was used, with recency only as a final tiebreak — so a
/// single recent entry never dominates the result.
///
/// Kept widget/provider-free so it can be unit-tested in isolation.

// ── Tuning knobs ────────────────────────────────────────────────────────────
const int kSuggestionMaxScan = 400; // newest entries of a kind to scan
const int kSuggestionMaxRows = 4; // suggestions shown at once
const double kSuggestionMinTxScore = 3.0; // a past entry must clear this
const double kSuggestionMinAggScore = 3.0; // an aggregated category must clear
const int kSuggestionDebounceMs = 180; // keystroke coalescing

double _log2(num x) => math.log(x) / math.ln2;

/// Lowercase, strip pt/es diacritics, collapse non-alphanumerics to spaces.
String normalizeForSearch(String s) {
  var r = s.toLowerCase();
  const map = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  map.forEach((k, v) => r = r.replaceAll(k, v));
  return r.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Tokens of a normalized string, keeping only words of length >= 2.
Set<String> suggestionTokens(String norm) =>
    norm.split(' ').where((w) => w.length >= 2).toSet();

/// One scannable, pre-normalized past transaction. Build once per kind/history
/// change (never per keystroke).
class SuggestionEntry {
  final String category;
  final String normText; // normalizeForSearch('title description')
  final Set<String> tokens; // tokens of normText, length >= 2
  final int recencyRank; // 0 = newest within the scanned window
  final String exampleTitle; // original-casing title, for the "ex.:" subtitle
  const SuggestionEntry({
    required this.category,
    required this.normText,
    required this.tokens,
    required this.recencyRank,
    required this.exampleTitle,
  });
}

/// One ranked, deduped-by-category suggestion shown in the list.
class CategorySuggestion {
  final String category;
  final double score;
  final int hits; // how many past transactions reinforced this category
  final int recencyRank; // smallest recencyRank contributing (final tiebreak)
  final String example; // example past title shown as subtitle
  const CategorySuggestion({
    required this.category,
    required this.score,
    required this.hits,
    required this.recencyRank,
    required this.example,
  });
}

/// Per-transaction raw similarity score between the query and one entry.
double scoreSuggestionEntry(
    String query, Set<String> queryTokens, SuggestionEntry e) {
  double score = 0;
  if (query.length >= 3 && e.normText.contains(query)) score += 6; // phrase
  if (query.isNotEmpty && e.normText.startsWith(query)) score += 1; // prefix

  double tokenSum = 0;
  var covered = 0;
  for (final q in queryTokens) {
    double best = 0;
    if (e.tokens.contains(q)) {
      best = 4; // whole-token exact
    } else {
      for (final t in e.tokens) {
        if ((t.startsWith(q) || q.startsWith(t)) &&
            math.min(t.length, q.length) >= 3) {
          best = math.max(best, 2.5); // prefix
        } else if (q.length >= 3 && t.contains(q)) {
          best = math.max(best, 1.5); // substring
        } else if (q.length >= 3 &&
            t.length >= 3 &&
            t.substring(0, 3) == q.substring(0, 3)) {
          best = math.max(best, 0.8); // shared 3-char prefix (typo/inflection)
        }
      }
    }
    // Only a genuine match (>= substring tier) counts toward coverage — the
    // weak shared-3-char-prefix tier (0.8) must not earn the +2 bonus, or lone
    // typo-ish noise would clear the threshold.
    if (best >= 1.5) covered++;
    tokenSum += best;
  }
  score += math.min(tokenSum, 12); // a long note cannot dominate
  if (queryTokens.isNotEmpty && covered == queryTokens.length) {
    score += 2; // every query token genuinely matched
  }
  return score;
}

/// Ranks the user's categories for [query] against a pre-built [index].
///
/// - [validCategories]: only these (the currently selectable ones) can surface.
/// - [currentCategory]: dropped from the result unless it's the only match.
/// Returns at most [maxRows], best first. Recency is strictly the last tiebreak.
List<CategorySuggestion> rankCategorySuggestions({
  required String query,
  required List<SuggestionEntry> index,
  required Set<String> validCategories,
  String? currentCategory,
  int maxRows = kSuggestionMaxRows,
}) {
  final normQuery = normalizeForSearch(query);
  if (normQuery.length < 2) return const [];
  final queryTokens = suggestionTokens(normQuery);
  if (queryTokens.isEmpty) return const [];

  final score = <String, double>{};
  final hits = <String, int>{};
  final bestRank = <String, int>{};
  final bestTxScore = <String, double>{};
  final example = <String, String>{};

  for (final e in index) {
    if (!validCategories.contains(e.category)) continue;
    final raw = scoreSuggestionEntry(normQuery, queryTokens, e);
    if (raw < kSuggestionMinTxScore) continue;
    final rf = 1 + 0.15 * math.max(0, 1 - e.recencyRank / 60);
    score[e.category] = (score[e.category] ?? 0) + raw * rf;
    hits[e.category] = (hits[e.category] ?? 0) + 1;
    bestRank[e.category] =
        math.min(bestRank[e.category] ?? 1 << 30, e.recencyRank);
    if (raw > (bestTxScore[e.category] ?? -1)) {
      bestTxScore[e.category] = raw;
      example[e.category] = e.exampleTitle;
    }
  }

  var candidates = <CategorySuggestion>[];
  for (final c in score.keys) {
    final h = hits[c] ?? 1;
    final finalScore = score[c]! * (1 + 0.10 * _log2(1 + h));
    if (finalScore < kSuggestionMinAggScore) continue;
    candidates.add(CategorySuggestion(
      category: c,
      score: finalScore,
      hits: h,
      recencyRank: bestRank[c] ?? 1 << 30,
      example: example[c] ?? '',
    ));
  }

  candidates.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    final hh = b.hits.compareTo(a.hits);
    if (hh != 0) return hh;
    return a.recencyRank.compareTo(b.recencyRank); // recency strictly last
  });

  if (candidates.length > 1 && currentCategory != null) {
    candidates = candidates.where((c) => c.category != currentCategory).toList();
  }
  return candidates.take(maxRows).toList();
}
