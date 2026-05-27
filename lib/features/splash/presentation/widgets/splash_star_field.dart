import 'package:flutter/material.dart';

class SplashStarField extends StatelessWidget {
  const SplashStarField({super.key});

  static const _stars = [
    _StarData(alignment: Alignment(-0.68, -0.76), size: 4, opacity: 0.58),
    _StarData(alignment: Alignment(0.58, -0.62), size: 3, opacity: 0.48),
    _StarData(alignment: Alignment(-0.52, 0.22), size: 3, opacity: 0.28),
    _StarData(alignment: Alignment(0.64, 0.34), size: 4, opacity: 0.44),
    _StarData(alignment: Alignment(0.18, 0.56), size: 2.5, opacity: 0.34),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final star in _stars)
          Align(
            alignment: star.alignment,
            child: Container(
              width: star.size,
              height: star.size,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: star.opacity),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _StarData {
  final Alignment alignment;
  final double size;
  final double opacity;

  const _StarData({
    required this.alignment,
    required this.size,
    required this.opacity,
  });
}
