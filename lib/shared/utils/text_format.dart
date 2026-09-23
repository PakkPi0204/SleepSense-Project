/// Rounds decimal numbers embedded in a sentence to at most two places.
///
/// Some text — the anomalies and suggestions on a Morning Report, for instance —
/// arrives from the backend as a finished sentence with a raw double spliced in,
/// e.g. "Average temperature stayed high all night (31.633333333333336°C)".
/// The client has no separate numeric field to call toStringAsFixed on, so the
/// numbers have to be found in the string and rounded there. Whole numbers (a
/// count of events, say) have no decimal point and are left alone.
final RegExp _decimalNumberPattern = RegExp(r'-?\d+\.\d+');

String roundDecimalsInText(String text, {int decimals = 2}) {
  return text.replaceAllMapped(_decimalNumberPattern, (match) {
    final value = double.tryParse(match.group(0)!);
    if (value == null) return match.group(0)!;
    return value.toStringAsFixed(decimals);
  });
}
