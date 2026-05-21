import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StatsPeriodSelector extends StatelessWidget {
  const StatsPeriodSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: const Row(
        children: [
          _PeriodOption(label: 'Today', selected: true),
          _PeriodOption(label: 'Week'),
          _PeriodOption(label: 'Month'),
        ],
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  final String label;
  final bool selected;

  const _PeriodOption({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.iconBox.withValues(alpha: 0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.42),
                  width: 1.2,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.secondary : AppColors.neutral,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
