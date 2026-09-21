import 'package:flutter/material.dart';

import '../network/api_models.dart';
import '../../shared/utils/english_text.dart';
import '../scoring/environment_scoring.dart';
import '../../features/dashboard/models/dashboard_models.dart';

/// Maps backend DTOs onto the UI models the screens already use, keeping value
/// formatting and status wording (Optimal / Warning / ...) in one place.
///
/// Note: every function that has to decide Warning vs Critical takes a
/// [ThresholdSettingsDto?]. When it is absent — or a field inside it is null —
/// the system defaults apply, and those defaults must match ThresholdConfig.java
/// on the backend.
class DashboardMapper {
  /// Is this reading too old to trust? The ESP32 posts every 30 seconds, so
  /// nothing for two minutes suggests the device is offline.
  static bool isStale(String timestamp) {
    try {
      final last = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(last);
      return diff.inSeconds > 120;
    } catch (_) {
      return false; // an unparseable timestamp is not evidence of staleness
    }
  }

  DashboardMapper._();

  /// SensorDataDto to the list of sensor cards.
  ///
  /// [thresholds] are the user's own values (or the backend defaults) and decide
  /// whether each reading shows as Optimal, Warning or Critical.
  static List<SensorReading> toSensorReadings(
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final tempMin = thresholds?.temperatureMin ?? 18;
    final tempMax = thresholds?.temperatureMax ?? 26;
    final tempCriticalMin = thresholds?.temperatureCriticalMin ?? 15;
    final tempCriticalMax = thresholds?.temperatureCriticalMax ?? 32;

    final humidityMin = thresholds?.humidityMin ?? 30;
    final humidityMax = thresholds?.humidityMax ?? 60;
    final humidityCriticalMin = thresholds?.humidityCriticalMin ?? 20;
    final humidityCriticalMax = thresholds?.humidityCriticalMax ?? 70;

    final co2Warning = thresholds?.co2Warning ?? 1000;
    final co2Critical = thresholds?.co2Critical ?? 2000;

    final pm25Warning = thresholds?.pm25Warning ?? 35;
    final pm25Critical = thresholds?.pm25Critical ?? 75;

    final lightWarning = thresholds?.lightMax ?? 50;
    final lightCritical = thresholds?.lightCritical ?? 200;

    final noiseWarning = thresholds?.noiseWarning ?? 40;
    final noiseCritical = thresholds?.noiseCritical ?? 60;

    return [
      SensorReading(
        icon: Icons.thermostat_outlined,
        title: 'Temperature',
        value: d.temperature < 0 ? 'N/A' : '${_fmt(d.temperature)}°C',
        status: d.temperature < 0
            ? 'No sensor'
            : _tempStatus(d.temperature, tempMin, tempMax, tempCriticalMin,
                tempCriticalMax),
        level: d.temperature < 0
            ? SensorLevel.normal
            : _rangeLevel(d.temperature, tempMin, tempMax,
                criticalMin: tempCriticalMin, criticalMax: tempCriticalMax),
      ),
      SensorReading(
        icon: Icons.water_drop_outlined,
        title: 'Humidity',
        value: d.humidity < 0 ? 'N/A' : '${_fmt(d.humidity)}%',
        status: d.humidity < 0
            ? 'No sensor'
            : _rangeStatus(d.humidity, humidityMin, humidityMax),
        level: d.humidity < 0
            ? SensorLevel.normal
            : _rangeLevel(d.humidity, humidityMin, humidityMax,
                criticalMin: humidityCriticalMin,
                criticalMax: humidityCriticalMax),
      ),
      SensorReading(
        icon: Icons.air,
        title: 'CO₂',
        value: d.co2 <= 0 ? 'N/A' : '${d.co2.round()} ppm',
        status: d.co2 <= 0
            ? 'No sensor'
            : _thresholdStatus(d.co2, co2Warning, co2Critical),
        level: d.co2 <= 0
            ? SensorLevel.normal
            : _thresholdLevel(d.co2, co2Warning, co2Critical),
      ),
      SensorReading(
        icon: Icons.speed_outlined,
        title: 'PM2.5',
        value: '${_fmt(d.pm25)} μg/m³',
        status: _pm25Status(d.pm25, pm25Warning, pm25Critical),
        level: _thresholdLevel(d.pm25, pm25Warning, pm25Critical),
      ),
      SensorReading(
        icon: Icons.wb_sunny_outlined,
        title: 'Light',
        value: '${d.lightIntensity.round()} lux',
        status: d.lightIntensity > lightCritical
            ? 'Critical'
            : d.lightIntensity > lightWarning
                ? 'Bright'
                : 'Optimal',
        level: _thresholdLevel(d.lightIntensity, lightWarning, lightCritical),
      ),
      SensorReading(
        icon: Icons.volume_up_outlined,
        title: 'Sound',
        value: '${d.noiseLevel.round()} dB',
        status: _noiseStatus(d.noiseLevel, noiseWarning, noiseCritical),
        level: _thresholdLevel(d.noiseLevel, noiseWarning, noiseCritical),
      ),
      SensorReading(
        icon: Icons.directions_walk,
        title: 'Motion',
        value: d.motionDetected ? 'Detected' : 'None',
        status: d.motionDetected ? 'Movement' : 'Still',
        level: SensorLevel.normal,
      ),
    ];
  }

