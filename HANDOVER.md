# SleepSense — Handover Notes

Covers three pieces of work: the Test Plan v1.3 functions and their tests, the
full conversion of the codebase to English, and splitting Morning Reports away
from the Stats tab so that tab can do real multi-night pattern analysis.

---

## 1. Read this first: the Test Plan's TD data contradicts the shipped thresholds

UTC-02's test data does not classify the way the Test Plan says it does under the
thresholds SleepSense actually ships.

TD-01 is described as "all within normal range", but under the defaults in
`application.properties`:

| Factor | TD-01 value | Shipped default | Classifies as |
|--------|-------------|-----------------|---------------|
| Light | 320 lux | warning at 50, critical at 200 | **critical** |
| Noise | 45.2 dB | warning at 40 | **warning** |
| Temperature | 27.5 °C | comfort band 18-26 | **warning** |
| Humidity | 65 % | comfort band 30-60 | **warning** |

TD-03 has the same problem — it is meant to be "CO2 warning, everything else
normal", but four other factors are out of range too.

For TD-01 to be "all normal" the thresholds would have to allow 320 lux and
45.2 dB in a bedroom, which is not a defensible sleep environment (the WHO puts
a bedroom under 30-40 dB, and above 50 lux melatonin is measurably suppressed).

**What was done about it.** The production thresholds were left untouched.
`checkThreshold` takes its configuration as a parameter, and each UTC-02 case
runs twice:

- against a `testPlanConfig` reconstructed from the TD values and declared in
  the test file with a comment explaining where it came from — this verifies the
  behaviour the Test Plan specifies;
- against the shipped defaults, verifying the behaviour the app really has.

**What is recommended.** Revise TD-01 and TD-03 in Test Plan v1.4 to
bedroom-realistic values, e.g. temperature 22.0, humidity 50.0, light 12,
noise 32.0, keeping CO2 at 850 (TD-01) and 1600 (TD-03). TD-02 needs no change —
it is critical on all six factors under both configurations. Once the document is
updated the duplicated test config can be deleted.

---

## 2. Test Plan functions

The Test Plan names its components as `services/sensorService.js`,
`utils/thresholdChecker.js` and `utils/reportHelper.js`, but the project has no
JavaScript. The equivalent modules were built on both sides.

| Test case | Dart (Flutter) | Java (Spring Boot) |
|-----------|----------------|--------------------|
| UTC-01 `getSensorData` | `lib/core/services/sensor_service.dart` | `SensorService#getSensorData` |
| UTC-02 `checkThreshold` | `lib/core/utils/threshold_checker.dart` | `analysis/ThresholdChecker` |
| UTC-03 `calculateDailyAverage` | `lib/core/utils/report_helper.dart` | `analysis/ReportHelper` |
| `sendAlert` | `lib/core/services/alert_service.dart` | `alert/AlertDispatcher`, `alert/FcmAlertDispatcher` |
| ITC-01 pipeline | `lib/core/pipeline/sensor_pipeline.dart` | `pipeline/SensorPipeline` |

### Tests

Flutter (`flutter test`):
```
test/unit/sensor_service_test.dart        UTC-01.01 / .02 / .03
test/unit/threshold_checker_test.dart     UTC-02.01 / .02 / .03
test/unit/report_helper_test.dart         UTC-03.01 / .02
test/integration/sensor_pipeline_test.dart ITC-01 TC-01 / TC-02, STC-05 TC-03
test/widget/app_navigation_test.dart      navigation and dashboard
```
Mocking uses `MockClient` from `package:http/testing.dart`, which ships with the
`http` package already in `pubspec.yaml` — no new dependency.

Backend (`mvn test`):
```
service/SensorServiceTest        UTC-01
analysis/ThresholdCheckerTest    UTC-02
analysis/ReportHelperTest        UTC-03
pipeline/SensorPipelineTest      ITC-01, STC-05 TC-03
analysis/PatternAnalyzerTest     STC-04
```
JUnit 5, Mockito and AssertJ all come from `spring-boot-starter-test`, which was
already in `pom.xml`.

### One design decision worth flagging

