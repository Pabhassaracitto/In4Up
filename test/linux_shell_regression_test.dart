import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in4up/features/shadowing/providers/shadowing_provider.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/providers/focus_provider.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/providers/soundlist_provider.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/providers/waveform_provider.dart';
import 'package:in4up/screens/home/home_screen.dart';
import 'package:in4up/screens/listen_mode/listen_mode_screen.dart';
import 'package:in4up/screens/main_shell.dart';
import 'package:in4up/screens/memory_mode/controllers/memory_controller.dart';
import 'package:in4up/screens/read_mode/read_mode_screen.dart';
import 'package:in4up/screens/read_mode/services/playback_controller.dart';
import 'package:in4up/screens/read_mode/services/playback_engine.dart';
import 'package:in4up/screens/read_mode/services/tts_notification_service.dart';
import 'package:in4up/screens/read_mode/services/tts_service.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up/screens/understand_mode/understand_workspace_screen.dart';
import 'package:in4up/services/auth_service.dart';
import 'package:in4up/services/learning_activity_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_queue_player.dart';

class _NoopTtsService implements TtsService {
  @override
  Future<void> dispose() async {}
  @override
  set onComplete(VoidCallback? callback) {}
  @override
  set onError(void Function(String error)? callback) {}
  @override
  set onStart(VoidCallback? callback) {}
  @override
  Future<void> setLanguage(String locale) async {}
  @override
  Future<void> setSpeechRate(double rate) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  void stop() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('linux_ui_repro_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>('settings');
  });

  tearDownAll(() {
    // Hive.close() can wait forever for a pending box future in this
    // fake-async widget suite. The process exits after the suite; remove the
    // temporary directory synchronously instead of hanging the whole CI job.
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('authStateChanges allows simultaneous and sequential subscribers',
      () async {
    final auth = AuthService();
    final first = auth.authStateChanges.listen((_) {});
    final second = auth.authStateChanges.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    await first.cancel();
    final afterRemount = auth.authStateChanges.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    await second.cancel();
    await afterRemount.cancel();
  });

  testWidgets('Home builds without a release gray ErrorWidget on Linux',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.reset);

    final activity = LearningActivityService(
      storage: InMemoryLearningActivityStorage(),
    );
    addTearDown(activity.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UnderstandProvider()),
          ChangeNotifierProvider<PlayerProvider>(
            create: (context) => PlayerProvider(
              understandProvider: context.read<UnderstandProvider>(),
              audioService: FakeQueueAudio(),
              storage: FakeQueueStorage(),
              initializeSttService: false,
              loadCachedLrc: false,
            ),
          ),
          ChangeNotifierProvider(create: (_) => TextProvider()),
          ChangeNotifierProvider(create: (_) => VocabularyProvider()),
          ChangeNotifierProvider(
            create: (_) => FocusProvider(service: activity),
          ),
          ChangeNotifierProvider(create: (_) => MemoryController()),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: HomeScreen(
              onNavigateToListen: () {},
              onNavigateToSpeak: () {},
              onNavigateToWatch: () {},
              onNavigateToRead: () {},
              onNavigateToWrite: () {},
              onNavigateToUnderstand: () {},
              onNavigateToMemory: () {},
              onOpenAiChat: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('I4U AI Chat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Linux primary tabs switch content and selected state',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.reset);

    final activity = LearningActivityService(
      storage: InMemoryLearningActivityStorage(),
    );
    addTearDown(activity.dispose);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_shellApp(activity, prefs));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);

    await _tapPrimaryTab(tester, 'ĐỌC');
    expect(find.byType(ReadModeScreen), findsOneWidget);

    await _tapPrimaryTab(tester, 'NGHE');
    expect(find.byType(ListenModeScreen), findsOneWidget);

    await _tapPrimaryTab(tester, 'HIỂU');
    expect(find.byType(UnderstandWorkspaceScreen), findsOneWidget);

    await _tapPrimaryTab(tester, 'Home');
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}

Finder _primaryTab(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        widget.properties.button == true &&
        widget.properties.label == label,
  );
}

Future<void> _tapPrimaryTab(WidgetTester tester, String label) async {
  final tab = _primaryTab(label);
  expect(tab, findsOneWidget);
  await tester.tap(tab);
  await tester.pump(const Duration(milliseconds: 300));
  expect(tester.takeException(), isNull);
  expect(find.byType(ErrorWidget), findsNothing);
  expect(tester.widget<Semantics>(tab).properties.selected, isTrue);
}

Widget _shellApp(
  LearningActivityService activity,
  SharedPreferences prefs,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => UnderstandProvider()),
      ChangeNotifierProvider<PlayerProvider>(
        create: (context) => PlayerProvider(
          understandProvider: context.read<UnderstandProvider>(),
          audioService: FakeQueueAudio(),
          storage: FakeQueueStorage(),
          initializeSttService: false,
          loadCachedLrc: false,
        ),
      ),
      ChangeNotifierProvider(create: (_) => SoundlistProvider()),
      ChangeNotifierProvider(create: (_) => TextProvider()),
      ChangeNotifierProvider(create: (_) => WaveformProvider()),
      ChangeNotifierProvider(create: (_) => ShadowingProvider()),
      ChangeNotifierProvider(create: (_) => VocabularyProvider()),
      ChangeNotifierProvider(create: (_) => FocusProvider(service: activity)),
      ChangeNotifierProvider(create: (_) => MemoryController()),
      Provider<SharedPreferences>.value(value: prefs),
      Provider<TtsService>(create: (_) => _NoopTtsService()),
      Provider<TtsNotificationService>(create: (_) => TtsNotificationService()),
      Provider<PlaybackEngine>(
        create: (context) => PlaybackEngine(context.read<TtsService>()),
      ),
      ChangeNotifierProvider<PlaybackController>(
        create: (context) => PlaybackController(
          context.read<PlaybackEngine>(),
          context.read<SharedPreferences>(),
          context.read<TtsNotificationService>(),
          () => 'vi',
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainShell(),
    ),
  );
}
