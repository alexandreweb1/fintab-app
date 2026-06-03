import 'package:equatable/equatable.dart';

class GoalEntity extends Equatable {
  final String id;
  final String userId;
  final String title;
  final double targetAmount;
  final DateTime? deadline;
  final int iconCodePoint;
  final int colorValue;
  final DateTime createdAt;

  const GoalEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetAmount,
    this.deadline,
    required this.iconCodePoint,
    required this.colorValue,
    required this.createdAt,
  });

  double progressPercent(double currentAmount) {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  bool isCompleted(double currentAmount) => currentAmount >= targetAmount;

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        targetAmount,
        deadline,
        iconCodePoint,
        colorValue,
        createdAt,
      ];
}
