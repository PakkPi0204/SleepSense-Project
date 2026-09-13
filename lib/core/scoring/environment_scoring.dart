import '../network/api_models.dart';

/// สูตรคิดคะแนน "สภาพแวดล้อมการนอน" แบบเดียว ใช้ร่วมกันทั้งหน้า Home
/// (Sleep Environment Score) และหน้า Sleep (Sleep Readiness) เพื่อไม่ให้
/// สองหน้าคิดคะแนนคนละสูตรแล้วโชว์ตัวเลขไม่ตรงกันสำหรับ sensor ชุดเดียวกัน
///
/// เดิม DashboardMapper ใช้สูตร "หัก" (เริ่ม 100 แล้วลบทีละก้อนตาม
/// warning/critical ที่โดน) ส่วน SleepMapper ใช้สูตร "ไล่เชิงเส้น" (100 เมื่อ
/// optimal ไล่ลงเป็นเส้นตรงจนถึง 0 ที่ critical) — สองสูตรนี้ให้ผลไม่ตรงกัน
/// แม้จะใช้ threshold ชุดเดียวกัน จึงรวมเป็นสูตรเดียวที่นี่ (แบบไล่เชิงเส้น)
/// แล้วให้ทั้งสอง mapper เรียกใช้ฟังก์ชันนี้แทนการคำนวณเอง
class EnvironmentScoring {
  EnvironmentScoring._();

  /// คะแนนของค่าที่ "ยิ่งสูงยิ่งแย่ทางเดียว" (CO2 / PM2.5 / Light / Noise)
  /// อยู่ในช่วง optimal (<= warning) = 100 เต็ม ไล่ลงเป็นเส้นตรงจนถึง 0 ที่
  /// ค่า critical แล้วค้างที่ 0 ต่อจากนั้น
  static double upperScore(double v, double warning, double critical) {
    if (v <= warning) return 100;
    if (critical <= warning) return 0; // กัน config ผิดพลาดหารด้วย 0
    if (v >= critical) return 0;
    final ratio = (v - warning) / (critical - warning);
    return (100 * (1 - ratio)).clamp(0, 100);
  }

  /// คะแนนของค่าที่มีทั้งขอบล่าง-บน (Temperature / Humidity) — อยู่ในช่วง
  /// [min, max] = 100 เต็ม ไล่ลงเป็นเส้นตรงจนถึง 0 ที่ขอบ critical ฝั่งนั้นๆ
  static double rangeScore(
      double v, double min, double max, double criticalMin, double criticalMax) {
    if (v >= min && v <= max) return 100;
    if (v < min) {
      if (criticalMin >= min) return 0;
      if (v <= criticalMin) return 0;
      final ratio = (min - v) / (min - criticalMin);
      return (100 * (1 - ratio)).clamp(0, 100);
    }
    if (criticalMax <= max) return 0;
    if (v >= criticalMax) return 0;
    final ratio = (v - max) / (criticalMax - max);
    return (100 * (1 - ratio)).clamp(0, 100);
  }

  /// คำนวณคะแนนย่อยทั้ง 4 หมวด (Room / Air / Light / Sound) + คะแนนรวม จาก
  /// ค่า sensor เดียว โดยอิงตาม threshold ของผู้ใช้ (หรือ default ถ้าไม่ส่งมา)
  /// — เรียกจากทั้ง DashboardMapper และ SleepMapper เพื่อให้ผลตรงกันเป๊ะเสมอ
  static EnvironmentFactorScores factorScores(
    SensorDataDto d, {
    ThresholdSettingsDto? thresholds,
  }) {
    final tempMin = thresholds?.temperatureMin ?? 18;
    final tempMax = thresholds?.temperatureMax ?? 26;
    final tempCriticalMin = thresholds?.temperatureCriticalMin ?? 15;
    final tempCriticalMax = thresholds?.temperatureCriticalMax ?? 32;

    final humidityMin = thresholds?.humidityMin ?? 30;
    final humidityMax = thresholds?.humidityMax ?? 60;
    final humidityCriticalMin = thresholds?.humidityCriticalMin ?? 20;
    final humidityCriticalMax = thresholds?.humidityCriticalMax ?? 70;

    final co2Warning = thresholds?.co2Warning ?? 1000;
    final co2Critical = thresholds?.co2Critical ?? 2000;
    final pm25Warning = thresholds?.pm25Warning ?? 35;
    final pm25Critical = thresholds?.pm25Critical ?? 75;

    final lightWarning = thresholds?.lightMax ?? 50;
    final lightCritical = thresholds?.lightCritical ?? 200;
    final noiseWarning = thresholds?.noiseWarning ?? 40;
    final noiseCritical = thresholds?.noiseCritical ?? 60;

    // ค่าที่ไม่มี sensor ต่ออยู่ (ติดลบ/0 ตาม convention ของ backend) ไม่ควร
    // ลากคะแนนรวมตก จึงถือว่า sensor นั้น "เต็ม 100" แทนการเอาไปคิดรวม
    final room = ((_scoreOrFull(d.temperature,
                () => rangeScore(d.temperature, tempMin, tempMax,
                    tempCriticalMin, tempCriticalMax),
                isMissing: d.temperature < 0) +
            _scoreOrFull(d.humidity,
                () => rangeScore(d.humidity, humidityMin, humidityMax,
                    humidityCriticalMin, humidityCriticalMax),
                isMissing: d.humidity < 0)) /
        2);
    final air = ((_scoreOrFull(d.co2,
                () => upperScore(d.co2, co2Warning, co2Critical),
                isMissing: d.co2 <= 0) +
            upperScore(d.pm25, pm25Warning, pm25Critical)) /
        2);
    final light = upperScore(d.lightIntensity, lightWarning, lightCritical);
    final sound = upperScore(d.noiseLevel, noiseWarning, noiseCritical);

    final overall = ((room + air + light + sound) / 4).round().clamp(0, 100);

    return EnvironmentFactorScores(
      room: room,
      air: air,
      light: light,
      sound: sound,
      overall: overall,
    );
  }

  static double _scoreOrFull(double value, double Function() score,
      {required bool isMissing}) {
    return isMissing ? 100 : score();
  }

  /// ข้อความสถานะจากคะแนนรวม — ใช้ค่าเดียวกันทั้ง Environment Score และ
  /// Sleep Readiness (>=80 Good, >=50 Moderate, ต่ำกว่านั้น Poor)
  static String statusFor(int overall) {
    if (overall >= 80) return 'Good';
    if (overall >= 50) return 'Moderate';
    return 'Poor';
  }
}

/// ผลลัพธ์คะแนนย่อย 4 หมวด + คะแนนรวม จาก [EnvironmentScoring.factorScores]
class EnvironmentFactorScores {
  final double room;
  final double air;
  final double light;
  final double sound;
  final int overall;

  const EnvironmentFactorScores({
    required this.room,
    required this.air,
    required this.light,
    required this.sound,
    required this.overall,
  });
}
