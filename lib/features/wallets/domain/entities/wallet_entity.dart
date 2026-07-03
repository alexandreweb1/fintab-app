import 'package:equatable/equatable.dart';

/// Categoriza a carteira para separar fluxo de caixa, reservas, investimentos
/// e cartões de crédito.
enum WalletType {
  regular,
  reserve,
  investment,
  creditCard;

  String get id => name;

  bool get isCreditCard => this == WalletType.creditCard;

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

  /// Credit limit — only meaningful for [WalletType.creditCard].
  final double creditLimit;
  /// Day of month (1-31) the invoice closes — credit cards only.
  final int closingDay;
  /// Day of month (1-31) the invoice is due — credit cards only.
  final int dueDay;

  /// Workspace (Carteira PF/PJ) this doc belongs to. Null = legacy pre-migration doc (treated as the default workspace).
  final String? workspaceId;

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
    this.creditLimit = 0,
    this.closingDay = 1,
    this.dueDay = 10,
    this.workspaceId,
  });

  bool get isCreditCard => type.isCreditCard;

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
    double? creditLimit,
    int? closingDay,
    int? dueDay,
    String? workspaceId,
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
      creditLimit: creditLimit ?? this.creditLimit,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
      workspaceId: workspaceId ?? this.workspaceId,
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
        creditLimit,
        closingDay,
        dueDay,
        workspaceId,
      ];
}
