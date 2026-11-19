// test/read_mode/psrc_238_source_language_test.dart
//
// PSRC-238 / ADR-0031 (bước 3b) — chọn ngôn ngữ nguồn + tự tránh cặp trùng.
//
// Triệu chứng: ngôn ngữ nguồn do app tự nhận diện; nhận diện sai thì người
// dùng không sửa được. `setTranslationSourceLanguage` đã có nhưng không có
// giao diện gọi tới và lựa chọn không được lưu. Nguồn trùng đích thì bấm
// «Dịch» chỉ ra một dòng lỗi đỏ.
//
// Máy bắt bốn lớp:
//   1. hàm thuần `translation_source_choice.dart` — đề nghị đích KHÔNG BAO
//      GIỜ trùng nguồn; giá trị lưu hỏng bị coi là «Tự nhận diện»;
//   2. `TranslationMixin` — lưu / khôi phục theo tài liệu, không kéo nguồn
//      sang tài liệu khác, không phá «Đổi vai» (PSRC-237), đổi cặp chỉ dịch
//      lại MỘT lượt, cặp trùng thành lời đề nghị;
//   3. bảng chọn ngôn ngữ (widget) — chọn nguồn, nguồn trùng đích thì bảng ở
//      lại và đề nghị đích khác, 320 px không tràn;
//   4. ghim nguồn cho phần nối dây + gói ngôn ngữ (quy tắc vàng #5).
//
// Không cần thiết bị / engine thật: `TranslationService.forTest`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/core/language/app_language.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';
import 'package:in4up/features/translation/line_role_swap.dart';
import 'package:in4up/features/translation/text_provider_translation.dart';
import 'package:in4up/features/translation/translation_language_picker.dart';
import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/features/translation/translation_source_choice.dart';
import 'package:in4up/models/text_item.dart';

String _src(String path) => File(path).readAsStringSync();

/// Bỏ dòng chú thích `//` để pin chỉ soi CODE.
String _code(String path) => _src(path)
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Engine ghi lại CẶP ngôn ngữ của từng lần được gọi.
///
/// «Bản dịch» trả về là `NGUỒN>ĐÍCH#<độ dài>` chứ không lặp lại văn bản gốc:
/// `TranslationService` loại kết quả trông như chưa dịch (vẫn là ngôn ngữ
/// nguồn) — một engine giả chỉ thêm tiền tố sẽ bị loại oan.
class _RecordingEngine extends TranslationEngine {
  final List<String> pairs = <String>[];

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
    final source = sourceLang.toUpperCase();
    final target = targetLang.toUpperCase();
    pairs.add('$source>$target');
    return TranslationResult.success(
      original: text,
      translated: '$source>$target#${text.length}',
      engine: name,
      detectedLang: source,
      targetLang: target,
    );
  }
}

class _MemoryStore implements RoleSwapMarkerStore {
  final Map<String, String> values = <String, String>{};

  @override
  String? read(String documentKey) => values[documentKey];

  @override
  void write(String documentKey, String value) => values[documentKey] = value;

  @override
  void remove(String documentKey) => values.remove(documentKey);
}

/// Host tối giản cho mixin — không kéo TextProvider (Hive/storage).
class _Doc extends ChangeNotifier with TranslationMixin {
  @override
  final List<TextItem> lines = <TextItem>[];

  String? documentKey;

  @override
  String? get roleSwapDocumentKey => documentKey;

  /// Như `TextProvider.updateFullText` / `toggleAutoSplit`: dựng lại dòng của
  /// CÙNG tài liệu (bước dựng lại gọi `resetTranslationForNewDocument`).
  void reparseSameDocument() =>
      reparseKeepingTranslationSource(resetTranslationForNewDocument);

  void clearSwapStateForTest() => clearRoleSwapState();
}

const String _keyA = 'file:/sdcard/bai-a.txt';
const String _keyB = 'cloud:doc-b';

class _Ctx {
  _Ctx(this.doc, this.sources, this.markers, this.engine);

  final _Doc doc;
  final _MemoryStore sources;
  final _MemoryStore markers;
  final _RecordingEngine engine;
}

_Ctx _newDoc({
  String? documentKey = _keyA,
  _MemoryStore? sources,
  _MemoryStore? markers,
}) {
  final engine = _RecordingEngine();
  final sourceStore = sources ?? _MemoryStore();
  final markerStore = markers ?? _MemoryStore();
  final doc = _Doc()
    ..translationServiceForTest = TranslationService.forTest(
      mlkitEngine: engine,
      offlineEngine: engine,
      networkAvailable: false,
    )
    ..translationSourceStoreForTest = sourceStore
    ..roleSwapMarkerStoreForTest = markerStore
    ..documentKey = documentKey;
  return _Ctx(doc, sourceStore, markerStore, engine);
}

/// Hai câu bị bộ nhận diện ghi là tiếng Đức (ca «nhận diện sai» của issue).
List<TextItem> _germanLookingLines() => <TextItem>[
      TextItem(id: '1', content: 'So ist das Leben.'),
      TextItem(id: '2', content: 'Der Hund ist nicht gross.'),
    ];

