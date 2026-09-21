import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import '../../../../core/network/dashboard_mapper.dart';
import '../../../../core/debug/debug_flags.dart';
import '../../../../core/storage/suggestion_ack_store.dart';
import '../../../../core/events/dashboard_refresh_bus.dart';
import '../../../alerts/presentation/screens/alerts_screen.dart';
import '../../../alerts/presentation/widgets/critical_alert_dialog.dart';
import '../../../reports/presentation/screens/morning_report_history_screen.dart';
import '../../data/dashboard_sample_data.dart';
import '../../models/dashboard_models.dart';
import '../widgets/environment_score_card.dart';
import '../widgets/morning_report_card.dart';
import '../widgets/pre_sleep_suggestion_card.dart';
import '../widgets/sensor_grid.dart';
import '../widgets/top_header.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late final AnimationController _pulseController;

  bool _loading = true;
  String? _error;

  // Start from sample data; a successful load replaces it.
  EnvironmentScore _score = sampleEnvironmentScore;
  List<SensorReading> _readings = sampleSensorReadings;
  PreSleepSuggestion _suggestion = samplePreSleepSuggestion;
  MorningReport _report = sampleMorningReport;
  List<AlertDto> _alerts = const [];

  // Factors whose critical popup has already been shown during this session, so
  // it does not reappear every 30 seconds while the app stays open. Deliberately
  // not persisted: the state that survives a restart is the acknowledgement in
  // SuggestionAckStore, tied to the dialog's action button.
  final Set<String> _shownThisSessionFactors = {};
  bool _deviceOffline = false;

  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadData();
    // Auto-refresh every 30 seconds, matching the ESP32's posting interval.
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadData(silent: true),
    );
    // Listen for signals from other tabs — pressing Stop Monitoring on the Sleep
    // screen generates a morning report, and this screen should show it at once
    // rather than waiting up to 30 seconds. Necessary because IndexedStack means
    // this screen is never disposed or re-initialised on a tab switch.
    DashboardRefreshBus.instance.listenable.addListener(_onExternalDataChanged);
  }

  void _onExternalDataChanged() {
    _loadData(silent: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _autoRefresh?.cancel();
    DashboardRefreshBus.instance.listenable
        .removeListener(_onExternalDataChanged);
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    // Each endpoint is called in isolation rather than through a single
    // Future.wait. Previously one failure — a dropped connection while fetching
    // alerts, say — discarded the whole batch including the sensor reading and
    // thresholds. That was why the dashboard would sit on stale values and seem
    // to need an app restart before it happened to catch a round where every
    // endpoint succeeded at once.
    //
    // All five requests start together (awaiting them one at a time would make
    // this five times slower), and are awaited afterwards. The raw sensor and
    // threshold futures are kept separately from the _safeCall wrappers so
    // _fetchAlertsForHome can reuse them on its fallback path — awaiting the
    // same future twice does not issue a second request.
    final rawSensorFuture = _api.fetchLatestSensor();
    final rawThresholdsFuture =
        _api.fetchThresholds(deviceId: ApiConfig.deviceId);

    final sensorFuture = _safeCall(() => rawSensorFuture);
    final thresholdsFuture = _safeCall(() => rawThresholdsFuture);
    final suggestionsFuture = _safeCall(() => _api.fetchPreSleepSuggestions());
    final reportFuture = _safeCall(() => _api.fetchLatestReport());
    // /active rather than /recent for the Home badge and the critical popup: it
    // returns only alerts the backend still considers active, not the whole
    // history including problems that have since cleared. An older backend
    // without that endpoint returns 404, and _fetchAlertsForHome falls back to
    // /recent filtered client-side, so a demo works either way.
    final alertsFuture = _safeCall(
        () => _fetchAlertsForHome(rawSensorFuture, rawThresholdsFuture));

    final sensorResult = await sensorFuture;
    final thresholdsResult = await thresholdsFuture;
    final suggestionsResult = await suggestionsFuture;
    final reportResult = await reportFuture;
    final alertsResult = await alertsFuture;

    if (!mounted) return;

    final allFailed = sensorResult.error != null &&
        thresholdsResult.error != null &&
        suggestionsResult.error != null &&
        reportResult.error != null &&
        alertsResult.error != null;

    // Remember the previous suggestion's factor before setState overwrites it,
    // so we can tell whether conditions have just returned to normal.
    final previousSuggestionFactor = _suggestion.factorKey;

    setState(() {
      final sensor = sensorResult.value;
      if (sensor != null) {
        // Thresholds may be null if that endpoint failed this round. The mapper
        // falls back to the defaults rather than dropping the reading too.
        _readings = DashboardMapper.toSensorReadings(sensor,
            thresholds: thresholdsResult.value);
        _score = DashboardMapper.toEnvironmentScore(sensor,
            thresholds: thresholdsResult.value);
        _deviceOffline = DashboardMapper.isStale(sensor.timestamp);
      }
      if (suggestionsResult.value != null) {
        _suggestion =
            DashboardMapper.toPreSleepSuggestion(suggestionsResult.value!);
      }
      if (reportResult.value != null) {
        _report = DashboardMapper.toMorningReport(reportResult.value!);
      }
      if (alertsResult.value != null) {
        _alerts = alertsResult.value!;
      }
      // Only show the error banner when every endpoint failed, which means the
      // backend really is unreachable. One success is enough to count as a
      // working update.
      _error = allFailed
          ? (sensorResult.error ??
              thresholdsResult.error ??
              'Could not reach the backend')
          : null;
      _loading = false;
    });

    // Conditions just went from a problem back to OK. Clear every stored
    // acknowledgement so that the next time the same problem occurs the user is
    // warned again, rather than the old "done" state lingering forever.
    if (previousSuggestionFactor != 'OK' && _suggestion.factorKey == 'OK') {
      SuggestionAckStore.instance.clearAll();
    }

    // Check for critical alerts that have not been acknowledged and force the
    // popup. This runs on every load, including the first one after launch. It
    // stops reappearing only once the user has pressed the dialog's action
    // button, which persists across restarts via SuggestionAckStore — merely
    // having seen it once is not enough.
    if (alertsResult.value != null) {
      await _checkCriticalAlerts(
        alertsResult.value!,
        sensor: sensorResult.value,
        thresholds: thresholdsResult.value,
      );
    }
  }

  /// Wraps a single future so one endpoint's failure cannot block another's result.
  Future<_Result<T>> _safeCall<T>(Future<T> Function() call) async {
    try {
      return _Result<T>(value: await call());
    } catch (e) {
      return _Result<T>(error: e.toString());
    }
  }

  /// Fetch alerts for Home. Tries /active first. If that fails — a 404 from an
  /// older backend that predates the resolved flag — it falls back to /recent
  /// (the full history) and filters client-side: keep the newest row per factor
  /// (/recent is already newest-first), then check each against the current
  /// reading and thresholds. That keeps the app usable without redeploying the
  /// backend.
  Future<List<AlertDto>> _fetchAlertsForHome(
    Future<SensorDataDto?> sensorFuture,
    Future<ThresholdSettingsDto> thresholdsFuture,
  ) async {
    try {
      return await _api.fetchActiveAlerts();
    } catch (_) {
      List<AlertDto> recent;
      try {
        recent = await _api.fetchRecentAlerts(limit: 20);
      } catch (_) {
        return const [];
      }

      SensorDataDto? sensor;
      ThresholdSettingsDto? thresholds;
      try {
        sensor = await sensorFuture;
      } catch (_) {
        sensor = null;
      }
      try {
        thresholds = await thresholdsFuture;
      } catch (_) {
        thresholds = null;
      }

      final seenFactors = <String>{};
      final result = <AlertDto>[];
      for (final a in recent) {
        final key = a.factor.toUpperCase();
        if (seenFactors.contains(key)) {
          continue; // newest row per factor only
        }
        seenFactors.add(key);
        if (sensor != null &&
            !DashboardMapper.isFactorStillFlagged(a.factor, a.level, sensor,
                thresholds: thresholds)) {
          continue;
        }
        result.add(a);
      }
      return result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.secondary,
              backgroundColor: AppColors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TopHeader(),
                    const SizedBox(height: 20),
                    if (_loading) _buildLoading(),
                    if (_error != null && !_loading) _buildErrorBanner(),
                    if (_error == null && _deviceOffline && !_loading)
                      _buildOfflineBanner(),
                    const SizedBox(height: 16),
                    EnvironmentScoreCard(score: _score),
                    const SizedBox(height: 28),
                    SensorGrid(readings: _readings),
                    const SizedBox(height: 28),
                    PreSleepSuggestionCard(suggestion: _suggestion),
                    const SizedBox(height: 24),
                    _alertsSection(),
                    const SizedBox(height: 24),
                    MorningReportCard(
                      report: _report,
                      onTap: _openMorningReports,
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

  /// Morning Reports live on their own screen now, reached from this card.
  void _openMorningReports() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MorningReportHistoryScreen()),
    );
  }

  /// Force the popup for any critical alert that has not been acknowledged.
  /// Acknowledgement is tied to the factor, not to alert.id, which changes on
  /// every sensor update.
  ///
  /// [sensor] and [thresholds] are this round's current values, used to re-check
  /// that each alert is genuinely still critical before forcing a popup. Alert
  /// rows are a historical log, so if the user has just widened a threshold, a
  /// row that was critical under the old settings would otherwise still trigger.
  Future<void> _checkCriticalAlerts(
    List<AlertDto> alerts, {
    required SensorDataDto? sensor,
    required ThresholdSettingsDto? thresholds,
  }) async {
    final criticals = alerts.where((a) => a.level == 'CRITICAL').toList();
    if (criticals.isEmpty) return;

    // Reduce to the newest row per factor first. Because alerts are a log, the
    // same factor can have several rows at once (different values, or different
    // thresholds captured before and after a settings change). Filtering here
    // guarantees at most one popup per factor per check, regardless of how the
    // acknowledgement checks below turn out — previously this relied entirely on
    // the acknowledgement state, which broke the moment anything bypassed it,
    // such as the "always show critical popup" developer flag.
    final latestPerFactor = <String, AlertDto>{};
    for (final a in criticals) {
      final key = a.factor.toUpperCase();
      final existing = latestPerFactor[key];
      if (existing == null) {
        latestPerFactor[key] = a;
        continue;
      }
      final existingTime = existing.timestamp;
      final currentTime = a.timestamp;
      if (existingTime == null ||
          (currentTime != null && currentTime.isAfter(existingTime))) {
        latestPerFactor[key] = a;
      }
    }
    final dedupedCriticals = latestPerFactor.values.toList();

    final toShow = <AlertDto>[];
    for (final a in dedupedCriticals) {
      // With a reading for this round, re-check against the current thresholds.
      // If it is no longer critical — the user widened the range — skip it. With
      // no reading (that endpoint failed), trust the backend as before.
      if (sensor != null &&
          !DashboardMapper.isFactorCritical(a.factor, sensor,
              thresholds: thresholds)) {
        continue;
      }

      final factorKey = 'CRITICAL_${a.factor.toUpperCase()}';
      // The developer flag always re-shows; otherwise check the persisted
      // acknowledgement.
      final forceDebug = DebugFlags.alwaysShowCriticalOnLoad;
      final alreadyAcked = !forceDebug &&
          await SuggestionAckStore.instance.isAcknowledged(factorKey);
      final alreadyShownThisSession =
          !forceDebug && _shownThisSessionFactors.contains(factorKey);
      if (!alreadyAcked && !alreadyShownThisSession) {
        toShow.add(a);
        _shownThisSessionFactors.add(factorKey);
      }
    }

    if (toShow.isNotEmpty && mounted) {
      _showCriticalAlertQueue(toShow);
    }
  }

  /// Show critical popups one at a time when several are queued. The user has to
  /// press a button to dismiss each one — nothing closes on its own, so an alert
  /// cannot be missed by looking away.
  Future<void> _showCriticalAlertQueue(List<AlertDto> alerts) async {
    for (final alert in alerts) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await CriticalAlertDialog.show(
        context,
        alert,
        onViewRoomStatus: () {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AlertsScreen()),
          );
        },
      );
    }
  }

  Widget _alertsSection() {
    final criticalCount = _alerts.where((a) => a.level == 'CRITICAL').length;
    final hasAlerts = _alerts.isNotEmpty;
    const criticalColor = Color(0xFFE85D5D);
    final accentColor = criticalCount > 0 ? criticalColor : AppColors.accent;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AlertsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          // With a critical alert present, tint the whole card rather than only
          // the border, so it reads as urgent at a glance.
          color: criticalCount > 0
              ? criticalColor.withOpacity(0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAlerts ? accentColor : AppColors.cardBorder,
            width: criticalCount > 0 ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasAlerts
                    ? accentColor.withOpacity(0.15)
                    : AppColors.iconBox,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasAlerts
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
                color: hasAlerts ? accentColor : AppColors.neutral,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Alerts',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (criticalCount > 0) ...[
                        const SizedBox(width: 8),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final opacity =
                                0.4 + (_pulseController.value * 0.6);
                            return Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: criticalColor.withOpacity(opacity),
                                boxShadow: [
                                  BoxShadow(
                                    color: criticalColor
                                        .withOpacity(opacity * 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAlerts
                        ? '${_alerts.length} alert'
                            '${_alerts.length == 1 ? '' : 's'}'
                            '${criticalCount > 0 ? ' ($criticalCount critical)' : ''}'
                        : 'No alerts',
                    style: TextStyle(
                      color: criticalCount > 0
                          ? criticalColor
                          : AppColors.neutral,
                      fontSize: 13,
                      fontWeight: criticalCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      ),
    );
  }

  /// STC-01 TC-03: the device is not sending data.
  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: const Row(
        children: [
          Icon(Icons.sensors_off, color: AppColors.accent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Device is not connected. Please check the IoT device.\n'
              'No new data for over 2 minutes — the values below may be stale.',
              style: TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: AppColors.accent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not connected to the backend — showing sample data\n'
              '(pull to retry)',
              style: TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// The result of one isolated endpoint call, keeping the error apart from the
/// value so a single failure cannot take a successful sibling down with it.
class _Result<T> {
  final T? value;
  final String? error;

  _Result({this.value, this.error});
}
