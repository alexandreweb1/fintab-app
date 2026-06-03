import '../../features/transactions/domain/entities/transaction_entity.dart';

class NotificationSuggestion {
  final double amount;
  final TransactionType? type;
  final String rawText;
  final String sourceApp;

  const NotificationSuggestion({
    required this.amount,
    required this.type,
    required this.rawText,
    required this.sourceApp,
  });

  factory NotificationSuggestion.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'unknown';
    return NotificationSuggestion(
      amount: (json['amount'] as num).toDouble(),
      type: typeStr == 'expense'
          ? TransactionType.expense
          : typeStr == 'income'
              ? TransactionType.income
              : null,
      rawText: json['text'] as String? ?? '',
      sourceApp: json['sourceApp'] as String? ?? '',
    );
  }
}
