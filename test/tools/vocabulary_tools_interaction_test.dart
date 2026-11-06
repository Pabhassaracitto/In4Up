import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;
import 'package:in4up/knowledge/visual/collection_scatter_painter.dart' show ScatterPoint;
import 'package:in4up/knowledge/visual/mastery_view_widget.dart';
import 'package:in4up/services/storage_service.dart';
import 'package:in4up/features/dictionary/models/dict_entry.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/services/ipa_resolver.dart';
import 'package:in4up/screens/tools/map_tab.dart';
import 'package:in4up/screens/tools/triangle_tab.dart';
import 'package:in4up/screens/tools/venn_tab.dart';
import 'package:in4up/screens/tools/vocabulary_map_clusters.dart';
import 'package:in4up/screens/tools/word_list/knowledge_graph_screen.dart';
import 'package:in4up/widgets/word_detail_sheet.dart';
import 'package:provider/provider.dart';

class _TestVocabularyProvider extends VocabularyProvider {
  void changed() => notifyListeners();
}

WordEntry _word(String id, {
  String? text,
  String? ipa,
  String language = 'en',
  double understand = 0.2,
  double listen = 0.2,
  double read = 0.2,
}) => WordEntry(
  id: id,
  word: text ?? id,
  meaning: 'meaning $id',
  phonetic: ipa,
  language: language,
  understand: understand,
  listen: listen,
  read: read,
);

