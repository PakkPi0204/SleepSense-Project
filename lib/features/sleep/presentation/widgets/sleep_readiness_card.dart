import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/sleep_models.dart';

class SleepReadinessCard extends StatelessWidget {
  final SleepReadiness readiness;

  const SleepReadinessCard({required this.readiness, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _ReadinessSummary(readiness: readiness)),
              const SizedBox(width: 18),
              ReadinessRing(readiness: readiness),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: readiness.factors
                .map(
                  (factor) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: factor == readiness.factors.last ? 0 : 12,
                      ),
                      child: _FactorBar(factor: factor),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  final SleepReadiness readiness;

  const _ReadinessSummary({required this.readiness});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SLEEP READINESS',
          style: TextStyle(
            color: AppColors.neutral,
            fontSize: 16,
            letterSpacing: 2.6,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              readiness.score.toString(),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 54,
                height: 0.95,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '/ ${readiness.maxScore}',
                style: const TextStyle(
                  color: AppColors.neutral,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
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
                    color: AppColors.secondary.withValues(alpha: 0.65),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              readiness.status,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          readiness.message,
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

class ReadinessRing extends StatelessWidget {
  final SleepReadiness readiness;

  const ReadinessRing({required this.readiness, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 122,
      height: 122,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(122),
            painter: _ReadinessRingPainter(
              progress: readiness.score / readiness.maxScore,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                readiness.score.toString(),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 31,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '/ ${readiness.maxScore}',
                style: const TextStyle(
                  color: AppColors.neutral,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessRingPainter extends CustomPainter {
  final double progress;

  const _ReadinessRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 10;
    final backgroundPaint = Paint()
      ..color = AppColors.iconBox.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2);

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress.clamp(0, 1) * math.pi * 2,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReadinessRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _FactorBar extends StatelessWidget {
  final ReadinessFactor factor;

  const _FactorBar({required this.factor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                factor.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.neutral,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${factor.percent}%',
              style: TextStyle(
                color: factor.color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: factor.percent / 100,
            minHeight: 7,
            backgroundColor: AppColors.cardBorder,
            color: factor.color,
          ),
        ),
      ],
    );
  }
}
