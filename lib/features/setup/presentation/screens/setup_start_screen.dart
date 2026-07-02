import 'package:flutter/material.dart';

import '../../../../app/navigation/sleepsense_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/setup_info_card.dart';
import '../widgets/setup_intro_illustration.dart';
import '../widgets/setup_steps_card.dart';

class SetupStartScreen extends StatelessWidget {
  const SetupStartScreen({super.key});

  void _openApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return const SleepSenseShell();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SetupHeader(),
                  const SizedBox(height: 36),
                  const SetupIntroIllustration(),
                  const SizedBox(height: 38),
                  const SetupInfoCard(),
                  const SizedBox(height: 28),
                  const SetupStepsCard(),
                  const SizedBox(height: 36),
                  _StartSetupButton(onPressed: () => _openApp(context)),
                  const SizedBox(height: 28),
                  Center(
                    child: TextButton(
                      onPressed: () => _openApp(context),
                      child: const Text('Skip for now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SetupBadgeIcon(),
            SizedBox(width: 12),
            Text(
              'SLEEPSENSE SETUP',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 16,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 28),
        Text(
          'Set up your\nSleepSense',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 42,
            height: 1.15,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 22),
        Text(
          'Connect your device and personalize your bedroom environment.',
          style: TextStyle(
            color: AppColors.neutral,
            fontSize: 21,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SetupBadgeIcon extends StatelessWidget {
  const _SetupBadgeIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: AppColors.iconBox,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.nightlight_round,
        color: AppColors.secondary,
        size: 21,
      ),
    );
  }
}

class _StartSetupButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StartSetupButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: onPressed,
        iconAlignment: IconAlignment.end,
        label: const Text('Start Setup'),
        icon: const Icon(Icons.arrow_forward_rounded, size: 28),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.primary,
          elevation: 16,
          shadowColor: AppColors.secondary.withValues(alpha: 0.42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
