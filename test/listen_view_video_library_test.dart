// test/listen_view_video_library_test.dart
//
// LISTEN-VIEW-001 regression: VideoLibraryScreen is embedded in the shell
// IndexedStack as the "Xem" sub-tab. Its AppBar back button used to call
// Navigator.pop unconditionally — with no pushed route that pops the ROOT
// route (black screen, no exit). Embedded mode must render no back button;
// standalone (pushed) mode keeps it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/video/widgets/video_library_screen.dart';

void main() {
  group('VideoLibraryScreen back navigation (LISTEN-VIEW-001)', () {
    testWidgets('embedded mode renders no back button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoLibraryScreen(showBackButton: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
      // Library still resolves to a real state (empty library, not blank).
      // Default locale is 'en' — Vietnamese label goes through uiText().
      expect(find.text('No videos yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('standalone mode keeps the back button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoLibraryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
