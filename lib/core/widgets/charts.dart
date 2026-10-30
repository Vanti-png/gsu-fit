import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChartPoint {
  const ChartPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

class BarDatum {
  const BarDatum(this.label, this.value);

  final String label;
  final double value;
}

typedef ValueFormatter = String Function(double value);
typedef DateFormatter = String Function(DateTime date);

/// Lightweight time-series line chart drawn with a CustomPainter.
/// Tap or drag across it to read individual values.
class SimpleLineChart extends StatefulWidget {
  const SimpleLineChart({
    super.key,
    required this.points,
    required this.formatValue,
    required this.formatDate,
    this.height = 200,
    this.color,
  });

  /// Must be sorted by date, oldest first.
  final List<ChartPoint> points;
  final ValueFormatter formatValue;
  final DateFormatter formatDate;
  final double height;
  final Color? color;

  @override
  State<SimpleLineChart> createState() => _SimpleLineChartState();
}

class _SimpleLineChartState extends State<SimpleLineChart> {
  int? _selected;

  void _select(Offset local, Size size) {
    if (widget.points.isEmpty) return;
    final offsets = _LineChartPainter.positions(widget.points, size);
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < offsets.length; i++) {
      final distance = (offsets[i].dx - local.dx).abs();
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    setState(() => _selected = best);
  }

  @override
  void didUpdateWidget(covariant SimpleLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.points.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;
    final last = widget.points.isEmpty ? null : widget.points.last;
    return Semantics(
      label: last == null
          ? null
          : '${widget.formatDate(last.date)}: ${widget.formatValue(last.value)}',
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _select(details.localPosition, size),
              onHorizontalDragUpdate: (details) => _select(details.localPosition, size),
              child: CustomPaint(
                size: size,
                painter: _LineChartPainter(
                  points: widget.points,
                  color: color,
                  gridColor: theme.colorScheme.outlineVariant,
                  labelStyle: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltipStyle: theme.textTheme.labelMedium!.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                  ),
                  tooltipColor: theme.colorScheme.inverseSurface,
                  surfaceColor: theme.colorScheme.surface,
                  formatValue: widget.formatValue,
                  formatDate: widget.formatDate,
                  selected: _selected,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.color,
    required this.gridColor,
    required this.labelStyle,
    required this.tooltipStyle,
    required this.tooltipColor,
    required this.surfaceColor,
    required this.formatValue,
    required this.formatDate,
    required this.selected,
  });

  final List<ChartPoint> points;
  final Color color;
  final Color gridColor;
  final TextStyle labelStyle;
  final TextStyle tooltipStyle;
  final Color tooltipColor;
  final Color surfaceColor;
  final ValueFormatter formatValue;
  final DateFormatter formatDate;
  final int? selected;

  static const double _left = 48;
  static const double _right = 12;
  static const double _top = 28;
  static const double _bottom = 24;

  static Rect _chartRect(Size size) =>
      Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom);

  static (double, double) _range(List<ChartPoint> points) {
    var minY = points.map((p) => p.value).reduce(math.min);
    var maxY = points.map((p) => p.value).reduce(math.max);
    if ((maxY - minY).abs() < 1e-6) {
      final pad = maxY.abs() < 1 ? 1.0 : maxY.abs() * 0.05;
      return (minY - pad, maxY + pad);
    }
    final pad = (maxY - minY) * 0.12;
    return (minY - pad, maxY + pad);
  }

  static List<Offset> positions(List<ChartPoint> points, Size size) {
    if (points.isEmpty) return const [];
    final chart = _chartRect(size);
    final (minY, maxY) = _range(points);
    final start = points.first.date.millisecondsSinceEpoch;
    final span = points.last.date.millisecondsSinceEpoch - start;
    return [
      for (final point in points)
        Offset(
          span == 0
              ? chart.center.dx
              : chart.left + chart.width * (point.date.millisecondsSinceEpoch - start) / span,
          chart.bottom - chart.height * (point.value - minY) / (maxY - minY),
        ),
    ];
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style,
      {TextAlign align = TextAlign.left, double maxWidth = 120}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    var dx = at.dx;
    if (align == TextAlign.right) dx -= painter.width;
    if (align == TextAlign.center) dx -= painter.width / 2;
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final chart = _chartRect(size);
    final (minY, maxY) = _range(points);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.bottom - chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _text(canvas, formatValue(minY + (maxY - minY) * i / 3), Offset(_left - 6, y),
          labelStyle, align: TextAlign.right, maxWidth: _left - 4);
    }

    final offsets = positions(points, size);
    final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (final offset in offsets.skip(1)) {
      line.lineTo(offset.dx, offset.dy);
    }
    if (offsets.length > 1) {
      final fill = Path.from(line)
        ..lineTo(offsets.last.dx, chart.bottom)
        ..lineTo(offsets.first.dx, chart.bottom)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final dot = Paint()..color = color;
    final dotHole = Paint()..color = surfaceColor;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, dot);
      canvas.drawCircle(offset, 2, dotHole);
    }

    final y = size.height - _bottom / 2;
    _text(canvas, formatDate(points.first.date), Offset(chart.left, y), labelStyle);
    if (points.length > 1) {
      _text(canvas, formatDate(points.last.date), Offset(chart.right, y), labelStyle,
          align: TextAlign.right);
    }

    final index = selected;
    if (index != null && index < offsets.length) {
      final at = offsets[index];
      canvas.drawLine(Offset(at.dx, chart.top), Offset(at.dx, chart.bottom), grid);
      canvas.drawCircle(at, 6, dot);
      final label = '${formatDate(points[index].date)} · ${formatValue(points[index].value)}';
      final painter = TextPainter(
        text: TextSpan(text: label, style: tooltipStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width - 16);
      final width = painter.width + 16;
      final left =
          (at.dx - width / 2).clamp(0.0, math.max(0.0, size.width - width)).toDouble();
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, painter.height + 8),
        const Radius.circular(8),
      );
      canvas.drawRRect(box, Paint()..color = tooltipColor);
      painter.paint(canvas, Offset(left + 8, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

/// Vertical bar chart; tap a bar to see its value.
class SimpleBarChart extends StatefulWidget {
  const SimpleBarChart({
    super.key,
    required this.bars,
    required this.formatValue,
    this.height = 200,
    this.color,
  });

  final List<BarDatum> bars;
  final ValueFormatter formatValue;
  final double height;
  final Color? color;

  @override
  State<SimpleBarChart> createState() => _SimpleBarChartState();
}

class _SimpleBarChartState extends State<SimpleBarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;
    final maxValue = widget.bars.isEmpty
        ? 0.0
        : widget.bars.map((b) => b.value).reduce(math.max);
    final selected = _selected;
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      label: widget.bars.isEmpty
          ? null
          : '${widget.bars.last.label}: ${widget.formatValue(widget.bars.last.value)}',
      child: SizedBox(
        height: widget.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 24,
              child: Text(
                selected != null && selected < widget.bars.length
                    ? '${widget.bars[selected].label} · ${widget.formatValue(widget.bars[selected].value)}'
                    : widget.formatValue(maxValue),
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < widget.bars.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selected = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: maxValue <= 0
                                      ? 0.02
                                      : math.max(0.02, widget.bars[i].value / maxValue),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: i == selected
                                          ? theme.colorScheme.tertiary
                                          : color,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.bars[i].label,
                                style: labelStyle,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                softWrap: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
