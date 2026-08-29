// test/translation_glossary_test.dart
//
// Test thuần logic cho glossary + protect-tokens + pipeline dịch:
// - normalize (bỏ dấu Pali/Việt)
// - longest-match + word boundary + priority
// - protect/restore placeholder
// - luật khóa (locked không bị đè)
// - đồng bộ WordEntry → glossary
// - thứ tự tầng trong TranslationService (glossary trước engine,
//   offline-only, pivot HI→VI)
//
// Không cần Flutter GUI / thiết bị; chạy bằng `flutter test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/features/translation/engines/translation_engine.dart';
import 'package:in4up/features/translation/engines/mlkit_engine.dart';
import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/features/translation/glossary/glossary_store.dart';
import 'package:in4up/features/translation/glossary/protect_tokens.dart';
import 'package:in4up/features/translation/glossary/translation_glossary.dart';
import 'package:in4up/models/word_entry.dart';

/// Engine giả: ghi lại MỌI input nhận được + trả về text (hoặc transform).
/// Dùng để chứng minh thứ tự tầng: engine nhận text đã protect hay text trần.
class _RecordingEngine extends TranslationEngine {
  _RecordingEngine({this.transform});

  final String Function(String input)? transform;
  final List<String> inputs = <String>[];

  @override
  String get name => 'Fake Engine';

  @override
  String get id => 'fake';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    inputs.add(text);
    final out = transform?.call(text) ?? text;
    return TranslationResult.success(
      original: text,
      translated: out,
      engine: name,
      detectedLang: sourceLang,
      targetLang: targetLang,
    );
  }
}

