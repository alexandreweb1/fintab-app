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
    );
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
      );
}
