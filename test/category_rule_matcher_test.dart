import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/category_rules/domain/category_rule_matcher.dart';
import 'package:my_finance_app/features/category_rules/domain/entities/category_rule_entity.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';

CategoryRuleEntity _rule(
  String keyword,
  String category, {
  TransactionType? type,
}) =>
    CategoryRuleEntity(
      id: keyword,
      userId: 'u',
      keyword: keyword,
      categoryName: category,
      type: type,
      createdAt: DateTime(2020),
    );

void main() {
  group('matchCategory', () {
    test('matches case- and accent-insensitively (contains)', () {
      final rules = [_rule('posto', 'Transporte')];
      expect(matchCategory(text: 'POSTO IPIRANGA', rules: rules), 'Transporte');
      expect(matchCategory(text: 'Pôsto Shell', rules: rules), 'Transporte');
      expect(matchCategory(text: 'paguei no posto', rules: rules), 'Transporte');
    });

    test('returns null when nothing matches', () {
      final rules = [_rule('posto', 'Transporte')];
      expect(matchCategory(text: 'Mercado Livre', rules: rules), isNull);
    });

    test('the most specific (longest) keyword wins', () {
      final rules = [
        _rule('posto', 'Transporte'),
        _rule('posto ipiranga', 'Combustível'),
      ];
      expect(
        matchCategory(text: 'PAGAMENTO POSTO IPIRANGA 12', rules: rules),
        'Combustível',
      );
    });

    test('respects the type constraint when the query type is known', () {
      final rules = [_rule('pix', 'Salário', type: TransactionType.income)];
      // Income-only rule must not fire for an expense.
      expect(
        matchCategory(
            text: 'PIX recebido', rules: rules, type: TransactionType.expense),
        isNull,
      );
      // Fires for the matching type.
      expect(
        matchCategory(
            text: 'PIX recebido', rules: rules, type: TransactionType.income),
        'Salário',
      );
      // Unknown query type → constrained rules still apply (best effort).
      expect(matchCategory(text: 'PIX recebido', rules: rules), 'Salário');
    });

    test('untyped rule applies to both income and expense', () {
      final rules = [_rule('uber', 'Transporte')];
      expect(
        matchCategory(
            text: 'UBER *TRIP', rules: rules, type: TransactionType.expense),
        'Transporte',
      );
      expect(
        matchCategory(
            text: 'UBER *TRIP', rules: rules, type: TransactionType.income),
        'Transporte',
      );
    });

    test('handles empty inputs and blank keywords gracefully', () {
      expect(matchCategory(text: 'qualquer', rules: const []), isNull);
      expect(matchCategory(text: '', rules: [_rule('x', 'Y')]), isNull);
      expect(matchCategory(text: 'abc', rules: [_rule('   ', 'Y')]), isNull);
    });

    test('ties keep the earliest rule', () {
      final rules = [_rule('abc', 'A'), _rule('xyz', 'B')];
      expect(matchCategory(text: 'abc xyz', rules: rules), 'A');
    });
  });
}