ITC-01 expects the FCM mock "invoked once", while STC-05 TC-03 expects two
separate notifications when CO2 and noise go critical together. These are
reconciled by making `sendAlert` a single call per pipeline run that emits one
notification per critical factor. Both assertions then hold, and
`SensorPipelineTest#oneNotificationPerCriticalFactor` covers exactly that case.

`FcmAlertDispatcher#deliver` is currently a logging stub. Wiring in real Firebase
Messaging means overriding that one method; nothing else changes, and the tests
stay valid.

---

## 3. Stats and Morning Reports were separated

Previously the Stats tab was a list of Morning Reports, which duplicated the path
the dashboard card already implied, and left nothing doing the multi-night
analysis STC-04 describes.

**Morning Reports** now live at
`lib/features/reports/presentation/screens/morning_report_history_screen.dart`,
reached by tapping the Morning Report card at the bottom of the dashboard. The
card grew a "View all morning reports" row so the tap target is visible. The
per-night detail screen moved with it.

**The Stats tab became Patterns**
(`lib/features/patterns/presentation/screens/patterns_screen.dart`), backed by a
new endpoint.

### How the pattern analysis works

`GET /api/suggestions/smart?deviceId=xxx&nights=14` →
`SmartSuggestionService` → `PatternAnalyzer`.

1. Load the recent Morning Reports, dropping nights with no sensor data.
2. Build a feature vector per night — avg CO2, temperature, humidity, PM2.5,
   light, noise, motion count — and min-max normalise each dimension, so CO2 in
   the hundreds does not drown out temperature in the tens.
3. k-means (k=2 once there are four or more nights). Centroids are seeded from
   the two most distant nights rather than at random, so the same input always
   produces the same grouping and the tests cannot be flaky.
4. Focus on the cluster holding the most recent night — the pattern the user is
   living with now.
5. A factor only becomes a pattern if it is out of range on at least 60% of that
   cluster's nights, and at least twice. Anything rarer is left out entirely, so
   the response never claims a trend the data does not support.
6. Each suggestion carries the id of the pattern it came from plus the evidence
   ("On 4 of 5 similar nights, ..."), which the screen displays.

Fewer than three nights returns `sufficientData: false` and the note "More data
is needed for detailed pattern analysis", which the screen shows instead of
inventing a trend.

There is also a `CO2_OVERNIGHT_BUILDUP` pattern, triggered when max CO2 sits
250 ppm or more above the nightly average on most nights. That is as close as the
stored data gets to the Test Plan's example ("CO2 consistently rises after 2
hours of sleep") — `MorningReport` keeps avg and max, not a within-night series.
Detecting the literal "after 2 hours" claim would need per-night time series kept
alongside the report; worth considering if that exact wording matters.

---

## 4. English conversion

Every Thai comment and user-facing string is gone — 802 lines across 50 files,
verified by scanning the whole tree for the Thai Unicode block. This covered the
Flutter app, the Spring Boot backend, `application.properties`, the ESP32 sketch
and the backend README. No Thai identifiers existed; all Thai was in comments and
strings.

One functional consequence worth knowing about: `DashboardMapper`'s pre-sleep
suggestion matching keyed on Thai substrings from the backend. Since the backend
now emits English, that matching was rewritten against the new wording. The two
have to stay in step — if you change the strings in
`ThresholdAnalyzer.generatePreSleepSuggestions`, update
`DashboardMapper._matchSuggestionRule` in the same commit. There is a comment on
the method saying so.

---

## 5. Not done / worth knowing

- **Neither test suite has been run.** The environment this work was done in had
  no network access, so `flutter pub get` and `mvn` could not fetch dependencies.
  The code was written carefully but has not been compiled. Run `flutter test`
  and `mvn test` first and expect to fix small things.
- `test/widget_test.dart` was replaced. The old file asserted on screens that no
  longer exist ("ENVIRONMENT SUMMARY", "CO₂ Trend", a settings screen with "ROOM"
  and "DEVICE" sections) and was already failing before any of this work.
- The widget tests let `ApiService` make real calls, which fail in the test
  environment and fall back to sample data. That is deliberate — it exercises the
  not-connected path in STC-01 Test Script 2 — but it does mean those tests are
  slower than they need to be. Injecting a mock client into the screens would fix
  that and is a reasonable next step.
- The bottom navigation tab is now labelled **Patterns**, not Stats. If the SRS
  or other documents name that tab, they need updating to match.
