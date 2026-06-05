import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/settings_sample_data.dart';
import '../widgets/settings_header.dart';
import '../widgets/settings_section_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsHeader(),
                  const SizedBox(height: 36),
                  for (final section in settingsSections) ...[
                    SettingsSectionCard(section: section),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
