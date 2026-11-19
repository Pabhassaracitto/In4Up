// Integration through the REAL TextLineWidget, without constructing platform
// audio/IPA engines. Renderer ownership stays with the word/IPA agent.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:in4up/features/translation/translation_display_mode.dart';
import 'package:in4up/models/color_mode.dart';
import 'package:in4up/models/ipa_color_visibility.dart';
import 'package:in4up/models/ipa_display_mode.dart';
import 'package:in4up/models/word_analysis.dart';
import 'package:in4up/models/word_color_style.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/screens/read_mode/models/playback_recipe.dart';
import 'package:in4up/screens/read_mode/services/playback_controller.dart';
import 'package:in4up/screens/read_mode/widgets/text_line_widget.dart';
import 'package:in4up/services/ipa_stress_annotator.dart';
import 'package:in4up/services/ipa_styling.dart';
import 'package:in4up/services/line_ipa_service.dart';

import '../translation/support/translation_fakes.dart';

class _IpaDocument extends TranslationTestDocument implements TextProvider {
  _IpaDocument(this.mode);
  final IpaDisplayMode mode;

  @override
  IpaDisplayMode get ipaDisplayMode => mode;
  @override
  int get currentLineIndex => 0;
  @override
  int? get focusCueLineIndex => null;
  @override
  ColorMode get colorMode => ColorMode.none;
  @override
  WordColorStyle get wordColorStyle => WordColorStyle.textOnly;
  @override
  bool get wordTapBoxes => false;
  @override
  bool get showLineNumbers => true;
  @override
  TextAlign get textAlign => TextAlign.left;
  @override
  double get fontSize => 18;
  @override
  bool isLineBeingSpoken(int index) => false;
  @override
  List<List<AnalyzedWord>> get analyzedLines => const [];
  @override
  bool get ipaColorByType => false;
  @override
  bool get ipaFadeKnown => false;
  @override
  IpaColorVisibility get ipaColorVisibility => const IpaColorVisibility();
  @override
  IpaLineStress? lineStressFor(List<IpaSegment>? segments) => null;
  @override
  List<IpaLinkMark>? linkMarksFor(List<IpaSegment>? segments) => null;
  @override
  List<IpaSegment>? lineIpaSegmentsFor(int index) => const [
        IpaSegment(
            surface: 'Hello',
            wordCore: 'Hello',
            ipa: 'həˈləʊ',
            phonemes: ['həˈləʊ']),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends ChangeNotifier implements PlayerProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Playback extends ChangeNotifier implements PlaybackController {
  @override
  final activeLineNotifier = ValueNotifier<int>(-1);
  @override
  final isSourceNotifier = ValueNotifier<bool>(true);
  @override
  PlaybackRecipe get recipe => PlaybackRecipe.enOnly;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  void dispose() {
    activeLineNotifier.dispose();
    isSourceNotifier.dispose();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TranslationCache().clear();
  });

  for (final ipaMode in IpaDisplayMode.values) {
    for (final display in [
      TranslationDisplayMode.stackedBelow,
      TranslationDisplayMode.sideBySide
    ]) {
      testWidgets(
          'actual renderer retains translation with IPA=$ipaMode and layout=$display',
          (tester) async {
        final doc = _IpaDocument(ipaMode);
        await doc.prepare(translationTestService(
            google: RecordingTranslationEngine('google_free')));
        // Stacked starts hidden to reproduce Translate -> visible default.
        if (display == TranslationDisplayMode.sideBySide)
          doc.setTranslationDisplayMode(display);
        final playback = _Playback();
        final player = _Player();
        final scroll = ScrollController();
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<TextProvider>.value(value: doc),
            ChangeNotifierProvider<PlayerProvider>.value(value: player),
            ChangeNotifierProvider<PlaybackController>.value(value: playback),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: SizedBox(
            width: 320,
            child: TextLineWidget(index: 0, scrollController: scroll),
          ))),
        ));
        unawaited(doc.translateLine(0));
        await tester.pumpAndSettle();
        expect(doc.translationDisplayMode, display);
        expect(find.text('Bản dịch google_free.'), findsOneWidget);
        if (ipaMode != IpaDisplayMode.hidden) {
          expect(find.textContaining('həˈləʊ', findRichText: true),
              findsOneWidget);
          expect(find.text('Hello'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
        playback.dispose();
        player.dispose();
        doc.dispose();
      });
    }
  }
}
