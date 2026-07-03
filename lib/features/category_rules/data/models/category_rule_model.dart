import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/category_rule_entity.dart';

class CategoryRuleModel extends CategoryRuleEntity {
  const CategoryRuleModel({
    required super.id,
    required super.userId,
    required super.keyword,
    required super.categoryName,
    super.type,
    required super.createdAt,
    super.workspaceId,
  });

  factory CategoryRuleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final typeStr = data['type'] as String?;
    return CategoryRuleModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      keyword: data['keyword'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      // A missing/null type means the rule applies to both income and expense.
      type: (typeStr == null || typeStr.isEmpty)
          ? null
          : TransactionType.fromId(typeStr),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      workspaceId: data['workspaceId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'keyword': keyword,
        'categoryName': categoryName,
        'type': type?.id,
        'createdAt': createdAt,
        if (workspaceId != null) 'workspaceId': workspaceId,
      };

  factory CategoryRuleModel.fromEntity(CategoryRuleEntity e) => CategoryRuleModel(
        id: e.id,
        userId: e.userId,
        keyword: e.keyword,
        categoryName: e.categoryName,
        type: e.type,
        createdAt: e.createdAt,
        workspaceId: e.workspaceId,
      );
}
