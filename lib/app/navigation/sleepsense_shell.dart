import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../features/stats/presentation/screens/stats_screen.dart';
import '../../features/sleep/presentation/screens/sleep_screen.dart';
import '../../shared/presentation/widgets/sleepsense_bottom_nav_bar.dart';
import 'app_tab.dart';

class SleepSenseShell extends StatefulWidget {
  const SleepSenseShell({super.key});

  @override
  State<SleepSenseShell> createState() => _SleepSenseShellState();
}

class _SleepSenseShellState extends State<SleepSenseShell> {
  AppTab _selectedTab = AppTab.home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedTab.index,
            children: const [
              HomeDashboardScreen(),
              StatsScreen(),
              SleepScreen(),
              _ProgressPlaceholderScreen(
                message:
                    'Settings will be available in the next development phase.',
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: SleepSenseBottomNavBar(
                  activeTab: _selectedTab,
                  onTabSelected: (tab) => setState(() => _selectedTab = tab),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPlaceholderScreen extends StatelessWidget {
  final String message;

  const _ProgressPlaceholderScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 150),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      color: AppColors.iconBox,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: AppColors.secondary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.neutral,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
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
