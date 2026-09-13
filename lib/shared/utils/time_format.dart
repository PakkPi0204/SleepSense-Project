/// Helper สำหรับแปลงเวลาเป็นข้อความ "ผ่านมาแล้วกี่นาที/ชั่วโมง" (relative time)
/// ใช้ร่วมกันในหน้า Alerts / Stats เพื่อให้ผู้ใช้เห็นว่าเหตุการณ์เพิ่งเกิดหรือไม่
String formatRelativeTime(DateTime? timestamp) {
  if (timestamp == null) return '';

  final now = DateTime.now().toUtc();
  final ts = timestamp.isUtc ? timestamp : timestamp.toUtc();
  final diff = now.difference(ts);

  if (diff.isNegative || diff.inSeconds < 60) {
    return 'เมื่อสักครู่';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes} นาทีที่แล้ว';
  } else if (diff.inHours < 24) {
    return '${diff.inHours} ชั่วโมงที่แล้ว';
  } else {
    return '${diff.inDays} วันที่แล้ว';
  }
}
