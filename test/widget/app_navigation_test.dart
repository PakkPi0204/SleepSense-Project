import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sleepsense_app/app/sleepsense_app.dart';
import 'package:sleepsense_app/features/splash/presentation/screens/splash_screen.dart';

/// Widget-level coverage of the shell: splash, setup, the dashboard and the tab
/// bar. These run without a backend, so every screen falls back to its sample
/// data — which is exactly the "not connected" path the Test Plan exercises in
/// STC-01 Test Script 2.

Future<void> pumpPastSplash(WidgetTester tester) async {
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
}

Future<void> pumpPastSetup(WidgetTester tester) async {
  await tester.tap(find.text('Skip for now'));
  await tester.pumpAndSettle();
}

Future<void> openApp(WidgetTester tester) async {
  await tester.pumpWidget(const SleepSenseApp());
  await pumpPastSplash(tester);
  await pumpPastSetup(tester);
}

void main() {
  testWidgets('shows the SleepSense splash screen first', (tester) async {
    await tester.pumpWidget(const SleepSenseApp());

    expect(find.text('SleepSense'), findsOneWidget);
    expect(find.text('Smarter room. Better sleep.'), findsOneWidget);
  });

  testWidgets('shows the setup start screen after the splash', (tester) async {
    await tester.pumpWidget(const SleepSenseApp());
    await pumpPastSplash(tester);

    expect(find.text('Start Setup'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('dashboard shows the environment score and sensor cards',
      (tester) async {
    await openApp(tester);

    expect(find.text('Sleep Environment Score'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Humidity'), findsOneWidget);
    expect(find.text('CO₂'), findsOneWidget);
  });

  testWidgets('the morning report card offers a way into the full history',
      (tester) async {
    await openApp(tester);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
    await tester.pumpAndSettle();

    expect(find.text('View all morning reports'), findsOneWidget);
  });

  testWidgets('opening the morning report history from the dashboard card',
      (tester) async {
    await openApp(tester);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View all morning reports'));
    await tester.pumpAndSettle();

    expect(find.text('Morning Reports'), findsOneWidget);
  });

  testWidgets('the bottom navigation offers the four tabs', (tester) async {
    await openApp(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the Stats tab shows the sleep pattern analysis, not reports',
      (tester) async {
    await openApp(tester);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Sleep Patterns'), findsOneWidget);
    // Without a backend there is no history, so it must say so rather than
    // claiming a pattern (Test Plan STC-04 TC-05).
    expect(find.text('Not enough history yet'), findsOneWidget);
  });

  testWidgets('opens the sleep screen from the bottom navigation',
      (tester) async {
    await openApp(tester);

    await tester.tap(find.text('Sleep'));
    await tester.pumpAndSettle();

    expect(find.text('Environment Checklist'), findsOneWidget);
  });

  testWidgets('opens the settings screen from the bottom navigation',
      (tester) async {
    await openApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Device and connection information'), findsOneWidget);
    expect(find.text('Alert thresholds'), findsOneWidget);
  });
}
