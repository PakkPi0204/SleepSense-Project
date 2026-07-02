import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../setup/presentation/screens/setup_start_screen.dart';
import '../widgets/splash_brand_mark.dart';
import '../widgets/splash_star_field.dart';

class SplashScreen extends StatefulWidget {
  static const duration = Duration(milliseconds: 2200);

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: SplashScreen.duration,
    );
    _progress = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOutCubic,
    );
    _progressController
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _openApp();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _openApp() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const SetupStartScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth <= 430;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isCompact ? 0 : 28),
                  child: _SplashPanel(progress: _progress),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplashPanel extends StatelessWidget {
  final Animation<double> progress;

  const _SplashPanel({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.42, -0.86),
          radius: 1.08,
          colors: [Color(0xFF0E3D52), AppColors.primary, Color(0xFF090D2A)],
          stops: [0, 0.42, 1],
        ),
      ),
      child: Stack(
        children: [
          const SplashStarField(),
          Positioned(
            left: -60,
            bottom: 70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    blurRadius: 86,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: _SplashHeroContent(),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 74,
            child: _LoadingMessage(progress: progress),
          ),
        ],
      ),
    );
  }
}

class _SplashHeroContent extends StatelessWidget {
  const _SplashHeroContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SplashBrandMark(),
        SizedBox(height: 34),
        Text(
          'SleepSense',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'Smarter room. Better sleep.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.neutral,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 54),
        _SplashBadge(),
      ],
    );
  }
}

class _SplashBadge extends StatelessWidget {
  const _SplashBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 254,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.34),
          width: 1.2,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BadgeDot(),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bedroom environment\nmonitor',
              style: TextStyle(
                color: AppColors.neutral,
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _LoadingMessage extends StatelessWidget {
  final Animation<double> progress;

  const _LoadingMessage({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        return Column(
          children: [
            const Text(
              'Preparing your sleep space...',
              style: TextStyle(
                color: AppColors.neutral,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: 124,
                height: 4,
                child: LinearProgressIndicator(
                  value: progress.value,
                  backgroundColor: AppColors.cardBorder,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
