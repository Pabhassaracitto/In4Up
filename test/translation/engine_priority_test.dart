import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/translation_ui_labels.dart';
import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:in4up/features/translation/engines/hymt_engine.dart';
import 'package:in4up/features/translation/translation_engine_priority.dart';
import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/features/translation/widgets/translation_engine_controls.dart';

import 'support/translation_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TranslationCache().clear();
  });

  group('Audit 1.29 §6 — priority, persistence and routing', () {
    test('normalize removes unknown/duplicate ids; dictionary stays last', () {
      final ids = normalizeTranslationEnginePriority(
          ['mlkit', 'mlkit', 'removed', 'offline']);
      expect(ids.first, 'mlkit');
      expect(ids.toSet().length, translationEngineDefaultPriority.length);
      expect(ids, isNot(contains('offline')));
      expect(ids, isNot(contains('removed')));
      expect(() => ids.add('google_free'), throwsUnsupportedError);
    });

    test(
        'legacy default remains online first, offline fallback, dictionary last',
        () async {
      final google = RecordingTranslationEngine('google_free');
      final mlkit = RecordingTranslationEngine('mlkit');
      final service = translationTestService(google: google, mlkit: mlkit);
      expect(service.routingOrder,
          ['Google Translate', 'ML Kit On-Device', 'Offline Dictionary']);
      expect(
          (await service.translateText('Hello', sourceLang: 'EN')).engineName,
          google.name);
      expect(mlkit.calls, 0);
    });

    test('dragging offline first really runs offline before Google', () async {
      final google = RecordingTranslationEngine('google_free');
      final mlkit = RecordingTranslationEngine('mlkit');
      final service = translationTestService(google: google, mlkit: mlkit)
        ..setEnginePriority(['mlkit', 'google_free']);
      final result = await service.translateText('Hello', sourceLang: 'EN');
      expect(result.engineName, mlkit.name);
      expect(result.route?.selectedEngineId, 'mlkit');
      expect(result.route?.actualEngineId, 'mlkit');
      expect(result.route?.usedFallback, isFalse);
      expect(google.calls, 0);
      expect(service.routingOrder.first, mlkit.name);
    });

    test('offline failure -> Google; selection and actual engine stay distinct',
        () async {
      final google = RecordingTranslationEngine('google_free');
      final mlkit = RecordingTranslationEngine('mlkit', succeeds: false);
      final service = translationTestService(google: google, mlkit: mlkit)
        ..setEnginePriority(['mlkit', 'google_free']);
      final result = await service.translateText('Hello', sourceLang: 'EN');
      expect(result.isSuccess, isTrue);
      expect(result.route?.selectedEngineName, mlkit.name);
      expect(result.route?.actualEngineId, google.id);
      expect(result.route?.attemptedEngineIds, ['mlkit', 'google_free']);
      expect(result.route?.usedFallback, isTrue);
      expect(service.selectedEngineId, 'mlkit',
          reason: 'fallback must not rewrite the preference');
      expect(service.activeEngineNotifier.value, isNull);
    });

    test('missing model/platform is skipped and reported as fallback',
        () async {
      final mlkit = RecordingTranslationEngine('mlkit', available: false);
      final google = RecordingTranslationEngine('google_free');
      final service = translationTestService(google: google, mlkit: mlkit)
        ..preferEngine('mlkit');
      final result = await service.translateText('Hello', sourceLang: 'EN');
      expect(mlkit.calls, 0);
      expect(result.route?.attemptedEngineIds, ['google_free']);
      expect(result.route?.usedFallback, isTrue);
    });

    test('no network -> offline; online preference is not silently changed',
        () async {
      final google = RecordingTranslationEngine('google_free');
      final service = translationTestService(
        google: google,
        mlkit: RecordingTranslationEngine('mlkit'),
        network: false,
      );
      final result = await service.translateText('Hello', sourceLang: 'EN');
      expect(google.calls, 0);
      expect(result.route?.selectedEngineId, 'google_free');
      expect(result.route?.actualEngineId, 'mlkit');
      expect(result.route?.usedFallback, isTrue);
    });

    test(
        'offline-only cannot be bypassed by dragging; choosing Google explicitly can',
        () async {
      final google = RecordingTranslationEngine('google_free');
      final mlkit = RecordingTranslationEngine('mlkit');
      final service = translationTestService(google: google, mlkit: mlkit)
        ..offlineOnly = true
        ..setEnginePriority(['google_free', 'mlkit']);
      expect(service.offlineOnly, isTrue);
      expect(
          (await service.translateText('Hello', sourceLang: 'EN')).engineName,
          mlkit.name);
      expect(google.calls, 0);
      service.preferEngine('google_free');
      expect(service.offlineOnly, isFalse);
      expect(
          (await service.translateText('Hello', sourceLang: 'EN')).engineName,
          google.name);
    });

    for (final failure in ['exception', 'untranslated']) {
      test('$failure falls through to the next engine, not a false success',
          () async {
        final google = RecordingTranslationEngine('google_free')
          ..throwError = failure == 'exception'
          ..echoSource = failure == 'untranslated';
        final service = translationTestService(
            google: google, mlkit: RecordingTranslationEngine('mlkit'));
        final result = await service.translateText(
          'This original sentence must not be accepted as its own translation.',
          sourceLang: 'EN',
        );
        expect(result.route?.usedFallback, isTrue);
        expect(result.engineName, 'ML Kit On-Device');
        expect(service.activeEngineName, isNull);
      });
    }

    test('total failure retains missing-model metadata and clears active state',
        () async {
      final mlkit = RecordingTranslationEngine('mlkit', succeeds: false)
        ..missingModels = ['EN'];
      final service = translationTestService(mlkit: mlkit);
      final result = await service.translateText('Hello', sourceLang: 'EN');
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'missing_models');
      expect(result.missingModelCodes, ['EN']);
      expect(result.route?.actualEngineId, isNull);
      expect(service.activeEngineName, isNull);
    });

    test(
        'changing order invalidates the same-text cache; cache never invents an engine',
        () async {
      final google = RecordingTranslationEngine('google_free');
      final mlkit = RecordingTranslationEngine('mlkit');
      final service = translationTestService(google: google, mlkit: mlkit);
      await service.translateText('Hello', sourceLang: 'EN');
      final cached = await service.translateText('Hello', sourceLang: 'EN');
      expect(cached.engineName, 'cache');
      expect(cached.route, isNull);
      final before = service.pipelineTag;
      service.preferEngine('mlkit');
      expect(service.pipelineTag, isNot(before));
      expect(
          (await service.translateText('Hello', sourceLang: 'EN')).engineName,
          mlkit.name);
      expect(google.calls, 1);
      expect(mlkit.calls, 1);
    });

    test('stable-id order round-trips; rapid writes keep the last selection',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final google = RecordingTranslationEngine('google_free');
      final mlkit = RecordingTranslationEngine('mlkit');
      TranslationService make() => TranslationService.forTest(
            onlineEngines: [google],
            mlkitEngine: mlkit,
            offlineEngine:
                RecordingTranslationEngine('offline', succeeds: false),
            preferences: prefs,
            networkAvailable: true,
          );
      final first = make();
      await first.settingsReady;
      first.preferEngine('mlkit');
      first.preferEngine('google_free');
      first.preferEngine('mlkit');
      first.offlineOnly = true;
      await first.settingsSaved;
      final reopened = make();
      await reopened.settingsReady;
      expect(reopened.engineChoices.first.id, 'mlkit');
      expect(reopened.offlineOnly, isTrue);
      expect(reopened.routingOrder.last, 'Offline Dictionary');
      reopened.resetEnginePriority();
      await reopened.settingsSaved;
      expect(
          prefs.containsKey(TranslationService.enginePriorityPrefKey), isFalse);
    });

    test(
        'legacy offline preference is read from its existing key, never migrated away',
        () async {
      SharedPreferences.setMockInitialValues(
          {'translation_offline_engine': 'mlkit'});
      final service = TranslationService.forTest(
          preferences: await SharedPreferences.getInstance());
      await service.settingsReady;
      expect(service.offlineEnginePref, HyMtOfflinePreference.mlkit);
      service.offlineEnginePref = HyMtOfflinePreference.auto;
      await service.settingsSaved;
      expect(
          (await SharedPreferences.getInstance())
              .getString('translation_offline_engine'),
          'auto');
    });

    test('a slow startup read cannot replace a new selection', () async {
      SharedPreferences.setMockInitialValues({
        TranslationService.enginePriorityPrefKey: ['google_free', 'mlkit'],
        'translation_offline_only': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = TranslationService.forTest(
        onlineEngines: [RecordingTranslationEngine('google_free')],
        mlkitEngine: RecordingTranslationEngine('mlkit'),
        preferences: prefs,
      );
      service.preferEngine('mlkit');
      await service.settingsReady;
      await service.settingsSaved;
      expect(service.selectedEngineId, 'mlkit');
      expect(service.offlineOnly, isTrue,
          reason: 'unrelated restored gate must survive a reorder');
      expect(prefs.getBool('translation_offline_only'), isTrue);
    });

    test('in-flight route uses request snapshot when settings change',
        () async {
      final pending = Completer<void>();
      final entered = Completer<void>();
      final google = RecordingTranslationEngine('google_free')
        ..waitFor = pending.future
        ..onCall = entered.complete;
      final service = translationTestService(
          google: google, mlkit: RecordingTranslationEngine('mlkit'));
      final run = service.translateText('Hello', sourceLang: 'EN');
      await entered.future;
      service.preferEngine('mlkit');
      pending.complete();
      final result = await run;
      expect(result.route?.selectedEngineId, 'google_free');
      expect(result.route?.actualEngineId, 'google_free');
      expect(service.selectedEngineId, 'mlkit');
    });
  });

  group('Engine UI — drag, selection and shared configuration', () {
    testWidgets(
        'two selectors synchronize immediately; Google exits offline-only',
        (tester) async {
      final service = translationTestService(
        google: RecordingTranslationEngine('google_free'),
        mlkit: RecordingTranslationEngine('mlkit'),
      )..offlineOnly = true;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        TranslationEnginePicker(service: service),
        TranslationEnginePicker(service: service),
      ]))));
      final first = find.byKey(const Key('translation-engine-picker')).first;
      await tester.tap(first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google Translate · Online').last);
      await tester.pumpAndSettle();
      expect(service.offlineOnly, isFalse);
      final selectors = tester.widgetList<DropdownButton<String>>(
          find.byType(DropdownButton<String>));
      expect(selectors.map((e) => e.value), everyElement('google_free'));
    });

    testWidgets(
        'dragging a handle reorders routing; buttons provide accessible alternative',
        (tester) async {
      final service = translationTestService(
        google: RecordingTranslationEngine('google_free'),
        mlkit: RecordingTranslationEngine('mlkit'),
      );
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SizedBox(
        width: 320,
        child: TranslationEngineOrderList(
            service: service, accentColor: Colors.purple),
      ))));
      await tester.drag(find.byKey(const ValueKey('translation-drag-mlkit')),
          const Offset(0, -65));
      await tester.pumpAndSettle();
      expect(service.engineChoices.first.id, 'mlkit');
      expect(tester.takeException(), isNull);
      await tester
          .tap(find.byKey(const ValueKey('translation-up-google_free')));
      await tester.pumpAndSettle();
      expect(service.engineChoices.first.id, 'google_free');
    });

    test(
        'every new label has English and native priority locales; JA falls back to English',
        () {
      for (final entry in translationUiOverrides.entries) {
        for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
          expect(entry.value[locale], isNotEmpty,
              reason: '${entry.key} [$locale]');
          if (entry.value['en'] != entry.key) {
            expect(AppUITranslations.translate(entry.key, locale),
                isNot(entry.key));
          }
        }
        if (entry.key != TranslationUiLabels.online &&
            entry.key != TranslationUiLabels.offline) {
          expect(
              AppUITranslations.translate(entry.key, 'ja'), entry.value['en']);
        }
      }
    });
  });
}
