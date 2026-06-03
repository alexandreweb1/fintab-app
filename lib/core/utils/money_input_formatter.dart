import 'package:flutter/services.dart';

/// Formats a raw [digits] string (only digit chars) as a Brazilian money
/// display string, e.g. "35000" → "350,00".
String _formatMoneyDigits(String digits) {
  if (digits.isEmpty) return '0,00';

  // Pad to at least 3 chars so we always have 2 decimal places.
  final padded = digits.padLeft(3, '0');

  final cents = padded.substring(padded.length - 2);
  var reaisStr = padded.substring(0, padded.length - 2);

  // Strip leading zeros but keep at least one digit.
  reaisStr = reaisStr.replaceAll(RegExp(r'^0+'), '');
  if (reaisStr.isEmpty) reaisStr = '0';

  // Add thousands separators (dot in Brazilian locale).
  final buffer = StringBuffer();
  for (int i = 0; i < reaisStr.length; i++) {
    if (i > 0 && (reaisStr.length - i) % 3 == 0) buffer.write('.');
    buffer.write(reaisStr[i]);
  }

  return '$buffer,$cents';
}

/// Converts a formatted money string (e.g. "1.234,56") to a [double].
double moneyTextToDouble(String text) {
  final digits = text.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return 0.0;
  return int.parse(digits) / 100.0;
}

/// Converts a [double] to a formatted money string (e.g. 1234.56 → "1.234,56").
String doubleToMoneyText(double value) {
  final cents = (value * 100).round();
  return _formatMoneyDigits(cents.toString());
}

/// A [TextInputFormatter] that formats user input as a Brazilian currency
/// value. Digits enter right-to-left (calculator style):
/// typing "5", "0", "0" produces "0,05" → "0,50" → "5,00".
class MoneyInputFormatter extends TextInputFormatter {
  /// Maximum number of digit characters allowed (999.999.999,99 = 11 digits).
  static const int _maxDigits = 11;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > _maxDigits) {
      digits = digits.substring(digits.length - _maxDigits);
    }
    final formatted = _formatMoneyDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