/// Tiếng Việt có dấu — không mẩu nào bị coi là ngoại ngữ.
List<TextItem> _vietnameseLines() => <TextItem>[
      TextItem(
        id: '1',
        content: 'Hôm nay trời rất đẹp. Tôi đi học bài ở thư viện.',
      ),
      TextItem(
        id: '2',
        content: 'Tôi đi học bài mới. Hôm nay cô giáo dạy rất kỹ.',
      ),
    ];

/// Tiếng Việt đã dịch sang tiếng Anh (nguồn do người dùng chọn = VI).
Future<_Ctx> _vietnameseTranslatedToEnglish({
  _MemoryStore? sources,
  _MemoryStore? markers,
  bool pickSource = true,
}) async {
  final ctx = _newDoc(sources: sources, markers: markers);
  ctx.doc.restoreTranslationTargetLanguage('EN');
  if (pickSource) {
    await ctx.doc.setTranslationSourceLanguage('VI', retranslateExisting: false);
  }
  ctx.doc.lines.addAll(<TextItem>[
    TextItem(
      id: '1',
      content: 'Hôm nay trời rất đẹp.',
      translation: 'The weather is very nice today.',
      sourceLanguageCode: 'VI',
      translationLanguageCode: 'EN',
    ),
    TextItem(
      id: '2',
      content: 'Tôi đi học bài ở thư viện.',
      translation: 'I study at the library.',
      sourceLanguageCode: 'VI',
      translationLanguageCode: 'EN',
    ),
  ]);
  return ctx;
}