  // ── Severity by threshold, used to choose colours ──
  // The bounds come from ThresholdSettingsDto rather than being hardcoded here.
  static SensorLevel _rangeLevel(double v, double min, double max,
      {double? criticalMin, double? criticalMax}) {
    if (criticalMin != null && v < criticalMin) return SensorLevel.critical;
    if (criticalMax != null && v > criticalMax) return SensorLevel.critical;
    if (v < min || v > max) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  /// For values that only get worse in one direction (CO2 / PM2.5 / Light / Noise).
  static SensorLevel _thresholdLevel(
      double v, double warning, double critical) {
    if (v >= critical) return SensorLevel.critical;
    if (v >= warning) return SensorLevel.warning;
    return SensorLevel.normal;
  }

  /// Environment score (0-100) for a reading, against the user's thresholds.
  ///
  /// Uses exactly the same formula as SleepMapper.toReadiness through the shared
  /// [EnvironmentScoring], so Home and Sleep cannot disagree about the same
  /// sensor data.
  static EnvironmentScore toEnvironmentScore(
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final scores = EnvironmentScoring.factorScores(d, thresholds: thresholds);

    return EnvironmentScore(
      title: 'Sleep Environment Score',
      value: scores.overall,
      maxValue: 100,
      status: EnvironmentScoring.statusFor(scores.overall),
    );
  }

  /// Backend advice strings to a single actionable pre-sleep suggestion.
  ///
  /// Shows the first thing the backend flagged, rewritten as something the user
  /// can act on, with a stable [PreSleepSuggestion.factorKey] tying the button
  /// state to the problem rather than to the numbers.
  static PreSleepSuggestion toPreSleepSuggestion(List<String> suggestions) {
    if (suggestions.isEmpty) {
      return const PreSleepSuggestion(
        icon: Icons.check_circle_outline,
        title: 'Pre-Sleep Check',
        message:
            'Your bedroom is ready for sleep. Nothing needs adjusting right now.',
        factorKey: 'OK',
      );
    }

    final raw = englishSuggestion(suggestions.first);
    final rule = _matchSuggestionRule(raw);
    return PreSleepSuggestion(
      icon: rule.icon,
      title: 'Pre-Sleep Check',
      message: rule.buildMessage(raw),
      factorKey: rule.factorKey,
      actionLabel: rule.actionLabel,
      isWarning: true,
    );
  }

  /// Match keywords in the backend's message to a stable factor plus an action.
  ///
  /// Keyword matching rather than exact comparison, because the numbers embedded
  /// in the sentence (degrees, ppm, %) change on every sensor update. The
  /// keywords track the wording in ThresholdAnalyzer.generatePreSleepSuggestions
  /// on the backend — if that wording changes, these have to change with it.
  static _SuggestionRule _matchSuggestionRule(String msg) {
    final m = msg.toLowerCase();

    if (m.contains('co2') || m.contains('co₂')) {
      return _SuggestionRule(
        factorKey: 'CO2_HIGH',
        icon: Icons.air,
        actionLabel: 'Open a window',
        intro: 'The air in here is getting stale. Airing the room out before '
            'bed will help you sleep more soundly.',
      );
    }
    if (m.contains('temperature is too high')) {
      return _SuggestionRule(
        factorKey: 'TEMP_HIGH',
        icon: Icons.thermostat_outlined,
        actionLabel: 'Turn on the fan or AC',
        intro: 'The room is warmer than is comfortable for sleep. Cool it down '
            'before you turn in.',
      );
    }
    if (m.contains('temperature is too low')) {
      return _SuggestionRule(
        factorKey: 'TEMP_LOW',
        icon: Icons.thermostat_outlined,
        actionLabel: 'Warm the room up',
        intro: 'The room is colder than is comfortable. A little more warmth '
            'will help you sleep through.',
      );
    }
    if (m.contains('humidity is high')) {
      return _SuggestionRule(
        factorKey: 'HUMIDITY_HIGH',
        icon: Icons.water_drop_outlined,
        actionLabel: 'Run a dehumidifier',
        intro: 'Humidity is above the comfortable range — damp air makes for a '
            'clammy night.',
      );
    }
    if (m.contains('humidity is low')) {
      return _SuggestionRule(
        factorKey: 'HUMIDITY_LOW',
        icon: Icons.water_drop_outlined,
        actionLabel: 'Run a humidifier',
        intro: 'The air is dry enough that it may leave your throat irritated '
            'by morning.',
      );
    }
    if (m.contains('pm2.5') || m.contains('dust')) {
      return _SuggestionRule(
        factorKey: 'PM25_HIGH',
        icon: Icons.speed_outlined,
        actionLabel: 'Turn on the air purifier',
        intro: 'PM2.5 is above the safe level. Filter the air before sleeping.',
      );
    }
    if (m.contains('bright') || m.contains('light')) {
      return _SuggestionRule(
        factorKey: 'LIGHT_HIGH',
        icon: Icons.wb_sunny_outlined,
        actionLabel: 'Dim the lights',
        intro: 'The room is still too bright for good quality sleep.',
      );
    }
    if (m.contains('noise')) {
      return _SuggestionRule(
        factorKey: 'NOISE_HIGH',
        icon: Icons.volume_up_outlined,
        actionLabel: 'Reduce the noise',
        intro: 'Background noise is above the level that suits sleep.',
      );
    }

    // Nothing recognised — show the backend's own wording, but still let the
    // user acknowledge it so the card behaves consistently.
    return const _SuggestionRule(
      factorKey: 'OTHER',
      icon: Icons.light_mode_outlined,
      actionLabel: 'Got it',
      intro: null,
    );
  }

  /// MorningReportDto to the Home summary card.
  static MorningReport toMorningReport(MorningReportDto d) {
    return MorningReport(
      title: 'Morning Report',
      period: 'Last night · ${d.environmentCluster}',
      metrics: [
        ReportMetric(label: 'Avg Temp', value: '${_fmt(d.avgTemperature)}°C'),
        ReportMetric(label: 'Avg CO₂', value: '${d.avgCo2.round()} ppm'),
        ReportMetric(label: 'Motion', value: '${d.motionEventCount}x'),
      ],
    );
  }

  // ── Format and status helpers ──
  static String _fmt(double v) => v.toStringAsFixed(1);

  static String _tempStatus(double t, double min, double max,
      double criticalMin, double criticalMax) {
    if (t < criticalMin || t > criticalMax) return 'Critical';
    // "Optimal" is the middle of the comfort range. This tracks whatever range
    // the user configured instead of the old hardcoded 20-24.
    final mid = (min + max) / 2;
    final tightLo = mid - (max - min) / 6;
    final tightHi = mid + (max - min) / 6;
    if (t >= tightLo && t <= tightHi) return 'Optimal';
    if (t >= min && t <= max) return 'Good';
    return 'Warning';
  }

  static String _rangeStatus(double v, double min, double max) {
    if (v >= min && v <= max) return 'Optimal';
    return 'Warning';
  }

  /// Status text for values that only get worse in one direction (CO2).
  static String _thresholdStatus(double v, double warning, double critical) {
    if (v < warning) return 'Optimal';
    if (v < critical) return 'Warning';
    return 'Critical';
  }

  static String _pm25Status(double p, double warning, double critical) {
    if (p < warning) return 'Good';
    if (p < critical) return 'Warning';
    return 'Critical';
  }

  static String _noiseStatus(double n, double warning, double critical) {
    if (n < warning) return 'Quiet';
    if (n < critical) return 'Warning';
    return 'Loud';
  }

  /// Is this factor (from AlertDto.factor, e.g. "TEMPERATURE", "CO2") still
  /// critical against the *current* reading and thresholds — rather than the
  /// value and threshold frozen into the alert row when it was created?
  ///
  /// Needed when falling back to /recent, which is a plain history log. If the
  /// user has since widened a threshold, an old row that was critical under the
  /// previous settings still comes back from that endpoint even though the
  /// current value is fine. This filters those out before forcing a popup.
  static bool isFactorCritical(
    String factor,
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final tempCriticalMin = thresholds?.temperatureCriticalMin ?? 15;
    final tempCriticalMax = thresholds?.temperatureCriticalMax ?? 32;
    final humidityCriticalMin = thresholds?.humidityCriticalMin ?? 20;
    final humidityCriticalMax = thresholds?.humidityCriticalMax ?? 70;
    final co2Critical = thresholds?.co2Critical ?? 2000;
    final pm25Critical = thresholds?.pm25Critical ?? 75;
    final lightCritical = thresholds?.lightCritical ?? 200;
    final noiseCritical = thresholds?.noiseCritical ?? 60;

    switch (factor.toUpperCase()) {
      case 'TEMPERATURE':
        return d.temperature < tempCriticalMin ||
            d.temperature > tempCriticalMax;
      case 'HUMIDITY':
        return d.humidity > 0 &&
            (d.humidity < humidityCriticalMin ||
                d.humidity > humidityCriticalMax);
      case 'CO2':
        return d.co2 >= co2Critical;
      case 'PM25':
        return d.pm25 >= pm25Critical;
      case 'LIGHT':
        return d.lightIntensity >= lightCritical;
      case 'NOISE':
        return d.noiseLevel >= noiseCritical;
      default:
        // Unknown factor — not enough information to re-check, so trust the
        // backend.
        return true;
    }
  }

  /// Like [isFactorCritical] but also handles WARNING. Used only on the fallback
  /// path, where an older backend has no /active endpoint and /recent has to be
  /// filtered client-side. CRITICAL rows check against the critical bounds and
  /// WARNING rows against the warning bounds, matching toSensorReadings.
  static bool isFactorStillFlagged(
    String factor,
    String level,
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    if (level.toUpperCase() == 'CRITICAL') {
      return isFactorCritical(factor, d, thresholds: thresholds);
    }

    final tempMin = thresholds?.temperatureMin ?? 18;
    final tempMax = thresholds?.temperatureMax ?? 26;
    final humidityMin = thresholds?.humidityMin ?? 30;
    final humidityMax = thresholds?.humidityMax ?? 60;
    final co2Warning = thresholds?.co2Warning ?? 1000;
    final pm25Warning = thresholds?.pm25Warning ?? 35;
    final lightWarning = thresholds?.lightMax ?? 50;
    final noiseWarning = thresholds?.noiseWarning ?? 40;

    switch (factor.toUpperCase()) {
      case 'TEMPERATURE':
        return d.temperature < tempMin || d.temperature > tempMax;
      case 'HUMIDITY':
        return d.humidity > 0 &&
            (d.humidity < humidityMin || d.humidity > humidityMax);
      case 'CO2':
        return d.co2 >= co2Warning;
      case 'PM25':
        return d.pm25 >= pm25Warning;
      case 'LIGHT':
        return d.lightIntensity >= lightWarning;
      case 'NOISE':
        return d.noiseLevel >= noiseWarning;
      default:
        return true;
    }
  }
}

/// One rule for turning a raw backend suggestion into a single-factor smart
/// suggestion: icon, stable factor key, action label and a readable lead-in.
class _SuggestionRule {
  final String factorKey;
  final IconData icon;
  final String actionLabel;
  final String? intro;

  const _SuggestionRule({
    required this.factorKey,
    required this.icon,
    required this.actionLabel,
    required this.intro,
  });

  /// Final message: the readable lead-in (when there is one) followed by the
  /// backend's own line, so the user sees both why it matters and the real
  /// number behind it.
  String buildMessage(String raw) {
    if (intro == null) return raw;
    return '$intro\n$raw';
  }
}
