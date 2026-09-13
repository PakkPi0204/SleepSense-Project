import 'package:shared_preferences/shared_preferences.dart';

/// เก็บสถานะ "จัดการแล้ว/เปิดแล้ว" ของคำแนะนำและ critical alert แต่ละปัจจัย
/// (factor) ลง local storage ของเครื่อง (SharedPreferences) แทนการเก็บไว้แค่ใน
/// memory ของ widget — ทำให้ปุ่ม "เปิดแล้ว ✓" คงสถานะเดิมอยู่ แม้ผู้ใช้จะปิดแอป
/// ไปแล้วเปิดใหม่ (force-kill + reopen) ก็ตาม
///
/// key ที่ใช้เป็น "factor" ของปัญหา (เช่น TEMP_HIGH, CRITICAL_CO2) ไม่ใช่ id ของ
/// แต่ละแถว sensor/alert ที่เปลี่ยนทุกรอบ 30 วิ — เพราะเราต้องการจำ "ปัญหานี้
/// ถูกจัดการแล้ว" ไม่ใช่จำแค่ "เคยเห็น record นี้แล้ว"
class SuggestionAckStore {
  SuggestionAckStore._();
  static final SuggestionAckStore instance = SuggestionAckStore._();

  static const _prefix = 'sleepsense_ack_';

  Future<bool> isAcknowledged(String factorKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$factorKey') ?? false;
  }

  Future<void> acknowledge(String factorKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$factorKey', true);
  }

  Future<void> clear(String factorKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$factorKey');
  }

  /// ล้างสถานะ "จัดการแล้ว" ทั้งหมดที่เคยบันทึกไว้ — เรียกตอนสภาพแวดล้อมกลับมา
  /// ปกติ/ดีแล้ว (ไม่มีปัญหาเหลือ) เพื่อให้รอบหน้าที่ปัญหาเดิมเกิดซ้ำ ระบบจะเตือน
  /// ใหม่ตามปกติ แทนที่จะค้างสถานะ "เปิดแล้ว" ไปตลอดกาลจากครั้งก่อนหน้า
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
