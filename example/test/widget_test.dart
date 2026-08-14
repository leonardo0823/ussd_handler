// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ussd_handler_example/main.dart';

void main() {
  testWidgets('Verify USSD Handler Example App loads', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is displayed.
    expect(find.text('USSD Handler - Essential Functions'), findsOneWidget);

    // Verify that system info section is present.
    expect(find.text('System Information'), findsOneWidget);

    // Verify that basic USSD section is present.
    expect(find.text('Basic USSD'), findsOneWidget);

    // Verify that multi-session section is present.
    expect(find.text('Multi-USSD Sessions'), findsOneWidget);

    // Verify that direct USSD section is present.
    expect(find.text('Direct USSD (No Dialog)'), findsOneWidget);
  });
}
