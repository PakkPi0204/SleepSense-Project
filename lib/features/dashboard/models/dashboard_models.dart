import 'package:flutter/material.dart';

class EnvironmentScore {
  final String title;
  final int value;
  final int maxValue;
  final String status;

  const EnvironmentScore({
    required this.title,
    required this.value,
    required this.maxValue,
    required this.status,
  });
}

/// ระดับสถานะของค่า sensor (ใช้เลือกสีตอนแสดงผล)
enum SensorLevel { normal, warning, critical }

class SensorReading {
  final IconData icon;
  final String title;
  final String value;
  final String status;
  final SensorLevel level;

  const SensorReading({
    required this.icon,
    required this.title,
    required this.value,
    required this.status,
    this.level = SensorLevel.normal,
  });
}

class PreSleepSuggestion {
  final IconData icon;
  final String title;
  final String message;

  /// key คงที่ของ "ปัญหา" นี้ (เช่น TEMP_HIGH, HUMIDITY_LOW, OK) ใช้อ้างอิงตอน
  /// บันทึก/อ่านสถานะ "จัดการแล้ว" ใน local storage — ไม่ผูกกับตัวเลขที่เปลี่ยน
  /// ทุกรอบ sensor อัปเดต เพื่อให้สถานะปุ่มคงอยู่ตราบใดที่ยังเป็นปัญหาเดิม
  final String factorKey;

  /// ข้อความปุ่ม action ที่แนะนำให้ทำ (เช่น "เปิดพัดลม/แอร์") — null เมื่อไม่มี
  /// อะไรต้องทำ (สภาพแวดล้อมโอเคอยู่แล้ว)
  final String? actionLabel;

  /// true = suggestion นี้คือปัญหาที่ควรเด่น (สีเตือน) ต่างจากข้อความปกติ/OK
  final bool isWarning;

  const PreSleepSuggestion({
    required this.icon,
    required this.title,
    required this.message,
    this.factorKey = 'OK',
    this.actionLabel,
    this.isWarning = false,
  });
}

class MorningReport {
  final String title;
  final String period;
  final List<ReportMetric> metrics;

  const MorningReport({
    required this.title,
    required this.period,
    required this.metrics,
  });
}

class ReportMetric {
  final String label;
  final String value;

  const ReportMetric({required this.label, required this.value});
}
