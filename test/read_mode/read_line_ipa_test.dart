import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/translation_display_mode.dart';
import 'package:in4up/features/word_lookup/services/word_insight_service.dart';
import 'package:in4up/models/color_mode.dart';
import 'package:in4up/models/ipa_display_mode.dart';
import 'package:in4up/models/text_item.dart';
import 'package:in4up/models/word_analysis.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/screens/read_mode/controllers/read_mode_controller.dart';
import 'package:in4up/screens/read_mode/services/playback_controller.dart';
import 'package:in4up/screens/read_mode/widgets/read_word_ipa.dart';
import 'package:in4up/screens/read_mode/widgets/text_line_widget.dart';
import 'package:in4up/screens/read_mode/widgets/word_mini_pop.dart';
import 'package:in4up/services/line_ipa_service.dart';
import 'package:in4up/services/syntax_highlighter_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _source = 'cat, an orange cat walks extraordinary distances.';
const _translation = 'Bản dịch thử nghiệm.';
const _repeatedWordIndex = 4;

class _ReaderText extends TextProvider {
  bool showIpa;
  @override
  final bool wordTapBoxes;
  @override
  final TranslationDisplayMode translationDisplayMode;
  final spoken = <String>[];

  _ReaderText(this.showIpa, this.wordTapBoxes, this.translationDisplayMode);

  @override
  final lines = [
    TextItem(id: 'line', content: _source, translation: _translation)
  ];
  @override
  final analyzedLines = [
    SyntaxHighlighterService.tokenizeText(_source)
        .map((word) => AnalyzedWord(word: word, wordType: WordType.noun))
        .toList(),
  ];
  @override
  int get currentLineIndex => 0;
  @override
  double get fontSize => 24;
  @override
  ColorMode get colorMode => ColorMode.cefrLevel;
  @override
  bool get showColorModeDetails => wordTapBoxes;
  @override
  IpaDisplayMode get ipaDisplayMode =>
      showIpa ? IpaDisplayMode.all : IpaDisplayMode.hidden;
  @override
  List<IpaSegment>? lineIpaSegmentsFor(int index) =>
      LineIpaService.buildLineIpaSegments(lines[index].content);
  @override
  Future<void> speak(String text, {int? lineIndex, String? language}) async {
    spoken.add(text);
  }
}

