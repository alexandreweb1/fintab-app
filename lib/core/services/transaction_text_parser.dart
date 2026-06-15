import '../../features/transactions/domain/entities/transaction_entity.dart';
import 'notification_suggestion.dart';

/// Pure-Dart port of the amount/type heuristics that live in the Android native
/// `NotificationMonitorService.kt`. Kept identical on purpose so every capture
/// path (Android notification listener, iOS Share Extension, clipboard, OCR)
/// produces the same result from the same text.
///
/// This is the single source of truth for "transaction text → suggestion".
class TransactionTextParser {
  TransactionTextParser._();

  /// Matches: R$ 1.500,00 | R$59,90 | R$ 100 | R$ 1500.00 | R$10 | BRL 3.09
  /// First alt: 4+ digits without thousands separator (e.g. 1500 or 1500,00).
  /// Second alt: 1-3 digits with optional thousands groups (e.g. 1.500,00).
  static final RegExp _moneyRegex = RegExp(
    r'(?:R\$|BRL)\s?(\d{4,}(?:[.,]\d{1,2})?|\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)',
    caseSensitive: false,
  );

  static const List<String> _expenseKeywords = [
    // Portuguese
    'débito', 'debito', 'debitado', 'debitada',
    'compra', 'pagamento', 'pago', 'paga',
    'saque', 'saída', 'saida', 'cobrança', 'cobranca', 'fatura',
    'aprovada', 'aprovado',
    'transferência enviada', 'transferencia enviada',
    'pix enviado', 'ted enviado', 'doc enviado',
    'cartão', 'cartao',
    'mastercard', 'visa', 'elo',
    // English
    'purchase', 'deducted', 'debit', 'charged', 'payment',
  ];

  static const List<String> _incomeKeywords = [
    // Portuguese
    'crédito', 'credito', 'creditado', 'creditada',
    'depósito', 'deposito', 'recebeu', 'recebido', 'recebida',
    'transferência recebida', 'transferencia recebida',
    'pix recebido', 'ted recebido', 'doc recebido',
    'cashback', 'estorno', 'reembolso',
    // English
    'received', 'credit', 'deposit', 'refund',
  ];

  /// Extracts the first monetary value from [text], or null if none is found.
  ///
  /// Normalisation mirrors the native logic exactly (so amounts match across
  /// platforms): "1.500,00" → 1500.00, "59,90" → 59.90, "100" → 100.
  static double? extractAmount(String text) {
    final match = _moneyRegex.firstMatch(text);
    if (match == null) return null;

    final raw = match.group(1);
    if (raw == null) return null;

    final String normalized;
    if (raw.contains(',') && raw.contains('.')) {
      normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    } else if (raw.contains(',')) {
      normalized = raw.replaceAll(',', '.');
    } else {
      normalized = raw;
    }

    return double.tryParse(normalized);
  }

  /// Classifies [text] as an expense or income from keyword heuristics.
  /// Returns null when no keyword matches (the caller lets the user choose).
  static TransactionType? detectType(String text) {
    final lower = text.toLowerCase();
    if (_expenseKeywords.any(lower.contains)) return TransactionType.expense;
    if (_incomeKeywords.any(lower.contains)) return TransactionType.income;
    return null;
  }

  /// Parses [text] into a [NotificationSuggestion], or null when no amount is
  /// present (nothing actionable to suggest).
  static NotificationSuggestion? parse(String text, {String sourceApp = ''}) {
    final amount = extractAmount(text);
    if (amount == null) return null;
    return NotificationSuggestion(
      amount: amount,
      type: detectType(text),
      rawText: text.trim(),
      sourceApp: sourceApp,
    );
  }
}
