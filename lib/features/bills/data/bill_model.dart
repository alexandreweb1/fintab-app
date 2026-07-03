import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/bill_entity.dart';

class BillModel extends BillEntity {
  const BillModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.amount,
    required super.dueDate,
    super.type,
    super.category,
    super.walletId,
    super.isPaid,
    super.paidDate,
    super.reminderDaysBefore,
    super.repeatMonthly,
    super.transactionId,
    super.workspaceId,
    required super.createdAt,
  });

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BillModel(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      type: BillType.fromId(data['type'] as String?),
      category: data['category'] as String? ?? 'Contas',
      walletId: data['walletId'] as String? ?? '',
      isPaid: data['isPaid'] as bool? ?? false,
      paidDate: (data['paidDate'] as Timestamp?)?.toDate(),
      reminderDaysBefore: (data['reminderDaysBefore'] as num?)?.toInt() ?? 1,
      repeatMonthly: data['repeatMonthly'] as bool? ?? false,
      transactionId: data['transactionId'] as String?,
      workspaceId: data['workspaceId'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'title': title,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'type': type.id,
        'category': category,
        'walletId': walletId,
        'isPaid': isPaid,
        'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
        'reminderDaysBefore': reminderDaysBefore,
        'repeatMonthly': repeatMonthly,
        'transactionId': transactionId,
        if (workspaceId != null) 'workspaceId': workspaceId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory BillModel.fromEntity(BillEntity e) => BillModel(
        id: e.id,
        userId: e.userId,
        title: e.title,
        amount: e.amount,
        dueDate: e.dueDate,
        type: e.type,
        category: e.category,
        walletId: e.walletId,
        isPaid: e.isPaid,
        paidDate: e.paidDate,
        reminderDaysBefore: e.reminderDaysBefore,
        repeatMonthly: e.repeatMonthly,
        transactionId: e.transactionId,
        workspaceId: e.workspaceId,
        createdAt: e.createdAt,
      );
}
