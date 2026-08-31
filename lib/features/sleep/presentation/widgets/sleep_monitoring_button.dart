import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';
import '../../models/sleep_models.dart';

class SleepMonitoringButton extends StatefulWidget {
  final List<EnvironmentCheckItem> items;

  const SleepMonitoringButton({required this.items, super.key});

  @override
  State<SleepMonitoringButton> createState() => _SleepMonitoringButtonState();
}

class _SleepMonitoringButtonState extends State<SleepMonitoringButton> {
  bool _monitoringActive = false;
  DateTime? _startedAt;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _monitoringActive
        ? AppColors.iconBox.withValues(alpha: 0.98)
        : AppColors.secondary;
    final foregroundColor = _monitoringActive
        ? AppColors.secondary
        : AppColors.primary;
    final icon = _monitoringActive
        ? Icons.radio_button_checked_rounded
        : Icons.fact_check_outlined;
    final label = _monitoringActive ? 'Monitoring Active' : 'Check Room';

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: () => _showRoomCheckResult(context),
        icon: Icon(icon, size: 30),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 16,
          shadowColor: AppColors.secondary.withValues(alpha: 0.48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  void _showRoomCheckResult(BuildContext context) {
    if (_monitoringActive) {
      _showActiveMonitoringSheet(context);

      // TODO: Enable again if active tap should only repeat the success state.
      // _showMonitoringStartedSheet(context);
      return;
    }

    final warnings = widget.items.where((item) => item.warning).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      isScrollControlled: true,
      builder: (context) {
        return _RoomCheckSheet(
          warnings: warnings,
          onStartMonitoring: () {
            Navigator.of(context).pop();
            setState(() {
              _monitoringActive = true;
              _startedAt = DateTime.now();
            });
            _showMonitoringStartedSheet(context);

            // TODO: Enable again if we want a lightweight notification.
            // The SnackBar was easy to miss behind the bottom navigation.
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //     content: Text('Night monitoring started.'),
            //     behavior: SnackBarBehavior.floating,
            //   ),
            // );
          },
        );
      },
    );
  }

  void _showActiveMonitoringSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (sheetContext) {
        return _ActiveMonitoringSheet(
          startedAt: _startedAt,
          onKeepMonitoring: () => Navigator.of(sheetContext).pop(),
          onStopMonitoring: () async {
            final start = _startedAt ?? DateTime.now();
            final end = DateTime.now();
            final duration = end.difference(start);

            Navigator.of(sheetContext).pop();
            setState(() {
              _monitoringActive = false;
              _startedAt = null;
            });

            // สร้าง morning report จริงจากช่วงเวลานอน
            final api = ApiService();
            final ok = await api.generateReport(
              sleepStart: start.millisecondsSinceEpoch,
              sleepEnd: end.millisecondsSinceEpoch,
            );
            api.dispose();

            if (!context.mounted) return;
            _showMonitoringStoppedSheet(context, duration, ok);
          },
        );
      },
    );
  }

  void _showMonitoringStartedSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (context) => const _MonitoringStartedSheet(),
    );
  }

  void _showMonitoringStoppedSheet(
      BuildContext context, Duration duration, bool reportCreated) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      isScrollControlled: true,
      builder: (context) => _MonitoringStoppedSheet(
        duration: duration,
        reportCreated: reportCreated,
      ),
    );
  }
}

class _ActiveMonitoringSheet extends StatelessWidget {
  final DateTime? startedAt;
  final VoidCallback onKeepMonitoring;
  final VoidCallback onStopMonitoring;

