import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'package:wsddigiclock/main.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  testWidgets('WSD clock app renders header', (WidgetTester tester) async {
    await tester.pumpWidget(const WSDClockApp());
    await tester.pump();

    expect(find.text('WSD'), findsOneWidget);
    expect(find.text('GROUP'), findsOneWidget);
  });

  testWidgets('All 6 city cards are present', (WidgetTester tester) async {
    await tester.pumpWidget(const WSDClockApp());
    await tester.pump();

    for (final city in kCities) {
      expect(find.text(city.name), findsOneWidget);
    }
  });
}
