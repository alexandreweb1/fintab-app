import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/referral/referral_home_card.dart';
import 'package:my_finance_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:my_finance_app/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// F0.9 — o card de indicação da Home só aparece para usuários engajados
// (≥5 transações) e some para sempre quando dispensado.

List<TransactionEntity> _txs(int count) => List.generate(
      count,
      (i) => TransactionEntity(
        id: 'tx$i',
        userId: 'u1',
        title: 'Compra $i',
        amount: 10.0 + i,
        type: TransactionType.expense,
        category: 'Mercado',
        date: DateTime(2026, 8, 1 + i),
      ),
    );

Widget _harness(List<TransactionEntity> txs) => ProviderScope(
      overrides: [
        transactionsStreamProvider.overrideWith((ref) => Stream.value(txs)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ReferralHomeCard()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('esconde com menos de 5 transações', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_harness(_txs(4)));
    await tester.pumpAndSettle();
    expect(find.text('Indique e ganhe 1 mês de Pro'), findsNothing);
  });

  testWidgets('aparece com 5+ transações', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_harness(_txs(5)));
    await tester.pumpAndSettle();
    expect(find.text('Indique e ganhe 1 mês de Pro'), findsOneWidget);
  });

  testWidgets('dispensado no X → some e persiste a escolha', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_harness(_txs(6)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Não mostrar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Indique e ganhe 1 mês de Pro'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('referral_home_card_dismissed'), isTrue);
  });

  testWidgets('não aparece se já foi dispensado antes', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'referral_home_card_dismissed': true});
    await tester.pumpWidget(_harness(_txs(10)));
    await tester.pumpAndSettle();
    expect(find.text('Indique e ganhe 1 mês de Pro'), findsNothing);
  });
}
