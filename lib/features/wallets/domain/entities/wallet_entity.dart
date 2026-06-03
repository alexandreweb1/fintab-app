import 'package:equatable/equatable.dart';

/// Categoriza a carteira para separar fluxo de caixa, reservas e investimentos.
enum WalletType {
  regular,
  reserve,
  investment;

  String get id => name;

  static WalletType fromId(String? id) {
    if (id == null) return WalletType.regular;
    for (final t in WalletType.values) {
      if (t.id == id) return t;
    }
    return WalletType.regular;
  }
}

class WalletEntity extends Equatable {
  final String id;
  final String userId;
  final String name;
  final int iconCodePoint;
  final int colorValue;
  final bool isDefault;
  /// ISO 4217 currency code (e.g. 'BRL', 'USD'). Empty = use app-level setting.
  final String currencyCode;
  final WalletType type;
  /// Optional target amount (used by reserve/investment wallets to render progress).
  final double targetAmount;

  const WalletEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.isDefault = false,
    this.currencyCode = '',
    this.type = WalletType.regular,
    this.targetAmount = 0,
  });

  WalletEntity copyWith({
    String? id,
    String? userId,
    String? name,
    int? iconCodePoint,
    int? colorValue,
    bool? isDefault,
    String? currencyCode,
    WalletType? type,
    double? targetAmount,
  }) {
    return WalletEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      currencyCode: currencyCode ?? this.currencyCode,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        iconCodePoint,
        colorValue,
        isDefault,
        currencyCode,
        type,
        targetAmount,
      ];
}
