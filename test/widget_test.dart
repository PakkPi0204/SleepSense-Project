import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sleepsense_app/app/sleepsense_app.dart';

void main() {
  testWidgets('shows the SleepSense dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const SleepSenseApp());

    expect(find.text('Bedroom'), findsOneWidget);
    expect(find.text('Sleep Environment Score'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Pre-Sleep Suggestion'), findsOneWidget);

    await tester.drag(find.byType(Scrollable), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Morning Report Preview'), findsOneWidget);
  });

  testWidgets('opens the pre-sleep screen from bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SleepSenseApp());

    await tester.tap(find.text('Sleep'));
    await tester.pumpAndSettle();

    expect(find.text('Ready for Sleep?'), findsOneWidget);
    expect(find.text('SLEEP READINESS'), findsOneWidget);
    expect(find.text('Environment Checklist'), findsOneWidget);
    expect(find.text('Start Night Monitoring'), findsOneWidget);
  });

  testWidgets('opens the stats screen from bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SleepSenseApp());

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Stats'), findsWidgets);
    expect(find.text('ENVIRONMENT SUMMARY'), findsOneWidget);
    expect(find.text('CO₂ Trend'), findsOneWidget);
    expect(find.text('Sensor Averages'), findsOneWidget);

    await tester.drag(find.byType(Scrollable), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Insight'), findsOneWidget);
  });
}
