import 'package:flutter/material.dart';

import '../../../app/navigation/app_tab.dart';
import '../../../core/theme/app_colors.dart';

class SleepSenseBottomNavBar extends StatelessWidget {
  final AppTab activeTab;
  final ValueChanged<AppTab> onTabSelected;

  const SleepSenseBottomNavBar({
    required this.activeTab,
    required this.onTabSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomNavItem(
            tab: AppTab.home,
            icon: Icons.home_outlined,
            label: 'Home',
            active: activeTab == AppTab.home,
            onTap: onTabSelected,
          ),
          _BottomNavItem(
            tab: AppTab.stats,
            icon: Icons.bar_chart_rounded,
            label: 'Stats',
            active: activeTab == AppTab.stats,
            onTap: onTabSelected,
          ),
          _BottomNavItem(
            tab: AppTab.sleep,
            icon: Icons.bed_outlined,
            label: 'Sleep',
            active: activeTab == AppTab.sleep,
            onTap: onTabSelected,
          ),
          _BottomNavItem(
            tab: AppTab.settings,
            icon: Icons.settings_outlined,
            label: 'Settings',
            active: activeTab == AppTab.settings,
            onTap: onTabSelected,
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final AppTab tab;
  final IconData icon;
  final String label;
  final bool active;
  final ValueChanged<AppTab> onTap;

  const _BottomNavItem({
    required this.tab,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.secondary : AppColors.neutral;

    return InkWell(
      onTap: () => onTap(tab),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 78,
        height: 82,
        decoration: BoxDecoration(
          color: active
              ? AppColors.iconBox.withValues(alpha: 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 31),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
