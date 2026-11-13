import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../domain/measurement_models.dart';

/// Kilo eğilim çizgisi (paketsiz, CustomPainter).
class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({super.key, required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (points.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Eğilim çizgisi için en az iki kilo ölçümü gerekir.',
          style: t.textTheme.bodyMedium,
        ),
      );
    }
    final first = points.first, last = points.last;
    final label =
        'Kilo eğilimi: ${formatDate(first.date)} tarihinde '
        '${formatMetric(MeasurementMetric.weight, first.value)}, '
        '${formatDate(last.date)} tarihinde '
        '${formatMetric(MeasurementMetric.weight, last.value)}; '
        '${points.length} ölçüm.';
    final cs = t.colorScheme;
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(
              points: points,
              line: cs.primary,
              grid: cs.outlineVariant,
              textColor: cs.onSurfaceVariant,
              fill: cs.surface,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.textColor,
    required this.fill,
  });

  final List<TrendPoint> points;
  final Color line, grid, textColor, fill;

  TextPainter _text(String s) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(color: textColor, fontSize: 11),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    var lo = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    var hi = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final pad = hi == lo ? 1.0 : (hi - lo) * 0.15;
    final dataLo = lo, dataHi = hi;
    lo -= pad;
    hi += pad;

    final maxLabel = _text(formatNumber(dataHi));
    final minLabel = _text(formatNumber(dataLo));
    final leftW =
        (maxLabel.width > minLabel.width ? maxLabel.width : minLabel.width) + 8;
    const topPad = 8.0, bottomH = 22.0, rightPad = 12.0;
    final plot = Rect.fromLTRB(
      leftW + 4,
      topPad,
      size.width - rightPad,
      size.height - bottomH,
    );

    final t0 = points.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.date.millisecondsSinceEpoch.toDouble();
    double xOf(DateTime d) => t1 == t0
        ? plot.center.dx
        : plot.left + (d.millisecondsSinceEpoch - t0) / (t1 - t0) * plot.width;
    double yOf(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    // Sol eksen: en düşük ve en yüksek değer.
    maxLabel.paint(
      canvas,
      Offset(leftW - maxLabel.width, yOf(dataHi) - maxLabel.height / 2),
    );
    minLabel.paint(
      canvas,
      Offset(leftW - minLabel.width, yOf(dataLo) - minLabel.height / 2),
    );

    // Alt eksen: ilk ve son tarih.
    final d0 = _text(formatDate(points.first.date));
    final d1 = _text(formatDate(points.last.date));
    final by = size.height - bottomH + 6;
    d0.paint(canvas, Offset(plot.left, by));
    d1.paint(canvas, Offset(size.width - rightPad - d1.width, by));

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(xOf(points[i].date), yOf(points[i].value));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    for (final p in points) {
      final o = Offset(xOf(p.date), yOf(p.value));
      canvas.drawCircle(o, 4, Paint()..color = fill);
      canvas.drawCircle(
        o,
        4,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      !listEquals(old.points, points) ||
      old.line != line ||
      old.grid != grid ||
      old.textColor != textColor ||
      old.fill != fill;
}
