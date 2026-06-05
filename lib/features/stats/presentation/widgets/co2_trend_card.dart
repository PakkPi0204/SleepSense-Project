import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/stats_models.dart';

class Co2TrendCard extends StatelessWidget {
  final List<TrendPoint> points;

  const Co2TrendCard({required this.points, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CO₂ Trend',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '12 AM – 7 AM',
                      style: TextStyle(
                        color: AppColors.neutral,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.iconBox,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'ppm',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 202,
            width: double.infinity,
            child: CustomPaint(painter: _Co2TrendPainter(points: points)),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              _LegendLine(color: AppColors.secondary),
              SizedBox(width: 8),
              Text(
                'CO₂ level',
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 22),
              _LegendLine(color: AppColors.accent, dashed: true),
              SizedBox(width: 8),
              Text(
                'Avg threshold',
                style: TextStyle(
                  color: AppColors.neutral,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Co2TrendPainter extends CustomPainter {
  final List<TrendPoint> points;

  const _Co2TrendPainter({required this.points});

  static const minY = 400.0;
  static const maxY = 750.0;
  static const threshold = 620.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    const leftPadding = 46.0;
    const rightPadding = 6.0;
    const topPadding = 6.0;
    const bottomPadding = 34.0;

    final chart = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    final gridPaint = Paint()
      ..color = AppColors.cardBorder.withValues(alpha: 0.62)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(
      color: AppColors.neutral,
      fontSize: 13,
      fontWeight: FontWeight.w800,
    );

    for (final value in [750.0, 550.0, 400.0]) {
      final y = _mapY(value, chart);
      _drawDashedLine(
        canvas,
        Offset(chart.left, y),
        Offset(chart.right, y),
        gridPaint,
      );
      _drawText(
        canvas,
        value.toInt().toString(),
        Offset(0, y - 10),
        labelStyle,
      );
    }

    final thresholdPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.72)
      ..strokeWidth = 1.2;
    final thresholdY = _mapY(threshold, chart);
    _drawDashedLine(
      canvas,
      Offset(chart.left, thresholdY),
      Offset(chart.right, thresholdY),
      thresholdPaint,
      dashWidth: 6,
      gapWidth: 7,
    );

    final offsets = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(
          chart.left + (chart.width / (points.length - 1)) * i,
          _mapY(points[i].value, chart),
        ),
    ];

    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 0; i < offsets.length - 1; i++) {
      final current = offsets[i];
      final next = offsets[i + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, chart.bottom)
      ..lineTo(offsets.first.dx, chart.bottom)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.secondary.withValues(alpha: 0.20),
          AppColors.secondary.withValues(alpha: 0.02),
        ],
      ).createShader(chart);
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      _drawText(
        canvas,
        points[i].label,
        Offset(offsets[i].dx - 19, chart.bottom + 12),
        labelStyle,
      );
    }
  }

  double _mapY(double value, Rect chart) {
    final normalized = ((value - minY) / (maxY - minY)).clamp(0, 1);
    return chart.bottom - chart.height * normalized;
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashWidth = 4,
    double gapWidth = 6,
  }) {
    final distance = (end - start).distance;
    final direction = (end - start) / distance;
    var drawn = 0.0;

    while (drawn < distance) {
      final segmentStart = start + direction * drawn;
      final segmentEnd =
          start + direction * math.min(drawn + dashWidth, distance);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _Co2TrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final bool dashed;

  const _LegendLine({required this.color, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 10,
      child: CustomPaint(
        painter: _LegendLinePainter(color: color, dashed: dashed),
      ),
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final bool dashed;

  const _LegendLinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 6, size.width), size.height / 2),
        paint,
      );
      x += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dashed != dashed;
  }
}
