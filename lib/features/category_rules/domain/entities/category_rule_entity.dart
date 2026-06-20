import 'package:equatable/equatable.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';

/// A user-defined auto-categorization rule: when a transaction's text contains
/// [keyword], assign [categoryName]. Optionally restricted to a single
/// [type] (expense or income); a null [type] applies to both.
///
/// Matching itself lives in `category_rule_matcher.dart` so it can be reused and
/// unit-tested independently of persistence.
class CategoryRuleEntity extends Equatable {
  final String id;
  final String userId;

  /// Text to look for inside the transaction title/description (case- and
  /// accent-insensitive "contains" match).
  final String keyword;

  /// Category assigned when the rule matches.
  final String categoryName;

  /// Restricts the rule to expenses or income. Null means it applies to both.
  final TransactionType? type;

  final DateTime createdAt;

  const CategoryRuleEntity({
    required this.id,
    required this.userId,
    required this.keyword,
    required this.categoryName,
    this.type,
    required this.createdAt,
  });

  CategoryRuleEntity copyWith({
    String? keyword,
    String? categoryName,
    TransactionType? type,
    bool clearType = false,
  }) {
    return CategoryRuleEntity(
      id: id,
      userId: userId,
      keyword: keyword ?? this.keyword,
      categoryName: categoryName ?? this.categoryName,
      type: clearType ? null : (type ?? this.type),
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, userId, keyword, categoryName, type, createdAt];
}
