import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/investments/domain/investment_asset.dart';
import 'package:my_finance_app/features/investments/domain/price_alert.dart';

PriceAlert _alert({
  required AlertCondition condition,
  required double target,
  bool active = true,
  AssetKind kind = AssetKind.stockBr,
}) =>
    PriceAlert(
      id: 'a',
      userId: 'u',
      ticker: 'PETR4',
      quoteSymbol: 'PETR4.SA',
      name: 'Petrobras',
      kind: kind,
      condition: condition,
      targetPrice: target,
      active: active,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('shouldTriggerAlert', () {
    test('above fires when price >= target (inclusive)', () {
      final a = _alert(condition: AlertCondition.above, target: 42);
      expect(shouldTriggerAlert(a, 41.99), isFalse);
      expect(shouldTriggerAlert(a, 42), isTrue);
      expect(shouldTriggerAlert(a, 42.01), isTrue);
    });

    test('below fires when price <= target (inclusive)', () {
      final a = _alert(condition: AlertCondition.below, target: 60000);
      expect(shouldTriggerAlert(a, 60001), isFalse);
      expect(shouldTriggerAlert(a, 60000), isTrue);
      expect(shouldTriggerAlert(a, 59999), isTrue);
    });

    test('inactive alerts never fire', () {
      final a = _alert(condition: AlertCondition.above, target: 42, active: false);
      expect(shouldTriggerAlert(a, 100), isFalse);
    });

    test('non-finite / non-positive prices never fire', () {
      final a = _alert(condition: AlertCondition.below, target: 42);
      expect(shouldTriggerAlert(a, double.nan), isFalse);
      expect(shouldTriggerAlert(a, double.infinity), isFalse);
      expect(shouldTriggerAlert(a, 0), isFalse);
      expect(shouldTriggerAlert(a, -5), isFalse);
    });

    test('non-finite / non-positive targets never fire', () {
      expect(
          shouldTriggerAlert(
              _alert(condition: AlertCondition.above, target: 0), 100),
          isFalse);
      expect(
          shouldTriggerAlert(
              _alert(condition: AlertCondition.above, target: double.nan), 100),
          isFalse);
    });
  });

  group('enum round-trips', () {
    test('AlertCondition.fromId', () {
      expect(AlertCondition.fromId('above'), AlertCondition.above);
      expect(AlertCondition.fromId('below'), AlertCondition.below);
      expect(AlertCondition.fromId(null), AlertCondition.above);
      expect(AlertCondition.fromId('garbage'), AlertCondition.above);
    });

    test('currency follows the asset kind', () {
      expect(_alert(condition: AlertCondition.above, target: 1).currency, 'BRL');
      expect(
          _alert(condition: AlertCondition.above, target: 1, kind: AssetKind.stockUs)
              .currency,
          'USD');
      expect(
          _alert(condition: AlertCondition.above, target: 1, kind: AssetKind.crypto)
              .currency,
          'BRL');
    });
  });
}
