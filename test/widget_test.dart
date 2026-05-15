import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'package:wsddigiclock/main.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  testWidgets('WSD clock app renders header quote', (WidgetTester tester) async {
    await tester.pumpWidget(const WSDClockApp());
    await tester.pump();

    // Quote is a RichText — search by widget predicate
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('Innovate')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('Excellence')),
      findsOneWidget,
    );
  });

  testWidgets('All 6 city cards are present', (WidgetTester tester) async {
    // Tall surface so all 3 grid rows are rendered without scrolling
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WSDClockApp());
    await tester.pump();

    for (final city in kCities) {
      expect(find.text(city.name), findsWidgets,
          reason: '${city.name} card not found');
    }
  });
}
