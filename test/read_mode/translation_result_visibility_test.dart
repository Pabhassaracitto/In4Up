import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:in4up/features/translation/text_provider_translation.dart';
import 'package:in4up/features/translation/translation_display_mode.dart';
import 'package:in4up/features/translation/translation_toolbar.dart';
import 'package:in4up/features/translation/widgets/translation_engine_controls.dart';

import '../translation/support/translation_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TranslationCache().clear();
  });

  test('single line reveals stacked result BEFORE engine completes', () async {
    final pending = Completer<void>();
    final engine = RecordingTranslationEngine('google_free')
      ..waitFor = pending.future;
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService(google: engine));
    expect(doc.translationDisplayMode, TranslationDisplayMode.hidden);
    final run = doc.translateLine(0);
    expect(doc.translationDisplayMode, TranslationDisplayMode.stackedBelow);
    expect(doc.translationStatus, TranslationRunStatus.translating);
    pending.complete();
    await run;
    expect(doc.lines.first.translation, 'Bản dịch google_free.');
    expect(doc.translationStatus, TranslationRunStatus.succeeded);
    expect(doc.successfulTranslations, 1);
    expect(doc.failedTranslations, 0);
    expect(doc.translationProgress, 1);
    expect(doc.isTranslating, isFalse);
  });

  test('single-line failure is finite and clears on successful retry',
      () async {
    final engine = RecordingTranslationEngine('google_free', succeeds: false);
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService(google: engine));
    await doc.translateLine(0);
    expect(doc.translationStatus, TranslationRunStatus.failed);
    expect(doc.translationError, isNotNull);
    expect(doc.failedTranslations, 1);
    expect(doc.isTranslating, isFalse);
    engine.succeeds = true;
    await doc.translateLine(0);
    expect(doc.translationStatus, TranslationRunStatus.succeeded);
    expect(doc.translationError, isNull);
    expect(doc.failedTranslations, 0);
  });

  test('single line and batch respect explicit side-by-side and blur settings',
      () async {
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService(
        google: RecordingTranslationEngine('google_free')));
    doc.setTranslationDisplayMode(TranslationDisplayMode.sideBySide);
    doc.setBlurTranslations(true);
    await doc.translateLine(0);
    expect(doc.translationDisplayMode, TranslationDisplayMode.sideBySide);
    await doc.translateAll(forceRetranslate: true);
    expect(doc.translationDisplayMode, TranslationDisplayMode.sideBySide);
    expect(doc.blurTranslations, isTrue);
  });

  test(
      'batch reveals first result while later lines are still translating; partial is not success',
      () async {
    final second = Completer<void>();
    final startedSecond = Completer<void>();
    final engine = RecordingTranslationEngine('google_free');
    engine.onCall = () {
      if (engine.calls == 2) {
        engine.waitFor = second.future;
        engine.succeeds = false;
        startedSecond.complete();
      }
    };
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService(google: engine), count: 2);
    final run = doc.translateAll();
    expect(doc.translationDisplayMode, TranslationDisplayMode.stackedBelow);
    await startedSecond.future;
    expect(doc.isTranslating, isTrue);
    expect(doc.lines.first.translation, isNotEmpty);
    expect(doc.successfulTranslations, 1);
    expect(doc.translationProgress, 0.5);
    second.complete();
    await run;
    expect(doc.translationStatus, TranslationRunStatus.partial);
    expect(doc.successfulTranslations, 1);
    expect(doc.failedTranslations, 1);
    expect(doc.translationProgress, 1);
  });

  for (final batch in [false, true]) {
    test(
        'cancel $batch ignores late result; new document never receives the old result',
        () async {
      final pending = Completer<void>();
      final entered = Completer<void>();
      final engine = RecordingTranslationEngine('google_free')
        ..waitFor = pending.future
        ..onCall = entered.complete;
      final doc = TranslationTestDocument();
      await doc.prepare(translationTestService(google: engine));
      final run = batch ? doc.translateAll() : doc.translateLine(0);
      await entered.future;
      doc.cancelTranslation();
      expect(doc.translationStatus, TranslationRunStatus.cancelled);
      pending.complete();
      await run;
      expect(doc.lines.first.translation, isNull);
      expect(doc.lastTranslationResult, isNull);
      doc.resetTranslationForNewDocument();
      expect(doc.translationStatus, TranslationRunStatus.idle);
      expect(doc.translationDisplayMode, TranslationDisplayMode.hidden);
    });
  }

  test(
      'user may explicitly hide results during a run; completion does not override that choice',
      () async {
    final pending = Completer<void>();
    final engine = RecordingTranslationEngine('google_free')
      ..waitFor = pending.future;
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService(google: engine));
    final run = doc.translateAll();
    doc.setTranslationDisplayMode(TranslationDisplayMode.hidden);
    pending.complete();
    await run;
    expect(doc.translationDisplayMode, TranslationDisplayMode.hidden);
    await doc.translateAll();
    expect(doc.translationDisplayMode, TranslationDisplayMode.stackedBelow,
        reason:
            'an explicit subsequent Translate reveals saved results without another request');
    expect(engine.calls, 1);
  });

  test('clear and source change reset the previous outcome', () async {
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService(
        google: RecordingTranslationEngine('google_free')));
    await doc.translateLine(0);
    doc.clearAllTranslations();
    expect(doc.translationStatus, TranslationRunStatus.idle);
    expect(doc.lastTranslationResult, isNull);
    await doc.translateLine(0);
    await doc.setTranslationSourceLanguage('DE', retranslateExisting: false);
    expect(doc.translationStatus, TranslationRunStatus.idle);
  });

  test(
      'first successful batch line notifies immediately even after a failed first line',
      () async {
    final third = Completer<void>();
    final startedThird = Completer<void>();
    final engine = RecordingTranslationEngine('google_free');
    engine.onCall = () {
      engine.succeeds = engine.calls != 1;
      if (engine.calls == 3) {
        engine.waitFor = third.future;
        startedThird.complete();
      }
    };
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService(google: engine), count: 3);
    var observedSuccess = false;
    doc.addListener(() {
      if (doc.lines[1].translation != null) observedSuccess = true;
    });
    final run = doc.translateAll();
    await startedThird.future;
    expect(observedSuccess, isTrue,
        reason: 'renderer must rebuild before the last line finishes');
    expect(doc.isTranslating, isTrue);
    third.complete();
    await run;
    expect(doc.translationStatus, TranslationRunStatus.partial);
  });

  test(
      'five failures stop finitely without replacing the model error with a network guess',
      () async {
    final doc = TranslationTestDocument();
    await doc.prepare(
        translationTestService(
          google: RecordingTranslationEngine('google_free', succeeds: false),
        ),
        count: 7);
    await doc.translateAll();
    expect(doc.failedTranslations, 5);
    expect(doc.translationProgress, 5 / 7);
    expect(doc.translationStatus, TranslationRunStatus.failed);
    expect(doc.translationError, contains('model unavailable'));
    expect(doc.translationError, isNot(contains('kết nối mạng')));
    expect(doc.isTranslating, isFalse);
  });

  for (final batch in [false, true]) {
    test(
        'target changed by another screen cancels $batch, never leaves a translating outcome',
        () async {
      final entered = Completer<void>();
      final pending = Completer<void>();
      final engine = RecordingTranslationEngine('google_free')
        ..waitFor = pending.future
        ..onCall = entered.complete;
      final service = translationTestService(google: engine);
      final doc = TranslationTestDocument();
      await doc.prepare(service);
      final run = batch ? doc.translateAll() : doc.translateLine(0);
      await entered.future;
      service.configure(targetLang: 'DE');
      pending.complete();
      await run;
      expect(doc.translationStatus, TranslationRunStatus.cancelled);
      expect(doc.isTranslating, isFalse);
      expect(doc.lines.first.translation, isNull);
    });

    test(
        'disposing a document invalidates pending $batch work without notifying a disposed provider',
        () async {
      final entered = Completer<void>();
      final pending = Completer<void>();
      final engine = RecordingTranslationEngine('google_free')
        ..waitFor = pending.future
        ..onCall = entered.complete;
      final doc = TranslationTestDocument();
      await doc.prepare(translationTestService(google: engine));
      final run = batch ? doc.translateAll() : doc.translateLine(0);
      await entered.future;
      doc.dispose();
      pending.complete();
      await run;
      expect(doc.lines.first.translation, isNull);
    });
  }

  test('clearing one document cannot clear another request active-engine label',
      () async {
    final entered = Completer<void>();
    final pending = Completer<void>();
    final engine = RecordingTranslationEngine('google_free')
      ..waitFor = pending.future
      ..onCall = entered.complete;
    final service = translationTestService(google: engine);
    final doc = TranslationTestDocument();
    await doc.prepare(service);
    final otherScreen = service.translateText('Hello', sourceLang: 'EN');
    await entered.future;
    doc.clearAllTranslations();
    expect(service.activeEngineName, 'Google Translate');
    pending.complete();
    await otherScreen;
    expect(service.activeEngineName, isNull);
  });

  testWidgets(
      'result is visibly below original; status identifies preferred and fallback engine at 320px',
      (tester) async {
    final mlkit = RecordingTranslationEngine('mlkit', succeeds: false);
    final service = translationTestService(
        google: RecordingTranslationEngine('google_free'), mlkit: mlkit)
      ..preferEngine('mlkit');
    final doc = TranslationTestDocument();
    await doc.prepare(service);
    Widget build() => MaterialApp(
            home: Scaffold(
                body: SizedBox(
          width: 320,
          child: AnimatedBuilder(
              animation: doc,
              builder: (context, _) => Column(children: [
                    TranslationEnginePicker(service: service),
                    TranslationRunStatusPanel(document: doc),
                    TranslationLineDisplay(
                      originalText: doc.lines.first.content,
                      translatedText: doc.lines.first.translation,
                      displayMode: doc.translationDisplayMode,
                      targetLanguage: AppLanguageCatalog.vietnamese,
                      originalWidget: Text(doc.lines.first.content),
                    ),
                  ])),
        )));
    await tester.pumpWidget(build());
    unawaited(doc.translateLine(0));
    await tester.pumpAndSettle();
    expect(find.text('Bản dịch google_free.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Bản dịch google_free.')).dy,
        greaterThan(tester.getTopLeft(find.text(doc.lines.first.content)).dy));
    expect(find.textContaining('Translation succeeded'), findsOneWidget);
    expect(
        find.text('Fallback engine used: ML Kit On-Device → Google Translate'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    // A later selection must not relabel a result from the previous request.
    service.preferEngine('google_free');
    await tester.pump();
    expect(
        find.text('Fallback engine used: ML Kit On-Device → Google Translate'),
        findsOneWidget);
  });

  testWidgets('failure details wrap, retry is exposed, no forever spinner',
      (tester) async {
    final doc = TranslationTestDocument();
    await doc.prepare(translationTestService());
    var retried = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 320,
      child: TranslationRunStatusPanel(
          document: doc, onRetry: () => retried = true),
    ))));
    unawaited(doc.translateLine(0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Translation failed'), findsOneWidget);
    expect(find.byKey(const Key('translation-error-detail')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Retry translation'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
}
