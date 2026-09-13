import 'package:flutter/material.dart';

import 'app/sleepsense_app.dart';
import 'core/debug/debug_flags.dart';

void main() async {
  // ต้องเรียกก่อนใช้ shared_preferences (หรือ plugin ใดๆ) ตอนที่ยังไม่มี
  // Widget ถูก build เลย
  WidgetsFlutterBinding.ensureInitialized();
  // กู้ค่า Developer toggle ("บังคับเด้ง Critical Popup") ที่เคยตั้งไว้กลับมา
  // ก่อน — ไม่งั้นจะรีเซ็ตเป็น false ทุกครั้งที่เปิดแอปใหม่
  await DebugFlags.load();
  runApp(const SleepSenseApp());
}
