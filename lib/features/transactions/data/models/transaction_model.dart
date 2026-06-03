import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.amount,
    required super.type,
    required super.category,
    required super.date,
    super.description,
    super.walletId,
    super.sourceWalletId,
    super.goalId,
    super.isPending,
    super.tags,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      type: TransactionType.fromId(data['type'] as String?),
      category: data['category'] as String,
      date: (data['date'] as Timestamp).toDate(),
      description: data['description'] as String?,
      walletId: data['walletId'] as String? ?? '',
      sourceWalletId: data['sourceWalletId'] as String?,
      goalId: data['goalId'] as String?,
      isPending: data['isPending'] as bool? ?? false,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'type': type.id,
      'category': category,
      'date': Timestamp.fromDate(date),
      'description': description,
      'walletId': walletId,
      'sourceWalletId': sourceWalletId,
      'goalId': goalId,
      'isPending': isPending,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory TransactionModel.fromEntity(TransactionEntity entity) {
    return TransactionModel(
      id: entity.id,
      userId: entity.userId,
      title: entity.title,
      amount: entity.amount,
      type: entity.type,
      category: entity.category,
      date: entity.date,
      description: entity.description,
      walletId: entity.walletId,
      sourceWalletId: entity.sourceWalletId,
      goalId: entity.goalId,
      isPending: entity.isPending,
      tags: entity.tags,
    );
  }
}
