import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SettingsSwitch extends StatefulWidget {
  final bool value;

  const SettingsSwitch({required this.value, super.key});

  @override
  State<SettingsSwitch> createState() => _SettingsSwitchState();
}

class _SettingsSwitchState extends State<SettingsSwitch> {
  late bool _enabled = widget.value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _enabled = !_enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 66,
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _enabled ? AppColors.secondary : AppColors.cardBorder,
          borderRadius: BorderRadius.circular(999),
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.34),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: _enabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
