import 'package:equatable/equatable.dart';

enum TransactionType {
  income,
  expense,
  /// Aporte/resgate em uma carteira de reserva ou investimento.
  /// O sinal é determinado pela combinação `walletId` (destino) e
  /// `sourceWalletId` (origem). Não conta como receita nem despesa do mês.
  transfer;

  String get id => name;

  static TransactionType fromId(String? id) {
    switch (id) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      default:
        return TransactionType.expense;
    }
  }
}

class TransactionEntity extends Equatable {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? description;
  /// ID of the wallet this transaction belongs to (destination for transfers).
  /// Empty string = "Geral".
  final String walletId;
  /// For transfers: source wallet that loses [amount]. Null means the aporte
  /// came from outside (external money) — only [walletId] is impacted.
  final String? sourceWalletId;
  /// Optional ID of a savings goal this transaction contributes to.
  final String? goalId;
  /// True when the transaction was auto-created from a notification and
  /// still needs the user to confirm/categorise it.
  final bool isPending;
  /// Free-form tags for extra classification beyond categories.
  final List<String> tags;

  const TransactionEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.description,
    this.walletId = '',
    this.sourceWalletId,
    this.goalId,
    this.isPending = false,
    this.tags = const [],
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
  bool get isTransfer => type == TransactionType.transfer;

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        amount,
        type,
        category,
        date,
        description,
        walletId,
        sourceWalletId,
        goalId,
        isPending,
        tags,
      ];
}