Future<void> _waitUntilIdle(_Doc doc) async {
  for (var i = 0; i < 200 && doc.isTranslating; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  expect(doc.isTranslating, isFalse, reason: 'lượt dịch phải kết thúc');
}

/// Nút mở bảng chọn cặp; kết quả (kể cả `null` khi đóng) được ghi vào [out].
Widget _pickerHost({
  required String detected,
  required String target,
  required List<TranslationPairChoice?> out,
  String? pinned,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const Key('open-picker'),
              onPressed: () async {
                out.add(
                  await showTranslationPairPicker(
                    context,
                    detectedSource: AppLanguageCatalog.fromCode(detected),
                    pinnedSourceCode: pinned,
                    currentTarget: AppLanguageCatalog.fromCode(target),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

Future<void> _openPicker(
  WidgetTester tester, {
  Size size = const Size(400, 1600),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-picker')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TranslationCache().clear();
  });

  group('PSRC-238 hàm thuần — đề nghị đích, giá trị lưu', () {
    AppLanguage lang(String code) => AppLanguageCatalog.fromCode(code);

    test('đích được đề nghị KHÔNG BAO GIỜ trùng nguồn (mọi nguồn × mọi '
        'ngôn ngữ giao diện)', () {
      for (final source in AppLanguageCatalog.languages) {
        for (final ui in <String?>[
          null,
          '',
          'rác',
          ...AppLanguageCatalog.languages.map((l) => l.languageTag),
        ]) {
          final suggestion = suggestTargetAvoidingSource(
            source: source,
            uiLanguageCode: ui,
            previousSource: source,
          );
          expect(
            suggestion.translationCode,
            isNot(source.translationCode),
            reason: 'nguồn ${source.translationCode}, giao diện $ui',
          );
        }
      }
    });

    test('ưu tiên: ngôn ngữ giao diện → nguồn trước đó → Anh → Việt', () {
      // Giao diện tiếng Thái, văn bản tiếng Việt ⇒ đọc nghĩa bằng tiếng Thái.
      expect(
        suggestTargetAvoidingSource(source: lang('VI'), uiLanguageCode: 'th')
            .translationCode,
        'TH',
      );
      // Giao diện trùng nguồn ⇒ bỏ qua, lấy nguồn trước đó.
      expect(
        suggestTargetAvoidingSource(
          source: lang('VI'),
          uiLanguageCode: 'vi',
          previousSource: lang('JA'),
        ).translationCode,
        'JA',
      );
      // Không có gì khác ⇒ tiếng Anh; nguồn là tiếng Anh ⇒ tiếng Việt.
      expect(
        suggestTargetAvoidingSource(source: lang('VI'), uiLanguageCode: 'vi')
            .translationCode,
        'EN',
      );
      expect(
        suggestTargetAvoidingSource(source: lang('EN'), uiLanguageCode: 'en-US')
            .translationCode,
        'VI',
      );
      expect(suggestTargetAvoidingSource(source: lang('EN')).translationCode,
          'VI');
      // Thẻ locale kiểu Flutter cho tiếng Trung phồn thể.
      expect(
        suggestTargetAvoidingSource(
          source: lang('EN'),
          uiLanguageCode: 'zh-TW',
        ).translationCode,
        'ZH-TW',
      );
    });

    test('giá trị lưu: mã hợp lệ được chuẩn hoá, còn lại = «Tự nhận diện»',
        () {
      expect(decodeSavedTranslationSource('EN'), 'EN');
      expect(decodeSavedTranslationSource(' en '), 'EN');
      expect(decodeSavedTranslationSource('zh-TW'), 'ZH-TW');
      expect(decodeSavedTranslationSource(null), isNull);
      expect(decodeSavedTranslationSource(''), isNull);
      expect(decodeSavedTranslationSource('AUTO'), isNull);
      expect(decodeSavedTranslationSource('rác'), isNull);
      expect(decodeSavedTranslationSource('EN>VI>2'), isNull,
          reason: 'dấu «Đổi vai» lọt vào nhầm chỗ cũng không được nhận');
    });

    test('khoá lưu: ASCII, ngắn, ổn định, KHÁC khoá của «Đổi vai»', () {
      const path = 'file:/sdcard/Tài liệu/bài đọc số 1 — bản nháp.txt';
      final key = translationSourceStorageKey(path);
      expect(key, translationSourceStorageKey(path));
      expect(key, isNot(translationSourceStorageKey('$path ')));
      expect(key, isNot(roleSwapStorageKey(path)));
      expect(key.length, lessThanOrEqualTo(255));
      expect(key.codeUnits.every((unit) => unit < 128), isTrue);
    });
  });

  group('PSRC-238 chọn nguồn — nhận diện sai thì sửa được', () {
    test('văn bản bị nhận diện là tiếng Đức: chọn lại nguồn ⇒ dịch đúng cặp',
        () async {
      final ctx = _newDoc()..doc.lines.addAll(_germanLookingLines());
      expect(ctx.doc.detectedSourceLanguage.translationCode, 'DE',
          reason: 'guard: đây đúng là ca nhận diện sai');
      expect(ctx.doc.translationSourceIsPinned, isFalse);

      expect(await ctx.doc.setTranslationSourceLanguage('EN'), isTrue);
      await ctx.doc.translateAll();

      expect(ctx.doc.translationSourceIsPinned, isTrue);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'EN');
      expect(ctx.engine.pairs.toSet(), <String>{'EN>VI'},
          reason: 'mọi dòng dùng đúng nguồn đã chọn');
      expect(ctx.doc.lines[0].translation, startsWith('EN>VI#'));
      expect(ctx.doc.lines[1].translation, startsWith('EN>VI#'));
      expect(ctx.doc.translationError, isNull);
      // `detectedSourceLanguage` giữ nguyên nghĩa: kết quả nhận diện thô.
      expect(ctx.doc.detectedSourceLanguage.translationCode, 'DE');
    });

    test('«Tự nhận diện» đưa về kết quả nhận diện', () async {
      final ctx = _newDoc()..doc.lines.addAll(_germanLookingLines());
      await ctx.doc.setTranslationSourceLanguage('EN');

      expect(
        await ctx.doc.setTranslationSourceLanguage(kTranslationSourceAuto),
        isTrue,
      );

      expect(ctx.doc.translationSourceIsPinned, isFalse);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'DE');
    });
  });

  group('PSRC-238 lưu theo tài liệu', () {
    test('chọn nguồn ⇒ lưu dưới khoá tài liệu; «Tự nhận diện» ⇒ xoá', () async {
      final ctx = _newDoc()..doc.lines.addAll(_germanLookingLines());

      await ctx.doc.setTranslationSourceLanguage('en');
      expect(ctx.sources.values, <String, String>{_keyA: 'EN'});

      await ctx.doc.setTranslationSourceLanguage('JA');
      expect(ctx.sources.values, <String, String>{_keyA: 'JA'});

      await ctx.doc.setTranslationSourceLanguage(kTranslationSourceAuto);
      expect(ctx.sources.values, isEmpty);

      // Mã lạ: không đổi gì, không ghi gì.
      expect(await ctx.doc.setTranslationSourceLanguage('XX'), isFalse);
      expect(ctx.sources.values, isEmpty);
      expect(ctx.markers.values, isEmpty,
          reason: 'không ghi nhầm sang chỗ lưu dấu «Đổi vai»');
    });

    test('mở lại tài liệu: nguồn còn nguyên, bản dịch KHÔNG bị xoá, '
        'không gọi engine', () async {
      final first = await _vietnameseTranslatedToEnglish();
      expect(first.sources.values[_keyA], 'VI');

      // «Mở lại»: phiên mới, cùng chỗ lưu, chưa gắn nguồn.
      final reopened = await _vietnameseTranslatedToEnglish(
        sources: first.sources,
        pickSource: false,
      );
      expect(reopened.doc.translationSourceIsPinned, isFalse);

      expect(reopened.doc.restoreSavedTranslationSource(), isTrue);

      expect(reopened.doc.translationSourceIsPinned, isTrue);
      expect(reopened.doc.translationSourceLanguage.translationCode, 'VI');
      expect(reopened.doc.lines[0].translation,
          'The weather is very nice today.');
      expect(reopened.doc.lines[1].translation, 'I study at the library.');
      expect(reopened.engine.pairs, isEmpty);
      // Gọi lại lần nữa: không còn gì để đổi.
      expect(reopened.doc.restoreSavedTranslationSource(), isFalse);
    });

    test('mở tài liệu KHÁC: nguồn của tài liệu trước không được kéo sang',
        () async {
      final ctx = _newDoc()..doc.lines.addAll(_germanLookingLines());
      await ctx.doc.setTranslationSourceLanguage('EN');

      // Tài liệu B chưa từng chọn nguồn.
      ctx.doc.documentKey = _keyB;
      expect(ctx.doc.restoreSavedTranslationSource(), isTrue);
      expect(ctx.doc.translationSourceIsPinned, isFalse);

      // Quay lại A: lựa chọn của A còn nguyên.
      ctx.doc.documentKey = _keyA;
      expect(ctx.doc.restoreSavedTranslationSource(), isTrue);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'EN');

      // Văn bản dán tay (không có khoá lưu) cũng về «Tự nhận diện».
      ctx.doc.documentKey = null;
      expect(ctx.doc.restoreSavedTranslationSource(), isTrue);
      expect(ctx.doc.translationSourceIsPinned, isFalse);
      expect(ctx.sources.values, <String, String>{_keyA: 'EN'});
    });

    test('văn bản dán tay: chọn được nguồn trong phiên, không ghi gì',
        () async {
      final ctx = _newDoc(documentKey: null)
        ..doc.lines.addAll(_germanLookingLines());

      expect(await ctx.doc.setTranslationSourceLanguage('EN'), isTrue);

      expect(ctx.doc.translationSourceIsPinned, isTrue);
      expect(ctx.sources.values, isEmpty);
    });

    test('giá trị lưu hỏng ⇒ coi như «Tự nhận diện»', () {
      final ctx = _newDoc()..doc.lines.addAll(_germanLookingLines());
      ctx.sources.values[_keyA] = 'rác';

      expect(ctx.doc.restoreSavedTranslationSource(), isFalse);
      expect(ctx.doc.translationSourceIsPinned, isFalse);
    });

    test('dựng lại dòng của CÙNG tài liệu (sửa nội dung, tách dòng): giữ '
        'nguồn, kể cả văn bản dán tay', () async {
      final ctx = _newDoc(documentKey: null)
        ..doc.lines.addAll(_germanLookingLines());
      await ctx.doc.setTranslationSourceLanguage('EN');

      ctx.doc.reparseSameDocument();
      expect(ctx.doc.translationSourceIsPinned, isTrue);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'EN');

      // Đối chứng: nạp tài liệu mới (không qua lớp giữ) thì bỏ gắn nguồn.
      ctx.doc.resetTranslationForNewDocument();
      expect(ctx.doc.translationSourceIsPinned, isFalse);
    });
  });

  group('PSRC-238 × PSRC-237 — không phá «Đổi vai»', () {
    test('đang đổi vai: đổi nguồn / đổi cặp bị chặn kèm lý do, lựa chọn đã '
        'lưu không đổi, văn bản gốc còn nguyên', () async {
      final ctx = await _vietnameseTranslatedToEnglish();
      expect(ctx.doc.swapTextAndTranslationRoles()?.swapped, 2);
      expect(ctx.doc.rolesSwapped, isTrue);

      expect(await ctx.doc.setTranslationSourceLanguage('JA'), isFalse);
      expect(ctx.doc.translationError, TranslationMixin.roleSwapGuardMessage);
      expect(
        await ctx.doc.setTranslationLanguagePair(
          sourceCode: 'JA',
          targetCode: 'KO',
        ),
        isFalse,
      );
      expect(ctx.doc.translationBlockedBySamePair, isFalse,
          reason: 'lỗi «đang đổi vai» không phải lời đề nghị đổi đích');

      // Văn bản gốc (đang nằm ở dòng dịch) không mất.
      expect(ctx.doc.lines[0].translation, 'Hôm nay trời rất đẹp.');
      expect(ctx.doc.lines[1].translation, 'Tôi đi học bài ở thư viện.');
      // Chỗ lưu chỉ giữ lựa chọn của NGƯỜI DÙNG, không phải mã mượn tạm.
      expect(ctx.sources.values, <String, String>{_keyA: 'VI'});
      expect(ctx.doc.restoreSavedTranslationSource(), isFalse);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'EN');
      expect(ctx.engine.pairs, isEmpty);

      // Đổi lại ⇒ nguồn người dùng đã chọn quay về.
      expect(ctx.doc.swapTextAndTranslationRoles()?.swapped, 2);
      expect(ctx.doc.translationSourceIsPinned, isTrue);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'VI');
      expect(ctx.sources.values, <String, String>{_keyA: 'VI'});
    });

    test('mở lại tài liệu vừa chọn nguồn vừa đổi vai: khôi phục nguồn TRƯỚC, '
        'đổi vai sau; đổi lại vẫn ra nguồn đã chọn', () async {
      final first = await _vietnameseTranslatedToEnglish();
      first.doc.swapTextAndTranslationRoles();
      expect(first.markers.values[_keyA], 'EN>VI>2');

      final reopened = await _vietnameseTranslatedToEnglish(
        sources: first.sources,
        markers: first.markers,
        pickSource: false,
      );
      expect(reopened.doc.restoreSavedTranslationSource(), isTrue);
      expect(reopened.doc.restoreSavedRoleSwap(), isTrue);
      expect(reopened.doc.rolesSwapped, isTrue);
      expect(reopened.doc.lines[0].content, 'The weather is very nice today.');

      reopened.doc.swapTextAndTranslationRoles();
      expect(reopened.doc.lines[0].content, 'Hôm nay trời rất đẹp.');
      expect(reopened.doc.translationSourceIsPinned, isTrue);
      expect(reopened.doc.translationSourceLanguage.translationCode, 'VI');
    });

    test('bỏ trạng thái đổi vai trên cùng tài liệu: trả lại nguồn đã chọn',
        () async {
      final ctx = await _vietnameseTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      ctx.doc.clearSwapStateForTest();

      expect(ctx.doc.rolesSwapped, isFalse);
      expect(ctx.doc.translationSourceIsPinned, isTrue);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'VI');
      expect(ctx.doc.translationTargetLanguage.translationCode, 'EN');
    });

    test('dựng lại dòng khi đang đổi vai: giữ nguồn của người dùng, không '
        'giữ mã mượn tạm', () async {
      final ctx = await _vietnameseTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();
      expect(ctx.doc.translationSourceLanguage.translationCode, 'EN');

      ctx.doc.reparseSameDocument();

      expect(ctx.doc.rolesSwapped, isFalse);
      expect(ctx.doc.translationSourceLanguage.translationCode, 'VI');
    });
  });

  group('PSRC-238 cặp trùng — đề nghị đích khác thay vì dừng ở lỗi', () {
    test('bấm Dịch khi nguồn trùng đích: thành lời đề nghị, nhận lời thì '
        'dịch được', () async {
      final ctx = _newDoc()..doc.lines.addAll(_vietnameseLines());
      expect(ctx.doc.detectedSourceLanguage.translationCode, 'VI');
      expect(ctx.doc.translationTargetLanguage.translationCode, 'VI');
      expect(ctx.doc.translationBlockedBySamePair, isFalse,
          reason: 'chưa bấm Dịch thì chưa làm phiền');

      await ctx.doc.translateAll();

      expect(ctx.engine.pairs, isEmpty);
      expect(ctx.doc.translationBlockedBySamePair, isTrue);
      // Chuỗi lỗi vẫn còn cho các màn hình khác đang đọc nó.
      expect(ctx.doc.translationError, contains('đã là ngôn ngữ đích'));
      final suggestion =
          ctx.doc.suggestedTranslationTarget(uiLanguageCode: 'vi');
      expect(suggestion.translationCode, 'EN');
      expect(
        ctx.doc.suggestedTranslationTarget(uiLanguageCode: 'th').translationCode,
        'TH',
      );

      expect(
        await ctx.doc.setTranslationLanguagePair(
          targetCode: suggestion.translationCode,
        ),
        isTrue,
      );
      expect(ctx.doc.translationBlockedBySamePair, isFalse);
      expect(ctx.doc.translationError, isNull);

      await ctx.doc.translateAll();
      expect(ctx.engine.pairs.toSet(), <String>{'VI>EN'});
      expect(ctx.doc.lines[0].translation, startsWith('VI>EN#'));
      expect(ctx.doc.lines[1].translation, startsWith('VI>EN#'));
      expect(ctx.doc.translationError, isNull);
    });

    test('dịch MỘT dòng khi cặp trùng cũng thành lời đề nghị', () async {
      final ctx = _newDoc()..doc.lines.addAll(_vietnameseLines());

      await ctx.doc.translateLine(0);

      expect(ctx.engine.pairs, isEmpty);
      expect(ctx.doc.translationBlockedBySamePair, isTrue);
    });

    test('lỗi khác (đang đổi vai) KHÔNG bị coi là lời đề nghị đổi đích',
        () async {
      final ctx = await _vietnameseTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      await ctx.doc.translateAll(forceRetranslate: true);

      expect(ctx.doc.translationError, TranslationMixin.roleSwapGuardMessage);
      expect(ctx.doc.translationBlockedBySamePair, isFalse);
    });
  });

  group('PSRC-238 đổi cả cặp một lần', () {
    test('đổi nguồn + đích: xoá bản dịch cũ, dịch lại MỘT lượt với cặp cuối '
        '(không dịch dở với cặp trung gian)', () async {
      final ctx = await _vietnameseTranslatedToEnglish();

      expect(
        await ctx.doc.setTranslationLanguagePair(
          sourceCode: 'TH',
          targetCode: 'JA',
        ),
        isTrue,
      );
      await _waitUntilIdle(ctx.doc);

      expect(ctx.doc.translationSourceLanguage.translationCode, 'TH');
      expect(ctx.doc.translationTargetLanguage.translationCode, 'JA');
      expect(ctx.engine.pairs.toSet(), <String>{'TH>JA'});
      expect(ctx.doc.lines[0].translation, startsWith('TH>JA#'));
      expect(ctx.doc.lines[1].translation, startsWith('TH>JA#'));
      expect(ctx.sources.values, <String, String>{_keyA: 'TH'});
    });

    test('không đổi gì ⇒ false, bản dịch còn nguyên, không gọi engine',
        () async {
      final ctx = await _vietnameseTranslatedToEnglish();

      expect(await ctx.doc.setTranslationLanguagePair(), isFalse);
      expect(
        await ctx.doc.setTranslationLanguagePair(
          sourceCode: 'VI',
          targetCode: 'EN',
        ),
        isFalse,
      );

      expect(ctx.doc.lines[0].translation, 'The weather is very nice today.');
      expect(ctx.engine.pairs, isEmpty);
    });

    test('đổi thành cặp trùng (chỉ đổi nguồn = đích): không tự dịch, không '
        'báo lỗi', () async {
      final ctx = await _vietnameseTranslatedToEnglish();

      expect(await ctx.doc.setTranslationLanguagePair(sourceCode: 'EN'), isTrue);
      await _waitUntilIdle(ctx.doc);

      expect(ctx.doc.translationPairUsesSameLanguage, isTrue);
      expect(ctx.doc.translationError, isNull);
      expect(ctx.doc.translationBlockedBySamePair, isFalse);
      expect(ctx.engine.pairs, isEmpty);
    });
  });

  group('PSRC-238 bảng chọn ngôn ngữ (widget)', () {
    String en(String text) => AppUITranslations.translate(text, 'en');

    testWidgets('mở khoá nguồn: «Tự nhận diện» + danh sách; chọn nguồn khác '
        'đích ⇒ trả về nguồn, không đụng đích', (tester) async {
      final out = <TranslationPairChoice?>[];
      await tester.pumpWidget(
        _pickerHost(detected: 'DE', target: 'VI', out: out),
      );
      await _openPicker(tester);

      // Mở ra ở phía đích; chưa có dòng «Tự nhận diện».
      expect(find.byKey(const Key('translation-source-auto')), findsNothing);
      expect(find.byKey(const Key('translation-same-pair-banner')),
          findsNothing);

      await tester.tap(find.byKey(const Key('translation-pair-source-side')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('translation-source-auto')), findsOneWidget);
      // Dòng «Tự nhận diện» cho thấy app đang nhận ra ngôn ngữ nào.
      expect(
        find.descendant(
          of: find.byKey(const Key('translation-source-auto')),
          matching: find.textContaining('Deutsch'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(out, hasLength(1));
      expect(out.single?.sourceCode, 'EN');
      expect(out.single?.target, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('đang gắn nguồn: chọn «Tự nhận diện» ⇒ trả về AUTO',
        (tester) async {
      final out = <TranslationPairChoice?>[];
      await tester.pumpWidget(
        _pickerHost(detected: 'DE', pinned: 'EN', target: 'VI', out: out),
      );
      await _openPicker(tester);

      await tester.tap(find.byKey(const Key('translation-pair-source-side')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translation-source-auto')));
      await tester.pumpAndSettle();

      expect(out.single?.sourceCode, kTranslationSourceAuto);
      expect(out.single?.target, isNull);
    });

    testWidgets('chọn nguồn TRÙNG đích: bảng ở lại, đề nghị đích khác; nhận '
        'lời ⇒ trả về cả nguồn lẫn đích (320 px, không tràn)', (tester) async {
      final out = <TranslationPairChoice?>[];
      await tester.pumpWidget(
        _pickerHost(detected: 'EN', target: 'DE', out: out),
      );
      await _openPicker(tester, size: const Size(320, 1600));

      await tester.tap(find.byKey(const Key('translation-pair-source-side')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();

      expect(out, isEmpty, reason: 'chưa đóng: còn phải chọn đích');
      expect(find.byKey(const Key('translation-same-pair-banner')),
          findsOneWidget);
      // Nguồn trước đó (tiếng Anh) là đích được đề nghị.
      expect(find.text(en('Dịch sang English')), findsOneWidget);
      expect(find.byKey(const Key('translation-same-pair-keep')),
          findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'bảng không được tràn ở 320 px');

      await tester.tap(find.byKey(const Key('translation-same-pair-accept')));
      await tester.pumpAndSettle();

      expect(out.single?.sourceCode, 'DE');
      expect(out.single?.target?.translationCode, 'EN');
      expect(tester.takeException(), isNull);
    });

    testWidgets('chọn nguồn trùng đích rồi «Chỉ đổi nguồn» ⇒ giữ đích',
        (tester) async {
      final out = <TranslationPairChoice?>[];
      await tester.pumpWidget(
        _pickerHost(detected: 'EN', target: 'DE', out: out),
      );
      await _openPicker(tester);

      await tester.tap(find.byKey(const Key('translation-pair-source-side')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translation-same-pair-keep')));
      await tester.pumpAndSettle();

      expect(out.single?.sourceCode, 'DE');
      expect(out.single?.target, isNull);
    });

    testWidgets('cặp đã trùng sẵn lúc mở: đề nghị ngay, không có «Chỉ đổi '
        'nguồn»; đóng bảng ⇒ không đổi gì', (tester) async {
      final out = <TranslationPairChoice?>[];
      await tester.pumpWidget(
        _pickerHost(detected: 'DE', target: 'DE', out: out),
      );
      await _openPicker(tester);

      expect(find.byKey(const Key('translation-same-pair-banner')),
          findsOneWidget);
      expect(find.text(en('Dịch sang English')), findsOneWidget);
      expect(find.byKey(const Key('translation-same-pair-keep')), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(out, <TranslationPairChoice?>[null]);

      // Mở lại và nhận lời đề nghị: chỉ đổi đích.
      await tester.tap(find.byKey(const Key('open-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translation-same-pair-accept')));
      await tester.pumpAndSettle();

      expect(out.last?.sourceCode, isNull);
      expect(out.last?.target?.translationCode, 'EN');
    });

    testWidgets('bảng CHỈ chọn đích (Dịch màn hình) không đổi: không có '
        'phía nguồn', (tester) async {
      AppLanguage? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const Key('open-picker'),
                  onPressed: () async {
                    picked = await showTranslationLanguagePicker(
                      context,
                      sourceLanguage: AppLanguageCatalog.fromCode('DE'),
                      currentTarget: AppLanguageCatalog.fromCode('VI'),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await _openPicker(tester);

      expect(find.byKey(const Key('translation-pair-source-side')),
          findsNothing);
      expect(find.byKey(const Key('translation-pair-target-side')),
          findsNothing);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(picked?.translationCode, 'EN');
    });
  });

  group('PSRC-238 nối dây (ghim nguồn)', () {
    final provider = _code('lib/providers/text_provider.dart');
    final toolbar = _code('lib/features/translation/translation_toolbar.dart');
    final settings =
        _code('lib/screens/read_mode/sheets/read_settings_sheet.dart');
    final playbackBar =
        _code('lib/screens/read_mode/widgets/smart_playback_bar.dart');

    test('TextProvider: mọi đường nạp tài liệu khôi phục nguồn đã lưu, TRƯỚC '
        'khi tô bản dịch từ cache', () {
      final metaStart = provider.indexOf('void _setSourceMeta({');
      expect(metaStart, greaterThan(0));
      final metaBody = provider.substring(
        metaStart,
        provider.indexOf('void clearText()', metaStart),
      );
      expect(metaBody.contains('restoreSavedTranslationSource()'), isTrue);

      final fileMeta =
          provider.indexOf('sourceType: TextSourceType.localFile,');
      final rehydrate =
          provider.indexOf('unawaited(rehydrateTranslationsFromCache());');
      expect(fileMeta, greaterThan(0));
      expect(rehydrate, greaterThan(fileMeta),
          reason: 'cache dịch được tra theo nguồn hiệu dụng');
    });

    test('TextProvider: sửa nội dung / tách dòng lại KHÔNG làm rơi nguồn', () {
      // updateFullText, toggleAutoSplit, _applyLines («Tách dòng tự động»).
      expect(
        RegExp(r'reparseKeepingTranslationSource\(')
            .allMatches(provider)
            .length,
        3,
      );
      final apply = provider.indexOf(
        'void _applyLines(List<String> lineStrings, {String? title}) {',
      );
      expect(
        provider.substring(apply, apply + 260),
        contains('reparseKeepingTranslationSource('),
      );
      final edit = provider.indexOf('void updateFullText(String newText)');
      final split = provider.indexOf('void toggleAutoSplit(bool value)');
      expect(
        provider.substring(edit, edit + 220),
        contains('reparseKeepingTranslationSource('),
      );
      expect(
        provider.substring(split, split + 260),
        contains('reparseKeepingTranslationSource('),
      );
    });

    test('giao diện tab Đọc dùng nguồn HIỆU DỤNG, không dùng kết quả nhận '
        'diện thô', () {
      // Chỉ còn được truyền làm «kết quả nhận diện» cho bảng chọn.
      for (final source in <String>[toolbar, settings]) {
        final raw = RegExp(r'\.detectedSourceLanguage').allMatches(source);
        final asPickerArg =
            RegExp(r'detectedSource: \w+\.detectedSourceLanguage,')
                .allMatches(source);
        expect(raw.length, asPickerArg.length);
        expect(source.contains('.translationSourceLanguage'), isTrue);
      }
      // Thanh phát: giọng đọc của văn bản gốc đi theo nguồn đã chọn.
      expect(playbackBar.contains('detectedSourceLanguage'), isFalse);
      expect(
        RegExp(r'tp\.translationSourceLanguage').allMatches(playbackBar).length,
        3,
      );
    });

    test('thanh dịch: đang đổi vai thì báo lý do TRƯỚC khi mở bảng; cặp '
        'trùng thì hiện lời đề nghị thay cho dòng lỗi', () {
      final open = toolbar.indexOf('Future<void> _openLanguagePair(');
      expect(open, greaterThan(0));
      final guard = toolbar.indexOf(
        'if (_blockedWhileSwapped(context, textProvider)) return;',
        open,
      );
      final sheet = toolbar.indexOf('showTranslationPairPicker(', open);
      expect(guard, greaterThan(open));
      expect(sheet, greaterThan(guard));

      final suggestion =
          toolbar.indexOf('if (textProvider.translationBlockedBySamePair)');
      expect(suggestion, greaterThan(0));
      // Audit §6 moved finite error/progress/provenance chrome to a shared
      // panel. The same-pair suggestion still takes precedence there.
      expect(toolbar.contains('TranslationRunStatusPanel('), isTrue);
      final statusPanel = _code(
          'lib/features/translation/widgets/translation_engine_controls.dart');
      final samePairGuard = statusPanel.indexOf('document.translationBlockedBySamePair');
      final hidden = statusPanel.indexOf('return const SizedBox.shrink();', samePairGuard);
      final error = statusPanel.indexOf('if (document.translationError != null)');
      expect(samePairGuard, greaterThan(0));
      expect(hidden, greaterThan(samePairGuard));
      expect(error, greaterThan(hidden));
      expect(toolbar.contains('_SamePairSuggestion('), isTrue);
      expect(toolbar.contains('setTranslationLanguagePair('), isTrue);
    });

    test('bảng cài đặt: chọn được nguồn; đang đổi vai thì nói lý do tại chỗ',
        () {
      expect(settings.contains('showTranslationPairPicker('), isTrue);
      expect(settings.contains('setTranslationLanguagePair('), isTrue);
      expect(settings.contains("Key('read-settings-role-swap-note')"), isTrue);
      expect(settings.contains('TranslationMixin.roleSwapGuardMessage'),
          isTrue);
      expect(settings.contains("Key('read-settings-same-pair-accept')"),
          isTrue);
    });

    test('«Dịch màn hình» giữ nguyên cách dùng nút (chỉ chọn đích)', () {
      final card =
          _code('lib/features/screen_translate/screen_translate_card.dart');
      expect(card.contains('onSelected: _onLanguageSelected,'), isTrue);
      expect(card.contains('showTranslationPairPicker('), isFalse);
    });
  });

  group('PSRC-238 i18n (quy tắc vàng #5)', () {
    const newStrings = <String>[
      'Dịch sang {value0}',
      'Chỉ đổi nguồn',
      'Ngôn ngữ nguồn: {value0}',
      'Nguồn do bạn chọn cho tài liệu này. Khi đọc song ngữ, In4Up sẽ chuyển '
          'giọng {value0} ↔ {value1} trước từng lượt đọc.',
    ];
    // Chuỗi có sẵn được dùng lại ở giao diện mới.
    const reusedStrings = <String>[
      'Tự nhận diện',
      'Ngôn ngữ nguồn',
      'Ngôn ngữ đích',
      'Ngôn ngữ bản dịch',
      'Ngôn ngữ nguồn và ngôn ngữ đích đang giống nhau.',
      'Hãy chọn ngôn ngữ đích khác ngôn ngữ nguồn.',
      'Đang đổi vai — hãy đổi lại trước khi đổi ngôn ngữ hoặc dịch lại.',
    ];
    const locales = <String>['en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja'];
    final placeholder = RegExp(r'\{value\d\}');

    test('4 chuỗi mới + chuỗi dùng lại có đủ 8 locale, giữ đủ chỗ điền', () {
      final pack = jsonDecode(_src('tool/priority_native_pack.json'))
          as Map<String, dynamic>;
      for (final text in <String>[...newStrings, ...reusedStrings]) {
        final entry = pack[text];
        expect(entry, isA<Map<String, dynamic>>(), reason: text);
        final expected =
            placeholder.allMatches(text).map((m) => m.group(0)).toSet();
        for (final locale in locales) {
          final value = (entry as Map<String, dynamic>)[locale];
          expect(value, isA<String>(), reason: '$text [$locale]');
          expect((value as String).trim(), isNotEmpty,
              reason: '$text [$locale]');
          expect(value, isNot(text), reason: '$text [$locale] còn tiếng Việt');
          expect(
            placeholder.allMatches(value).map((m) => m.group(0)).toSet(),
            expected,
            reason: '$text [$locale] sai chỗ điền',
          );
        }
      }
    });

    test('4 chuỗi mới có bản tiếng Anh trong overrides', () {
      final overrides = jsonDecode(_src('tool/legacy_ui_english_overrides.json'))
          as Map<String, dynamic>;
      for (final text in newStrings) {
        expect(overrides[text], isA<String>(), reason: text);
      }
    });

    test('chuỗi có chỗ điền dịch được lúc chạy (qua `context.uiText`)', () {
      expect(AppUITranslations.translate('Dịch sang English', 'en'),
          'Translate to English');
      expect(AppUITranslations.translate('Dịch sang ไทย', 'th'),
          isNot(contains('Dịch')));
      expect(AppUITranslations.translate('Dịch sang ไทย', 'th'),
          contains('ไทย'));
      expect(
        AppUITranslations.translate('Ngôn ngữ nguồn: 🇬🇧 English', 'ja'),
        '元の言語: 🇬🇧 English',
      );
      final hint = AppUITranslations.translate(
        'Nguồn do bạn chọn cho tài liệu này. Khi đọc song ngữ, In4Up sẽ '
        'chuyển giọng en-US ↔ vi-VN trước từng lượt đọc.',
        'si',
      );
      expect(hint, contains('en-US ↔ vi-VN'));
      expect(hint, isNot(contains('Nguồn')));
      // Tiếng Việt giữ nguyên văn.
      expect(AppUITranslations.translate('Chỉ đổi nguồn', 'vi'),
          'Chỉ đổi nguồn');
    });

    test('chuỗi mới đúng là chuỗi đang dùng trong giao diện', () {
      final picker =
          _src('lib/features/translation/translation_language_picker.dart');
      final toolbar = _src('lib/features/translation/translation_toolbar.dart');
      final settings =
          _src('lib/screens/read_mode/sheets/read_settings_sheet.dart');
      expect(picker.contains("context.uiText('Chỉ đổi nguồn')"), isTrue);
      for (final source in <String>[picker, toolbar, settings]) {
        expect(
          source.contains(r"context.uiText('Dịch sang ${suggestion.nativeName}')"),
          isTrue,
        );
      }
      expect(
        toolbar.contains(r"context.uiText('Ngôn ngữ nguồn: $sourceLabel')"),
        isTrue,
      );
      expect(
        settings.contains(
          r"context.uiText('Nguồn do bạn chọn cho tài liệu này. Khi đọc song "
          r'ngữ, In4Up sẽ chuyển giọng ${source.ttsLocale} ↔ '
          r"${target.ttsLocale} trước từng lượt đọc.')",
        ),
        isTrue,
      );
    });
  });
}
