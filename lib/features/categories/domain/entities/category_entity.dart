import 'package:equatable/equatable.dart';

enum CategoryType { income, expense }

class CategoryEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final int iconCodePoint;
  final int colorValue;
  final bool isDefault;

  const CategoryEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
  });

  bool get isIncome => type == CategoryType.income;
  bool get isExpense => type == CategoryType.expense;

  @override
  List<Object?> get props =>
      [id, userId, name, type, iconCodePoint, colorValue, isDefault];
}
