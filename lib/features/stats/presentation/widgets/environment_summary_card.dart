import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/stats_models.dart';

class EnvironmentSummaryCard extends StatelessWidget {
  final EnvironmentSummary summary;

  const EnvironmentSummaryCard({required this.summary, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.34),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _SummaryText(summary: summary)),
              const SizedBox(width: 18),
              SummaryGauge(percentage: summary.percentage),
            ],
          ),
          const SizedBox(height: 26),
          Divider(color: AppColors.cardBorder.withValues(alpha: 0.92)),
          const SizedBox(height: 20),
          Row(
            children: summary.metrics
                .map((metric) => Expanded(child: _SummaryMetric(metric)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SummaryText extends StatelessWidget {
  final EnvironmentSummary summary;

  const _SummaryText({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ENVIRONMENT SUMMARY',
          style: TextStyle(
            color: AppColors.neutral,
            fontSize: 16,
            letterSpacing: 2.3,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '${summary.percentage}%',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 58,
            height: 0.95,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.64),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                summary.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          summary.message,
          style: const TextStyle(
            color: AppColors.neutral,
            fontSize: 18,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class SummaryGauge extends StatelessWidget {
  final int percentage;

  const SummaryGauge({required this.percentage, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(104, 74),
            painter: _SummaryGaugePainter(progress: percentage / 100),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '$percentage%',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGaugePainter extends CustomPainter {
  final double progress;

  const _SummaryGaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(8, 16, size.width - 16, size.height);
    final backgroundPaint = Paint()
      ..color = AppColors.iconBox.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2);

    canvas.drawArc(rect, math.pi, math.pi, false, backgroundPaint);
    canvas.drawArc(
      rect,
      math.pi,
      progress.clamp(0, 1) * math.pi,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SummaryGaugePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SummaryMetric extends StatelessWidget {
  final SummaryMetric metric;

  const _SummaryMetric(this.metric);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            metric.value,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.neutral,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