class _Player extends ChangeNotifier implements PlayerProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playback extends ChangeNotifier implements PlaybackController {
  @override
  final activeLineNotifier = ValueNotifier(-1);
  @override
  final isSourceNotifier = ValueNotifier(true);
  @override
  void dispose() {
    activeLineNotifier.dispose();
    isSourceNotifier.dispose();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReaderController implements ReadModeController {
  @override
  int getLineStartOffset(int lineIndex) => 0;
  @override
  void removeFloatingMenu() {}
  @override
  void showFloatingMenu(OverlayEntry entry, BuildContext context) =>
      entry.dispose();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Vocab extends ChangeNotifier implements VocabularyProvider {
  @override
  bool hasWord(String word) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _ipa(String text) => find.descendant(
      of: find.byType(ReadWordIpa),
      matching: find.text(text, findRichText: true),
    );

Finder _sourceWord(String text) => find.descendant(
      of: find.byType(TextLineWidget),
      matching: find.text(text, findRichText: true),
    );

Future<void> _mount(WidgetTester tester, _ReaderText tp) async {
  final pp = _Player();
  final playback = _Playback();
  final vocab = _Vocab();
  final scroll = ScrollController();
  addTearDown(() {
    tp.dispose();
    pp.dispose();
    playback.dispose();
    vocab.dispose();
    scroll.dispose();
  });
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<TextProvider>.value(value: tp),
      ChangeNotifierProvider<PlayerProvider>.value(value: pp),
      Provider<PlaybackController>.value(value: playback),
      Provider<ReadModeController>.value(value: _ReaderController()),
      ChangeNotifierProvider<VocabularyProvider>.value(value: vocab),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 1.5,
            child: SingleChildScrollView(
              controller: scroll,
              child: SizedBox(
                width: 320,
                child: TextLineWidget(index: 0, scrollController: scroll),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LineIpaService.clearCache();
    LineIpaService.wordIpaOverride = (word) => switch (word) {
          'cat' => 'kæt',
          'an' => 'æn',
          'orange' => 'ɒrɪndʒ',
          'walks' => 'wɔks',
          'extraordinary' => 'ɪkstrɔːrdɪnəri',
          'distances' => 'dɪstənsɪz',
          _ => null,
        };
    WordInsightService.dictionaryLookupOverride = (_) async => [];
    WordInsightService.onlineLookupOverride = (_) async => null;
    WordInsightService.offlineIpaOverride = (_) async => null;
    WordInsightService.offlineMeaningOverride = (_) => 'Test definition';
    WordInsightService.targetLanguageOverride = () => 'VI';
  });
  tearDown(() {
    WordMiniPop.dismiss();
    WordInsightService.resetForTest();
    LineIpaService.wordIpaOverride = null;
    LineIpaService.clearCache();
  });

  for (final mode in TranslationDisplayMode.values) {
    for (final boxes in [false, true]) {
      testWidgets('IPA on/off, ${mode.name}, boxes=$boxes', (tester) async {
        final tp = _ReaderText(true, boxes, mode);
        await _mount(tester, tp);
        expect(
            find.text(_translation),
            mode == TranslationDisplayMode.hidden
                ? findsNothing
                : findsOneWidget);
        expect(find.byType(ReadWordIpa), findsNWidgets(7));

        final secondCat = _sourceWord('cat').at(1);
        final secondIpa = _ipa('kæt').at(1);
        final wordRect = tester.getRect(secondCat);
        final ipaRect = tester.getRect(secondIpa);
        expect(wordRect.top,
            greaterThan(tester.getTopLeft(_sourceWord('cat').first).dy),
            reason: 'the second cat must wrap onto a later run');
        expect(ipaRect.top, closeTo(wordRect.bottom + (boxes ? 1 : 1.5), 1));
        expect(ipaRect.center.dx, closeTo(wordRect.center.dx, 1));
        expect(tester.getRect(_ipa('ɪkstrɔːrdɪnəri')).width, lessThan(320));
        expect(tester.takeException(), isNull);

        // Touching either tier opens the real quick dictionary pop for the
        // second occurrence, not the first word that shares its pronunciation.
        await tester.tap(secondIpa);
        await tester.pump();
        expect(tp.spoken, ['cat']);
        var pop = tester.widget<WordMiniPop>(find.byType(WordMiniPop));
        expect(pop.wordIndex, _repeatedWordIndex);
        expect(pop.anchorRect!.contains(wordRect.center), isTrue);
        WordMiniPop.dismiss();
        await tester.pump();

        tp.showIpa = false;
        tp.notifyListeners();
        await tester.pump();
        expect(find.byType(ReadWordIpa), findsNothing);
        if (boxes) {
          await tester.tap(_sourceWord('an'));
        } else {
          final paragraph = tester.renderObject<RenderParagraph>(
            _sourceWord(_source),
          );
          final start = _source.indexOf('an');
          final target = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: start, extentOffset: start + 2),
              )
              .first
              .toRect()
              .center;
          await tester.tapAt(paragraph.localToGlobal(target));
        }
        await tester.pump();
        expect(tp.spoken, ['cat', 'an']);
        pop = tester.widget<WordMiniPop>(find.byType(WordMiniPop));
        expect(pop.wordIndex, 2);
        WordMiniPop.dismiss();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final boxes in [false, true]) {
    testWidgets('hold + drag from IPA across a wrapped run, boxes=$boxes',
        (tester) async {
      final tp = _ReaderText(true, boxes, TranslationDisplayMode.sideBySide);
      await _mount(tester, tp);
      final gesture =
          await tester.startGesture(tester.getCenter(_ipa('kæt').at(1)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(tp.selectedText, 'cat');
      expect(tp.selectedTextInfo!.startOffset, _source.lastIndexOf('cat'));
      await gesture.moveTo(tester.getCenter(_ipa('wɔks')));
      await tester.pump();
      await gesture.up();
      expect(tp.selectedText, 'cat walks');
      expect(tp.selectedTextInfo!.endOffset, _source.indexOf(' extraordinary'));
      expect(tp.spoken, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }
}
