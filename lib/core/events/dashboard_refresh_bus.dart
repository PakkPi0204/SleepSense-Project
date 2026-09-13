import 'package:flutter/foundation.dart';

/// สัญญาณกลางง่ายๆ (ไม่ใช้ state management library เพิ่ม) สำหรับบอกหน้า Home
/// ว่า "มีข้อมูลใหม่ที่ควรโหลดใหม่ทันที"
///
/// แอปนี้ใช้ IndexedStack เก็บทุกแท็บไว้พร้อมกัน (ดู SleepSenseShell) —
/// HomeDashboardScreen จึงไม่ถูก dispose/initState ใหม่ตอนสลับแท็บ และจะรอ
/// แค่ auto-refresh timer (ทุก 30 วิ) เท่านั้นถึงจะเห็นข้อมูลใหม่ ปัญหาที่เจอ
/// คือ: ตอนกด "Stop Monitoring" ที่หน้า Sleep แล้ว backend สร้าง morning
/// report ใหม่เสร็จ ถ้าสลับกลับมาหน้า Home ทันที การ์ด Morning Report จะยัง
/// โชว์ของเก่าอยู่จนกว่าจะครบรอบ 30 วิถัดไป — ใช้ signal ตัวนี้แจ้ง Home ให้
/// โหลดใหม่ทันทีแทนที่จะรอรอบถัดไป
class DashboardRefreshBus {
  DashboardRefreshBus._();
  static final DashboardRefreshBus instance = DashboardRefreshBus._();

  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  ValueListenable<int> get listenable => _tick;

  /// เรียกทุกครั้งที่มีข้อมูลใหม่ที่หน้า Home ควรรู้ทันที (เช่น สร้าง morning
  /// report ใหม่สำเร็จ) — เพิ่มค่าใน notifier เพื่อ trigger listener ทุกตัว
  void notifyDataChanged() {
    _tick.value++;
  }
}
