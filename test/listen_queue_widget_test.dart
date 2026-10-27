import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/audio_library_entry.dart';
import 'package:in4up/models/audio_playlist.dart';
import 'package:in4up/models/audio_queue_item.dart';
import 'package:in4up/providers/audio_library_provider.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/screens/listen_mode/widgets/audio_library_drawer.dart';
import 'package:in4up/screens/listen_mode/widgets/audio_library_view.dart';
import 'package:in4up/screens/listen_mode/widgets/audio_playlists_sheet.dart';
import 'package:in4up/screens/listen_mode/widgets/mini_player.dart';
import 'package:in4up/services/audio_library_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_queue_player.dart';

class StubAudioLibrary extends AudioLibraryProvider {
  final List<AudioLibraryEntry> items;
  final List<AudioPlaylist> saved;
  final List<String> marked = [];
  StubAudioLibrary(this.items, [List<AudioPlaylist>? saved])
      : saved = saved ?? <AudioPlaylist>[];

  @override
  List<AudioLibraryEntry> get entries => List.unmodifiable(items);
  @override
  List<AudioPlaylist> get playlists => List.unmodifiable(saved);
  @override
  bool get hasPermission => true;
  @override
  bool get isScanning => false;
  @override
  String? get error => null;
  @override
  Future<void> load() async {}
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> scan() async {}
  @override
  Future<void> markPlayed(AudioLibraryEntry entry) async => marked.add(entry.libraryId);
  @override
  List<AudioLibraryEntry> filtered({
    String query = '',
    SmartPlaylist smart = SmartPlaylist.all,
    String? album,
    String? artist,
    String? folder,
  }) => items.where((e) => e.title.toLowerCase().contains(query.toLowerCase())).toList();
}

AudioLibraryEntry entry(String id, String title) => AudioLibraryEntry(
  libraryId: id,
  uri: 'https://example.test/$id.mp3',
  title: title,
  addedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeQueueAudio audio;
  late FakeQueueStorage storage;
  late StubAudioLibrary library;
  late PlayerProvider player;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    audio = FakeQueueAudio();
    storage = FakeQueueStorage();
    library = StubAudioLibrary([
      entry('a', 'Group A'),
      entry('b', 'Other'),
      entry('c', 'Group C'),
    ]);
    player = PlayerProvider(
      audioService: audio,
      storage: storage,
      audioLibraryProvider: library,
      // History writes have their own integration tests. A no-op seam keeps
      // platform-backed writes out of the widget fakeAsync zone.
      recordRecentAudio: (_) async {},
      initializeSttService: false,
      loadCachedLrc: false,
    );
  });

  tearDown(() {
    player.dispose();
    library.dispose();
  });

  Future<void> pumpQueue(WidgetTester tester) async {
    // Loads and mock platform calls complete through microtasks. Pump the
    // widget clock instead of awaiting a pending provider future in fakeAsync.
    for (var attempt = 0; attempt < 30; attempt++) {
      // The provider is created in setUp outside fakeAsync, so let futures
      // and stream events from that real zone settle between widget frames.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
      if (!player.isQueueLoading) return;
    }
    fail('Queue did not finish loading during widget pumps');
  }

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<PlayerProvider>.value(value: player),
      ChangeNotifierProvider<AudioLibraryProvider>.value(value: library),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('filtered library tap snapshots visible order and selected index', (tester) async {
    await tester.pumpWidget(wrap(const AudioLibraryView()));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Group');
    await tester.pump();
    expect(find.text('Other'), findsNothing);
    await tester.tap(find.text('Group C'));
    await pumpQueue(tester);
    await tester.pump();
    expect(player.queueItems.map((e) => e.libraryId), ['a', 'c']);
    expect(player.queueIndex, 1);
    expect(library.marked, ['c']);
    // Changing the visible filter later must not mutate the session snapshot.
    await tester.enterText(find.byType(TextField).first, 'Other');
    await tester.pump();
    expect(player.queueItems.map((e) => e.libraryId), ['a', 'c']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('saved playlist play-all retains missing slots and skips them', (tester) async {
    final playlist = AudioPlaylist.create('Saved')
      ..trackIds.addAll(['missing', 'c', 'a']);
    library.saved.add(playlist);
    await tester.pumpWidget(wrap(PlaylistDetailScreen(playlistId: playlist.id)));
    await tester.pump();
    expect(find.text('Track is no longer in the library'), findsOneWidget);
    await tester.tap(find.byTooltip('Play all'));
    await pumpQueue(tester);
    await tester.pump();
    expect(player.queueItems.map((e) => e.libraryId), ['missing', 'c', 'a']);
    expect(player.queueFailedIndices, {0});
    expect(player.queueIndex, 1);
    expect(library.marked, ['c']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('compact drawer keeps responsive tabs and the shared queue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final started = player.startQueue([
      const AudioQueueItem(source: 'https://example.test/a', title: 'Bài trước'),
      const AudioQueueItem(source: 'https://example.test/b', title: 'Second'),
    ]);
    await pumpQueue(tester);
    expect(await started, isTrue);
    await tester.pumpWidget(wrap(const Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: 262.4, child: AudioLibraryDrawer()),
    )));
    await tester.pump();

    // The upstream narrow-layout tabs and the feature queue must coexist.
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
    // Do not translate a user's title even when it matches a known UI label.
    expect(find.text('Bài trước'), findsOneWidget);
    // Off-screen ListView children are lazy. Scroll the preview itself until
    // the second item is built and visible, rather than assuming it exists.
    final preview = find.byKey(const ValueKey('drawer-queue-preview'));
    await tester.scrollUntilVisible(
      find.text('Second'),
      100,
      scrollable: find.descendant(of: preview, matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Second').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Second'));
    await pumpQueue(tester);
    await tester.pump();
    expect(player.queueIndex, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('narrow mini player has distinct track/seek controls and queue', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final started = player.startQueue([
      const AudioQueueItem(source: 'https://example.test/a', title: 'Bài trước'),
      const AudioQueueItem(source: 'https://example.test/b', title: 'Second'),
    ]);
    await pumpQueue(tester);
    expect(await started, isTrue);
    await tester.pumpWidget(wrap(const MiniPlayer()));
    await tester.pump();
    // The margin must not consume the fixed-height transport bar.
    expect(tester.getSize(find.byType(MiniPlayer)).height,
        MiniPlayerDimensions.microHeight + 24);
    expect(tester.widget<IconButton>(find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Previous track',
    )).onPressed, isNull);
    expect(find.byTooltip('Back 10 seconds'), findsOneWidget);
    expect(find.byTooltip('Forward 10 seconds'), findsOneWidget);
    await tester.tap(find.byTooltip('Next track'));
    await pumpQueue(tester);
    await tester.pump();
    expect(player.queueIndex, 1);
    expect(tester.widget<IconButton>(find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Next track',
    )).onPressed, isNull);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    // Start the implicit animation in one frame, then advance its clock.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(find.byType(MiniPlayer)).height,
        MiniPlayerDimensions.mediumHeight + 24);
    expect(find.byTooltip('Now playing queue').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Now playing queue'));
    await tester.pump(const Duration(milliseconds: 300));
    // User titles are content, not translated even when they match a UI label.
    expect(find.text('Bài trước'), findsOneWidget);
    expect(find.text('Second'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
