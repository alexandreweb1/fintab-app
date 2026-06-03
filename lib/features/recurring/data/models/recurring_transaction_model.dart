import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/recurring_transaction_entity.dart';

class RecurringTransactionModel extends RecurringTransactionEntity {
  const RecurringTransactionModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.amount,
    required super.type,
    required super.category,
    super.description,
    super.walletId,
    required super.frequency,
    required super.dayOfRecurrence,
    required super.startDate,
    super.endDate,
    super.isActive,
    super.lastGeneratedDate,
    required super.createdAt,
  });

  factory RecurringTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringTransactionModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: data['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: data['category'] as String? ?? '',
      description: data['description'] as String?,
      walletId: data['walletId'] as String? ?? '',
      frequency: _frequencyFromString(data['frequency'] as String? ?? 'monthly'),
      dayOfRecurrence: data['dayOfRecurrence'] as int? ?? 1,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] as bool? ?? true,
      lastGeneratedDate: data['lastGeneratedDate'] != null
          ? (data['lastGeneratedDate'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'title': title,
        'amount': amount,
        'type': type == TransactionType.income ? 'income' : 'expense',
        'category': category,
        'description': description,
        'walletId': walletId,
        'frequency': frequency.name,
        'dayOfRecurrence': dayOfRecurrence,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'isActive': isActive,
        'lastGeneratedDate': lastGeneratedDate != null
            ? Timestamp.fromDate(lastGeneratedDate!)
            : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory RecurringTransactionModel.fromEntity(RecurringTransactionEntity e) =>
      RecurringTransactionModel(
        id: e.id,
        userId: e.userId,
        title: e.title,
        amount: e.amount,
        type: e.type,
        category: e.category,
        description: e.description,
        walletId: e.walletId,
        frequency: e.frequency,
        dayOfRecurrence: e.dayOfRecurrence,
        startDate: e.startDate,
        endDate: e.endDate,
        isActive: e.isActive,
        lastGeneratedDate: e.lastGeneratedDate,
        createdAt: e.createdAt,
      );

  static RecurrenceFrequency _frequencyFromString(String value) {
    switch (value) {
      case 'daily':
        return RecurrenceFrequency.daily;
      case 'weekly':
        return RecurrenceFrequency.weekly;
      case 'yearly':
        return RecurrenceFrequency.yearly;
      default:
        return RecurrenceFrequency.monthly;
    }
  }
}
