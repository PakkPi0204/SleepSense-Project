import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_models.dart';
import '../../../../core/storage/suggestion_ack_store.dart';

/// Per-factor content: icon, display name, unit, advice and action button label.
class _FactorInfo {
  final IconData icon;
  final String label; // e.g. "CO₂", "Temperature"
  final String unit;
  final String verb; // e.g. "is critically high"
  final String suggestion;
  final String actionLabel; // short action button text, e.g. "Turn on fan/AC"

  const _FactorInfo({
    required this.icon,
    required this.label,
    required this.unit,
    required this.verb,
    required this.suggestion,
    required this.actionLabel,
  });
}

const Map<String, _FactorInfo> _factorInfo = {
  'CO2': _FactorInfo(
    icon: Icons.air,
    label: 'CO₂',
    unit: 'ppm',
    verb: 'is critically high',
    suggestion: 'Open a window or improve ventilation immediately.',
    actionLabel: "I've opened the window",
  ),
  'TEMPERATURE': _FactorInfo(
    icon: Icons.thermostat_outlined,
    label: 'Temperature',
    unit: '°C',
    verb: 'is out of a safe range',
    suggestion: 'Adjust your thermostat, fan, or AC to a comfortable range.',
    actionLabel: "I've turned on the fan/AC",
  ),
  'HUMIDITY': _FactorInfo(
    icon: Icons.water_drop_outlined,
    label: 'Humidity',
    unit: '%',
    verb: 'is out of a safe range',
    suggestion:
        'Use a dehumidifier or humidifier to balance moisture levels.',
    actionLabel: "I've adjusted the humidity",
  ),
  'PM25': _FactorInfo(
    icon: Icons.speed_outlined,
    label: 'PM2.5',
    unit: 'μg/m³',
    verb: 'is critically high',
    suggestion: 'Turn on an air purifier and keep windows closed.',
    actionLabel: "I've turned on the air purifier",
  ),
  'NOISE': _FactorInfo(
    icon: Icons.volume_up_outlined,
    label: 'Sound',
    unit: 'dB',
    verb: 'is critically loud',
    suggestion: 'Reduce noise sources or consider earplugs before sleeping.',
    actionLabel: "I've handled the noise",
  ),
  'LIGHT': _FactorInfo(
    icon: Icons.wb_sunny_outlined,
    label: 'Light',
    unit: 'lux',
    verb: 'is critically bright',
    suggestion: 'Dim or turn off lights for better sleep quality.',
    actionLabel: "I've dimmed the lights",
  ),
};

_FactorInfo _infoFor(String factor) =>
    _factorInfo[factor.toUpperCase()] ??
    _FactorInfo(
      icon: Icons.warning_amber_rounded,
      label: factor,
      unit: '',
      verb: 'needs immediate attention',
      suggestion: 'Check this room condition as soon as possible.',
      actionLabel: "I've handled it",
    );

/// Modal popup for a critical alert.
/// Show it via [CriticalAlertDialog.show].
class CriticalAlertDialog extends StatelessWidget {
  final AlertDto alert;
  final VoidCallback? onViewRoomStatus;

  const CriticalAlertDialog({
    required this.alert,
    this.onViewRoomStatus,
    super.key,
  });

  static const _critical = Color(0xFFE85D5D);

  /// Shows the dialog. Tapping outside will not dismiss it — one of the buttons
  /// below has to be pressed.
  static Future<void> show(
    BuildContext context,
    AlertDto alert, {
    VoidCallback? onViewRoomStatus,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => CriticalAlertDialog(
        alert: alert,
        onViewRoomStatus: onViewRoomStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _infoFor(alert.factor);
    final valueText = alert.value > 0
        ? '${_fmt(alert.value)} ${info.unit}'.trim()
        : null;
    final thresholdText = alert.threshold > 0
        ? 'threshold ${_fmt(alert.threshold)} ${info.unit}'.trim()
        : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _critical.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Critical room alert',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Some room conditions may need immediate attention.',
                          style: TextStyle(
                            color: AppColors.neutral,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _critical.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _critical.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _critical.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(info.icon, color: _critical, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${info.label} ${info.verb}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (valueText != null) ...[
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: valueText,
                                    style: const TextStyle(
                                      color: _critical,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (thresholdText != null)
                                    TextSpan(
                                      text: '  ·  $thresholdText',
                                      style: const TextStyle(
                                        color: AppColors.neutral,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            info.suggestion,
                            style: const TextStyle(
                              color: AppColors.neutral,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Primary button: acknowledges that the user has dealt with it.
              // The acknowledgement is stored locally against this factor, not
              // against the alert id (which changes every round), so restarting
              // the app will not force this popup again until the problem clears
              // and then recurs.
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    await SuggestionAckStore.instance
                        .acknowledge('CRITICAL_${alert.factor.toUpperCase()}');
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    info.actionLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Remind me later',
                      style: TextStyle(
                        color: AppColors.neutral,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onViewRoomStatus?.call();
                    },
                    child: const Text(
                      'View Room Status',
                      style: TextStyle(
                        color: AppColors.neutral,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
