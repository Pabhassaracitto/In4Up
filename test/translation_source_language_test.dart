// test/translation_source_language_test.dart
//
// XLAT-MLKIT-001 — regression test cho nguồn dịch explicit vs AUTO:
// - Nguồn EXPLICIT (đã gắn): mọi dòng dịch đúng cặp đã chọn, KHÔNG gọi
//   LanguageDetector từng dòng, KHÔNG retry bằng ngôn ngữ khác.
// - AUTO: vẫn re-detect từng dòng (tài liệu hỗn hợp ngôn ngữ); dòng ngắn
//   bị detector nhầm (vd EN → 'DE') mà model của ngôn ngữ vừa nhận diện
//   chưa tải → retry ĐÚNG 1 lần với nguồn tài liệu, không còn lỗi
//   "Chưa tải gói dịch german" trên tài liệu Anh.
// - AUTO với văn Đức thật: vẫn báo thiếu gói German đúng cặp DE → VI, có
//   chú thích "nguồn tự nhận diện".
// - Lỗi ML Kit nêu đúng cặp source→target + tên native từ catalog.
//
// Không cần thiết bị / ML Kit thật: engine giả qua TranslationService.forTest.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:in4up/features/translation/engines/mlkit_engine.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';
import 'package:in4up/features/translation/text_provider_translation.dart';
import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/features/tts/language_detector.dart';
import 'package:in4up/models/text_item.dart';

/// Host tối giản cho mixin — không kéo TextProvider (Hive/storage).
class _TestDocument extends ChangeNotifier with TranslationMixin {
  @override
  final List<TextItem> lines = <TextItem>[];
}

/// ML Kit giả: mô phỏng máy owner (đã tải en+vi, chưa tải de). Lỗi thiếu
/// model dùng đúng message của engine thật để test cả chuỗi attribution.
class _ScriptedMlKitEngine extends TranslationEngine {
  _ScriptedMlKitEngine({this.missingModelSources = const <String>{}});

  /// Translation code mà "model chưa tải" (vd {'DE'}).
  final Set<String> missingModelSources;
  final List<String> requestedSources = <String>[];

  @override
  String get name => 'ML Kit On-Device';

  @override
  String get id => 'mlkit';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    final source = sourceLang.trim().toUpperCase();
    final target = targetLang.trim().toUpperCase();
    requestedSources.add(source);
    final language = MlKitEngine.languageForCode(source);
    if (missingModelSources.contains(source) && language != null) {
      return TranslationResult.failure(
        original: text,
        error: MlKitEngine.missingModelError(
          sourceCode: source,
          targetCode: target,
          missing: <TranslateLanguage>[language],
        ),
        engine: name,
        detectedLang: source,
        targetLang: target,
        missingModelCodes: <String>[source],
      );
    }
    return TranslationResult.success(
      original: text,
      translated: '[$source→$target] $text',
      engine: name,
      detectedLang: source,
      targetLang: target,
    );
  }
}

/// Từ điển offline giả: luôn fail (như OfflineEngine với cặp không phải
/// EN→VI) để lỗi ML Kit được trả về caller.
class _FailingDictionaryEngine extends TranslationEngine {
  @override
  String get name => 'Từ điển offline';

  @override
  String get id => 'dict';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    return TranslationResult.failure(
      original: text,
      error: 'Không có trong từ điển',
      engine: name,
      detectedLang: sourceLang.toUpperCase(),
      targetLang: targetLang.toUpperCase(),
    );
  }
}

_TestDocument _hostWith(_ScriptedMlKitEngine mlkit) {
  return _TestDocument()
    ..translationServiceForTest = TranslationService.forTest(
      offlineEngine: _FailingDictionaryEngine(),
      mlkitEngine: mlkit,
      networkAvailable: false,
    );
}

