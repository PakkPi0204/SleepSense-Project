import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SetupIntroIllustration extends StatelessWidget {
  const SetupIntroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 272,
        height: 220,
        child: CustomPaint(painter: _SetupIntroIllustrationPainter()),
      ),
    );
  }
}

class _SetupIntroIllustrationPainter extends CustomPainter {
  static const _sensorPositions = [
    _SensorNodeData(
      icon: Icons.air_rounded,
      alignment: Alignment(-0.88, -0.55),
    ),
    _SensorNodeData(
      icon: Icons.wb_sunny_outlined,
      alignment: Alignment(0.0, -0.96),
    ),
    _SensorNodeData(
      icon: Icons.thermostat_outlined,
      alignment: Alignment(0.72, -0.82),
    ),
    _SensorNodeData(
      icon: Icons.water_drop_outlined,
      alignment: Alignment(0.94, 0.34),
    ),
    _SensorNodeData(icon: Icons.bolt_outlined, alignment: Alignment(0.0, 0.96)),
    _SensorNodeData(
      icon: Icons.volume_up_outlined,
      alignment: Alignment(-0.96, 0.46),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final panelRect = Rect.fromLTWH(20, 36, size.width - 40, 150);
    final panelRRect = RRect.fromRectAndRadius(
      panelRect,
      const Radius.circular(30),
    );
    final borderPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final panelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.iconBox.withValues(alpha: 0.72),
          AppColors.card.withValues(alpha: 0.82),
        ],
      ).createShader(panelRect);

    canvas.drawRRect(panelRRect, panelPaint);
    canvas.drawRRect(panelRRect, borderPaint);
    _drawStars(canvas, panelRect);
    _drawMoon(canvas, Offset(panelRect.right - 42, panelRect.top + 34));
    _drawBed(canvas, panelRect);
    _drawHub(canvas, panelRect.center.translate(0, -18));
    _drawSensorNodes(canvas, size, panelRect);
  }

  void _drawStars(Canvas canvas, Rect bounds) {
    final paint = Paint()..color = AppColors.neutral.withValues(alpha: 0.68);
    for (final offset in [
      Offset(bounds.left + 44, bounds.top + 66),
      Offset(bounds.left + 74, bounds.top + 42),
      Offset(bounds.right - 66, bounds.top + 40),
      Offset(bounds.right - 50, bounds.top + 72),
    ]) {
      canvas.drawCircle(offset, 1.4, paint);
    }
  }

  void _drawMoon(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 18, Paint()..color = const Color(0xFFE7F5FF));
    canvas.drawCircle(
      center.translate(14, -10),
      18,
      Paint()..color = AppColors.primary,
    );
  }

  void _drawBed(Canvas canvas, Rect panelRect) {
    final bedBase = RRect.fromRectAndRadius(
      Rect.fromLTWH(panelRect.left + 18, panelRect.bottom - 28, 178, 28),
      const Radius.circular(14),
    );
    final headboard = RRect.fromRectAndRadius(
      Rect.fromLTWH(panelRect.left + 38, panelRect.bottom - 68, 142, 58),
      const Radius.circular(26),
    );
    final pillow = RRect.fromRectAndRadius(
      Rect.fromLTWH(panelRect.left + 48, panelRect.bottom - 44, 46, 18),
      const Radius.circular(10),
    );
    final rail = RRect.fromRectAndRadius(
      Rect.fromLTWH(panelRect.left + 92, panelRect.bottom - 32, 148, 16),
      const Radius.circular(10),
    );

    canvas
      ..drawRRect(headboard, Paint()..color = const Color(0xFF243164))
      ..drawRRect(
        headboard,
        Paint()
          ..color = AppColors.neutral.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      )
      ..drawRRect(
        rail,
        Paint()..color = AppColors.secondary.withValues(alpha: 0.16),
      )
      ..drawRRect(
        rail,
        Paint()
          ..color = AppColors.secondary.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      )
      ..drawRRect(bedBase, Paint()..color = const Color(0xFF2A376D))
      ..drawRRect(
        bedBase,
        Paint()
          ..color = AppColors.neutral.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      )
      ..drawRRect(pillow, Paint()..color = AppColors.cardBorder);
  }

  void _drawHub(Canvas canvas, Offset center) {
    final ringPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dashPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (final radius in [28.0, 36.0, 44.0]) {
      canvas.drawCircle(center, radius, ringPaint);
    }

    for (final end in [
      center.translate(-72, 46),
      center.translate(-26, 70),
      center.translate(34, 70),
      center.translate(80, 48),
    ]) {
      _drawDashedLine(canvas, center, end, dashPaint);
    }

    canvas.drawCircle(center, 24, Paint()..color = AppColors.iconBox);
    canvas.drawIcon(
      Icons.memory_rounded,
      center.translate(-12, -12),
      24,
      Paint()..color = AppColors.secondary,
    );
  }

  void _drawSensorNodes(Canvas canvas, Size size, Rect panelRect) {
    final center = panelRect.center;
    for (final sensor in _sensorPositions) {
      final position = Offset(
        center.dx + sensor.alignment.x * panelRect.width / 2,
        center.dy + sensor.alignment.y * panelRect.height / 2,
      );
      canvas.drawCircle(position, 22, Paint()..color = AppColors.iconBox);
      canvas.drawCircle(
        position,
        22,
        Paint()
          ..color = AppColors.secondary.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.drawIcon(
        sensor.icon,
        position.translate(-10, -10),
        20,
        Paint()..color = AppColors.secondary,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vector = end - start;
    final distance = vector.distance;
    final direction = vector / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * (drawn + 5).clamp(0, distance);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += 12;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _SensorNodeData {
  final IconData icon;
  final Alignment alignment;

  const _SensorNodeData({required this.icon, required this.alignment});
}

extension _CanvasIcon on Canvas {
  void drawIcon(IconData icon, Offset offset, double size, Paint paint) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: paint.color,
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(this, offset);
  }
}
