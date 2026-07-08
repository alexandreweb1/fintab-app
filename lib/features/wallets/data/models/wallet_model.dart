import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/wallet_entity.dart';

class WalletModel extends WalletEntity {
  const WalletModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.iconCodePoint,
    required super.colorValue,
    super.isDefault,
    super.currencyCode,
    super.type,
    super.targetAmount,
    super.creditLimit,
    super.closingDay,
    super.dueDay,
    super.closedInvoiceAmounts,
    super.workspaceId,
  });

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel(
      id: doc.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      iconCodePoint: (data['iconCodePoint'] as num).toInt(),
      colorValue: (data['colorValue'] as num).toInt(),
      isDefault: data['isDefault'] as bool? ?? false,
      currencyCode: data['currencyCode'] as String? ?? '',
      type: WalletType.fromId(data['type'] as String?),
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0,
      creditLimit: (data['creditLimit'] as num?)?.toDouble() ?? 0,
      closingDay: (data['closingDay'] as num?)?.toInt() ?? 1,
      dueDay: (data['dueDay'] as num?)?.toInt() ?? 10,
      closedInvoiceAmounts: _parseClosedInvoices(data['closedInvoiceAmounts']),
      workspaceId: data['workspaceId'] as String?,
    );
  }

  static Map<String, double> _parseClosedInvoices(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, double>{};
    raw.forEach((k, v) {
      final d = (v as num?)?.toDouble();
      if (k is String && d != null && d.isFinite) out[k] = d;
    });
    return out;
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'isDefault': isDefault,
        'currencyCode': currencyCode,
        'type': type.id,
        'targetAmount': targetAmount,
        'creditLimit': creditLimit,
        'closingDay': closingDay,
        'dueDay': dueDay,
        if (closedInvoiceAmounts.isNotEmpty)
          'closedInvoiceAmounts': closedInvoiceAmounts,
        if (workspaceId != null) 'workspaceId': workspaceId,
      };

  factory WalletModel.fromEntity(WalletEntity entity) => WalletModel(
        id: entity.id,
        userId: entity.userId,
        name: entity.name,
        iconCodePoint: entity.iconCodePoint,
        colorValue: entity.colorValue,
        isDefault: entity.isDefault,
        currencyCode: entity.currencyCode,
        type: entity.type,
        targetAmount: entity.targetAmount,
        creditLimit: entity.creditLimit,
        closingDay: entity.closingDay,
        dueDay: entity.dueDay,
        closedInvoiceAmounts: entity.closedInvoiceAmounts,
        workspaceId: entity.workspaceId,
      );
}
