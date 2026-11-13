import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/web_core/linux_external_browser_screen.dart';
import 'package:in4up/features/youtube/yt_player_screen.dart';
import 'package:in4up/features/youtube/youtube_explorer_screen.dart';

void main() {
  YtExVideo video(String id) => YtExVideo(
    id: id, title: 'Video', channelId: 'channel', channelTitle: 'Channel',
  );

  testWidgets('Linux player avoids WebView and exposes the selected watch URL',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: YtPlayerScreen(video: video('abc123'))));
    expect(tester.takeException(), isNull);
    expect(find.byType(LinuxExternalBrowserScreen), findsOneWidget);
    expect(find.text('https://www.youtube.com/watch?v=abc123'), findsOneWidget);
    expect(find.textContaining('in-app subtitles and learning tools'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.pumpWidget(MaterialApp(home: YtPlayerScreen(video: video('next456'))));
    expect(find.text('https://www.youtube.com/watch?v=next456'), findsOneWidget);
  });
}
