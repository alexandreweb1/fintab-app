import 'package:csv/csv.dart';

import '../../transactions/domain/entities/transaction_entity.dart';
import '../domain/parsed_transaction.dart';

/// Parses a CSV with an auto-detected header. Expected columns (case-
/// insensitive, Portuguese/English): date/data, description/descrição/title,
/// amount/valor/value. Either a single signed amount column OR two columns
/// (debit+credit) are accepted.
class CsvParser {
  List<ParsedTransaction> parse(String content) {
    // Try both common delimiters and pick whichever yields more columns.
    final rowsSemi = const CsvToListConverter(
      fieldDelimiter: ';',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);
    final rowsComma = const CsvToListConverter(
      fieldDelimiter: ',',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(content);
    final rows =
        _maxColumns(rowsSemi) >= _maxColumns(rowsComma) ? rowsSemi : rowsComma;
    if (rows.length < 2) return [];

    final header = rows.first.map((c) => c.toString().trim()).toList();
    final indexes = _detectColumns(header);
    if (indexes.date == null || indexes.amount == null) return [];

    final result = <ParsedTransaction>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final tx = _fromRow(row, indexes);
      if (tx != null) result.add(tx);
    }
    return result;
  }

  int _maxColumns(List<List<dynamic>> rows) =>
      rows.isEmpty ? 0 : rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

  _ColumnIndexes _detectColumns(List<String> header) {
    int? dateCol;
    int? descCol;
    int? amountCol;
    int? debitCol;
    int? creditCol;

    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase();
      if (dateCol == null && _matches(h, ['date', 'data', 'dt'])) {
        dateCol = i;
      } else if (descCol == null &&
          _matches(h, ['description', 'descrição', 'descricao',
              'historico', 'histórico', 'memo', 'title', 'título',
              'titulo'])) {
        descCol = i;
      } else if (amountCol == null &&
          _matches(h, ['amount', 'valor', 'value'])) {
        amountCol = i;
      } else if (debitCol == null && _matches(h, ['debit', 'débito', 'debito'])) {
        debitCol = i;
      } else if (creditCol == null &&
          _matches(h, ['credit', 'crédito', 'credito'])) {
        creditCol = i;
      }
    }
    return _ColumnIndexes(
      date: dateCol,
      desc: descCol,
      amount: amountCol ?? debitCol ?? creditCol,
      debit: debitCol,
      credit: creditCol,
    );
  }

  bool _matches(String s, List<String> needles) =>
      needles.any((n) => s == n || s.contains(n));

  ParsedTransaction? _fromRow(List<dynamic> row, _ColumnIndexes idx) {
    final dateStr = _cell(row, idx.date);
    if (dateStr == null) return null;
    final date = _parseDate(dateStr);
    if (date == null) return null;

    double? amount;
    var type = TransactionType.expense;
    if (idx.debit != null && idx.credit != null) {
      final debit = _parseAmount(_cell(row, idx.debit) ?? '');
      final credit = _parseAmount(_cell(row, idx.credit) ?? '');
      if (credit != null && credit > 0) {
        amount = credit;
        type = TransactionType.income;
      } else if (debit != null && debit > 0) {
        amount = debit;
        type = TransactionType.expense;
      }
    } else {
      final raw = _parseAmount(_cell(row, idx.amount) ?? '');
      if (raw != null) {
        amount = raw.abs();
        type = raw < 0 ? TransactionType.expense : TransactionType.income;
      }
    }
    if (amount == null || amount == 0) return null;

    final title = (_cell(row, idx.desc) ?? 'Transação importada').trim();
    return ParsedTransaction(
      title: title.isEmpty ? 'Transação importada' : title,
      amount: amount,
      type: type,
      date: date,
    );
  }

  String? _cell(List<dynamic> row, int? i) {
    if (i == null || i < 0 || i >= row.length) return null;
    final v = row[i]?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Accepts: "R$ 1.234,56", "1234.56", "-120,50", "(120,50)" (negative),
  /// "1,234.56".
  double? _parseAmount(String raw) {
    if (raw.isEmpty) return null;
    var s = raw
        .replaceAll(RegExp(r'[R$€£\s]'), '')
        .replaceAll('US\$', '');
    final isNegative = s.startsWith('(') && s.endsWith(')');
    if (isNegative) s = s.substring(1, s.length - 1);

    // Decide decimal separator: whichever appears last.
    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
    final v = double.tryParse(s);
    if (v == null) return null;
    return isNegative ? -v : v;
  }

  /// Accepts dd/MM/yyyy, yyyy-MM-dd, MM/dd/yyyy (fallback), dd-MM-yyyy.
  DateTime? _parseDate(String raw) {
    final s = raw.split(' ').first;
    // ISO yyyy-MM-dd
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    // dd/MM/yyyy or dd-MM-yyyy
    final br = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(s);
    if (br != null) {
      final day = int.parse(br.group(1)!);
      final month = int.parse(br.group(2)!);
      var year = int.parse(br.group(3)!);
      if (year < 100) year += 2000;
      // Heuristic: if first number > 12, assume dd/MM; otherwise still dd/MM
      // (Brazilian apps default) — this is the right choice for our audience.
      return DateTime(year, month, day);
    }
    return null;
  }
}

class _ColumnIndexes {
  final int? date;
  final int? desc;
  final int? amount;
  final int? debit;
  final int? credit;
  const _ColumnIndexes({
    required this.date,
    required this.desc,
    required this.amount,
    required this.debit,
    required this.credit,
  });
}
