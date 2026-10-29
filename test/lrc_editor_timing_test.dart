import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up/widgets/lrc_editor_panel.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';
import 'package:provider/provider.dart';

class _EditorPlayer extends ChangeNotifier implements PlayerProvider {
  _EditorPlayer(this.path);
  final String path;
  @override
  String? get lastGeneratedLrcPath => path;
  @override
  String? get currentSongPath => 'audio-source';
  @override
  String? get lastSttError => null;
  @override
  bool get isGeneratingLrc => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editing timed words asks before changing the original file', (tester) async {
    late Directory dir;
    late File file;
    const original = '[ti:My recording]\r\n# Keep this note\r\n[00:00.000]one <00:01.007>two\r\n';
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('in4up-lrc-test-');
      file = File('${dir.path}/test.lrc');
      await file.writeAsString(original);
    });
    addTearDown(() async => dir.delete(recursive: true));
    final player = _EditorPlayer(file.path);
    final understand = UnderstandProvider();
    addTearDown(() {
      player.dispose();
      understand.dispose();
    });
    // Start widget callbacks in the real-async zone: they use actual file IO.
    await tester.runAsync(() async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PlayerProvider>.value(value: player),
          ChangeNotifierProvider<UnderstandProvider>.value(value: understand),
        ],
        child: const MaterialApp(home: Scaffold(body: LrcEditorPanel())),
      ));
      // Let the editor's real async file read complete before interacting.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'changed two');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Word timings no longer match'), findsOneWidget);
      expect(file.readAsStringSync(), original);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(file.readAsStringSync(), original);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'changed two');

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final savedContent = file.readAsStringSync();
      expect(savedContent, startsWith('[ti:My recording]\r\n# Keep this note\r\n'));
      expect(savedContent, endsWith('\r\n'));
      final saved = SttLrcConverter().parseLrcContent(savedContent).single;
      expect(saved.text, 'changed two');
      expect(saved.words, isEmpty); // explicit confirmation; line timing remains
      expect(saved.timestamp, Duration.zero);
      expect(understand.lrcLines.single.text, 'changed two');
      ScaffoldMessenger.of(tester.element(find.byType(LrcEditorPanel)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();

      // Another writer must never be silently overwritten by this editor.
      await tester.enterText(find.byType(TextField), 'second draft');
      const external = '[00:00.00]external change\n';
      file.writeAsStringSync(external);
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(file.readAsStringSync(), external);
      expect(find.textContaining('LRC changed elsewhere'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'second draft');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    expect(tester.takeException(), isNull);
  });
}
