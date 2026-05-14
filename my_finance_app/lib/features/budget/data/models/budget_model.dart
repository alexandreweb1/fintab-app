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
    super.period,
    super.parentBudgetId,
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
      period: BudgetPeriod.fromKey(data['period'] as String?),
      parentBudgetId: data['parentBudgetId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'limitAmount': limitAmount,
        'month': Timestamp.fromDate(month),
        'period': period.key,
        if (parentBudgetId != null) 'parentBudgetId': parentBudgetId,
      };

  factory BudgetModel.fromEntity(BudgetEntity entity) => BudgetModel(
        id: entity.id,
        userId: entity.userId,
        categoryId: entity.categoryId,
        categoryName: entity.categoryName,
        limitAmount: entity.limitAmount,
        month: entity.month,
        period: entity.period,
        parentBudgetId: entity.parentBudgetId,
      );
}
