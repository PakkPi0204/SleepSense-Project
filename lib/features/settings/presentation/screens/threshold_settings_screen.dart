import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_models.dart';
import '../../../../core/network/api_service.dart';

/// หน้าปรับ threshold การแจ้งเตือนด้วยตัวเอง — เผื่อบางคนต้องนอนห้องเย็นกว่าปกติ,
/// ไวต่อฝุ่น/เสียงมากกว่าค่าเฉลี่ยทั่วไป ฯลฯ ค่าที่ปรับจะถูกบันทึกไว้ที่ backend
/// (ผูกกับ deviceId) แล้วมีผลกับทั้ง alert badge สีต่างๆ และ critical popup
class ThresholdSettingsScreen extends StatefulWidget {
  const ThresholdSettingsScreen({super.key});

  @override
  State<ThresholdSettingsScreen> createState() =>
      _ThresholdSettingsScreenState();
}

class _ThresholdSettingsScreenState extends State<ThresholdSettingsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  ThresholdSettingsDto? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _api.fetchThresholds(deviceId: ApiConfig.deviceId);
      setState(() {
        _settings = s;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'โหลดค่า threshold ไม่ได้: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_settings == null) return;
    setState(() => _saving = true);
    try {
      final saved = await _api.updateThresholds(_settings!);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _saving = false;
      });
      _showSnack('บันทึกค่า threshold แล้ว ✓', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('บันทึกไม่สำเร็จ: $e', isError: true);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('รีเซ็ตค่า threshold?',
            style: TextStyle(color: AppColors.white)),
        content: const Text(
          'จะกลับไปใช้ค่าเริ่มต้นของระบบทั้งหมด การปรับแต่งที่ทำไว้จะหายไป',
          style: TextStyle(color: AppColors.neutral),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก',
                style: TextStyle(color: AppColors.neutral)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('รีเซ็ต',
                style: TextStyle(color: Color(0xFFE85D5D))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final reset = await _api.resetThresholds(deviceId: ApiConfig.deviceId);
      if (!mounted) return;
      setState(() {
        _settings = reset;
        _saving = false;
      });
      _showSnack('รีเซ็ตกลับเป็นค่าเริ่มต้นแล้ว', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('รีเซ็ตไม่สำเร็จ: $e', isError: true);
    }
  }

  void _showSnack(String text, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFFE85D5D) : AppColors.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('ปรับค่าการแจ้งเตือน'),
      ),
      // Center + ConstrainedBox(430) คือ layout wrapper ที่ทุกหน้าในแอปใช้
      // เหมือนกันหมด (Dashboard, Stats, Sleep, Settings, Alerts) — เดิมหน้านี้
      // ไม่มี เลยยืดเต็มจอบนจอกว้าง (tablet/web) ไม่เหมือนหน้าอื่น
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(bottom: false, child: _buildBody()),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.secondary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: AppColors.neutral, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.neutral)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('ลองใหม่')),
            ],
          ),
        ),
      );
    }

    final s = _settings!;
    // RefreshIndicator + subtitle บนสุด + bottom padding 150 คือ pattern
    // เดียวกับหน้า Alerts/Dashboard — ให้ pull-to-refresh ใช้ได้เหมือนกันทั้งแอป
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.secondary,
      backgroundColor: AppColors.card,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
        children: [
          const Text(
            'ปรับความไวของการแจ้งเตือนให้เข้ากับตัวเอง',
            style: TextStyle(color: AppColors.neutral, fontSize: 14),
          ),
          const SizedBox(height: 20),
          _headerBanner(s.customized),
        const SizedBox(height: 20),
        _factorCard(
          title: 'อุณหภูมิ (Temperature)',
          icon: Icons.thermostat_outlined,
          child: Column(
            children: [
              _rangeRow(
                label: 'ช่วงสบาย (Warning นอกช่วงนี้)',
                unit: '°C',
                lowValue: s.temperatureMin ?? 18,
                highValue: s.temperatureMax ?? 26,
                min: 10,
                max: 34,
                divisions: 48,
                color: AppColors.accent,
                onChanged: (lo, hi) => setState(() {
                  _settings = s.copyWith(temperatureMin: lo, temperatureMax: hi);
                }),
              ),
              const SizedBox(height: 18),
              _rangeRow(
                label: 'ขีดวิกฤต (Critical นอกช่วงนี้)',
                unit: '°C',
                lowValue: s.temperatureCriticalMin ?? 15,
                highValue: s.temperatureCriticalMax ?? 32,
                min: 5,
                max: 40,
                divisions: 70,
                color: const Color(0xFFE85D5D),
                onChanged: (lo, hi) => setState(() {
                  _settings = _settings!.copyWith(
                      temperatureCriticalMin: lo, temperatureCriticalMax: hi);
                }),
              ),
            ],
          ),
        ),
        _factorCard(
          title: 'ความชื้น (Humidity)',
          icon: Icons.water_drop_outlined,
          child: Column(
            children: [
              _rangeRow(
                label: 'ช่วงสบาย (Warning นอกช่วงนี้)',
                unit: '%',
                lowValue: s.humidityMin ?? 30,
                highValue: s.humidityMax ?? 60,
                min: 10,
                max: 80,
                divisions: 70,
                color: AppColors.accent,
                onChanged: (lo, hi) => setState(() {
                  _settings = s.copyWith(humidityMin: lo, humidityMax: hi);
                }),
              ),
              const SizedBox(height: 18),
              _rangeRow(
                label: 'ขีดวิกฤต (Critical นอกช่วงนี้)',
                unit: '%',
                lowValue: s.humidityCriticalMin ?? 20,
                highValue: s.humidityCriticalMax ?? 70,
                min: 5,
                max: 90,
                divisions: 85,
                color: const Color(0xFFE85D5D),
                onChanged: (lo, hi) => setState(() {
                  _settings = _settings!.copyWith(
                      humidityCriticalMin: lo, humidityCriticalMax: hi);
                }),
              ),
            ],
          ),
        ),
        _factorCard(
          title: 'CO₂',
          icon: Icons.air,
          child: _twoSliders(
            unit: 'ppm',
            warningValue: s.co2Warning ?? 1000,
            criticalValue: s.co2Critical ?? 2000,
            min: 400,
            max: 3000,
            divisions: 52,
            onWarningChanged: (v) =>
                setState(() => _settings = s.copyWith(co2Warning: v)),
            onCriticalChanged: (v) =>
                setState(() => _settings = _settings!.copyWith(co2Critical: v)),
          ),
        ),
        _factorCard(
          title: 'ฝุ่น PM2.5',
          icon: Icons.speed_outlined,
          child: _twoSliders(
            unit: 'µg/m³',
            warningValue: s.pm25Warning ?? 35,
            criticalValue: s.pm25Critical ?? 75,
            min: 5,
            max: 150,
            divisions: 145,
            onWarningChanged: (v) =>
                setState(() => _settings = s.copyWith(pm25Warning: v)),
            onCriticalChanged: (v) =>
                setState(() => _settings = _settings!.copyWith(pm25Critical: v)),
          ),
        ),
        _factorCard(
          title: 'เสียงรบกวน (Noise)',
          icon: Icons.volume_up_outlined,
          child: _twoSliders(
            unit: 'dB',
            warningValue: s.noiseWarning ?? 40,
            criticalValue: s.noiseCritical ?? 60,
            min: 20,
            max: 90,
            divisions: 70,
            onWarningChanged: (v) =>
                setState(() => _settings = s.copyWith(noiseWarning: v)),
            onCriticalChanged: (v) =>
                setState(() => _settings = _settings!.copyWith(noiseCritical: v)),
          ),
        ),
        _factorCard(
          title: 'ความสว่าง (Light)',
          icon: Icons.wb_sunny_outlined,
          child: _twoSliders(
            unit: 'lux',
            warningValue: s.lightMax ?? 50,
            criticalValue: s.lightCritical ?? 200,
            min: 0,
            max: 400,
            divisions: 80,
            warningLabel: 'Warning (สว่างเกิน)',
            criticalLabel: 'Critical (สว่างมาก)',
            onWarningChanged: (v) =>
                setState(() => _settings = s.copyWith(lightMax: v)),
            onCriticalChanged: (v) =>
                setState(() => _settings = _settings!.copyWith(lightCritical: v)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.primary),
                  )
                : const Text('บันทึกค่า',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _saving ? null : _reset,
            child: const Text('รีเซ็ตเป็นค่าเริ่มต้นของระบบ',
                style: TextStyle(color: AppColors.neutral, fontSize: 13)),
          ),
        ),
        ],
      ),
    );
  }

  Widget _headerBanner(bool customized) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (customized ? AppColors.secondary : AppColors.neutral)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (customized ? AppColors.secondary : AppColors.neutral)
              .withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            customized ? Icons.tune : Icons.info_outline,
            color: customized ? AppColors.secondary : AppColors.neutral,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customized
                  ? 'กำลังใช้ค่าที่คุณปรับเอง'
                  : 'กำลังใช้ค่าเริ่มต้นของระบบ — ลากแถบด้านล่างเพื่อปรับตามที่เหมาะกับคุณ',
              style: const TextStyle(color: AppColors.white, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _factorCard(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.iconBox,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.secondary, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// ใช้กับ CO2 / PM2.5 / Noise / Light — ยิ่งค่าสูงยิ่งแย่ (single-direction)
  Widget _twoSliders({
    required String unit,
    required double warningValue,
    required double criticalValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onWarningChanged,
    required ValueChanged<double> onCriticalChanged,
    String warningLabel = 'Warning',
    String criticalLabel = 'Critical',
  }) {
    return Column(
      children: [
        _labeledSlider(
          label: warningLabel,
          value: warningValue,
          unit: unit,
          min: min,
          max: max,
          divisions: divisions,
          color: AppColors.accent,
          onChanged: onWarningChanged,
        ),
        const SizedBox(height: 14),
        _labeledSlider(
          label: criticalLabel,
          value: criticalValue,
          unit: unit,
          min: min,
          max: max,
          divisions: divisions,
          color: const Color(0xFFE85D5D),
          onChanged: onCriticalChanged,
        ),
      ],
    );
  }

  Widget _labeledSlider({
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    final clamped = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.neutral, fontSize: 13)),
            Text('${_fmt(clamped)} $unit',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: AppColors.cardBorder,
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 3,
          ),
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// ช่วงต่ำ-สูง แสดงเป็น RangeSlider เดียว (ใช้กับอุณหภูมิ/ความชื้น ที่มีทั้งขอบบนขอบล่าง)
  Widget _rangeRow({
    required String label,
    required String unit,
    required double lowValue,
    required double highValue,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required void Function(double lo, double hi) onChanged,
  }) {
    final lo = lowValue.clamp(min, max);
    final hi = highValue.clamp(min, max);
    final values = lo <= hi
        ? RangeValues(lo, hi)
        : RangeValues(hi, lo); // กันพัง ถ้า lo>hi จากการลากสวนกัน

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.neutral, fontSize: 13)),
            Text('${_fmt(values.start)}–${_fmt(values.end)} $unit',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: AppColors.cardBorder,
            overlayColor: color.withValues(alpha: 0.15),
            rangeThumbShape:
                const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            trackHeight: 3,
          ),
          child: RangeSlider(
            values: values,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => onChanged(v.start, v.end),
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}