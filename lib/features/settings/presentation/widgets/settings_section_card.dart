import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../models/settings_models.dart';
import 'settings_switch.dart';

class SettingsSectionCard extends StatelessWidget {
  final SettingsSection section;

  const SettingsSectionCard({required this.section, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            section.title,
            style: const TextStyle(
              color: AppColors.neutral,
              fontSize: 17,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
          ),
          child: Column(
            children: [
              for (var index = 0; index < section.rows.length; index++) ...[
                SettingsRow(row: section.rows[index]),
                if (index != section.rows.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 86, right: 18),
                    child: Divider(
                      height: 1,
                      color: AppColors.cardBorder.withValues(alpha: 0.72),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsRow extends StatelessWidget {
  final SettingsRowData row;

  const SettingsRow({required this.row, super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 86),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.iconBox,
                shape: BoxShape.circle,
              ),
              child: Icon(row.icon, color: AppColors.secondary, size: 27),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                row.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _SettingsRowTrailing(row: row),
          ],
        ),
      ),
    );
  }
}

class _SettingsRowTrailing extends StatelessWidget {
  final SettingsRowData row;

  const _SettingsRowTrailing({required this.row});

  @override
  Widget build(BuildContext context) {
    if (row.type == SettingsRowType.toggle) {
      return SettingsSwitch(value: row.enabled);
    }

    final value = row.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 136),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: value == 'Connected'
                    ? AppColors.secondary
                    : AppColors.neutral,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        if (row.type == SettingsRowType.navigation) ...[
          const SizedBox(width: 10),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.neutral,
            size: 26,
          ),
        ],
      ],
    );
  }
}