/// Tài liệu Anh (như repro owner) trộn 1 dòng ngắn bị detector ghi DE.
List<TextItem> _englishDocWithShortLine() {
  return <TextItem>[
    TextItem(id: '1', content: 'The quick brown fox jumps over the lazy dog.'),
    TextItem(id: '2', content: 'So ist das Leben.'),
    TextItem(id: '3', content: 'This is a test of the system and the flags.'),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // TranslationCache là singleton (memory LRU) — xoá giữa các test.
    await TranslationCache().clear();
  });

  group('AUTO mode (mặc định)', () {
    test(
        'dòng ngắn bị nhận diện nhầm DE không còn lỗi german — retry 1 lần với nguồn tài liệu',
        () async {
      // Guard: dòng này THẬT SỰ bị detector ghi DE, tài liệu ghi EN.
      expect(
        LanguageDetector.detectLanguage('So ist das Leben.').translationCode,
        'DE',
      );
      final mlkit = _ScriptedMlKitEngine(missingModelSources: <String>{'DE'});
      final host = _hostWith(mlkit)
        ..lines.addAll(_englishDocWithShortLine());
      expect(host.detectedSourceLanguage.translationCode, 'EN');
      expect(host.translationSourceIsPinned, isFalse);

      await host.translateAll();

      expect(host.translationError, isNull, reason: 'không còn lỗi "german"');
      // Dòng bị nhầm DE được retry bằng nguồn tài liệu EN.
      expect(host.lines[1].translation, contains('[EN→VI]'));
      expect(host.lines[1].sourceLanguageCode, 'EN');
      // Dòng thường vẫn dịch bình thường.
      expect(host.lines[0].translation, contains('[EN→VI]'));
      // Đúng 1 lần DE (lần đầu sai), sau đó không lặp.
      expect(mlkit.requestedSources.where((s) => s == 'DE').length, 1);
    });

    test('translateLine: call site đơn dòng cũng retry với nguồn tài liệu',
        () async {
      final mlkit = _ScriptedMlKitEngine(missingModelSources: <String>{'DE'});
      final host = _hostWith(mlkit)
        ..lines.addAll(_englishDocWithShortLine());

      await host.translateLine(1);

      expect(host.translationError, isNull);
      expect(host.lines[1].translation, contains('[EN→VI]'));
      expect(mlkit.requestedSources, <String>['DE', 'EN']);
    });

    test('văn Đức thật vẫn báo thiếu gói German đúng cặp, không retry EN',
        () async {
      final mlkit = _ScriptedMlKitEngine(missingModelSources: <String>{'DE'});
      final host = _hostWith(mlkit)
        ..lines.addAll(<TextItem>[
          TextItem(id: '1', content: 'So ist das Leben.'),
          TextItem(id: '2', content: 'Der Hund ist nicht gross.'),
        ]);
      expect(host.detectedSourceLanguage.translationCode, 'DE');

      await host.translateAll();

      // Lỗi nêu đúng cặp thật + tên native + chú thích auto-detect.
      expect(host.translationError, isNotNull);
      expect(host.translationError, contains('Cặp DE → VI'));
      expect(host.translationError, contains('Deutsch'));
      expect(host.translationError, contains('nguồn tự nhận diện'));
      // Không âm thầm đổi nguồn: mọi request đều DE.
      expect(mlkit.requestedSources.toSet(), <String>{'DE'});
    });

    test('đủ model: dòng Đức trong tài liệu Anh vẫn dịch đúng DE (mixed doc)',
        () async {
      final mlkit = _ScriptedMlKitEngine();
      final host = _hostWith(mlkit)
        ..lines.addAll(_englishDocWithShortLine());

      await host.translateAll();

      expect(mlkit.requestedSources, contains('DE'));
      expect(host.lines[1].sourceLanguageCode, 'DE');
      expect(host.lines[1].translation, contains('[DE→VI]'));
      expect(host.lines[0].sourceLanguageCode, 'EN');
      expect(host.translationError, isNull);
    });
  });

  group('Explicit source (đã gắn nguồn)', () {
    test('mọi dòng dùng nguồn đã chọn, không gọi detector từng dòng',
        () async {
      final mlkit = _ScriptedMlKitEngine(missingModelSources: <String>{'DE'});
      final host = _hostWith(mlkit)
        ..lines.addAll(_englishDocWithShortLine());

      expect(await host.setTranslationSourceLanguage('EN'), isTrue);
      expect(host.translationSourceIsPinned, isTrue);
      expect(host.translationSourceLanguage.translationCode, 'EN');

      await host.translateAll();

      // Không bao giờ request DE — kể cả dòng "So ist das Leben.".
      expect(mlkit.requestedSources.toSet(), <String>{'EN'});
      expect(host.lines[1].translation, contains('[EN→VI]'));
      expect(host.lines[1].sourceLanguageCode, 'EN');
      expect(host.translationError, isNull);
    });

    test('translateLine: nguồn explicit không detect lại từng dòng', () async {
      final mlkit = _ScriptedMlKitEngine(missingModelSources: <String>{'DE'});
      final host = _hostWith(mlkit)
        ..lines.addAll(_englishDocWithShortLine());

      await host.setTranslationSourceLanguage('EN', retranslateExisting: false);
      await host.translateLine(1);

      expect(mlkit.requestedSources, <String>['EN']);
      expect(host.lines[1].translation, contains('[EN→VI]'));
    });

    test('thiếu model của chính cặp đã chọn: lỗi nêu đúng cặp, không retry',
        () async {
      final mlkit = _ScriptedMlKitEngine(missingModelSources: <String>{'EN'});
      final host = _hostWith(mlkit)
        ..lines.addAll(<TextItem>[
          TextItem(id: '1', content: 'The quick brown fox jumps over the lazy dog.'),
        ]);

      await host.setTranslationSourceLanguage('EN');
      await host.translateAll();

      expect(host.translationError, contains('Cặp EN → VI'));
      expect(host.translationError, contains('cặp nguồn đã chọn'));
      // Không retry bằng ngôn ngữ khác khi user đã chọn explicit.
      expect(mlkit.requestedSources.toSet(), <String>{'EN'});
    });
  });

  group('setTranslationSourceLanguage API', () {
    test('validate code, AUTO reset, cùng ngôn ngữ chặn dịch', () async {
      final host = _hostWith(_ScriptedMlKitEngine());

      expect(await host.setTranslationSourceLanguage('XX'), isFalse);
      expect(await host.setTranslationSourceLanguage(' EN '), isTrue);
      expect(host.translationSourceIsPinned, isTrue);
      expect(await host.setTranslationSourceLanguage('EN'), isFalse); // không đổi
      expect(await host.setTranslationSourceLanguage('AUTO'), isTrue);
      expect(host.translationSourceIsPinned, isFalse);
      expect(host.translationSourceLanguage.translationCode, 'EN'); // quay lại detect

      // Gắn VI khi đích VI → chặn dịch như luật nguồn==đích sẵn có.
      host.lines.add(
        TextItem(id: '1', content: 'Xin chào, tôi là người Việt Nam.'),
      );
      await host.setTranslationSourceLanguage('VI');
      await host.translateAll();
      expect(host.translationError, contains('đã là ngôn ngữ đích'));
    });

    test('resetTranslationForNewDocument bỏ gắn nguồn của tài liệu cũ',
        () async {
      final host = _hostWith(_ScriptedMlKitEngine());

      await host.setTranslationSourceLanguage('DE');
      expect(host.translationSourceIsPinned, isTrue);

      host.resetTranslationForNewDocument();
      expect(host.translationSourceIsPinned, isFalse);
    });
  });

  group('MlKitEngine message', () {
    test('lỗi thiếu model nêu đúng cặp + tên native từ catalog', () {
      final german = MlKitEngine.languageForCode('DE');
      expect(german, isNotNull);
      final error = MlKitEngine.missingModelError(
        sourceCode: 'DE',
        targetCode: 'VI',
        missing: <TranslateLanguage>[german!],
      );
      expect(error, contains('Cặp DE → VI'));
      expect(error, contains('Deutsch'));
      expect(error, contains('Cài đặt engine dịch'));
      expect(
        MlKitEngine.missingModelCodesOf(<TranslateLanguage>[german]),
        <String>['DE'],
      );
    });

    test('ngôn ngữ ngoài catalog vẫn ra code uppercase', () {
      final welsh = MlKitEngine.languageForCode('CY');
      expect(welsh, isNotNull);
      expect(
        MlKitEngine.missingModelCodesOf(<TranslateLanguage>[welsh!]),
        <String>['CY'],
      );
      expect(
        MlKitEngine.missingModelError(
          sourceCode: 'CY',
          targetCode: 'VI',
          missing: <TranslateLanguage>[welsh],
        ),
        contains('Cặp CY → VI'),
      );
    });
  });
}
