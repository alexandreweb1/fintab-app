import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/category_entity.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    required super.iconCodePoint,
    required super.colorValue,
    super.isDefault,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      type: (data['type'] as String) == 'income'
          ? CategoryType.income
          : CategoryType.expense,
      iconCodePoint: (data['iconCodePoint'] as num).toInt(),
      colorValue: (data['colorValue'] as num).toInt(),
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'name': name,
        'type': type == CategoryType.income ? 'income' : 'expense',
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'isDefault': isDefault,
      };

  factory CategoryModel.fromEntity(CategoryEntity entity) => CategoryModel(
        id: entity.id,
        userId: entity.userId,
        name: entity.name,
        type: entity.type,
        iconCodePoint: entity.iconCodePoint,
        colorValue: entity.colorValue,
        isDefault: entity.isDefault,
      );
}
