import 'package:flutter/material.dart';

import '../../data/investment_quote_service.dart';
import '../screens/investments_screen.dart' show fmtNative;

const _kGreen = Color(0xFF00A86B);

/// Price chart with a period selector (1D / 1S / 1M / 1A / 5A) and an
/// interactive scrubber: drag a finger (or tap) across the chart to reveal the
/// price at that point via a crosshair, a dot and a floating value bubble.
///
/// Works for any asset — [quoteSymbol] is the provider symbol (Yahoo ticker for
/// stocks, CoinGecko id for crypto). [currency] is used to format the bubble.
class AssetPriceChart extends StatefulWidget {
  final String quoteSymbol;
  final bool isCrypto;
  final String currency;
  const AssetPriceChart({
    super.key,
    required this.quoteSymbol,
    required this.isCrypto,
    this.currency = 'BRL',
  });

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
  int? _touchIndex; // scrubber selection

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _touchIndex = null;
    });
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

  void _selectAt(double dx, double width) {
    if (_series.length < 2 || width <= 0) return;
    final i =
        (dx / width * (_series.length - 1)).round().clamp(0, _series.length - 1);
    if (i != _touchIndex) setState(() => _touchIndex = i);
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
          height: 150,
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _selectAt(d.localPosition.dx, w),
                          onHorizontalDragStart: (d) =>
                              _selectAt(d.localPosition.dx, w),
                          onHorizontalDragUpdate: (d) =>
                              _selectAt(d.localPosition.dx, w),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ChartPainter(
                                    values: _series,
                                    color: accent,
                                    selectedIndex: _touchIndex,
                                    crosshairColor: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (_touchIndex != null)
                                _ValueBubble(
                                  width: w,
                                  index: _touchIndex!,
                                  count: _series.length,
                                  text: fmtNative(
                                      _series[_touchIndex!], widget.currency),
                                  color: accent,
                                ),
                            ],
                          ),
                        );
                      },
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

/// Floating label positioned above the scrubbed point, showing its value.
class _ValueBubble extends StatelessWidget {
  final double width;
  final int index;
  final int count;
  final String text;
  final Color color;
  const _ValueBubble({
    required this.width,
    required this.index,
    required this.count,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const bubbleW = 104.0;
    final x = count <= 1 ? 0.0 : width * (index / (count - 1));
    final maxLeft = (width - bubbleW).clamp(0.0, width);
    final left = (x - bubbleW / 2).clamp(0.0, maxLeft).toDouble();
    return Positioned(
      left: left,
      top: 0,
      child: Container(
        width: bubbleW,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int? selectedIndex;
  final Color crosshairColor;
  _ChartPainter({
    required this.values,
    required this.color,
    this.selectedIndex,
    required this.crosshairColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    double y(double v) =>
        size.height - ((v - minV) / range) * size.height * 0.82 - size.height * 0.12;

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

    // ── Scrubber crosshair + dot ──
    final i = selectedIndex;
    if (i != null && i >= 0 && i < values.length) {
      final px = dx * i;
      final py = y(values[i]);
      canvas.drawLine(
        Offset(px, 0),
        Offset(px, size.height),
        Paint()
          ..color = crosshairColor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(px, py), 5.5,
          Paint()..color = Colors.white);
      canvas.drawCircle(Offset(px, py), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values ||
      old.color != color ||
      old.selectedIndex != selectedIndex;
}
