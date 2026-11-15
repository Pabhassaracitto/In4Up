// test/read_mode/psrc_237_role_swap_test.dart
//
// PSRC-237 / ADR-0031 — «Đổi vai» văn bản ⇄ bản dịch.
//
// Ca của owner: văn bản tiếng mẹ đẻ đã dịch sang tiếng Anh, muốn xem IPA /
// tô màu / tra từ trên phần tiếng Anh. Các công cụ đó chỉ chạy trên
// `TextItem.content` ⇒ đổi vai đưa bản dịch lên `content`.
//
// Máy bắt ba lớp:
//   1. hàm thuần `line_role_swap.dart` — đổi rồi đổi lại phải trả NGUYÊN VĂN;
//   2. `TranslationMixin` — cặp ngôn ngữ đi theo, mọi thao tác ghi vào dòng
//      dịch bị chặn khi đang đổi vai (văn bản gốc không được mất), dấu lưu
//      theo tài liệu;
//   3. ghim nguồn cho phần giao diện + gói ngôn ngữ (quy tắc vàng #5).
//
// Không cần thiết bị / engine thật: `TranslationService.forTest`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/features/translation/cache/translation_cache.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';
import 'package:in4up/features/translation/line_role_swap.dart';
import 'package:in4up/features/translation/text_provider_translation.dart';
import 'package:in4up/features/translation/translation_service.dart';
import 'package:in4up/models/text_item.dart';

String _src(String path) => File(path).readAsStringSync();

/// Engine đếm số lần bị gọi — khi đang đổi vai, con số này phải đứng yên.
class _CountingEngine extends TranslationEngine {
  int calls = 0;

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
    calls++;
    return TranslationResult.success(
      original: text,
      translated: '[MT] $text',
      engine: name,
      detectedLang: sourceLang.toUpperCase(),
      targetLang: targetLang.toUpperCase(),
    );
  }
}

class _MemoryMarkerStore implements RoleSwapMarkerStore {
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
  int hookCalls = 0;

  @override
  String? get roleSwapDocumentKey => documentKey;

  @override
  void onLineRolesSwapped() => hookCalls++;
}

const String _key = 'file:/sdcard/bai-doc.txt';

/// Văn bản tiếng Việt (nguồn đã gắn VI), đích EN, 2/3 dòng đã có bản dịch.
class _Ctx {
  _Ctx(this.doc, this.store, this.engine);

  final _Doc doc;
  final _MemoryMarkerStore store;
  final _CountingEngine engine;
}

