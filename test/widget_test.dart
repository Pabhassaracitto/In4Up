import 'package:flutter_test/flutter_test.dart';

import 'package:ultra_music_player/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const UltraMusicApp());

    // Wait for permissions check
    await tester.pumpAndSettle();

    // Check if app title is displayed
    expect(find.text('Ultra Music Player'), findsOneWidget);
  });
}