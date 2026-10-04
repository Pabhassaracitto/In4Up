import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/models/read_content_source.dart';
import 'package:in4up/models/shell_content_order.dart';
import 'package:in4up/models/workspace_navigation.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/providers/waveform_provider.dart';
import 'package:in4up/screens/main_shell.dart';
import 'package:in4up/screens/memory_mode/widgets/remember_workspace_header.dart';
import 'package:in4up/screens/settings/shell_ui_settings_screen.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up/screens/understand_mode/widgets/understand_workspace_header.dart';
import 'package:in4up/services/storage_service.dart';
import 'package:in4up/features/shadowing/providers/shadowing_provider.dart';
import 'package:in4up/widgets/workspace_navigation/workspace_mode_bar.dart';
import 'package:provider/provider.dart';

void main() {
  late Directory tempDir;
  final storage = StorageService();

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('workspace_shell_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.box('settings').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('workspace persistence', () {
    test('read/listen/understand keys persist and corrupt values fail safe', () async {
      await storage.saveDefaultReadContentSource(ReadContentSource.tipitaka);
      await storage.saveReadContentSource(ReadContentSource.web);
      expect(storage.getReadContentSource(), ReadContentSource.web);

      await storage.saveSetting('read_content_source_v1', 'bad-value');
      expect(storage.getReadContentSource(), ReadContentSource.tipitaka);

      await storage.saveDefaultListenContentSource(
        ListenContentSource.videoLibrary,
      );
      await storage.saveListenContentSource(ListenContentSource.youtube);
      expect(storage.getListenContentSource(), ListenContentSource.youtube);

      await storage.saveSetting('listen_content_source_v1', 123);
      expect(storage.getListenContentSource(), ListenContentSource.videoLibrary);

      await storage.saveDefaultUnderstandWorkspaceMode(
        UnderstandWorkspaceMode.shadowing,
      );
      await storage.saveUnderstandWorkspaceMode(UnderstandWorkspaceMode.sync);
      expect(storage.getUnderstandWorkspaceMode(), UnderstandWorkspaceMode.sync);

      await storage.saveSetting('understand_workspace_mode_v1', 123);
      expect(
        storage.getUnderstandWorkspaceMode(),
        UnderstandWorkspaceMode.shadowing,
      );
    });

    test('shell_content_order_v1 keeps old drawer/audio/text mapping', () {
      expect(ShellContentOrder.listenRead.listenOnLeft, isTrue);
      expect(ShellContentOrder.listenRead.readOnLeft, isFalse);
      expect(ShellContentOrder.readListen.readOnLeft, isTrue);
      expect(ShellContentOrder.readListen.listenOnLeft, isFalse);
      expect(
        shellContentOrderFromStorage('old-or-corrupt'),
        ShellContentOrder.listenRead,
      );
    });
  });

  group('settings defaults', () {
    testWidgets('writes default sources and understand mode', (tester) async {
      await tester.pumpWidget(_appHost(const ShellUiSettingsScreen()));

      await tester.tap(find.text('Tam tạng'));
      await tester.pump();
      expect(storage.getDefaultReadContentSource(), ReadContentSource.tipitaka);

      await tester.tap(find.text('Video'));
      await tester.pump();
      expect(
        storage.getDefaultListenContentSource(),
        ListenContentSource.videoLibrary,
      );

      await tester.tap(find.text('Shadowing'));
      await tester.pump();
      expect(
        storage.getDefaultUnderstandWorkspaceMode(),
        UnderstandWorkspaceMode.shadowing,
      );
    });
  });

  group('workspace primitive integration', () {
    testWidgets('read source picker is surfaced by the shell header',
        (tester) async {
      await _pumpMainShell(tester);

      await tester.tap(find.text('Đọc'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byKey(const Key('workspace-context-header')), findsOneWidget);
      expect(find.byKey(const Key('read-source-picker')), findsOneWidget);
      expect(find.text('Tài liệu'), findsOneWidget);
      expect(find.text('Web'), findsOneWidget);
      expect(find.text('Tam tạng'), findsOneWidget);
    });

    testWidgets('Listen mode bar keeps Nghe/Nói/Xem isolated from source state',
        (tester) async {
      var mode = 0;
      var source = ListenContentSource.audioLibrary;
      await tester.pumpWidget(
        _appHost(
          StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  WorkspaceModeBar<int>(
                    items: const [
                      WorkspaceNavigationItem(
                        value: 0,
                        label: 'Nghe',
                        icon: Icons.headphones,
                      ),
                      WorkspaceNavigationItem(
                        value: 1,
                        label: 'Nói',
                        icon: Icons.mic,
                      ),
                      WorkspaceNavigationItem(
                        value: 2,
                        label: 'Xem',
                        icon: Icons.videocam,
                      ),
                    ],
                    selectedValue: mode,
                    onChanged: (value) => setState(() => mode = value),
                    presentation: WorkspaceNavigationPresentation.chips,
                  ),
                  WorkspaceModeBar<ListenContentSource>(
                    items: const [
                      WorkspaceNavigationItem(
                        value: ListenContentSource.audioLibrary,
                        label: 'Âm thanh',
                        icon: Icons.library_music,
                      ),
                      WorkspaceNavigationItem(
                        value: ListenContentSource.youtube,
                        label: 'YouTube',
                        icon: Icons.play_circle,
                      ),
                    ],
                    selectedValue: source,
                    onChanged: (value) => setState(() => source = value),
                    presentation: WorkspaceNavigationPresentation.chips,
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Nói'));
      await tester.pump();
      expect(mode, 1);
      expect(source, ListenContentSource.audioLibrary);

      await tester.tap(find.text('YouTube'));
      await tester.pump();
      expect(source, ListenContentSource.youtube);
      expect(mode, 1);
    });

    testWidgets('Understand AI callback stays contextual', (tester) async {
      var aiCoach = 0;
      await tester.pumpWidget(
        _appHost(
          UnderstandWorkspaceHeader(
            onOpenSpeakMode: () {},
            onOpenYouGlish: () {},
            onOpenReview: () {},
            onOpenQuickActions: () {},
            onOpenAiCoach: () => aiCoach++,
          ),
        ),
      );

      await tester.tap(find.text('Hỏi AI'));
      await tester.pump();
      expect(aiCoach, 1);
    });

    testWidgets('Remember primary CTA remains the learning action',
        (tester) async {
      var review = 0;
      var learnByHeart = 0;
      await tester.pumpWidget(
        _appHost(
          RememberWorkspaceHeader(
            dueCount: 3,
            totalWords: 12,
            onOpenReview: () => review++,
            onOpenLearnByHeart: () => learnByHeart++,
            onOpenWordList: () {},
            onOpenTimeline: () {},
            onOpenStats: () {},
            onOpenMap: () {},
            onOpenQuickActions: () {},
          ),
        ),
      );

      await tester.tap(find.byKey(rememberPrimaryCtaKey));
      await tester.pump();
      expect(review, 1);
      expect(learnByHeart, 0);
    });
  });

  group('shell integration', () {
    testWidgets('bottom nav obeys shell_content_order_v1', (tester) async {
      await storage.saveShellContentOrder(ShellContentOrder.readListen);
      await _pumpMainShell(tester);

      final readCenter = tester.getCenter(find.text('Đọc'));
      final listenCenter = tester.getCenter(find.text('Nghe'));
      expect(readCenter.dx, lessThan(listenCenter.dx));
    });

    testWidgets('quick tools put recent context tools first', (tester) async {
      await storage.recordQuickActionUsage('review');
      await _pumpMainShell(tester);

      await tester.tap(find.byIcon(Icons.bolt_rounded));
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('Ôn tập'), findsOneWidget);
      expect(find.text('Nói'), findsOneWidget);
      final reviewTop = tester.getTopLeft(find.text('Ôn tập')).dy;
      final speakTop = tester.getTopLeft(find.text('Nói')).dy;
      expect(reviewTop, lessThanOrEqualTo(speakTop));
    });
  });
}

Widget _appHost(Widget child) {
  return MaterialApp(
    locale: const Locale('vi'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

Future<void> _pumpMainShell(WidgetTester tester) async {
  final understand = UnderstandProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UnderstandProvider>.value(value: understand),
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => PlayerProvider(understandProvider: understand),
        ),
        ChangeNotifierProvider<TextProvider>(create: (_) => TextProvider()),
        ChangeNotifierProvider<WaveformProvider>(create: (_) => WaveformProvider()),
        ChangeNotifierProvider<ShadowingProvider>(create: (_) => ShadowingProvider()),
        ChangeNotifierProvider<VocabularyProvider>(
          create: (_) => VocabularyProvider(),
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
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}
