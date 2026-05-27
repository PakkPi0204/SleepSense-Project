import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SplashBrandMark extends StatelessWidget {
  const SplashBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.42),
          width: 1.1,
        ),
      ),
      child: CustomPaint(painter: _SplashBrandMarkPainter()),
    );
  }
}

class _SplashBrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final moonPaint = Paint()..color = AppColors.secondary;
    final cutoutPaint = Paint()..color = AppColors.primary;
    final accentPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 4.6
      ..strokeCap = StrokeCap.round;
    final basePaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.82)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(center.dx - 12, center.dy - 4), 28, moonPaint);
    canvas.drawCircle(Offset(center.dx + 12, center.dy - 12), 28, cutoutPaint);

    canvas.drawLine(
      Offset(center.dx - 28, center.dy + 26),
      Offset(center.dx + 28, center.dy + 26),
      accentPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 18, center.dy + 42),
      Offset(center.dx + 18, center.dy + 42),
      basePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
