import '../../transactions/domain/entities/transaction_entity.dart';
import '../../transactions/domain/transaction_suggestions.dart';
import 'entities/category_rule_entity.dart';

/// Returns the category of the best rule that matches [text], or null when none
/// applies. Pure and side-effect free so it can run in the dialog, the
/// notification auto-save path and unit tests alike.
///
/// Semantics:
///  - Matching is a case- and accent-insensitive "contains", using the same
///    [normalizeForSearch] normalization as the smart-suggestion engine, so a
///    rule for "posto" matches "POSTO IPIRANGA", "Pôsto", etc.
///  - When [type] is known, rules constrained to the other type are ignored;
///    rules without a type constraint always apply.
///  - The most specific rule wins: the one whose (normalized) keyword is the
///    longest among those that match. Ties keep the earliest rule in [rules].
String? matchCategory({
  required String text,
  required List<CategoryRuleEntity> rules,
  TransactionType? type,
}) {
  if (rules.isEmpty) return null;
  final haystack = normalizeForSearch(text);
  if (haystack.isEmpty) return null;

  String? bestCategory;
  int bestLen = -1;
  for (final rule in rules) {
    if (rule.type != null && type != null && rule.type != type) continue;
    final needle = normalizeForSearch(rule.keyword);
    if (needle.isEmpty || !haystack.contains(needle)) continue;
    if (needle.length > bestLen) {
      bestLen = needle.length;
      bestCategory = rule.categoryName;
    }
  }
  return bestCategory;
}
