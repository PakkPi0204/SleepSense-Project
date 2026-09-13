import 'package:shared_preferences/shared_preferences.dart';

/// Flag สำหรับโหมดทดสอบระหว่างพัฒนา
///
/// เดิม [alwaysShowCriticalOnLoad] เป็น static bool เก็บใน memory ล้วนๆ —
/// toggle ในหน้า Settings > Developer จะรีเซ็ตกลับเป็น false ทุกครั้งที่ปิดแอป
/// (force-kill) แล้วเปิดใหม่ ทั้งที่ผู้ใช้เพิ่งเปิดสวิตช์ไว้ ตอนนี้ persist ค่า
/// ผ่าน SharedPreferences แทน — ต้องเรียก [load] ครั้งเดียวตอนแอปเริ่มทำงาน
/// (ใน main() ก่อน runApp) เพื่อกู้ค่าที่เคยตั้งไว้กลับมาก่อน widget แรกจะ build
abstract final class DebugFlags {
  static bool alwaysShowCriticalOnLoad = false;

  static const _kAlwaysShowCriticalKey = 'debug_always_show_critical';

  /// โหลดค่าที่เคยบันทึกไว้จาก storage — เรียกครั้งเดียวตอนแอปเริ่มทำงาน
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    alwaysShowCriticalOnLoad = prefs.getBool(_kAlwaysShowCriticalKey) ?? false;
  }

  /// ปกติ (false): critical alert popup จะเด้งให้ก็ต่อเมื่อยังไม่เคยถูก
  /// "รับทราบว่าจัดการแล้ว" (เช็คจาก SuggestionAckStore ซึ่ง persist ข้าม
  /// การปิด-เปิดแอป) — ถ้าเคยกดปุ่ม action ใน dialog ไปแล้ว จะไม่เด้งซ้ำอีก
  /// จนกว่าปัญหานั้นจะหายไปแล้วเกิดขึ้นใหม่
  ///
  /// โหมดทดสอบ (true): เด้ง popup ให้ critical alert ทุกตัวที่เจอเสมอ ไม่สนใจ
  /// สถานะ acknowledge ที่เคยบันทึกไว้ — มีประโยชน์ตอนทดสอบว่า popup แสดงผล
  /// ถูกต้องหรือไม่ โดยไม่ต้องไปเคลียร์ local storage เอง
  ///
  /// ใช้ตัวนี้แทนการเซ็ต [alwaysShowCriticalOnLoad] ตรงๆ จากหน้า UI เพื่อให้
  /// ค่าที่ผู้ใช้ตั้งถูกบันทึกลง storage ด้วย ไม่ใช่แค่เปลี่ยนใน memory
  static Future<void> setAlwaysShowCriticalOnLoad(bool value) async {
    alwaysShowCriticalOnLoad = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlwaysShowCriticalKey, value);
  }
}
