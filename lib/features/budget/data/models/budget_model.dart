import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/budget_entity.dart';

class BudgetModel extends BudgetEntity {
  const BudgetModel({
    required super.id,
    required super.userId,
    required super.categoryId,
    required super.categoryName,
    required super.limitAmount,
    required super.month,
    super.isAnnual,
    super.period,
    super.parentBudgetId,
    super.rollover,
    super.workspaceId,
  });

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final monthTs = data['month'] as Timestamp;
    return BudgetModel(
      id: doc.id,
      userId: data['userId'] as String,
      categoryId: data['categoryId'] as String,
      categoryName: data['categoryName'] as String,
      limitAmount: (data['limitAmount'] as num).toDouble(),
      month: monthTs.toDate(),
      isAnnual: data['isAnnual'] as bool? ?? false,
      period: BudgetPeriod.fromKey(data['period'] as String?),
      parentBudgetId: data['parentBudgetId'] as String?,
      rollover: data['rollover'] as bool? ?? false,
      workspaceId: data['workspaceId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'limitAmount': limitAmount,
        'month': Timestamp.fromDate(month),
        'isAnnual': isAnnual,
        'period': period.key,
        'rollover': rollover,
        if (parentBudgetId != null) 'parentBudgetId': parentBudgetId,
        if (workspaceId != null) 'workspaceId': workspaceId,
      };

  factory BudgetModel.fromEntity(BudgetEntity entity) => BudgetModel(
        id: entity.id,
        userId: entity.userId,
        categoryId: entity.categoryId,
        categoryName: entity.categoryName,
        limitAmount: entity.limitAmount,
        month: entity.month,
        isAnnual: entity.isAnnual,
        period: entity.period,
        parentBudgetId: entity.parentBudgetId,
        rollover: entity.rollover,
        workspaceId: entity.workspaceId,
      );
}