  const _ActiveMonitoringSheet({
    required this.startedAt,
    required this.onKeepMonitoring,
    required this.onStopMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = startedAt == null
        ? 'SleepSense is currently monitoring your room conditions.'
        : 'Started at ${_formatStartedAt(startedAt!)}. Stop monitoring when you wake up.';

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.42),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHeader(
                    icon: Icons.radio_button_checked_rounded,
                    iconColor: AppColors.secondary,
                    title: 'Night monitoring is active',
                    message: subtitle,
                  ),
                  const SizedBox(height: 24),
                  _SheetActions(
                    primaryLabel: 'Stop Monitoring',
                    secondaryLabel: 'Keep Monitoring',
                    onPrimary: onStopMonitoring,
                    onSecondary: onKeepMonitoring,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatStartedAt(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MonitoringStartedSheet extends StatelessWidget {
  const _MonitoringStartedSheet();

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.48),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.secondary,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Night monitoring started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SleepSense will monitor your room conditions overnight.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.neutral,
                      fontSize: 16,
                      height: 1.42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Text('Done'),
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

class _MonitoringStoppedSheet extends StatelessWidget {
  final Duration duration;
  final bool reportCreated;

  const _MonitoringStoppedSheet({
    required this.duration,
    required this.reportCreated,
  });

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.42),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: AppColors.secondary,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        reportCreated
                            ? 'สร้างรายงานเช้าแล้ว'
                            : 'หยุดการติดตามแล้ว',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        reportCreated
                            ? 'ดูรายงานสภาพแวดล้อมการนอนคืนนี้ได้ที่หน้า Stats'
                            : 'ไม่สามารถสร้างรายงานได้ (เชื่อมต่อ backend ไม่สำเร็จ)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.neutral,
                          fontSize: 16,
                          height: 1.42,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ReportMetricRow(
                      icon: Icons.schedule_rounded,
                      label: 'ระยะเวลาติดตาม',
                      value: _formatDuration(duration),
                    ),
                    const SizedBox(height: 10),
                    _ReportMetricRow(
                      icon: reportCreated
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      label: 'สถานะรายงาน',
                      value: reportCreated ? 'สร้างสำเร็จ' : 'ไม่สำเร็จ',
                      accent: !reportCreated,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);

    if (hours == 0 && minutes == 0) return 'Less than 1 min';
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class _ReportMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  const _ReportMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.accent : AppColors.secondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.iconBox.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.neutral,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCheckSheet extends StatelessWidget {
  final List<EnvironmentCheckItem> warnings;
  final VoidCallback onStartMonitoring;

  const _RoomCheckSheet({
    required this.warnings,
    required this.onStartMonitoring,
  });

  bool get _roomReady => warnings.isEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _roomReady
                      ? AppColors.secondary.withValues(alpha: 0.42)
                      : AppColors.accent.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: _roomReady
                  ? _RoomReadyContent(onStartMonitoring: onStartMonitoring)
                  : _RoomNeedsWorkContent(
                      warnings: warnings,
                      onStartMonitoring: onStartMonitoring,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomReadyContent extends StatelessWidget {
  final VoidCallback onStartMonitoring;

  const _RoomReadyContent({required this.onStartMonitoring});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetHeader(
          icon: Icons.check_circle_outline_rounded,
          iconColor: AppColors.secondary,
          title: 'Your room is ready',
          message:
              'Your bedroom conditions look comfortable for sleep. Do you want to start monitoring now?',
        ),
        const SizedBox(height: 24),
        _SheetActions(
          primaryLabel: 'Start Monitoring',
          secondaryLabel: 'Not Now',
          onPrimary: onStartMonitoring,
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _RoomNeedsWorkContent extends StatelessWidget {
  final List<EnvironmentCheckItem> warnings;
  final VoidCallback onStartMonitoring;

  const _RoomNeedsWorkContent({
    required this.warnings,
    required this.onStartMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetHeader(
          icon: Icons.warning_amber_rounded,
          iconColor: AppColors.accent,
          title: 'Adjust your room first',
          message:
              'Some room conditions may affect sleep comfort. Try improving these before monitoring.',
        ),
        const SizedBox(height: 18),
        ...warnings.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WarningRow(item: item),
          ),
        ),
        const SizedBox(height: 12),
        _SheetActions(
          primaryLabel: 'Check Again',
          secondaryLabel: 'Start Anyway',
          onPrimary: () => Navigator.of(context).pop(),
          onSecondary: onStartMonitoring,
        ),
      ],
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;

  const _SheetHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: iconColor, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: AppColors.neutral,
                  fontSize: 16,
                  height: 1.42,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningRow extends StatelessWidget {
  final EnvironmentCheckItem item;

  const _WarningRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(item.icon, color: AppColors.accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.title} needs attention',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.value} • ${item.status}',
                  style: const TextStyle(
                    color: AppColors.neutral,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetActions extends StatelessWidget {
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _SheetActions({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(primaryLabel),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onSecondary,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.neutral,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(secondaryLabel),
        ),
      ],
    );
  }
}

// TODO: Enable in Progress II if we return to direct-start behavior.
// Previous button intent:
// - Icon: Icons.play_arrow_rounded
// - Label: 'Start Night Monitoring'
// - Action: start night monitoring immediately.
