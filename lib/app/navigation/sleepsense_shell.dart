import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../features/sleep/presentation/screens/sleep_screen.dart';
import '../../features/stats/presentation/screens/stats_screen.dart';
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
              _ComingSoonScreen(title: 'Settings'),
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

class _ComingSoonScreen extends StatelessWidget {
  final String title;

  const _ComingSoonScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
