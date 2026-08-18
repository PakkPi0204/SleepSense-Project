import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_service.dart';

/// หน้า Settings — แสดงข้อมูล device + สถานะการเชื่อมต่อ + ข้อมูลระบบ
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();

  bool _checking = true;
  bool _connected = false;
  String? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _checking = true);
    try {
      final sensor = await _api.fetchLatestSensor();
      setState(() {
        _connected = sensor != null;
        _lastUpdate = sensor?.timestamp;
        _checking = false;
      });
    } catch (_) {
      setState(() {
        _connected = false;
        _checking = false;
      });
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ข้อมูลอุปกรณ์และการเชื่อมต่อ',
                    style: TextStyle(color: AppColors.neutral, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // ── สถานะการเชื่อมต่อ ──
                  _sectionTitle('Connection'),
                  const SizedBox(height: 12),
                  _connectionCard(),
                  const SizedBox(height: 28),

                  // ── ข้อมูลอุปกรณ์ ──
                  _sectionTitle('Device'),
                  const SizedBox(height: 12),
                  _infoTile(Icons.memory, 'Device ID', ApiConfig.deviceId),
                  _infoTile(Icons.dns_outlined, 'Backend URL', ApiConfig.baseUrl),
                  _infoTile(Icons.sensors, 'Sensors', '6 environmental sensors'),
                  const SizedBox(height: 28),

                  // ── เกี่ยวกับ ──
                  _sectionTitle('About'),
                  const SizedBox(height: 12),
                  _infoTile(Icons.info_outline, 'App', 'SleepSense'),
                  _infoTile(Icons.tag, 'Version', '1.0.0'),
                  _infoTile(Icons.bedtime_outlined, 'Purpose',
                      'Sleep environment monitoring'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.neutral,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _connectionCard() {
    final statusColor = _checking
        ? AppColors.neutral
        : (_connected ? AppColors.secondary : const Color(0xFFE85D5D));
    final statusText = _checking
        ? 'กำลังตรวจสอบ...'
        : (_connected ? 'เชื่อมต่อแล้ว' : 'ไม่ได้เชื่อมต่อ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.neutral),
                onPressed: _checking ? null : _checkConnection,
              ),
            ],
          ),
          if (_connected && _lastUpdate != null) ...[
            const Divider(color: AppColors.cardBorder, height: 24),
            Row(
              children: [
                const Icon(Icons.access_time,
                    color: AppColors.neutral, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'อัปเดตล่าสุด: ${_formatTime(_lastUpdate!)}',
                    style: const TextStyle(
                        color: AppColors.neutral, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.iconBox,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(color: AppColors.neutral, fontSize: 14),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'เมื่อสักครู่';
      if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
      if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'ไม่ทราบ';
    }
  }
}
