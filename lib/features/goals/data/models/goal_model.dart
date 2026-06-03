import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/goal_entity.dart';

class GoalModel extends GoalEntity {
  const GoalModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.targetAmount,
    super.deadline,
    required super.iconCodePoint,
    required super.colorValue,
    required super.createdAt,
  });

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0,
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      iconCodePoint: data['iconCodePoint'] as int? ?? 0xe0d4,
      colorValue: data['colorValue'] as int? ?? 0xFF00D887,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'title': title,
        'targetAmount': targetAmount,
        'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'createdAt': createdAt,
      };

  factory GoalModel.fromEntity(GoalEntity e) => GoalModel(
        id: e.id,
        userId: e.userId,
        title: e.title,
        targetAmount: e.targetAmount,
        deadline: e.deadline,
        iconCodePoint: e.iconCodePoint,
        colorValue: e.colorValue,
        createdAt: e.createdAt,
      );
}
