import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/sleep_models.dart';

class EnvironmentChecklist extends StatelessWidget {
  final List<EnvironmentCheckItem> items;

  const EnvironmentChecklist({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Environment Checklist',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              iconAlignment: IconAlignment.end,
              label: const Text('Details'),
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: EnvironmentChecklistItem(item: item),
          ),
        ),
      ],
    );
  }
}

class EnvironmentChecklistItem extends StatelessWidget {
  final EnvironmentCheckItem item;

  const EnvironmentChecklistItem({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.warning ? AppColors.accent : AppColors.secondary;
    final iconBackground = item.warning
        ? AppColors.accent.withValues(alpha: 0.18)
        : AppColors.iconBox.withValues(alpha: 0.86);

    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: statusColor, size: 29),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.value,
                  style: const TextStyle(
                    color: AppColors.neutral,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusPill(label: item.status, color: statusColor),
          const SizedBox(width: 12),
          Icon(
            item.warning
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: statusColor,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
