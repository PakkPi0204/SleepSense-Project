import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/api_models.dart';
import '../../../../shared/utils/time_format.dart';

const _criticalColor = Color(0xFFE85D5D);

/// หน้าแสดงประวัติ Alert จาก backend (/api/alerts/recent)
///
/// ปรับปรุงให้ "ดูเตือน" ชัดเจนขึ้นกว่าเดิม:
///  - เรียงลำดับ CRITICAL ขึ้นก่อนเสมอ แล้วค่อยเรียงตามเวลาล่าสุด
///  - การ์ด CRITICAL ใช้พื้นหลังสีแดงเข้ม (ไม่ใช่แค่กรอบสี) ให้เด่นชัด
///  - มีแถบสรุปจำนวน CRITICAL/WARNING ด้านบนสุด พร้อมจุดกระพริบเมื่อมี CRITICAL
///  - แสดงเวลาแบบ relative ("5 นาทีที่แล้ว") ให้รู้ว่าใหม่แค่ไหน
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<AlertDto> _alerts = const [];

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final alerts = await _api.fetchRecentAlerts(limit: 30);
      // CRITICAL ขึ้นก่อนเสมอ, ในระดับเดียวกันเรียงใหม่สุดก่อน
      final sorted = [...alerts]..sort((a, b) {
          if (a.isCritical != b.isCritical) {
            return a.isCritical ? -1 : 1;
          }
          final at = a.timestamp;
          final bt = b.timestamp;
          if (at == null || bt == null) return 0;
          return bt.compareTo(at);
        });
      setState(() {
        _alerts = sorted;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final criticalCount = _alerts.where((a) => a.isCritical).length;
    final warningCount = _alerts.length - criticalCount;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Alerts'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.secondary,
              backgroundColor: AppColors.card,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'การแจ้งเตือนสภาพแวดล้อมล่าสุด',
                      style: TextStyle(color: AppColors.neutral, fontSize: 14),
                    ),
                    if (!_loading && _error == null && _alerts.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _summaryBar(criticalCount, warningCount),
                    ],
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary),
                        ),
                      ),
                    if (_error != null && !_loading) _errorBox(),
                    if (!_loading && _error == null && _alerts.isEmpty)
                      _emptyBox(),
                    if (!_loading && _error == null)
                      ..._alerts.map(_alertCard),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// แถบสรุปด้านบน — เห็นภาพรวมทันทีโดยไม่ต้องไล่อ่านทีละการ์ด
  Widget _summaryBar(int criticalCount, int warningCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: criticalCount > 0
            ? _criticalColor.withOpacity(0.15)
            : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: criticalCount > 0 ? _criticalColor : AppColors.cardBorder,
          width: criticalCount > 0 ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          if (criticalCount > 0) ...[
            _PulsingDot(controller: _pulseController, color: _criticalColor),
            const SizedBox(width: 10),
            Text(
              '$criticalCount วิกฤต',
              style: const TextStyle(
                color: _criticalColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (warningCount > 0) const SizedBox(width: 14),
          ],
          if (warningCount > 0)
            Text(
              '$warningCount คำเตือน',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _alertCard(AlertDto a) {
    final isCritical = a.isCritical;
    final accent = isCritical ? _criticalColor : AppColors.accent;
    final relTime = formatRelativeTime(a.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // CRITICAL: เติมพื้นหลังสีแดงเข้มทั้งการ์ดให้เด่นชัด ไม่ใช่แค่กรอบ
        color: isCritical ? accent.withOpacity(0.14) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical ? accent : accent.withOpacity(0.5),
          width: isCritical ? 1.6 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCritical ? Icons.warning_amber_rounded : Icons.info_outline,
              color: accent,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a.level,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      a.factor,
                      style: const TextStyle(
                        color: AppColors.neutral,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (relTime.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        relTime,
                        style: const TextStyle(
                          color: AppColors.neutral,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  a.message,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight:
                        isCritical ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'โหลด alerts ไม่ได้ — เชื่อมต่อ backend ไม่สำเร็จ\n(ดึงลงเพื่อลองใหม่)',
              style: const TextStyle(color: AppColors.neutral, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.check_circle_outline,
              color: AppColors.secondary, size: 48),
          SizedBox(height: 12),
          Text(
            'ไม่มีการแจ้งเตือน\nสภาพแวดล้อมอยู่ในเกณฑ์ปกติ',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.neutral, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// จุดกลมกระพริบ (pulsing dot) ใช้ดึงความสนใจตอนมี CRITICAL alert
class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _PulsingDot({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final opacity = 0.4 + (controller.value * 0.6);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(opacity),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(opacity * 0.6),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
