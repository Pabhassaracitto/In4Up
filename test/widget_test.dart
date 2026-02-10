import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraMusicApp() as Widget);

    // Wait for permissions check
    await tester.pumpAndSettle();

    // Check if app title is displayed
    expect(find.text('Ultra Music Player'), findsOneWidget);
  });
}

class UltraMusicApp {
  const UltraMusicApp();
}