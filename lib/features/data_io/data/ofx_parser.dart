import 'package:xml/xml.dart';

import '../../transactions/domain/entities/transaction_entity.dart';
import '../domain/parsed_transaction.dart';

/// Parses OFX 1.x (SGML-like) and 2.x (XML) bank statement files.
///
/// The strategy is deliberately simple: we normalise the input into
/// XML-ish text, then extract `<STMTTRN>` blocks and read their children.
/// Works for the vast majority of Brazilian bank OFX exports.
class OfxParser {
  List<ParsedTransaction> parse(String content) {
    final xml = _toXmlString(content);
    final doc = XmlDocument.parse(xml);
    final txElements = doc.findAllElements('STMTTRN');
    return txElements
        .map(_fromElement)
        .whereType<ParsedTransaction>()
        .toList();
  }

  ParsedTransaction? _fromElement(XmlElement e) {
    final amountStr = _text(e, 'TRNAMT');
    final dateStr = _text(e, 'DTPOSTED');
    if (amountStr == null || dateStr == null) return null;

    final amount = double.tryParse(amountStr.replaceAll(',', '.'));
    if (amount == null) return null;

    final date = _parseOfxDate(dateStr);
    if (date == null) return null;

    final memo = _text(e, 'MEMO') ?? '';
    final name = _text(e, 'NAME') ?? '';
    final title = (memo.isNotEmpty ? memo : name).trim();

    return ParsedTransaction(
      title: title.isEmpty ? 'Transação importada' : title,
      amount: amount.abs(),
      type: amount < 0 ? TransactionType.expense : TransactionType.income,
      date: date,
      rawDescription: memo.isEmpty ? null : memo,
    );
  }

  String? _text(XmlElement parent, String tag) {
    final child = parent.findElements(tag).firstOrNull;
    final value = child?.innerText.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// Converts OFX 1.x (SGML, unclosed tags) into well-formed XML.
  /// For OFX 2.x (already XML) the header is stripped and the body returned.
  String _toXmlString(String content) {
    // Strip BOM + OFX headers that come before the body.
    var body = content.replaceAll('\r\n', '\n');
    final startXml = body.indexOf('<?xml');
    final startOfx = body.indexOf('<OFX>');
    if (startXml >= 0 && startOfx > startXml) {
      // OFX 2.x — strip anything before <?xml
      body = body.substring(startXml);
    } else if (startOfx >= 0) {
      // OFX 1.x — drop the header lines before <OFX>
      body = body.substring(startOfx);
    }

    if (body.contains('<?xml')) return body;

    // OFX 1.x → close every unclosed tag by regex.
    // A leaf tag like "<TRNAMT>-120.50" becomes "<TRNAMT>-120.50</TRNAMT>"
    // when the next character is another tag.
    final regex = RegExp(r'<([A-Z0-9_.]+)>([^<\r\n]+)');
    body = body.replaceAllMapped(regex, (m) {
      final tag = m.group(1)!;
      final value = m.group(2)!.trim();
      return '<$tag>${_escapeXml(value)}</$tag>';
    });

    return '<?xml version="1.0"?>\n$body';
  }

  String _escapeXml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// OFX dates are `YYYYMMDD` or `YYYYMMDDHHMMSS` optionally followed by
  /// `[timezone:LABEL]`. We only care about the day.
  DateTime? _parseOfxDate(String raw) {
    final s = raw.replaceAll(RegExp(r'\[.*\]'), '').trim();
    if (s.length < 8) return null;
    final year = int.tryParse(s.substring(0, 4));
    final month = int.tryParse(s.substring(4, 6));
    final day = int.tryParse(s.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}