Future<_Ctx> _vietnameseDocTranslatedToEnglish({
  String? documentKey = _key,
}) async {
  final engine = _CountingEngine();
  final store = _MemoryMarkerStore();
  final doc = _Doc()
    ..translationServiceForTest = TranslationService.forTest(
      mlkitEngine: engine,
      offlineEngine: engine,
      networkAvailable: false,
    )
    ..roleSwapMarkerStoreForTest = store
    ..documentKey = documentKey;
  doc.restoreTranslationTargetLanguage('EN');
  // Gắn nguồn TRƯỚC khi có bản dịch (đổi nguồn sẽ xoá bản dịch).
  await doc.setTranslationSourceLanguage('VI', retranslateExisting: false);
  doc.lines.addAll(<TextItem>[
    TextItem(
      id: 'line_0',
      content: 'Hôm nay trời đẹp.',
      translation: 'The weather is nice today.',
      sourceLanguageCode: 'VI',
      translationLanguageCode: 'EN',
      startTime: const Duration(seconds: 1),
      endTime: const Duration(seconds: 4),
    ),
    TextItem(
      id: 'line_1',
      content: '  Tôi đi học.  ',
      translation: 'I go to school.',
      sourceLanguageCode: 'VI',
      translationLanguageCode: 'EN',
    ),
    TextItem(id: 'line_2', content: 'Dòng này chưa dịch.'),
  ]);
  return _Ctx(doc, store, engine);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TranslationCache().clear();
  });

  group('PSRC-237 hàm thuần — swapLineRoles', () {
    List<TextItem> sample() => <TextItem>[
          TextItem(
            id: 'a',
            content: 'Xin chào.',
            translation: 'Hello.',
            sourceLanguageCode: 'VI',
            translationLanguageCode: 'EN',
            startTime: const Duration(seconds: 2),
            endTime: const Duration(seconds: 5),
          ),
          TextItem(id: 'b', content: 'Chưa dịch.'),
          TextItem(
            id: 'c',
            content: 'Dòng dịch sang tiếng Nhật.',
            translation: 'こんにちは',
            translationLanguageCode: 'JA',
          ),
          TextItem(id: 'd', content: '   '),
        ];

    test('chỉ đổi dòng có bản dịch ở đúng ngôn ngữ; dòng khác giữ nguyên',
        () {
      final result = swapLineRoles(sample(), fromCode: 'EN', toCode: 'VI');

      expect(result.swapped, 1);
      expect(result.kept, 2, reason: 'dòng trắng không tính là «giữ lại»');
      expect(result.lines.length, 4);

      final first = result.lines[0];
      expect(first.content, 'Hello.');
      expect(first.translation, 'Xin chào.');
      expect(first.sourceLanguageCode, 'EN');
      expect(first.translationLanguageCode, 'VI');
      // Mốc thời gian và id đi theo dòng ⇒ LRC/SRT vẫn khớp âm thanh.
      expect(first.id, 'a');
      expect(first.startTime, const Duration(seconds: 2));
      expect(first.endTime, const Duration(seconds: 5));

      expect(result.lines[1].content, 'Chưa dịch.');
      expect(result.lines[1].translation, isNull);
      expect(result.lines[2].content, 'Dòng dịch sang tiếng Nhật.');
      expect(result.lines[2].translation, 'こんにちは');
    });

    test('đổi rồi đổi lại trả NGUYÊN VĂN — kể cả khoảng trắng đầu / cuối',
        () {
      final original = <TextItem>[
        TextItem(
          id: 'a',
          content: '  Thụt đầu dòng.  ',
          translation: ' Indented. ',
          translationLanguageCode: 'EN',
        ),
        TextItem(id: 'b', content: 'Chưa dịch.'),
      ];
      final there = swapLineRoles(original, fromCode: 'EN', toCode: 'VI');
      final back = swapLineRoles(there.lines, fromCode: 'VI', toCode: 'EN');

      expect(back.swapped, 1);
      expect(back.lines[0].content, '  Thụt đầu dòng.  ');
      expect(back.lines[0].translation, ' Indented. ');
      expect(back.lines[0].translationLanguageCode, 'EN');
      expect(back.lines[1].content, 'Chưa dịch.');
      expect(back.lines[1].translation, isNull);
    });

    test('dòng song ngữ kiểu cũ (không metadata) được coi là bản dịch VI',
        () {
      final legacy = <TextItem>[
        TextItem(id: 'a', content: 'Good morning.', translation: 'Chào buổi sáng.'),
      ];
      expect(countSwappableLines(legacy, 'VI'), 1);
      expect(countSwappableLines(legacy, 'EN'), 0);

      final result = swapLineRoles(legacy, fromCode: 'VI', toCode: 'EN');
      expect(result.lines.single.content, 'Chào buổi sáng.');
      expect(result.lines.single.translation, 'Good morning.');
    });

    test('không có dòng nào đổi được ⇒ danh sách y nguyên', () {
      final lines = <TextItem>[TextItem(id: 'a', content: 'Chưa dịch.')];
      final result = swapLineRoles(lines, fromCode: 'EN', toCode: 'VI');
      expect(result.swapped, 0);
      expect(identical(result.lines.single, lines.single), isTrue);
    });
  });

  group('PSRC-237 hàm thuần — dấu lưu theo tài liệu', () {
    test('encode / decode khứ hồi', () {
      const state = LineRoleSwapState(
        promotedCode: 'EN',
        originalCode: 'VI',
        swappedLines: 42,
      );
      expect(state.encode(), 'EN>VI>42');
      final decoded = LineRoleSwapState.decode('EN>VI>42');
      expect(decoded, isNotNull);
      expect(decoded!.promotedCode, 'EN');
      expect(decoded.originalCode, 'VI');
      expect(decoded.swappedLines, 42);
    });

    test('dấu hỏng / lạ bị từ chối — coi như chưa từng đổi vai', () {
      for (final raw in <String?>[
        null,
        '',
        'EN>VI',
        'EN>VI>abc',
        'EN>VI>0',
        'EN>VI>-3',
        'EN>EN>5',
        'QQ>VI>5',
        'EN>VI>5>thừa',
      ]) {
        expect(LineRoleSwapState.decode(raw), isNull, reason: 'raw=$raw');
      }
    });

    test('khoá lưu: ASCII, ngắn, ổn định, khác nhau theo tài liệu', () {
      final a = roleSwapStorageKey('file:/sdcard/Tài liệu/bài đọc số 1.txt');
      final b = roleSwapStorageKey('file:/sdcard/Tài liệu/bài đọc số 2.txt');
      expect(a, startsWith('read_role_swap_v1_'));
      expect(a.length, 'read_role_swap_v1_'.length + 32);
      expect(a.codeUnits.every((unit) => unit < 128), isTrue);
      expect(a, isNot(b));
      expect(
        roleSwapStorageKey('file:/sdcard/Tài liệu/bài đọc số 1.txt'),
        a,
      );
    });
  });

  group('PSRC-237 mixin — đổi vai và đổi lại', () {
    test('bản dịch tiếng Anh thành văn bản chính; cặp ngôn ngữ đi theo',
        () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      final doc = ctx.doc;
      expect(doc.rolesSwapped, isFalse);
      expect(doc.canSwapRoles, isTrue);
      expect(doc.roleSwappableLineCount, 2);
      final revision = doc.translationDocumentRevision;
      var notified = 0;
      doc.addListener(() => notified++);

      final result = doc.swapTextAndTranslationRoles();

      expect(result, isNotNull);
      expect(result!.swapped, 2);
      expect(result.kept, 1);
      expect(doc.rolesSwapped, isTrue);
      // Thứ IPA / tô màu / tra từ nhìn thấy nay là tiếng Anh.
      expect(doc.lines[0].content, 'The weather is nice today.');
      expect(doc.lines[0].translation, 'Hôm nay trời đẹp.');
      expect(doc.lines[1].content, 'I go to school.');
      expect(doc.lines[1].translation, '  Tôi đi học.  ');
      // Dòng chưa dịch không mất chữ.
      expect(doc.lines[2].content, 'Dòng này chưa dịch.');
      expect(doc.lines[2].translation, isNull);
      // Mốc thời gian còn nguyên.
      expect(doc.lines[0].startTime, const Duration(seconds: 1));

      expect(doc.translationTargetLanguage.translationCode, 'VI');
      expect(doc.translationSourceLanguage.translationCode, 'EN');
      expect(doc.translationPairUsesSameLanguage, isFalse);
      expect(doc.roleSwapPromotedLanguage?.translationCode, 'EN');
      // Văn bản gốc vẫn được tính là «bản dịch» ⇒ thanh công cụ dịch còn đó.
      expect(doc.translatedLineCount, 2);

      expect(doc.hookCalls, 1, reason: 'lớp chủ phải phân tích lại từ loại');
      expect(doc.translationDocumentRevision, revision + 1);
      expect(notified, greaterThan(0));
    });

    test('đổi lại trả nguyên văn, trả cặp ngôn ngữ và nguồn đã gắn',
        () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      final doc = ctx.doc;
      doc.swapTextAndTranslationRoles();
      expect(doc.canSwapRoles, isTrue, reason: 'nút «Đổi lại» phải bấm được');

      final back = doc.swapTextAndTranslationRoles();

      expect(back, isNotNull);
      expect(back!.swapped, 2);
      expect(doc.rolesSwapped, isFalse);
      expect(doc.lines[0].content, 'Hôm nay trời đẹp.');
      expect(doc.lines[0].translation, 'The weather is nice today.');
      expect(doc.lines[0].translationLanguageCode, 'EN');
      expect(doc.lines[1].content, '  Tôi đi học.  ');
      expect(doc.lines[1].translation, 'I go to school.');
      expect(doc.lines[2].content, 'Dòng này chưa dịch.');
      expect(doc.translationTargetLanguage.translationCode, 'EN');
      expect(doc.translationSourceIsPinned, isTrue);
      expect(doc.translationSourceLanguage.translationCode, 'VI');
      expect(doc.roleSwapPromotedLanguage, isNull);
      expect(doc.hookCalls, 2);
    });

    test(
        'tài liệu song ngữ kiểu cũ (Anh + dịch Việt, nguồn tự nhận diện): '
        'đổi lại thì bỏ gắn nguồn', () {
      final doc = _Doc()
        ..translationServiceForTest = TranslationService.forTest(
          mlkitEngine: _CountingEngine(),
          offlineEngine: _CountingEngine(),
        )
        ..roleSwapMarkerStoreForTest = _MemoryMarkerStore()
        ..lines.addAll(<TextItem>[
          TextItem(
            id: '1',
            content: 'The quick brown fox jumps over the lazy dog.',
            translation: 'Con cáo nâu nhanh nhẹn nhảy qua con chó lười.',
          ),
          TextItem(
            id: '2',
            content: 'This is a test of the system and the flags.',
            translation: 'Đây là bài kiểm tra hệ thống và các lá cờ.',
          ),
        ]);
      expect(doc.translationTargetLanguage.translationCode, 'VI');
      expect(doc.detectedSourceLanguage.translationCode, 'EN');
      expect(doc.translationSourceIsPinned, isFalse);

      expect(doc.swapTextAndTranslationRoles()?.swapped, 2);
      expect(doc.lines[0].content,
          'Con cáo nâu nhanh nhẹn nhảy qua con chó lười.');
      expect(doc.translationTargetLanguage.translationCode, 'EN');
      // Nguồn được GẮN vào ngôn ngữ vừa đưa lên — không phụ thuộc bộ nhận
      // diện chạy trên văn bản dịch.
      expect(doc.translationSourceIsPinned, isTrue);
      expect(doc.translationSourceLanguage.translationCode, 'VI');

      expect(doc.swapTextAndTranslationRoles()?.swapped, 2);
      expect(doc.lines[0].content,
          'The quick brown fox jumps over the lazy dog.');
      expect(doc.translationTargetLanguage.translationCode, 'VI');
      expect(doc.translationSourceIsPinned, isFalse);
    });

    test('chưa có bản dịch / tài liệu rỗng ⇒ không đổi được, không đổi gì',
        () {
      final doc = _Doc()
        ..translationServiceForTest = TranslationService.forTest(
          mlkitEngine: _CountingEngine(),
          offlineEngine: _CountingEngine(),
        )
        ..roleSwapMarkerStoreForTest = _MemoryMarkerStore();
      expect(doc.canSwapRoles, isFalse);
      expect(doc.swapTextAndTranslationRoles(), isNull);

      doc.lines.add(
        TextItem(id: '1', content: 'The quick brown fox jumps over it.'),
      );
      expect(doc.canSwapRoles, isFalse);
      expect(doc.swapTextAndTranslationRoles(), isNull);
      expect(doc.rolesSwapped, isFalse);
      expect(doc.hookCalls, 0);
      expect(doc.lines.single.content, 'The quick brown fox jumps over it.');
    });
  });

  group('PSRC-237 mixin — văn bản gốc không được mất khi đang đổi vai', () {
    void expectOriginalIntact(_Doc doc) {
      expect(doc.rolesSwapped, isTrue);
      expect(doc.lines[0].content, 'The weather is nice today.');
      expect(doc.lines[0].translation, 'Hôm nay trời đẹp.');
      expect(doc.lines[1].translation, '  Tôi đi học.  ');
      expect(doc.lines[2].translation, isNull);
    }

    test('đổi ngôn ngữ đích bị chặn và báo lý do', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      final changed = await ctx.doc.setTranslationTargetLanguage('JA');

      expect(changed, isFalse);
      expect(ctx.doc.translationTargetLanguage.translationCode, 'VI');
      expect(ctx.doc.translationError, TranslationMixin.roleSwapGuardMessage);
      expectOriginalIntact(ctx.doc);
      expect(ctx.engine.calls, 0);
    });

    test('đổi ngôn ngữ nguồn bị chặn', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      expect(await ctx.doc.setTranslationSourceLanguage('DE'), isFalse);
      expect(await ctx.doc.setTranslationSourceLanguage('AUTO'), isFalse);

      expect(ctx.doc.translationSourceLanguage.translationCode, 'EN');
      expectOriginalIntact(ctx.doc);
    });

    test('«Dịch lại tất cả» bị chặn và báo lý do; engine không được gọi',
        () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      await ctx.doc.translateAll(forceRetranslate: true);

      expect(ctx.engine.calls, 0);
      expect(ctx.doc.isTranslating, isFalse);
      expect(ctx.doc.translationError, TranslationMixin.roleSwapGuardMessage);
      expectOriginalIntact(ctx.doc);
    });

    test('dịch nền (phát song ngữ) bị bỏ qua im lặng — không báo lỗi',
        () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      await ctx.doc.translateAll();

      expect(ctx.engine.calls, 0);
      expect(ctx.doc.translationError, isNull);
      expectOriginalIntact(ctx.doc);
    });

    test('dịch lại một dòng bị chặn — kể cả dòng chưa có bản dịch', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      await ctx.doc.translateLine(0);
      await ctx.doc.translateLine(2);

      expect(ctx.engine.calls, 0);
      expectOriginalIntact(ctx.doc);
    });

    test('tô lại bản dịch từ cache bị bỏ qua', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      expect(await ctx.doc.rehydrateTranslationsFromCache(), 0);
      expectOriginalIntact(ctx.doc);
    });

    test('«Xóa tất cả bản dịch» = đổi lại rồi xoá: còn văn bản gốc, mất bản '
        'dịch máy', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();

      ctx.doc.clearAllTranslations();

      expect(ctx.doc.rolesSwapped, isFalse);
      expect(ctx.doc.lines[0].content, 'Hôm nay trời đẹp.');
      expect(ctx.doc.lines[1].content, '  Tôi đi học.  ');
      expect(ctx.doc.lines[2].content, 'Dòng này chưa dịch.');
      expect(ctx.doc.lines.every((line) => line.translation == null), isTrue);
      expect(ctx.doc.translationTargetLanguage.translationCode, 'EN');
      expect(ctx.store.values, isEmpty);
    });
  });

  group('PSRC-237 mixin — lưu theo tài liệu', () {
    test('đổi vai ghi dấu; đổi lại xoá dấu', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();

      ctx.doc.swapTextAndTranslationRoles();
      expect(ctx.store.values, <String, String>{_key: 'EN>VI>2'});

      ctx.doc.swapTextAndTranslationRoles();
      expect(ctx.store.values, isEmpty);
    });

    test('tài liệu không có danh tính bền ⇒ đổi vai được nhưng không lưu',
        () async {
      final ctx = await _vietnameseDocTranslatedToEnglish(documentKey: null);

      expect(ctx.doc.swapTextAndTranslationRoles(), isNotNull);
      expect(ctx.doc.rolesSwapped, isTrue);
      expect(ctx.store.values, isEmpty);
      expect(ctx.doc.restoreSavedRoleSwap(), isFalse);
    });

    test('mở lại: bản dịch về đủ ⇒ tự đổi vai lại', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.store.values[_key] = 'EN>VI>2';

      expect(ctx.doc.restoreSavedRoleSwap(), isTrue);

      expect(ctx.doc.rolesSwapped, isTrue);
      expect(ctx.doc.lines[0].content, 'The weather is nice today.');
      expect(ctx.doc.translationTargetLanguage.translationCode, 'VI');
      // Đã đổi vai rồi thì gọi lại không làm gì thêm.
      expect(ctx.doc.restoreSavedRoleSwap(), isFalse);
      expect(ctx.doc.lines[0].content, 'The weather is nice today.');
    });

    test('mở lại: bản dịch về THIẾU ⇒ mở ở dạng gốc, giữ dấu', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.store.values[_key] = 'EN>VI>3';

      expect(ctx.doc.restoreSavedRoleSwap(), isFalse);

      expect(ctx.doc.rolesSwapped, isFalse);
      expect(ctx.doc.lines[0].content, 'Hôm nay trời đẹp.');
      expect(ctx.store.values[_key], 'EN>VI>3');
    });

    test('mở lại: đích dịch đã đổi sang ngôn ngữ khác ⇒ không đổi vai',
        () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.store.values[_key] = 'JA>VI>2';

      expect(ctx.doc.restoreSavedRoleSwap(), isFalse);
      expect(ctx.doc.rolesSwapped, isFalse);
    });

    test('mở lại: dấu hỏng ⇒ bỏ qua', () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.store.values[_key] = 'rác';

      expect(ctx.doc.restoreSavedRoleSwap(), isFalse);
      expect(ctx.doc.rolesSwapped, isFalse);
    });

    test('mở tài liệu khác: trả đích dịch về như cũ, GIỮ dấu của tài liệu cũ',
        () async {
      final ctx = await _vietnameseDocTranslatedToEnglish();
      ctx.doc.swapTextAndTranslationRoles();
      expect(ctx.doc.translationTargetLanguage.translationCode, 'VI');

      ctx.doc.resetTranslationForNewDocument();

      expect(ctx.doc.rolesSwapped, isFalse);
      expect(ctx.doc.translationTargetLanguage.translationCode, 'EN',
          reason: 'đổi vai chỉ MƯỢN đích dịch cho một tài liệu');
      expect(ctx.doc.translationSourceIsPinned, isFalse);
      expect(ctx.store.values[_key], 'EN>VI>2');
    });
  });

  group('PSRC-237 ghim nguồn — nối dây', () {
    final mixin =
        _src('lib/features/translation/text_provider_translation.dart');
    final provider = _src('lib/providers/text_provider.dart');
    final controls = _src('lib/features/translation/role_swap_controls.dart');
    final toolbar = _src('lib/features/translation/translation_toolbar.dart');
    final screen = _src('lib/screens/read_mode/read_mode_screen.dart');
    final autoSplit = _src('lib/screens/read_mode/sheets/auto_split_sheet.dart');

    test('mở lại tài liệu (file và cloud) đều thử khôi phục đổi vai', () {
      final rehydrate = mixin.substring(
        mixin.indexOf('Future<int> rehydrateTranslationsFromCache()'),
      );
      expect(rehydrate.contains('restoreSavedRoleSwap();'), isTrue);

      final apply = provider.substring(
        provider.indexOf('void applySavedTranslations('),
        provider.indexOf('Future<void> saveCurrentTranslationsToCloud()'),
      );
      expect(apply.contains('if (rolesSwapped) return;'), isTrue);
      expect(apply.contains('restoreSavedRoleSwap();'), isTrue);
    });

    test('TextProvider: danh tính tài liệu, phân tích lại, không lưu văn bản '
        'gốc thành bản dịch cloud', () {
      expect(provider.contains("return 'cloud:\$cloudId';"), isTrue);
      expect(provider.contains("return 'file:\$path';"), isTrue);

      final hook = provider.substring(
        provider.indexOf('void onLineRolesSwapped()'),
        provider.indexOf('void applySavedTranslations('),
      );
      expect(hook.contains('SyntaxHighlighterService.analyzeLines('), isTrue);
      expect(hook.contains('clearIpaMarkCaches();'), isTrue);
      expect(hook.contains('_fullTextBeforeRoleSwap'), isTrue);

      final save = provider.substring(
        provider.indexOf('Future<void> saveCurrentTranslationsToCloud()'),
        provider.indexOf('void loadFromSttResult('),
      );
      expect(save.contains('if (rolesSwapped) return;'), isTrue);
    });

    test('mọi nơi thay toàn bộ dòng đều bỏ trạng thái đổi vai', () {
      for (final signature in <String>[
        'void loadFromSttResult(SttResult result) {',
        'void _parseLrc(String content, {String? title}) {',
        'void _parseSrt(String content, {String? title}) {',
        'void clearText() {',
        'void _applyLines(List<String> lineStrings, {String? title}) {',
      ]) {
        final start = provider.indexOf(signature);
        expect(start, greaterThanOrEqualTo(0), reason: signature);
        final head = provider.substring(start, start + signature.length + 200);
        expect(head.contains('_dropRoleSwapForNewLines();'), isTrue,
            reason: signature);
      }
    });

    test('thanh công cụ dịch có nút «Đổi vai» ở cả hai bố cục + bảng nhấn giữ',
        () {
      expect(
        toolbar.contains('RoleSwapButton(primaryColor: primaryColor)'),
        isTrue,
      );
      expect('roleSwapButton,'.allMatches(toolbar).length, 2,
          reason: 'bố cục hẹp (<560) và bố cục rộng');
      expect(toolbar.contains("Key('translation-options-role-swap')"), isTrue);
      // Dịch / dịch lại / đổi ngôn ngữ khi đang đổi vai: chặn + giải thích
      // bằng SnackBar (nút Dịch, đổi ngôn ngữ, 2 dòng trong bảng nhấn giữ).
      expect(
        '_blockedWhileSwapped(context, textProvider)'
            .allMatches(toolbar)
            .length,
        4,
      );
      expect(toolbar.contains('roleSwapGuardSnackBar(context)'), isTrue);
    });

    test('dải trạng thái nằm ngay trên vùng đọc, không phụ thuộc dock', () {
      final strip = screen.indexOf('const RoleSwapStatusStrip()');
      expect(strip, greaterThan(0));
      expect(strip, greaterThan(screen.indexOf('const TranslationToolbar()')));
      final line = screen.substring(screen.lastIndexOf('\n', strip), strip);
      expect(line.contains('useDock'), isFalse);
    });

    test('dải trạng thái: nhãn «bản dịch máy», nút «Đổi lại», gợi ý đóng được',
        () {
      for (final needle in <String>[
        "Key('translation-role-swap-button')",
        "Key('read-role-swap-strip')",
        "Key('read-role-swap-back')",
        "Key('read-role-swap-hint')",
        "Key('read-role-swap-hint-accept')",
        "Key('read-role-swap-hint-dismiss')",
        "'Đang đọc bản dịch máy'",
        "'Đổi lại'",
      ]) {
        expect(controls.contains(needle), isTrue, reason: needle);
      }
      // Gợi ý chỉ hiện khi một công cụ chỉ-tiếng-Anh đang bật.
      expect(controls.contains('tp.ipaDisplayMode != IpaDisplayMode.hidden'),
          isTrue);
      expect(controls.contains('tp.colorMode != ColorMode.none'), isTrue);
      expect(
        controls.contains(
          "tp.translationTargetLanguage.translationCode != 'EN'",
        ),
        isTrue,
      );
      // Dừng phát trước khi đổi nội dung dòng.
      expect(controls.contains('playback.stop('), isTrue);
      expect(controls.contains('tp.stopSpeaking()'), isTrue);
    });

    test('không dùng widget animation (READ-TOOLBAR-001)', () {
      for (final banned in <String>[
        'AnimatedSize',
        'AnimatedOpacity',
        'AnimatedSlide',
        'AnimatedCrossFade',
        'AnimatedContainer',
        'AnimatedSwitcher',
      ]) {
        expect(controls.contains('$banned('), isFalse, reason: banned);
      }
    });

    test('«Tách dòng tự động» đổi lại trước khi mở — thứ được tách là văn '
        'bản gốc', () {
      final guard =
          autoSplit.indexOf('if (tp.rolesSwapped) toggleReadRoleSwap(context);');
      expect(guard, greaterThan(0));
      expect(guard, lessThan(autoSplit.indexOf('showModalBottomSheet<void>(')));
    });
  });

  group('PSRC-237 i18n (quy tắc vàng #5)', () {
    const strings = <String>[
      'Đổi vai văn bản ⇄ bản dịch',
      'Đổi vai',
      'Đổi lại',
      'Đang đọc bản dịch máy',
      'Đã đổi vai: bản dịch thành văn bản chính',
      'Đã đổi lại văn bản gốc',
      'IPA và tô màu chỉ chạy trên tiếng Anh. Đổi vai để dùng trên bản dịch?',
      'Đang đổi vai — hãy đổi lại trước khi đổi ngôn ngữ hoặc dịch lại.',
    ];
    const locales = <String>['en', 'hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja'];

    test('8 chuỗi mới có đủ 8 locale trong gói ưu tiên', () {
      final pack = jsonDecode(_src('tool/priority_native_pack.json'))
          as Map<String, dynamic>;
      for (final text in strings) {
        final entry = pack[text];
        expect(entry, isA<Map<String, dynamic>>(), reason: text);
        for (final locale in locales) {
          final value = (entry as Map<String, dynamic>)[locale];
          expect(value, isA<String>(), reason: '$text [$locale]');
          expect((value as String).trim(), isNotEmpty,
              reason: '$text [$locale]');
          expect(value, isNot(text), reason: '$text [$locale] còn tiếng Việt');
        }
      }
    });

    test('8 chuỗi mới có bản tiếng Anh trong overrides', () {
      final overrides = jsonDecode(_src('tool/legacy_ui_english_overrides.json'))
          as Map<String, dynamic>;
      for (final text in strings) {
        expect(overrides[text], isA<String>(), reason: text);
      }
    });

    test('chuỗi dùng trong giao diện đúng là chuỗi có trong gói', () {
      final controls = _src('lib/features/translation/role_swap_controls.dart');
      final toolbar = _src('lib/features/translation/translation_toolbar.dart');
      final mixin =
          _src('lib/features/translation/text_provider_translation.dart');
      for (final text in strings) {
        final used = controls.contains("'$text'") ||
            toolbar.contains("'$text'") ||
            mixin.contains("'$text'");
        expect(used, isTrue, reason: text);
      }
    });
  });
}
