/// Keeps alert / report / suggestion text in English.
///
/// The backend now writes English, but rows saved while it still wrote Thai
/// (old alerts, old Morning Reports) keep coming back from the API unchanged.
/// The helpers below leave English text alone and only rewrite a string when it
/// contains Thai characters, so they are safe to call on everything.
///
/// The replacement is built from what we can reliably read out of the Thai
/// sentence — which factor it is about (CO₂, temperature, ...), whether it was
/// "high" or "low", and the number with its unit. Alerts are better still:
/// they carry structured level / factor / value / threshold fields, so their
/// message is rebuilt from those rather than guessed from the Thai wording.
library;

final RegExp _thai = RegExp(r'[\u0E00-\u0E7F]');

/// True when [text] contains any Thai character.
bool containsThai(String text) => _thai.hasMatch(text);

enum _Factor { co2, temperature, humidity, pm25, noise, light, motion }

_Factor? _factorOf(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('co₂') || lower.contains('co2')) return _Factor.co2;
  if (lower.contains('pm2.5') || lower.contains('pm25') || text.contains('ฝุ่น')) {
    return _Factor.pm25;
  }
  if (text.contains('อุณหภูมิ')) return _Factor.temperature;
  if (text.contains('ความชื้น')) return _Factor.humidity;
  if (text.contains('เสียง')) return _Factor.noise;
  if (text.contains('แสง')) return _Factor.light;
  if (text.contains('เคลื่อนไหว')) return _Factor.motion;
  return null;
}

/// "ต่ำ" means low; anything else in these messages is about a high reading.
bool _isLow(String text) => text.contains('ต่ำ');

final RegExp _numberWithUnit = RegExp(
  r'(-?\d+(?:\.\d+)?)\s*(ppm|°C|%|µg/m³|μg/m³|dB|lux)?',
);

/// The first number in [text] with its unit, rounded to one decimal
/// ("2541 ppm", "33.2°C"), or null when the sentence has none.
String? _firstReading(String text) {
  final m = _numberWithUnit.firstMatch(text);
  if (m == null) return null;
  final unit = m.group(2) ?? '';
  final spaced = (unit.isEmpty || unit == '°C' || unit == '%') ? '' : ' ';
  return '${_num(double.parse(m.group(1)!))}$spaced$unit';
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

// ─────────────────────────── Alerts ───────────────────────────

/// English text for an alert.
///
/// English messages pass through untouched. A Thai one is rebuilt from the
/// alert's own [level], [factor], [value] and [threshold], e.g.
/// "Critical CO2 level: 3004 ppm — open a window now".
String englishAlertMessage({
  required String message,
  required String level,
  required String factor,
  required double value,
  required double threshold,
}) {
  if (!containsThai(message)) return message;

  final critical = level.toUpperCase() == 'CRITICAL';
  final prefix = critical ? 'Critical' : 'Warning';
  final key = factor.toUpperCase();
  final isLow = threshold > 0 && value < threshold;
  final reading = _num(value);

  switch (key) {
    case 'CO2':
      return '$prefix CO2 level: $reading ppm — '
          '${critical ? 'open a window now' : 'consider airing the room'}';
    case 'TEMPERATURE':
      return isLow
          ? '$prefix low temperature: $reading°C — '
              '${critical ? 'too cold for healthy sleep' : 'warm the room up a little'}'
          : '$prefix high temperature: $reading°C — '
              '${critical ? 'health risk while sleeping' : 'cool the room down'}';
    case 'HUMIDITY':
      return isLow
          ? '$prefix low humidity: $reading% — '
              '${critical ? 'risk of dry throat and skin' : 'consider a humidifier'}'
          : '$prefix high humidity: $reading% — '
              '${critical ? 'risk of mold and dust mites' : 'consider a dehumidifier'}';
    case 'PM25':
      return '$prefix PM2.5 level: $reading µg/m³ — '
          '${critical ? 'turn on an air purifier now' : 'consider an air purifier'}';
    case 'NOISE':
      return '$prefix noise level: $reading dB — '
          '${critical ? 'reduce the noise now' : 'try to reduce the noise'}';
    case 'LIGHT':
      return '$prefix light level: $reading lux — '
          '${critical ? 'turn off or dim the lights' : 'consider dimming the lights'}';
    default:
      return '$prefix $factor reading: $reading';
  }
}

// ───────────────────── Morning Report text ─────────────────────

/// English text for one "Notable events" line on a Morning Report.
String englishNotableEvent(String text) {
  if (!containsThai(text)) return text;

  final reading = _firstReading(text);
  final tail = reading == null ? '' : ' ($reading)';
  final low = _isLow(text);

  switch (_factorOf(text)) {
    case _Factor.co2:
      return 'Peak CO₂ exceeded the safe limit$tail';
    case _Factor.temperature:
      return low
          ? 'Temperature dropped too low during the night$tail'
          : 'Temperature stayed high during the night$tail';
    case _Factor.humidity:
      return low
          ? 'Humidity was too low during the night$tail'
          : 'Humidity was too high during the night$tail';
    case _Factor.pm25:
      return 'PM2.5 exceeded the safe limit$tail';
    case _Factor.noise:
      return 'Noise exceeded the recommended level$tail';
    case _Factor.light:
      return 'Light exceeded the recommended level$tail';
    case _Factor.motion:
      return 'Frequent movement detected during the night$tail';
    case null:
      return 'Unusual reading detected during the night$tail';
  }
}

/// English text for one "Suggestions" line, or a pre-sleep suggestion.
///
/// The wording of the temperature / humidity / light lines deliberately keeps
/// the phrases DashboardMapper matches on ("temperature is too high",
/// "humidity is high", ...), so the Home card still picks the right icon and
/// action button for a translated suggestion.
String englishSuggestion(String text) {
  if (!containsThai(text)) return text;

  final low = _isLow(text);

  switch (_factorOf(text)) {
    case _Factor.co2:
      return 'Open a window or adjust the ventilation before bed to reduce CO₂';
    case _Factor.temperature:
      return low
          ? 'Temperature is too low — warm the room up a little before bed'
          : 'Temperature is too high — cool the room down with a fan or AC '
              'before bed';
    case _Factor.humidity:
      return low
          ? 'Humidity is low — use a humidifier before bed'
          : 'Humidity is high — use a dehumidifier or improve ventilation '
              'before bed';
    case _Factor.pm25:
      return 'PM2.5 is high — turn on an air purifier and keep the windows '
          'closed';
    case _Factor.noise:
      return 'Noise is high — reduce noise sources or consider earplugs '
          'before sleeping';
    case _Factor.light:
      return 'The room is too bright — dim or turn off the lights before '
          'sleeping';
    case _Factor.motion:
      return 'Check your room comfort before bed — restless movement was '
          'recorded during the night';
    case null:
      return 'Check your bedroom environment before sleeping';
  }
}
