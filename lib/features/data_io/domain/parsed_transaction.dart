import '../../transactions/domain/entities/transaction_entity.dart';

/// Lightweight DTO for a transaction parsed from an imported file.
/// Not persisted on its own — used as a staging model between the parser
/// and the import screen's "confirm" action.
class ParsedTransaction {
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String? rawDescription;

  const ParsedTransaction({
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.rawDescription,
  });
}