Widget _host(VocabularyProvider provider, Widget child, {Locale locale = const Locale('vi')}) {
  return ChangeNotifierProvider<VocabularyProvider>.value(
    value: provider,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('in4up_vocab_tools_test');
    Hive.init(directory.path);
    await VocabularyProvider.ensureBoxOpen();
    await Hive.openBox('settings');
  });

  // Widget tests drive the real provider inside Flutter's fake-async zone.
  // Its fire-and-forget Hive writes may remain pending there; waiting for
  // clear()/close() between tests can deadlock (see linux_shell_regression_test).
  // Each test creates a fresh provider and never loads the previous fixture.
  // The process closes the boxes when this test file's isolate exits.
  tearDownAll(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('batch changes persist once, preserve unrelated words, and same-zone is a no-op', () async {
    final provider = _TestVocabularyProvider();
    final a = _word('a', understand: .32, listen: .24, read: .13);
    final b = _word('b', understand: .43, listen: .22, read: .11);
    final untouched = _word('c', understand: .8);
    provider.allWords.addAll([a, b, untouched]);
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.setWordsZone(['a', 'b', 'a', 'missing'], MasteryZone.listenRead);
    expect(notifications, 1);
    expect(a.zone, MasteryZone.listenRead);
    expect(b.zone, MasteryZone.listenRead);
    expect(untouched.zone, MasteryZone.understandOnly);
    expect(untouched.understand, .8);
    await Hive.box<String>('vocabulary_v2').flush();
    final savedA = WordEntry.fromJson(jsonDecode(Hive.box<String>('vocabulary_v2').get('a')!) as Map<String, dynamic>);
    final savedB = WordEntry.fromJson(jsonDecode(Hive.box<String>('vocabulary_v2').get('b')!) as Map<String, dynamic>);
    expect(savedA.zone, MasteryZone.listenRead);
    expect(savedB.zone, MasteryZone.listenRead);
    a.updateAllScores(.1, .72, .93);
    provider.setWordsZone(['a'], MasteryZone.listenRead);
    expect(notifications, 1);
    expect(a.listen, .72);
    expect(a.read, .93);
    provider.dispose();
  });

  testWidgets('listening button speaks the current word and language, then reveals it', (tester) async {
    final provider = _TestVocabularyProvider()..allWords.add(_word('a', text: 'bonjour', ipa: '/bɔ̃ʒuʁ/', language: 'fr'));
    final spoken = <String>[];
    await tester.pumpWidget(_host(provider, TriangleTab(pronounce: (text, language) async {
      spoken.add('$text:$language');
    })));
    await tester.tap(find.text('Đánh giá nhanh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGHE'));
    await tester.pumpAndSettle();
    expect(find.text('bonjour'), findsNothing, reason: 'listening stimulus must not reveal the answer');
    await tester.tap(find.byKey(const Key('assessment_listen_speak')));
    await tester.pump();
    expect(spoken, ['bonjour:fr']);
    await tester.tap(find.byKey(const Key('assessment_reveal')));
    await tester.pumpAndSettle();
    expect(find.text('bonjour'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('reading answer shows the stored IPA before the meaning', (tester) async {
    final provider = _TestVocabularyProvider()..allWords.add(_word('a', text: 'hello', ipa: '/həˈləʊ/'));
    await tester.pumpWidget(_host(provider, const TriangleTab()));
    await tester.tap(find.text('Đánh giá nhanh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ĐỌC'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_reveal')));
    await tester.pumpAndSettle();
    final ipa = find.byKey(const Key('assessment_ipa'));
    expect(ipa, findsOneWidget);
    expect(find.text('/həˈləʊ/'), findsOneWidget);
    expect(tester.getTopLeft(ipa).dy, lessThan(tester.getTopLeft(find.text('meaning a')).dy));
    provider.dispose();
  });

  testWidgets('missing IPA is looked up without fabricating or changing saved data', (tester) async {
    final word = _word('a', text: 'world');
    final provider = _TestVocabularyProvider()..allWords.add(word);
    IpaResolver.dictLookupOverride = (_) async => [
      DictEntry(headword: 'world', definition: 'earth', phonetic: '/wɜːld/', dictId: 'test'),
    ];
    addTearDown(() => IpaResolver.dictLookupOverride = null);
    await tester.pumpWidget(_host(provider, const TriangleTab()));
    await tester.tap(find.text('Đánh giá nhanh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ĐỌC'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_reveal')));
    await tester.pumpAndSettle();
    expect(find.text('/wɜːld/'), findsOneWidget);
    expect(word.phonetic, isNull, reason: 'the on-demand lookup is display-only');
    provider.dispose();
  });

  testWidgets('failed pronunciation displays an actionable error', (tester) async {
    final provider = _TestVocabularyProvider()..allWords.add(_word('a', text: 'hello'));
    await tester.pumpWidget(_host(provider, TriangleTab(pronounce: (_, __) async {
      throw StateError('no engine');
    })));
    await tester.tap(find.text('Đánh giá nhanh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NGHE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assessment_listen_speak')));
    await tester.pump();
    expect(find.text('Không phát được âm thanh. Hãy kiểm tra cài đặt giọng đọc.'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('triangle and word map expose every overlapping word on a dark panel', (tester) async {
    final provider = _TestVocabularyProvider()
      ..allWords.addAll([_word('a'), _word('b'), _word('c')]);
    for (final triangle in [true, false]) {
      await tester.pumpWidget(_host(provider, triangle ? const TriangleTab() : const MapTab()));
      await tester.pumpAndSettle();
      // A cluster's key is based on its first member, not insertion order.
      final cluster = find.byType(VocabularyClusterMarker);
      expect(cluster, findsOneWidget);
      await tester.tap(cluster);
      await tester.pumpAndSettle();
      for (final id in ['a', 'b', 'c']) {
        expect(find.byKey(Key('cluster_word_$id')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('cluster_word_b')));
      await tester.pumpAndSettle();
      final panel = tester.widget<Container>(find.byKey(Key(triangle ? 'triangle_selected_panel' : 'word_map_selected_panel')));
      expect((panel.decoration! as BoxDecoration).color, const Color(0xFF1A2235));
      expect(find.text('b'), findsWidgets);
    }
    provider.dispose();
  });

  testWidgets('Venn word detail keeps dark contrast and does not translate user data', (tester) async {
    final word = _word('a', text: 'Tất cả', ipa: '/test/')
      ..meaning = 'Chưa có từ vựng';
    final provider = _TestVocabularyProvider()..allWords.add(word);
    await tester.pumpWidget(_host(provider, const VennTab(), locale: const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venn_word_a')));
    await tester.pumpAndSettle();
    final sheet = find.byType(WordDetailSheet);
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Tất cả')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Chưa có từ vựng')), findsOneWidget);
    final phonetic = tester.widget<Text>(find.text('/test/'));
    expect(phonetic.style?.color, ThemeData.dark().colorScheme.onSurfaceVariant);
    expect(find.byWidgetPredicate((widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration! as BoxDecoration).color == const Color(0xFF3D3019)), findsOneWidget);

    final understandButton = find.byIcon(Icons.lightbulb_outline);
    await tester.ensureVisible(understandButton);
    await tester.pumpAndSettle();
    await tester.tap(understandButton);
    await tester.pumpAndSettle();
    expect(find.text('Tất cả - ${AppUITranslations.translate('Hiểu', 'en')}'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('two fingers add same-zone words to one drag and drop the whole batch', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final a = _word('a');
    final b = _word('b');
    final other = _word('other', understand: .8);
    final provider = _TestVocabularyProvider()..allWords.addAll([a, b, other]);
    await tester.pumpWidget(_host(provider, const VennTab()));
    await tester.pumpAndSettle();

    final firstFinger = await tester.startGesture(tester.getCenter(find.byKey(const Key('venn_word_a'))));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await firstFinger.moveBy(const Offset(0, -15));
    await tester.pump();
    expect(find.byKey(const Key('venn_drag_badge')), findsOneWidget);
    await tester.tap(find.byKey(const Key('venn_word_b')));
    await tester.pump();
    expect(find.descendant(of: find.byKey(const Key('venn_drag_badge')), matching: find.text('2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('venn_word_other')));
    await tester.pump();
    expect(find.text('Chỉ gom các từ cùng vùng ban đầu.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('venn_drag_badge')), matching: find.text('2')), findsOneWidget);
    await firstFinger.moveTo(tester.getCenter(find.byKey(const Key('venn_target_listenOnly'))));
    await tester.pump();
    await firstFinger.up();
    await tester.pumpAndSettle();
    expect(a.zone, MasteryZone.listenOnly);
    expect(b.zone, MasteryZone.listenOnly);
    expect(other.zone, MasteryZone.understandOnly);
    provider.dispose();
  });

  testWidgets('dropping outside does not change scores and keeps the group selected', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final a = _word('a', understand: .31);
    final b = _word('b');
    final provider = _TestVocabularyProvider()..allWords.addAll([a, b]);
    await tester.pumpWidget(_host(provider, const VennTab()));
    await tester.pumpAndSettle();
    final finger = await tester.startGesture(tester.getCenter(find.byKey(const Key('venn_word_a'))));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await finger.moveBy(const Offset(0, -15));
    await tester.pump();
    await tester.tap(find.byKey(const Key('venn_word_b')));
    await tester.pump();
    await finger.moveTo(const Offset(5, 890));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(a.understand, .31);
    expect(a.zone, MasteryZone.blindSpot);
    expect(b.zone, MasteryZone.blindSpot);
    expect(find.text('Đã chọn 2 từ'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('a drop on the painted circle works even away from the badge', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final word = _word('a');
    final provider = _TestVocabularyProvider()..allWords.add(word);
    await tester.pumpWidget(_host(provider, const VennTab()));
    await tester.pumpAndSettle();
    final finger = await tester.startGesture(tester.getCenter(find.byKey(const Key('venn_word_a'))));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await finger.moveBy(const Offset(0, -15));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const Key('venn_diagram_background')));
    final size = rect.size.shortestSide;
    // Inside the understand circle, but outside its small count badge.
    await finger.moveTo(rect.center + Offset(-size * .09, -size * .32));
    await tester.pump();
    await finger.up();
    await tester.pumpAndSettle();
    expect(word.zone, MasteryZone.understandOnly);
    provider.dispose();
  });

  testWidgets('single-finger bulk selection moves a whole source zone', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final a = _word('a');
    final b = _word('b');
    final other = _word('other', listen: .8);
    final provider = _TestVocabularyProvider()..allWords.addAll([a, b, other]);
    await tester.pumpWidget(_host(provider, const VennTab()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('venn_selection_mode')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('venn_word_a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('venn_select_all')));
    await tester.pump();
    expect(find.text('Đã chọn 2 từ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('venn_move_selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉ Hiểu').last);
    await tester.pumpAndSettle();
    expect(a.zone, MasteryZone.understandOnly);
    expect(b.zone, MasteryZone.understandOnly);
    expect(other.zone, MasteryZone.listenOnly);
    provider.dispose();
  });

  testWidgets('graph pages, searches and refreshes edits without a count change', (tester) async {
    final provider = _TestVocabularyProvider()
      ..allWords.addAll([for (var i = 0; i < 83; i++) _word('w$i', text: 'word$i')]);
    await tester.pumpWidget(_host(provider, const KnowledgeGraphScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('knowledge_graph_node_w0')), findsOneWidget);
    expect(find.byKey(const Key('knowledge_graph_node_w80')), findsNothing);
    await tester.tap(find.byKey(const Key('graph_next_page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('knowledge_graph_node_w80')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('graph_search')), 'word82');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('knowledge_graph_node_w82')), findsOneWidget);
    expect(find.byKey(const Key('knowledge_graph_node_w80')), findsNothing);
    provider.allWords[82].word = 'word82 updated';
    provider.changed();
    await tester.pumpAndSettle();
    expect(find.text('word82 updated'), findsOneWidget);
    provider.dispose();
  });

  test('six-skill preference uses the settings box and defaults off', () async {
    final storage = StorageService();
    await Hive.box('settings').delete('hexagon_v1');
    expect(storage.getHexagonV1Flag(), isFalse);
    await storage.saveHexagonV1Flag(true);
    expect(storage.getHexagonV1Flag(), isTrue);
    await storage.saveHexagonV1Flag(false);
    expect(storage.getHexagonV1Flag(), isFalse);
  });

  testWidgets('six-skill toggle is reversible, persisted and never invents scores', (tester) async {
    var saved = false;
    final writes = <bool>[];
    final item = _word('a', understand: 0, listen: 0, read: 0.4)
      ..understandData.totalReviews = 1;
    final provider = _TestVocabularyProvider()..allWords.add(item);
    Widget view() => VennTab(
      key: UniqueKey(),
      readSixSkillMode: () => saved,
      writeSixSkillMode: (value) async { saved = value; writes.add(value); },
    );
    await tester.pumpWidget(_host(provider, view()));
    expect(find.byKey(const Key('venn_diagram_background')), findsOneWidget);
    await tester.tap(find.byKey(const Key('venn_toggle_six_skills')));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(find.byKey(const Key('mastery_hexagram')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('mastery_value_understanding'))).data, '0%');
    expect(tester.widget<Text>(find.byKey(const Key('mastery_value_listening'))).data, 'Chưa đánh giá');
    expect(tester.widget<Text>(find.byKey(const Key('mastery_value_reading'))).data, '40%');
    for (final dim in ['use', 'speak', 'write']) {
      expect(tester.widget<Text>(find.byKey(Key('mastery_value_$dim'))).data, 'Chưa đánh giá');
    }
    expect(find.byKey(const Key('mastery_output_unavailable')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mastery_collection_mode')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('mastery_scatter_count'))).data, '0/1');
    expect(find.byKey(const Key('mastery_scatter_empty')), findsOneWidget);

    // A fresh screen reads the saved preference; switching back restores Venn.
    await tester.pumpWidget(_host(provider, view()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mastery_hexagram')), findsOneWidget);
    await tester.tap(find.byKey(const Key('venn_toggle_six_skills')));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(writes, [true, false]);
    expect(find.byKey(const Key('venn_diagram_background')), findsOneWidget);
    provider.dispose();
  });

  testWidgets('six-skill picker preserves user text and reflects Venn changes', (tester) async {
    final first = _word('a', text: 'first');
    final second = WordEntry(id: 'b', word: 'Tất cả', meaning: 'fox', read: 0.1);
    second.readData
      ..totalReviews = 4
      ..interval = 7
      ..repetitions = 2;
    final history = Map<String, dynamic>.from(second.readData.toJson())..remove('score');
    final provider = _TestVocabularyProvider()..allWords.addAll([first, second]);
    await tester.pumpWidget(_host(provider, VennTab(
      readSixSkillMode: () => true,
      writeSixSkillMode: (_) async {},
    ), locale: const Locale('en')));
    await tester.tap(find.byKey(const Key('mastery_choose_word')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mastery_word_search')), 'fox');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mastery_pick_a')), findsNothing);
    expect(find.text('Tất cả'), findsOneWidget, reason: 'user vocabulary must not be translated');
    await tester.tap(find.byKey(const Key('mastery_pick_b')));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('mastery_value_reading'))).data, '10%');
    provider.setWordsZone(['b'], MasteryZone.readOnly);
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('mastery_value_reading'))).data, '80%');
    expect(Map<String, dynamic>.from(second.readData.toJson())..remove('score'), history);
    provider.dispose();
  });

  testWidgets('partial output, real zero, equal gap and collection count are explicit', (tester) async {
    final provider = _TestVocabularyProvider();
    final complete = <SkillDimension, double?>{
      SkillDimension.understanding: 0.5,
      SkillDimension.listening: null,
      SkillDimension.reading: null,
      SkillDimension.use: 0.5,
      SkillDimension.speak: null,
      SkillDimension.write: 0,
    };
    await tester.pumpWidget(_host(provider, MasteryViewWidget(
      mastery: complete,
      useIsPartial: true,
      collectionPoints: [
        ScatterPoint(unitId: 'complete', mastery: complete),
        const ScatterPoint(unitId: 'no-output', mastery: {SkillDimension.reading: 0.5}),
        const ScatterPoint(unitId: 'no-input', mastery: {SkillDimension.write: 0}),
      ],
    )));
    expect(tester.widget<Text>(find.byKey(const Key('mastery_value_use'))).data, '50% · Một phần');
    expect(tester.widget<Text>(find.byKey(const Key('mastery_value_write'))).data, '0%');
    expect(find.text('Hiểu ↔ Dùng: 0%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mastery_collection_mode')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('mastery_scatter_count'))).data, '1/3');
    expect(find.byKey(const Key('mastery_scatter_empty')), findsNothing);
    provider.dispose();
  });

  test('new chrome has English fallback and priority-locale translations', () {
    const sources = [
      'Chạm cụm để chọn từng từ',
      'Chuyển vùng sẽ thay đổi điểm của cả ba kỹ năng.',
      'Giữ và kéo một từ; chạm thêm từ cùng vùng bằng ngón khác.',
      'Chưa có IPA cho từ này',
      'Không phát được âm thanh. Hãy kiểm tra cài đặt giọng đọc.',
      'Liên kết hiện trong trang',
      'Tìm từ hoặc nghĩa',
      'Sáu kỹ năng',
      'Venn ba kỹ năng',
      'Từng từ',
      'Kho từ',
      'Chọn từ',
      'Không tìm thấy từ',
      'Điểm Hiểu, Nghe, Đọc là điểm hiện đang lưu, không phải EMA.',
      'Đánh giá và lưu Dùng, Nói, Viết chưa được kết nối.',
      'Chưa đủ dữ liệu đầu vào và đầu ra để hiển thị từ nào.',
      'Từ có đủ dữ liệu',
      'Ngang: Hiểu, Nghe, Đọc. Dọc: Dùng, Nói, Viết.',
      'Một phần',
      'Không lưu được chế độ xem; lựa chọn chỉ áp dụng trong phiên này.',
      'Chênh lệch',
    ];
    for (final source in sources) {
      expect(AppUITranslations.translate(source, 'bn'), AppUITranslations.translate(source, 'en'));
      for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
        expect(AppUITranslations.translate(source, locale), isNot(source), reason: '$locale: $source');
      }
    }
    expect(AppUITranslations.translate('Đã chọn 12 từ', 'en'), '12 words selected');
    expect(AppUITranslations.translate('5 từ trong cụm', 'en'), '5 words in cluster');
  });
}
