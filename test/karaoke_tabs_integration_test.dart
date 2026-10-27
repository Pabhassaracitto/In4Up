import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/shadowing/providers/shadowing_provider.dart';
import 'package:in4up/models/audio_queue_item.dart';
import 'package:in4up/models/text_item.dart';
import 'package:in4up/providers/karaoke_settings_provider.dart';
import 'package:in4up/providers/locale_provider.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/providers/soundlist_provider.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/providers/waveform_provider.dart';
import 'package:in4up/screens/listen_mode/listen_mode_screen.dart';
import 'package:in4up/screens/understand_mode/understand_mode_screen.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_queue_player.dart';

class _PlayerWithSimulatedStt extends PlayerProvider {
  _PlayerWithSimulatedStt({required FakeQueueAudio audio, required UnderstandProvider understand})
      : super(
          audioService: audio,
          storage: FakeQueueStorage(),
          understandProvider: understand,
          recordRecentAudio: (_) async {},
          initializeSttService: false,
          loadCachedLrc: false,
        );

  bool _newLrc = false;
  void signalLrcResult() {
    _newLrc = true;
    notifyListeners();
  }

  @override
  bool get lrcJustGenerated => _newLrc;
  @override
  void consumeLrcJustGenerated() => _newLrc = false;
}

class _NoReadDocument extends ChangeNotifier implements TextProvider {
  @override
  bool get hasLyrics => false;
  @override
  List<TextItem> get lines => const [];
  @override
  int get currentLineIndex => -1;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WaveformStub extends ChangeNotifier implements WaveformProvider {
  @override
  List<double> get waveformData => const [0.2, 0.4, 0.3];
  @override
  List<double> get displayWaveform => waveformData;
  @override
  String? get currentFilePath => 'https://example.test/audio.mp3';
  @override
  Duration get audioDuration => const Duration(minutes: 2);
  // Avoid filesystem/plugin work while exercising the real screens.
  @override
  bool get isLoading => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SoundlistStub extends ChangeNotifier implements SoundlistProvider {
  @override
  bool get autoTocRunning => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ShadowingStub extends ChangeNotifier implements ShadowingProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeQueueAudio audio;
  late _PlayerWithSimulatedStt player;
  late UnderstandProvider understand;
  late KaraokeSettingsProvider karaoke;
  late _NoReadDocument text;
  late _WaveformStub waveform;
  late _SoundlistStub soundlist;
  late _ShadowingStub shadowing;
  late LocaleProvider locale;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    audio = FakeQueueAudio();
    understand = UnderstandProvider();
    karaoke = KaraokeSettingsProvider();
    text = _NoReadDocument();
    waveform = _WaveformStub();
    soundlist = _SoundlistStub();
    shadowing = _ShadowingStub();
    locale = LocaleProvider(await SharedPreferences.getInstance());
    player = _PlayerWithSimulatedStt(audio: audio, understand: understand);
    await player.startQueue([
      const AudioQueueItem(source: 'https://example.test/audio.mp3', title: 'Audio'),
    ], autoPlay: false);
    await Future<void>.delayed(Duration.zero);
    audio.position(const Duration(seconds: 17));
    await Future<void>.delayed(Duration.zero);
    // Simulates the in-memory result of AI while paused: no Read document and
    // no persisted LRC file path is required to display it.
    understand.loadLrcLines(List.generate(30, (index) => LrcLine(
      timestamp: Duration(seconds: index),
      text: 'AI line $index',
    )));
  });

  tearDown(() async {
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    understand.dispose();
    karaoke.dispose();
    text.dispose();
    waveform.dispose();
    soundlist.dispose();
    shadowing.dispose();
    locale.dispose();
  });

  Widget app(Widget screen) => MultiProvider(
    providers: [
      ChangeNotifierProvider<PlayerProvider>.value(value: player),
      ChangeNotifierProvider<UnderstandProvider>.value(value: understand),
      ChangeNotifierProvider<KaraokeSettingsProvider>.value(value: karaoke),
      ChangeNotifierProvider<TextProvider>.value(value: text),
      ChangeNotifierProvider<WaveformProvider>.value(value: waveform),
      ChangeNotifierProvider<SoundlistProvider>.value(value: soundlist),
      ChangeNotifierProvider<ShadowingProvider>.value(value: shadowing),
      ChangeNotifierProvider<LocaleProvider>.value(value: locale),
    ],
    child: MaterialApp(home: Scaffold(body: screen)),
  );

  testWidgets('Understand displays AI lyrics without a Read document', (tester) async {
    await tester.pumpWidget(app(const UnderstandModeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('understand-karaoke-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('karaoke-line-17')).hitTestable(), findsOneWidget);
    await tester.runAsync(() => karaoke.update(karaoke.style.copyWith(
      displayMode: KaraokeDisplayMode.currentLineOnly,
    )));
    await tester.pump();
    expect(find.byKey(const ValueKey('karaoke-line-17')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('karaoke-line-16')), findsNothing);
    expect(find.byKey(const ValueKey('karaoke-line-18')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Listen shows paused AI lyrics and respects an explicit hide', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const ListenModeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('listen-karaoke-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('karaoke-line-17')).hitTestable(), findsOneWidget);
    player.signalLrcResult();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // A completed generation must not reopen an overlay over the current line.
    expect(find.byKey(const ValueKey('karaoke-line-17')).hitTestable(), findsOneWidget);
    await tester.runAsync(() => karaoke.update(karaoke.style.copyWith(
      displayMode: KaraokeDisplayMode.currentLineOnly,
    )));
    await tester.pump();
    expect(find.byKey(const ValueKey('karaoke-line-17')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('karaoke-line-16')), findsNothing);
    expect(find.byKey(const ValueKey('karaoke-line-18')), findsNothing);
    await tester.runAsync(() => karaoke.update(karaoke.style.copyWith(
      displayMode: KaraokeDisplayMode.context,
    )));
    await tester.pump();
    await tester.tap(find.byTooltip('Hide'));
    await tester.pump();
    expect(find.byKey(const ValueKey('listen-karaoke-view')), findsNothing);
    await tester.runAsync(() async {
      audio.position(const Duration(seconds: 18));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('listen-karaoke-view')), findsNothing);

    // The reopen pill and the compact curtain must fit a short, narrow screen.
    await tester.binding.setSurfaceSize(const Size(320, 500));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('karaoke-line-18')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
