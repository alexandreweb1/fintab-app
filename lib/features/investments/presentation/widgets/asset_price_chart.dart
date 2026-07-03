import 'package:flutter/material.dart';

import '../../data/investment_quote_service.dart';

const _kGreen = Color(0xFF00A86B);

/// Price chart with a period selector (1D / 1S / 1M / 1A / 5A).
///
/// Works for any asset — [quoteSymbol] is the provider symbol (Yahoo ticker for
/// stocks, CoinGecko id for crypto). Reused by the saved-asset detail screen and
/// the pre-add preview screen.
class AssetPriceChart extends StatefulWidget {
  final String quoteSymbol;
  final bool isCrypto;
  const AssetPriceChart(
      {super.key, required this.quoteSymbol, required this.isCrypto});

  @override
  State<AssetPriceChart> createState() => _AssetPriceChartState();
}

class _AssetPriceChartState extends State<AssetPriceChart> {
  // label → (stock range, stock interval, crypto days)
  static const _periods = <String, (String, String, int)>{
    '1D': ('1d', '5m', 1),
    '1S': ('5d', '60m', 7),
    '1M': ('1mo', '1d', 30),
    '1A': ('1y', '1d', 365),
    '5A': ('5y', '1wk', 1825),
  };

  String _sel = '1M';
  bool _loading = false;
  List<double> _series = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = _periods[_sel]!;
    final data = widget.isCrypto
        ? await InvestmentQuoteService.fetchCryptoHistory(widget.quoteSymbol,
            days: p.$3)
        : await InvestmentQuoteService.fetchStockHistory(widget.quoteSymbol,
            range: p.$1, interval: p.$2);
    if (!mounted) return;
    setState(() {
      _series = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final up = _series.length >= 2 ? _series.last >= _series.first : true;
    final accent = up ? _kGreen : cs.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 140,
          child: _loading
              ? const Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : _series.length < 2
                  ? Center(
                      child: Text('Sem histórico',
                          style: TextStyle(color: cs.onSurfaceVariant)))
                  : CustomPaint(
                      painter: _ChartPainter(values: _series, color: accent),
                      child: const SizedBox.expand(),
                    ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: _periods.keys
              .map((k) => ButtonSegment(value: k, label: Text(k)))
              .toList(),
          selected: {_sel},
          onSelectionChanged: (s) {
            setState(() => _sel = s.first);
            _load();
          },
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _ChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    double y(double v) =>
        size.height - ((v - minV) / range) * size.height * 0.92 - size.height * 0.04;

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final px = dx * i;
      final py = y(values[i]);
      if (i == 0) {
        line.moveTo(px, py);
      } else {
        line.lineTo(px, py);
      }
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values || old.color != color;
}
