import 'package:flutter/material.dart';

/// A bank / card-network brand used to visually identify a credit card.
///
/// We deliberately DON'T bundle real logos (trademark risk on the App Store /
/// Play, plus asset weight). Instead each brand renders as a rounded avatar in
/// the brand's official color with a short label — recognizable and safe.
class BankBrand {
  final String id;
  final String name;
  final int colorValue;

  /// Short text shown inside the colored avatar (e.g. "nu", "Itaú", "VISA").
  final String shortLabel;

  /// True for the (few) international brands; false for Brazilian ones.
  final bool international;

  const BankBrand({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.shortLabel,
    this.international = false,
  });

  Color get color => Color(colorValue);

  /// Readable text/icon color on top of [color].
  Color get onColor =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
          ? Colors.white
          : Colors.black;
}

/// Main Brazilian banks + only the main international ones. Ordered by
/// popularity so the most-used appear first in the picker.
const List<BankBrand> kBankBrands = [
  // ── Brasil ──────────────────────────────────────────────────────────────
  BankBrand(id: 'nubank', name: 'Nubank', colorValue: 0xFF820AD1, shortLabel: 'nu'),
  BankBrand(id: 'itau', name: 'Itaú', colorValue: 0xFFEC7000, shortLabel: 'Itaú'),
  BankBrand(id: 'bradesco', name: 'Bradesco', colorValue: 0xFFCC092F, shortLabel: 'brad'),
  BankBrand(id: 'bb', name: 'Banco do Brasil', colorValue: 0xFF0033A0, shortLabel: 'BB'),
  BankBrand(id: 'santander', name: 'Santander', colorValue: 0xFFEC0000, shortLabel: 'San'),
  BankBrand(id: 'caixa', name: 'Caixa', colorValue: 0xFF005CA9, shortLabel: 'CX'),
  BankBrand(id: 'inter', name: 'Inter', colorValue: 0xFFFF7A00, shortLabel: 'inter'),
  BankBrand(id: 'c6', name: 'C6 Bank', colorValue: 0xFF242424, shortLabel: 'C6'),
  BankBrand(id: 'btg', name: 'BTG Pactual', colorValue: 0xFF0A1F3C, shortLabel: 'BTG'),
  BankBrand(id: 'original', name: 'Banco Original', colorValue: 0xFF00A335, shortLabel: 'orig'),
  BankBrand(id: 'next', name: 'Next', colorValue: 0xFF00C86F, shortLabel: 'next'),
  BankBrand(id: 'neon', name: 'Neon', colorValue: 0xFF00A0E4, shortLabel: 'neon'),
  BankBrand(id: 'picpay', name: 'PicPay', colorValue: 0xFF11C76F, shortLabel: 'PP'),
  BankBrand(id: 'mercadopago', name: 'Mercado Pago', colorValue: 0xFF009EE3, shortLabel: 'MP'),
  BankBrand(id: 'xp', name: 'XP', colorValue: 0xFF0A0A0A, shortLabel: 'XP'),
  BankBrand(id: 'pagbank', name: 'PagBank', colorValue: 0xFF0FA958, shortLabel: 'pag'),
  BankBrand(id: 'will', name: 'Will Bank', colorValue: 0xFFEFAF00, shortLabel: 'will'),
  BankBrand(id: 'pan', name: 'Banco Pan', colorValue: 0xFF0090D4, shortLabel: 'pan'),
  BankBrand(id: 'bmg', name: 'BMG', colorValue: 0xFFF57F20, shortLabel: 'BMG'),
  BankBrand(id: 'safra', name: 'Safra', colorValue: 0xFF00263A, shortLabel: 'safra'),
  BankBrand(id: 'sicoob', name: 'Sicoob', colorValue: 0xFF00995D, shortLabel: 'coob'),
  BankBrand(id: 'sicredi', name: 'Sicredi', colorValue: 0xFF4A8B2C, shortLabel: 'sic'),
  BankBrand(id: 'ame', name: 'Ame Digital', colorValue: 0xFFE4002B, shortLabel: 'ame'),

  // ── Internacionais (principais) ───────────────────────────────────────────
  BankBrand(id: 'visa', name: 'Visa', colorValue: 0xFF1A1F71, shortLabel: 'VISA', international: true),
  BankBrand(id: 'mastercard', name: 'Mastercard', colorValue: 0xFFEB001B, shortLabel: 'MC', international: true),
  BankBrand(id: 'amex', name: 'American Express', colorValue: 0xFF006FCF, shortLabel: 'AMEX', international: true),
  BankBrand(id: 'elo', name: 'Elo', colorValue: 0xFF1A1A1A, shortLabel: 'elo', international: true),
  BankBrand(id: 'hipercard', name: 'Hipercard', colorValue: 0xFFED1C24, shortLabel: 'hiper', international: true),
  BankBrand(id: 'paypal', name: 'PayPal', colorValue: 0xFF0070BA, shortLabel: 'PayPal', international: true),
  BankBrand(id: 'revolut', name: 'Revolut', colorValue: 0xFF191C1F, shortLabel: 'R', international: true),
  BankBrand(id: 'wise', name: 'Wise', colorValue: 0xFF163300, shortLabel: 'wise', international: true),
  BankBrand(id: 'n26', name: 'N26', colorValue: 0xFF1B1B1B, shortLabel: 'N26', international: true),
  BankBrand(id: 'citi', name: 'Citi', colorValue: 0xFF056DAE, shortLabel: 'citi', international: true),
  BankBrand(id: 'chase', name: 'Chase', colorValue: 0xFF117ACA, shortLabel: 'chase', international: true),
  BankBrand(id: 'hsbc', name: 'HSBC', colorValue: 0xFFDB0011, shortLabel: 'HSBC', international: true),

  // ── Genérico ────────────────────────────────────────────────────────────
  BankBrand(id: 'other', name: 'Outro', colorValue: 0xFF546E7A, shortLabel: '••'),
];

BankBrand? bankBrandById(String? id) {
  if (id == null) return null;
  for (final b in kBankBrands) {
    if (b.id == id) return b;
  }
  return null;
}

/// Finds the brand whose color matches a stored wallet color (best-effort, used
/// to render the right avatar for existing cards).
BankBrand? bankBrandByColor(int colorValue) {
  for (final b in kBankBrands) {
    if (b.colorValue == colorValue) return b;
  }
  return null;
}

/// A rounded, brand-colored avatar with the short label — the "symbol".
class BankAvatar extends StatelessWidget {
  final BankBrand brand;
  final double size;
  const BankAvatar({super.key, required this.brand, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand.color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.14),
          child: Text(
            brand.shortLabel,
            style: TextStyle(
              color: brand.onColor,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.34,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}
