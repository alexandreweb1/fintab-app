import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/core/services/transaction_text_parser.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  group('TransactionTextParser.extractAmount', () {
    test('parses simple cents with comma decimal', () {
      expect(TransactionTextParser.extractAmount('R\$ 59,90'), 59.90);
      expect(TransactionTextParser.extractAmount('R\$59,90'), 59.90);
    });

    test('parses thousands with comma decimals', () {
      expect(TransactionTextParser.extractAmount('R\$ 1.500,00'), 1500.00);
    });

    test('parses integer amounts', () {
      expect(TransactionTextParser.extractAmount('R\$ 100'), 100.0);
      expect(TransactionTextParser.extractAmount('R\$10'), 10.0);
    });

    test('parses 4+ digit amounts with dot decimals', () {
      expect(TransactionTextParser.extractAmount('R\$ 1500.00'), 1500.00);
    });

    test('parses BRL prefix and is case-insensitive', () {
      expect(TransactionTextParser.extractAmount('BRL 3.09'), 3.09);
      expect(TransactionTextParser.extractAmount('r\$ 50'), 50.0);
    });

    test('returns the first match in a longer notification text', () {
      expect(
        TransactionTextParser.extractAmount(
          'Compra aprovada de R\$ 25,00 no cartão final 1234. Limite R\$ 900,00',
        ),
        25.00,
      );
    });

    test('returns null when no monetary value is present', () {
      expect(TransactionTextParser.extractAmount('Seu app foi atualizado'),
          isNull);
      expect(TransactionTextParser.extractAmount('1234'), isNull);
    });

    // Mirrors the native quirk: "R\$ 1.500" with no cents is read as a decimal
    // separator (1.5), not thousands. Locked in here so iOS and Android stay
    // identical; change both parsers together if this is ever "fixed".
    test('mirrors native ambiguity for dotted value without cents', () {
      expect(TransactionTextParser.extractAmount('R\$ 1.500'), 1.5);
    });
  });

  group('TransactionTextParser.detectType', () {
    test('detects expenses from keywords', () {
      expect(TransactionTextParser.detectType('Compra aprovada'),
          TransactionType.expense);
      expect(TransactionTextParser.detectType('PIX enviado'),
          TransactionType.expense);
      expect(TransactionTextParser.detectType('Pagamento de fatura'),
          TransactionType.expense);
    });

    test('detects income from keywords', () {
      expect(TransactionTextParser.detectType('PIX recebido'),
          TransactionType.income);
      expect(TransactionTextParser.detectType('Estorno efetuado'),
          TransactionType.income);
      expect(TransactionTextParser.detectType('Depósito efetuado'),
          TransactionType.income);
    });

    test('returns null when no keyword matches', () {
      expect(TransactionTextParser.detectType('Saldo disponível R\$ 10'),
          isNull);
    });

    test('expense keywords take priority over income when both appear', () {
      // "compra" (expense) appears before income keyword resolution.
      expect(TransactionTextParser.detectType('compra estorno'),
          TransactionType.expense);
    });
  });

  group('TransactionTextParser.parse', () {
    test('returns a full suggestion with trimmed text and source', () {
      final s = TransactionTextParser.parse(
        '  Compra aprovada de R\$ 25,00  ',
        sourceApp: 'share',
      );
      expect(s, isNotNull);
      expect(s!.amount, 25.00);
      expect(s.type, TransactionType.expense);
      expect(s.rawText, 'Compra aprovada de R\$ 25,00');
      expect(s.sourceApp, 'share');
    });

    test('returns null when there is no amount to act on', () {
      expect(TransactionTextParser.parse('Bem-vindo ao app'), isNull);
    });

    test('leaves type null when undetermined', () {
      final s = TransactionTextParser.parse('Valor R\$ 80,00');
      expect(s, isNotNull);
      expect(s!.type, isNull);
    });
  });
}
