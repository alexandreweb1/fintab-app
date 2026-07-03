import 'package:flutter_test/flutter_test.dart';
import 'package:my_finance_app/features/investments/domain/investment_trade.dart';

InvestmentTrade _t(TradeSide side, double qty, double price,
        {double fees = 0, int day = 1}) =>
    InvestmentTrade(
      id: '$side-$qty-$price-$day',
      userId: 'u',
      assetId: 'a',
      side: side,
      quantity: qty,
      unitPrice: price,
      fees: fees,
      date: DateTime(2026, 1, day),
      createdAt: DateTime(2026, 1, day),
    );

void main() {
  group('computePosition (weighted average, BR method)', () {
    test('single buy', () {
      final p = computePosition([_t(TradeSide.buy, 100, 30)]);
      expect(p.quantity, 100);
      expect(p.avgCost, 30);
      expect(p.costBasis, 3000);
      expect(p.realizedPnl, 0);
    });

    test('two buys → weighted average cost', () {
      final p = computePosition([
        _t(TradeSide.buy, 100, 30, day: 1),
        _t(TradeSide.buy, 100, 40, day: 2),
      ]);
      expect(p.quantity, 200);
      expect(p.avgCost, 35); // (3000+4000)/200
    });

    test('fees on buy raise the average cost', () {
      final p = computePosition([_t(TradeSide.buy, 100, 30, fees: 100)]);
      expect(p.avgCost, closeTo(31, 1e-9)); // (3000+100)/100
    });

    test('partial sell realizes P&L against avg cost; avg cost unchanged', () {
      final p = computePosition([
        _t(TradeSide.buy, 100, 30, day: 1),
        _t(TradeSide.buy, 100, 40, day: 2), // avg 35
        _t(TradeSide.sell, 50, 50, day: 3), // sell 50 @ 50 → (50-35)*50 = 750
      ]);
      expect(p.quantity, 150);
      expect(p.avgCost, 35); // unchanged by the sell (BR method)
      expect(p.costBasis, closeTo(150 * 35, 1e-9));
      expect(p.realizedPnl, closeTo(750, 1e-9));
    });

    test('sell everything → zero holdings, realized captured', () {
      final p = computePosition([
        _t(TradeSide.buy, 10, 100, day: 1),
        _t(TradeSide.sell, 10, 120, day: 2),
      ]);
      expect(p.quantity, 0);
      expect(p.hasHoldings, false);
      expect(p.realizedPnl, closeTo(200, 1e-9)); // (120-100)*10
    });

    test('trades consolidate regardless of input order', () {
      final ordered = computePosition([
        _t(TradeSide.buy, 100, 30, day: 1),
        _t(TradeSide.sell, 40, 45, day: 5),
      ]);
      final shuffled = computePosition([
        _t(TradeSide.sell, 40, 45, day: 5),
        _t(TradeSide.buy, 100, 30, day: 1),
      ]);
      expect(shuffled.quantity, ordered.quantity);
      expect(shuffled.realizedPnl, closeTo(ordered.realizedPnl, 1e-9));
    });
  });
}
