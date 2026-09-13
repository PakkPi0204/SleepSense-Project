/// Helper สำหรับปัดตัวเลขทศนิยมที่ฝังอยู่ในข้อความ (string) ให้เหลือไม่เกิน 2 ตำแหน่ง
///
/// ข้อความบางส่วน (เช่น anomalies/suggestions ของ Morning Report) มาจาก
/// backend เป็นประโยคสำเร็จรูปที่ฝังตัวเลขดิบไว้ตรงๆ เช่น
/// "อุณหภูมิเฉลี่ยสูงตลอดคืน (31.633333333333336°C)" — ค่านี้มาจาก double
/// ของ Java ที่ไม่ได้ format มาก่อนส่ง ฝั่ง client จึงไม่มี field ตัวเลขแยก
/// ให้เรียก toStringAsFixed ตรงๆ ได้ ต้องหาตัวเลขทศนิยมในข้อความแล้วปัดเอง
///
/// ใช้ regex หาเลขทศนิยม (จุด + ตัวเลข) ทุกตัวในข้อความ แล้วแทนที่ด้วยค่าที่
/// ปัดเหลือ [decimals] ตำแหน่งแล้ว (ตัวเลขที่เป็นจำนวนเต็มอยู่แล้ว เช่น
/// จำนวนครั้ง จะไม่ถูกแตะต้อง)
final RegExp _decimalNumberPattern = RegExp(r'-?\d+\.\d+');

String roundDecimalsInText(String text, {int decimals = 2}) {
  return text.replaceAllMapped(_decimalNumberPattern, (match) {
    final value = double.tryParse(match.group(0)!);
    if (value == null) return match.group(0)!;
    return value.toStringAsFixed(decimals);
  });
}
