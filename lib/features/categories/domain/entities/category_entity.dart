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

  /// Workspace (Carteira PF/PJ) this doc belongs to. Null = legacy pre-migration doc (treated as the default workspace).
  final String? workspaceId;

  const CategoryEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
    this.workspaceId,
  });

  bool get isIncome => type == CategoryType.income;
  bool get isExpense => type == CategoryType.expense;

  @override
  List<Object?> get props =>
      [id, userId, name, type, iconCodePoint, colorValue, isDefault, workspaceId];
}