GlossaryEntry _e(
  String source,
  String target, {
  String sourceLang = 'pi',
  String targetLang = 'vi',
  bool locked = true,
  int priority = 0,
  String domain = GlossaryDomain.buddhist,
}) {
  return GlossaryEntry(
    id: GlossaryEntry.makeId(source, sourceLang, targetLang),
    sourceNorm: source,
    sourceLang: sourceLang,
    targetLang: targetLang,
    targetText: target,
    locked: locked,
    domain: domain,
    priority: priority,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // TranslationCache dùng SharedPreferences — mock in-memory cho test.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('normalizeTerm', () {
    test('bỏ dấu Pali (ā → a) + lowercase', () {
      expect(normalizeTerm('nibbāna'), 'nibbana');
      expect(normalizeTerm('NIBBĀNA'), 'nibbana');
      expect(normalizeTerm('saṅgha'), 'sangha');
      expect(normalizeTerm('paṭiccasamuppāda'), 'paticcasamuppada');
    });

    test('bỏ dấu tiếng Việt', () {
      expect(normalizeTerm('chánh niệm'), 'chanh niem');
      expect(normalizeTerm('Pháp'), 'phap');
    });

    test('makeId ổn định giữa bản có dấu / không dấu', () {
      expect(
        GlossaryEntry.makeId('nibbāna', 'pi', 'vi'),
        GlossaryEntry.makeId('nibbana', 'pi', 'vi'),
      );
    });
  });

  group('GlossaryEntry.appliesTo', () {
    test('entry Pali khớp mọi ngôn ngữ nguồn Latin (EN, HI)', () {
      final entry = _e('sati', 'chánh niệm', sourceLang: 'pi');
      expect(entry.appliesTo(source: 'EN', target: 'VI'), isTrue);
      expect(entry.appliesTo(source: 'HI', target: 'VI'), isTrue);
      expect(entry.appliesTo(source: 'EN', target: 'HI'), isFalse);
    });

    test('entry EN không khớp khi nguồn là HI', () {
      final entry = _e('mindfulness', 'chánh niệm', sourceLang: 'en');
      expect(entry.appliesTo(source: 'EN', target: 'VI'), isTrue);
      expect(entry.appliesTo(source: 'HI', target: 'VI'), isFalse);
    });
  });

  group('longest-match + boundary', () {
    final glossary = Glossary(<GlossaryEntry>[
      _e('mindfulness', 'chánh niệm (mind)', sourceLang: 'en'),
      _e('right mindfulness', 'chánh niệm (right)', sourceLang: 'en'),
    ]);

    test('cụm dài thắng từ ngắn (right mindfulness vs mindfulness)', () {
      final protection = glossary.protect(
        'practice right mindfulness daily',
        source: 'en',
        target: 'vi',
      );
      expect(protection.protectedText, 'practice __G0__ daily');
      expect(protection.placeholderCount, 1);
      expect(protection.restore(protection.protectedText),
          'practice chánh niệm (right) daily');
    });

    test('từ đơn vẫn khớp khi không có cụm (mindfulness)', () {
      final protection = glossary.protect(
        'mindfulness practice',
        source: 'en',
        target: 'vi',
      );
      expect(protection.protectedText, '__G0__ practice');
      expect(protection.restore(protection.protectedText),
          'chánh niệm (mind) practice');
    });

    test('word boundary: sati KHÔNG khớp trong satisfaction', () {
      final g = Glossary(<GlossaryEntry>[_e('sati', 'chánh niệm')]);
      final protection = g.protect(
        'satisfaction is enough',
        source: 'en',
        target: 'vi',
      );
      expect(protection.changed, isFalse);
      expect(protection.protectedText, 'satisfaction is enough');
    });

    test('biến thể không dấu khớp entry có dấu (nibbana vs nibbāna)', () {
      final g = Glossary(<GlossaryEntry>[_e('nibbāna', 'Niết-bàn')]);
      final protection = g.protect(
        'the path to nibbana',
        source: 'en',
        target: 'vi',
      );
      expect(protection.protectedText, 'the path to __G0__');
      expect(protection.restore(protection.protectedText),
          'the path to Niết-bàn');
    });

    test('cùng độ dài: priority user thắng hạt giống', () {
      final g = Glossary(<GlossaryEntry>[
        _e('dhamma', 'Pháp (seed)'),
        _e(
          'dhamma',
          'Pháp (user)',
          domain: GlossaryDomain.user,
          priority: 100,
        ),
      ]);
      final protection = g.protect('dhamma', source: 'en', target: 'vi');
      expect(protection.restore(protection.protectedText), 'Pháp (user)');
    });

    test('startIndex: placeholder tiếp số (pivot nhiều bước)', () {
      final g = Glossary(<GlossaryEntry>[_e('sati', 'chánh niệm')]);
      final p1 = g.protect('sati', source: 'en', target: 'vi');
      final p2 = g.protect(
        'sati again',
        source: 'en',
        target: 'vi',
        startIndex: p1.placeholderCount,
      );
      expect(p2.protectedText, '__G1__ again');
    });
  });

  group('restore placeholder', () {
    test('restore đủ placeholder (3 thuật ngữ)', () {
      final g = Glossary(<GlossaryEntry>[
        _e('sati', 'chánh niệm'),
        _e('dhamma', 'Pháp'),
        _e('nibbāna', 'Niết-bàn'),
      ]);
      final protection = g.protect(
        'sati and dhamma lead to nibbāna',
        source: 'en',
        target: 'vi',
      );
      expect(protection.placeholderCount, 3);
      expect(protection.protectedText,
          '__G0__ and __G1__ lead to __G2__');
      // Giả engine dịch phần còn lại (đảo giữ nguyên placeholder).
      final engineOut = protection.protectedText.replaceAll('lead to', '→');
      expect(protection.restore(engineOut),
          'chánh niệm and Pháp → Niết-bàn');
    });

    test('restore best-effort khi engine lowercase placeholder', () {
      final g = Glossary(<GlossaryEntry>[
        _e('sati', 'chánh niệm'),
        _e('dhamma', 'Pháp'),
      ]);
      final protection = g.protect(
        'sati dhamma',
        source: 'en',
        target: 'vi',
      );
      final mangled = protection.protectedText.toLowerCase();
      expect(mangled, '__g0__ __g1__');
      expect(protection.restore(mangled), 'chánh niệm Pháp');
    });

    test('không hit → text trần, restore không đổi', () {
      final g = Glossary(<GlossaryEntry>[_e('sati', 'chánh niệm')]);
      final protection = g.protect(
        'hello world',
        source: 'en',
        target: 'vi',
      );
      expect(protection.changed, isFalse);
      expect(protection.restore('xin chào'), 'xin chào');
    });
  });

  group('luật khóa (resolveUpsert)', () {
    test('chưa có entry → nhận', () {
      final incoming = _e('sati', 'chánh niệm');
      expect(GlossaryStore.resolveUpsert(null, incoming), same(incoming));
    });

    test('entry khóa hạt giống bị user (priority cao hơn) thay', () {
      final seed = _e('sati', 'chánh niệm');
      final user = _e(
        'sati',
        'chánh niệm (user)',
        domain: GlossaryDomain.user,
        priority: 100,
      );
      expect(GlossaryStore.resolveUpsert(seed, user), same(user));
    });

    test('entry khóa KHÔNG bị đè bằng priority bằng/thấp hơn', () {
      final seed = _e('sati', 'chánh niệm');
      expect(
        GlossaryStore.resolveUpsert(seed, _e('sati', 'x')),
        isNull,
      );
      final lockedUser = _e(
        'sati',
        'chánh niệm (user)',
        domain: GlossaryDomain.user,
        priority: 100,
      );
      expect(
        GlossaryStore.resolveUpsert(
          lockedUser,
          _e(
            'sati',
            'khác',
            domain: GlossaryDomain.user,
            priority: 100,
          ),
        ),
        isNull,
      );
    });

    test('entry chưa khóa → thay tự do', () {
      final unlocked = _e('sati', 'chánh niệm', locked: false);
      expect(
        GlossaryStore.resolveUpsert(unlocked, _e('sati', 'mới')),
        isNotNull,
      );
    });
  });

  group('GlossarySync.fromWordEntry', () {
    WordEntry word({
      required String word,
      String meaning = '',
      String language = 'en',
      List<String>? topics,
    }) {
      return WordEntry(
        id: 'test_${word.replaceAll(RegExp(r'\W'), '_')}',
        word: word,
        meaning: meaning,
        language: language,
        topics: topics ?? const <String>[],
      );
    }

    test('Pali + meaning tiếng Việt → entry user, target vi', () {
      final entry =
          GlossarySync.fromWordEntry(word(word: 'sati', meaning: 'chánh niệm', language: 'pali'));
      expect(entry, isNotNull);
      expect(entry!.sourceLang, 'pi');
      expect(entry.targetLang, 'vi');
      expect(entry.targetText, 'chánh niệm');
      expect(entry.domain, GlossaryDomain.user);
      expect(entry.priority, 100);
      expect(entry.locked, isTrue);
    });

    test('Pali + meaning tiếng Anh → target en', () {
      final entry =
          GlossarySync.fromWordEntry(word(word: 'sati', meaning: 'mindfulness', language: 'pali'));
      expect(entry, isNotNull);
      expect(entry!.targetLang, 'en');
    });

    test('topic Phật học (không Pali) → vẫn đồng bộ', () {
      final entry = GlossarySync.fromWordEntry(
        word(
          word: 'middle way',
          meaning: 'trung đạo',
          topics: const <String>['Phật giáo'],
        ),
      );
      expect(entry, isNotNull);
    });

    test('topic không liên quan → bỏ qua', () {
      expect(
        GlossarySync.fromWordEntry(
          word(word: 'hello', meaning: 'xin chào', topics: const <String>['Toán']),
        ),
        isNull,
      );
    });

    test('meaning rỗng → bỏ qua', () {
      expect(
        GlossarySync.fromWordEntry(word(word: 'sati', language: 'pali')),
        isNull,
      );
    });
  });

  group('TranslationService pipeline (thứ tự tầng)', () {
    final glossary = Glossary(<GlossaryEntry>[
      _e('sati', 'chánh niệm'),
      _e('dhamma', 'Pháp'),
    ]);

    test('glossary BẬT: engine nhận text đã protect (placeholder)', () async {
      final fake = _RecordingEngine();
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[fake],
        glossary: glossary,
        networkAvailable: true,
      );
      const text = 'the teaching of sati and dhamma';
      final result = await service.translateText(
        text,
        sourceLang: 'en',
        targetLang: 'vi',
      );
      // Engine phải nhận placeholder, KHÔNG nhận 'sati'/'dhamma'.
      expect(fake.inputs, hasLength(1));
      expect(fake.inputs.first, isNot(contains('sati')));
      expect(fake.inputs.first, isNot(contains('dhamma')));
      expect(fake.inputs.first, contains('__G0__'));
      expect(fake.inputs.first, contains('__G1__'));
      // Output restore đúng nghĩa khóa.
      expect(result.isSuccess, isTrue);
      expect(result.translatedText,
          'the teaching of chánh niệm and Pháp');
    });

    test('glossary TẮT: engine nhận text trần (chứng minh thứ tự tầng)',
        () async {
      final fake = _RecordingEngine();
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[fake],
        glossary: glossary,
        networkAvailable: true,
      )..glossaryEnabled = false;
      const text = 'the teaching of sati and dhamma again';
      await service.translateText(
        text,
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(fake.inputs, hasLength(1));
      expect(fake.inputs.first, text);
    });

    test('offline, không mạng, EN→VI: glossary + từ điển (last resort)',
        () async {
      final service = TranslationService.forTest(
        onlineEngines: const <TranslationEngine>[],
        glossary: glossary,
        networkAvailable: false,
      );
      final result = await service.translateText(
        'sati and dhamma',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(result.isSuccess, isTrue);
      expect(result.translatedText, contains('chánh niệm'));
      expect(result.translatedText, contains('Pháp'));
      expect(result.translatedText, isNot(contains('sati')));
      expect(result.engineName, isNot('skip'));
    });

    test('offline-only: engine online không được gọi dù có mạng', () async {
      final fake = _RecordingEngine();
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[fake],
        glossary: glossary,
        networkAvailable: true,
      )..offlineOnly = true;
      await service.translateText(
        'sati practice offline',
        sourceLang: 'en',
        targetLang: 'vi',
      );
      expect(fake.inputs, isEmpty);
    });

    test(
        'pivot HI→VI: 2 bước qua EN, glossary bảo vệ ở bước EN→VI',
        () async {
      // ML Kit giả: bước 1 (HI→EN) giữ 'sati', bước 2 (EN→VI) pass-through.
      final mlkitFake = _RecordingEngine(transform: (input) {
        if (input.contains('sati') && !input.contains('__G')) {
          return 'sati is here'; // HI → EN
        }
        return input; // EN → VI (text đã protect)
      });
      final service = TranslationService.forTest(
        onlineEngines: const <TranslationEngine>[],
        mlkitEngine: mlkitFake,
        glossary: glossary,
        networkAvailable: true,
      );
      final result = await service.translateText(
        'sati hai',
        sourceLang: 'hi',
        targetLang: 'vi',
      );
      expect(mlkitFake.inputs, hasLength(2));
      // Bước 1: text HI trần (không có entry HI→* trong glossary test).
      expect(mlkitFake.inputs.first, 'sati hai');
      // Bước 2: 'sati' (EN context) đã bị protect thành placeholder.
      expect(mlkitFake.inputs[1], isNot(contains('sati')));
      expect(mlkitFake.inputs[1], contains('__G0__'));
      expect(result.translatedText, 'chánh niệm is here');
    });
  });

  group('MlKitEngine desktop', () {
    test('isAvailable false + failure rõ (không crash import)', () async {
      // CI/test chạy trên Linux/macOS/Windows → không Android/iOS.
      // (Trên Android device test này sẽ khác — chấp nhận: mục tiêu là
      // desktop build không sập.)
      final engine = MlKitEngine();
      if (MlKitEngine.platformSupported) return; // skip trên Android/iOS
      expect(await engine.isAvailable(), isFalse);
      final result = await engine.translate(
        text: 'hello',
        targetLang: 'vi',
        sourceLang: 'en',
      );
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('ML Kit'));
    });

    test('languageForCode map mã app → TranslateLanguage', () {
      expect(MlKitEngine.languageForCode('EN'), isNotNull);
      expect(MlKitEngine.languageForCode('vi'), isNotNull);
      expect(MlKitEngine.languageForCode('HI'), isNotNull);
      expect(MlKitEngine.languageForCode('BO'), isNull);
      expect(MlKitEngine.languageForCode('ZH-TW'), isNull);
      expect(MlKitEngine.supportsTranslationCode('en'), isTrue);
      expect(MlKitEngine.supportsTranslationCode('lo'), isFalse);
    });
  });

  group('XLAT-002: da ngu (zh/zh-tw/si/my + CJK boundary)', () {
    GlossaryEntry e2(
      String source,
      String target, {
      String sourceLang = 'pi',
      String targetLang = 'vi',
    }) {
      return GlossaryEntry(
        id: GlossaryEntry.makeId(source, sourceLang, targetLang),
        sourceNorm: source,
        sourceLang: sourceLang,
        targetLang: targetLang,
        targetText: target,
      );
    }

    test('GlossaryLang.normalize: zh/zh-tw/si/my + alias', () {
      expect(GlossaryLang.normalize('zh'), 'zh');
      expect(GlossaryLang.normalize('ZH'), 'zh');
      expect(GlossaryLang.normalize('zh-tw'), 'zh-tw');
      expect(GlossaryLang.normalize('zh_hant'), 'zh-tw');
      expect(GlossaryLang.normalize('si'), 'si');
      expect(GlossaryLang.normalize('sinhala'), 'si');
      expect(GlossaryLang.normalize('my'), 'my');
      expect(GlossaryLang.normalize('burmese'), 'my');
      expect(GlossaryLang.normalize('pali'), 'pi');
    });

    test('CJK: term "正念" khop trong "正念禅修" (khong co khoang trang)', () {
      final g = Glossary(<GlossaryEntry>[e2('正念', 'chánh niệm', sourceLang: 'zh')]);
      final p = g.protect('正念禅修', source: 'zh', target: 'vi');
      expect(p.placeholderCount, 1);
      expect(p.protectedText, '__G0__禅修');
      expect(p.restore(p.protectedText), 'chánh niệm禅修');
    });

    test('CJK longest-match: "正念禅修" dau, "正念" sau', () {
      final g = Glossary(<GlossaryEntry>[
        e2('正念', 'chánh niệm', sourceLang: 'zh'),
        e2('正念禅修', 'thiền chánh niệm', sourceLang: 'zh'),
      ]);
      final p = g.protect('正念禅修法', source: 'zh', target: 'vi');
      expect(p.placeholderCount, 1);
      expect(p.restore(p.protectedText), 'thiền chánh niệm法');
    });

    test('zh-tw (phan) va zh (gian) la 2 term rieng', () {
      expect(
        GlossaryEntry.makeId('禪修', 'zh-tw', 'vi'),
        isNot(GlossaryEntry.makeId('禅修', 'zh', 'vi')),
      );
      final g = Glossary(<GlossaryEntry>[
        e2('禪修', 'thiền tu', sourceLang: 'zh-tw'),
        e2('禅修', 'thiền tu (gian)', sourceLang: 'zh'),
      ]);
      final pTw = g.protect('禪修', source: 'zh-tw', target: 'vi');
      final pS = g.protect('禅修', source: 'zh', target: 'vi');
      // term phan chi khop khi source = zh-tw (va nguoc lai voi gian)
      expect(pTw.restore(pTw.protectedText), 'thiền tu');
      expect(pS.restore(pS.protectedText), 'thiền tu (gian)');
    });

    test('pi nhung trong cau CJK: "sati" giua han tu van khop', () {
      final g = Glossary(<GlossaryEntry>[_e('sati', 'chánh niệm')]);
      final p = g.protect('正念sati修行', source: 'zh', target: 'vi');
      expect(p.placeholderCount, 1);
      expect(p.restore(p.protectedText), '正念chánh niệm修行');
    });

    test('Burmese: term "သတိ" → vi (khong boundary ASCII)', () {
      final g = Glossary(<GlossaryEntry>[e2('သတိ', 'chánh niệm', sourceLang: 'my')]);
      final p = g.protect('သတိ ပဋ္ဌာန', source: 'my', target: 'vi');
      expect(p.placeholderCount, 1);
      expect(p.restore(p.protectedText), 'chánh niệm ပဋ္ဌာန');
    });

    test('regression: Latin boundary van chan ("sati" trong "satisfaction")',
        () {
      final g = Glossary(<GlossaryEntry>[_e('sati', 'chánh niệm')]);
      final p = g.protect('satisfaction', source: 'en', target: 'vi');
      expect(p.changed, isFalse);
    });

    test('pipeline EN→ZH: term en khop, CJK target khong bi break', () async {
      final fake = _RecordingEngine();
      final service = TranslationService.forTest(
        onlineEngines: <TranslationEngine>[fake],
        glossary: Glossary(<GlossaryEntry>[
          _e('mindfulness', '正念', sourceLang: 'en', targetLang: 'zh'),
        ]),
        networkAvailable: true,
      );
      final result = await service.translateText(
        'mindfulness practice',
        sourceLang: 'en',
        targetLang: 'zh',
      );
      expect(fake.inputs, hasLength(1));
      expect(fake.inputs.first, contains('__G0__'));
      expect(fake.inputs.first, isNot(contains('mindfulness')));
      expect(result.translatedText, contains('正念'));
    });
  });
}
