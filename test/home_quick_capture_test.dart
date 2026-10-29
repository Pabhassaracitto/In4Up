// HOME-QUICK-001 — test flow/state cho "Nạp tri thức nhanh" ở tab Home.
//
// Phủ:
//  1. QuickCaptureController: ưu tiên Sherpa offline → fallback system STT,
//     lỗi có cấu trúc, gom transcript realtime, DỪNG SẠCH (không nhận thêm
//     kết quả sau stop, engine được stop + release khi dispose).
//  2. QuickCaptureLanguagePolicy: không hardcode EN khi máy chỉ có model VI.
//  3. QuickSuggestionPicker: entry THẬT từ WordList, ưu tiên thẻ đến kỳ ôn,
//     danh sách rỗng → null (UI hiện empty state).
//  4. QuickCaptureNoteStore: ghi chú nói round-trip + cap + dữ liệu hỏng.
//  5. QuickCaptureSaver trên VocabularyProvider THẬT (Hive temp): lưu
//     transcript → thấy entry trong WordList, mở lại vẫn còn; lưu ghi chú.
//  6. HebbianInputCard: hai nút nối callback thật + chrome không tiếng Việt
//     khi locale ≠ vi (rule #5).

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:in4up_stt/models/stt_result.dart';

import 'package:in4up/models/skill_review_data.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/models/word_entry.dart';
import 'package:in4up/providers/vocabulary_bridge.dart';
import 'package:in4up/providers/vocabulary_provider.dart';
import 'package:in4up/screens/home/quick_capture/quick_capture_controller.dart';
import 'package:in4up/screens/home/quick_capture/quick_capture_repository.dart';
import 'package:in4up/screens/home/quick_capture/quick_capture_suggestion.dart';
import 'package:in4up/screens/home/quick_capture/quick_capture_stt_sources.dart';
import 'package:in4up/screens/home/widgets/hebbian_input_card.dart';

// ─────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────

class _FakeSttSource implements QuickCaptureSttSource {
  _FakeSttSource({
    required this.kind,
    this.language = 'vi',
    this.ready = true,
    this.startSucceeds = true,
    this.reason,
    this.throwOnStart,
  });

  @override
  final QuickCaptureEngineKind kind;

  @override
  final String language;

  final bool ready;
  final bool startSucceeds;
  final String? reason;
  final Object? throwOnStart;

  final StreamController<SttResult> _controller =
      StreamController<SttResult>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;
  int releaseCalls = 0;
  String? _error;

  @override
  bool get isReady => ready;

  @override
  String? get unavailableReason => reason;

  @override
  Stream<SttResult> get results => _controller.stream;

  @override
  String? get lastError => _error;

  @override
  Future<bool> start() async {
    startCalls++;
    if (throwOnStart != null) throw throwOnStart!;
    if (!startSucceeds) {
      _error = 'fake start failure';
      return false;
    }
    return true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> release() async {
    releaseCalls++;
  }

  void emit(String text, {bool isFinal = false}) {
    _controller.add(
      SttResult(
        fullText: text,
        segments: const [],
        engineUsed: SttEngineType.sherpa,
        language: language,
        processingTime: Duration.zero,
        audioFingerprint: '',
        isFinal: isFinal,
      ),
    );
  }

  Future<void> close() => _controller.close();
}

/// Kho key-value in-memory thay cho StorageService (không cần Hive box).
class _MemoryKv {
  final Map<String, String?> values = <String, String?>{};

  String? read(String key) => values[key];

  Future<void> write(String key, String? value) async {
    values[key] = value;
  }
}

WordEntry _word(
  String text, {
  bool due = false,
  String meaning = '',
  String? phonetic,
  String language = 'vi',
}) {
  final future = DateTime.now().add(const Duration(days: 9));
  final notDue = SkillReviewData(nextReview: future);
  return WordEntry(
    id: 'w_${text.hashCode}',
    word: text,
    meaning: meaning,
    phonetic: phonetic,
    language: language,
    understandData: due ? SkillReviewData() : SkillReviewData(nextReview: future),
    listenData: due ? SkillReviewData() : notDue,
    readData: due ? SkillReviewData() : notDue,
  );
}

void main() {
  // ───────────────────────────────────────────────────────────────────────
  group('QuickCaptureLanguagePolicy', () {
    test('dùng ngôn ngữ app khi máy đã có model Sherpa cho nó', () {
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: 'en',
          sherpaLanguages: ['en', 'vi'],
        ),
        'en',
      );
    });

    test('KHÔNG ép English khi máy chỉ import model VI', () {
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: 'en',
          sherpaLanguages: ['vi'],
        ),
        'vi',
      );
    });

    test('không có model Sherpa → dùng ngôn ngữ app cho system STT', () {
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: 'ja',
          sherpaLanguages: const [],
        ),
        'ja',
      );
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: '',
          sherpaLanguages: const [],
        ),
        QuickCaptureLanguagePolicy.fallbackLearningLanguage,
      );
    });

    test('máy chỉ có model ngôn ngữ khác → dùng model đã cài', () {
      expect(
        QuickCaptureLanguagePolicy.resolve(
          appLanguage: 'de',
          sherpaLanguages: ['en'],
        ),
        'en',
      );
    });

    test('map locale BCP-47 cho speech service hệ thống', () {
      expect(QuickCaptureLanguagePolicy.toSystemLocale('vi'), 'vi-VN');
      expect(QuickCaptureLanguagePolicy.toSystemLocale('en'), 'en-US');
      expect(QuickCaptureLanguagePolicy.toSystemLocale('hi'), 'hi-IN');
      expect(QuickCaptureLanguagePolicy.toSystemLocale(''), 'en-US');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('QuickCaptureController', () {
    test('ưu tiên Sherpa offline khi khả dụng, không đụng system STT',
        () async {
      final sherpa = _FakeSttSource(kind: QuickCaptureEngineKind.sherpaOffline);
      final system = _FakeSttSource(
        kind: QuickCaptureEngineKind.system,
        language: 'vi',
      );
      final controller = QuickCaptureController(sources: [sherpa, system]);

      final ok = await controller.start();

      expect(ok, isTrue);
      expect(controller.isListening, isTrue);
      expect(controller.engineKind, QuickCaptureEngineKind.sherpaOffline);
      expect(controller.engineLanguage, 'vi');
      expect(sherpa.startCalls, 1);
      expect(system.startCalls, 0);

      await controller.stop();
      controller.dispose();
      await sherpa.close();
      await system.close();
    });

    test('Sherpa chưa có model → fallback system STT + ghi lý do', () async {
      final sherpa = _FakeSttSource(
        kind: QuickCaptureEngineKind.sherpaOffline,
        ready: false,
        reason: 'Sherpa VI: chưa import model Zipformer',
      );
      final system = _FakeSttSource(kind: QuickCaptureEngineKind.system);
      final controller = QuickCaptureController(sources: [sherpa, system]);

      final ok = await controller.start();

      expect(ok, isTrue);
      expect(controller.engineKind, QuickCaptureEngineKind.system);
      expect(sherpa.startCalls, 0);
      expect(system.startCalls, 1);
      expect(controller.unavailableDetail, contains('Zipformer'));

      await controller.stop();
      controller.dispose();
      await sherpa.close();
      await system.close();
    });

    test('không engine nào sẵn sàng → lỗi noEngineAvailable (không im lặng)',
        () async {
      final sherpa = _FakeSttSource(
        kind: QuickCaptureEngineKind.sherpaOffline,
        ready: false,
        reason: 'thiếu model',
      );
      final controller = QuickCaptureController(sources: [sherpa]);

      final ok = await controller.start();

      expect(ok, isFalse);
      expect(controller.status, QuickCaptureStatus.error);
      expect(controller.failure, QuickCaptureFailure.noEngineAvailable);
      expect(controller.failureDetail, contains('thiếu model'));

      controller.dispose();
      await sherpa.close();
    });

    test('từ chối quyền mic → không bật engine nào', () async {
      final sherpa = _FakeSttSource(kind: QuickCaptureEngineKind.sherpaOffline);
      final controller = QuickCaptureController(
        sources: [sherpa],
        ensureMicrophonePermission: () async => false,
      );

      final ok = await controller.start();

      expect(ok, isFalse);
      expect(controller.failure, QuickCaptureFailure.microphonePermission);
      expect(sherpa.startCalls, 0);
      expect(controller.status, QuickCaptureStatus.error);

      controller.dispose();
      await sherpa.close();
    });

    test('engine start thất bại → báo startFailed kèm lỗi engine', () async {
      final source = _FakeSttSource(
        kind: QuickCaptureEngineKind.system,
        startSucceeds: false,
      );
      final controller = QuickCaptureController(sources: [source]);

      final ok = await controller.start();

      expect(ok, isFalse);
      expect(controller.failure, QuickCaptureFailure.startFailed);
      expect(controller.failureDetail, 'fake start failure');
      // nguồn fail phải được dọn (stop + release), không để mic treo
      expect(source.stopCalls, 1);
      expect(source.releaseCalls, 1);

      controller.dispose();
      await source.close();
    });

    test('gom transcript realtime: partial → final, bỏ final trùng', () async {
      final source = _FakeSttSource(kind: QuickCaptureEngineKind.sherpaOffline);
      final controller = QuickCaptureController(sources: [source]);
      await controller.start();

      source.emit('Xin chào');
      await Future<void>.delayed(Duration.zero);
      expect(controller.transcript, 'Xin chào');
      expect(controller.partialText, 'Xin chào');
      expect(controller.finalSegments, isEmpty);

      source.emit('Xin chào các bạn');
      await Future<void>.delayed(Duration.zero);
      expect(controller.transcript, 'Xin chào các bạn');

      source.emit('Xin chào các bạn', isFinal: true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.finalSegments, ['Xin chào các bạn']);
      expect(controller.partialText, isEmpty);
      expect(controller.transcript, 'Xin chào các bạn');

      // engine phát lại cùng câu final (VAD flush khi dừng) → không lặp
      source.emit('Xin chào các bạn', isFinal: true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.finalSegments, ['Xin chào các bạn']);

      source.emit('Hôm nay trời đẹp', isFinal: true);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.transcript,
        'Xin chào các bạn Hôm nay trời đẹp',
      );
      expect(controller.hasTranscript, isTrue);

      await controller.stop();
      controller.dispose();
      await source.close();
    });

    test('dừng sạch: giữ transcript, tắt engine, bỏ kết quả đến sau', () async {
      final source = _FakeSttSource(kind: QuickCaptureEngineKind.sherpaOffline);
      final controller = QuickCaptureController(sources: [source]);
      await controller.start();

      source.emit('Câu đầu tiên', isFinal: true);
      await Future<void>.delayed(Duration.zero);

      await controller.stop();

      expect(controller.status, QuickCaptureStatus.idle);
      expect(controller.isListening, isFalse);
      expect(source.stopCalls, 1);
      expect(controller.transcript, 'Câu đầu tiên');

      // kết quả đến sau khi dừng không được ghép vào transcript
      source.emit('không được nhận');
      await Future<void>.delayed(Duration.zero);
      expect(controller.transcript, 'Câu đầu tiên');

      controller.dispose();
      await source.close();
    });

    test('dispose (UI đóng sheet) cũng dừng mic + release engine', () async {
      final source = _FakeSttSource(kind: QuickCaptureEngineKind.sherpaOffline);
      final controller = QuickCaptureController(sources: [source]);
      await controller.start();
      expect(source.stopCalls, 0);

      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(source.stopCalls, 1);
      expect(source.releaseCalls, 1);
      await source.close();
    });

    test('clearTranscript / restoreTranscript phục vụ nút dùng lại ghi chú',
        () async {
      final source = _FakeSttSource(kind: QuickCaptureEngineKind.system);
      final controller = QuickCaptureController(sources: [source]);
      await controller.start();
      source.emit('nội dung cũ', isFinal: true);
      await Future<void>.delayed(Duration.zero);

      controller.restoreTranscript('  ghi chú đã lưu  ');
      expect(controller.transcript, 'ghi chú đã lưu');

      controller.clearTranscript();
      expect(controller.transcript, isEmpty);
      expect(controller.hasTranscript, isFalse);

      await controller.stop();
      controller.dispose();
      await source.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('QuickSuggestionPicker', () {
    test('WordList rỗng → null (UI hiện empty state có hướng dẫn)', () {
      expect(
        QuickSuggestionPicker.pick(entries: const [], random: Random(1)),
        isNull,
      );
      expect(
        QuickSuggestionPicker.pick(
          entries: [_word('   ')],
          random: Random(1),
        ),
        isNull,
      );
    });

    test('ưu tiên thẻ đến kỳ ôn hơn từ chưa đến kỳ', () {
      final due = _word('từ đến kỳ', due: true);
      final notDue = _word('từ chưa đến kỳ');

      for (var seed = 0; seed < 12; seed++) {
        final picked = QuickSuggestionPicker.pick(
          entries: [notDue, due],
          random: Random(seed),
        );
        expect(picked, isNotNull);
        expect(picked!.entry.word, 'từ đến kỳ');
        expect(picked.dueForReview, isTrue);
      }
    });

    test('nhiều thẻ đến kỳ → vẫn là một entry thật trong danh sách', () {
      final entries = [
        _word('a', due: true),
        _word('b', due: true),
        _word('c', due: true),
        _word('d'),
      ];
      final seen = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final picked =
            QuickSuggestionPicker.pick(entries: entries, random: Random(seed));
        expect(entries.map((e) => e.word), contains(picked!.word));
        expect(picked.dueForReview, isTrue);
        seen.add(picked.word);
      }
      // không dính cứng một từ duy nhất
      expect(seen.length, greaterThan(1));
    });

    test('không có thẻ đến kỳ → chọn ngẫu nhiên trong WordList', () {
      final entries = [_word('x'), _word('y'), _word('z')];
      final picked =
          QuickSuggestionPicker.pick(entries: entries, random: Random(7));
      expect(picked, isNotNull);
      expect(picked!.dueForReview, isFalse);
      expect(entries.map((e) => e.word), contains(picked.word));
    });

    test('entry mang đủ word/IPA/meaning cho UI', () {
      final picked = QuickSuggestionPicker.pick(
        entries: [
          _word('hiểu', meaning: 'to understand', phonetic: '/hieu˧˩/'),
        ],
        random: Random(3),
      );
      expect(picked!.word, 'hiểu');
      expect(picked.phonetic, '/hieu˧˩/');
      expect(picked.meaning, 'to understand');
      expect(picked.hasPhonetic, isTrue);
      expect(picked.hasMeaning, isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('QuickCaptureNoteStore', () {
    test('round-trip: thêm → đọc lại → xoá', () async {
      final kv = _MemoryKv();
      final store = QuickCaptureNoteStore(read: kv.read, write: kv.write);

      expect(store.load(), isEmpty);

      final first = await store.add(
        'Câu nói đầu tiên',
        language: 'vi',
        now: DateTime(2026, 9, 16, 8, 0),
      );
      final second = await store.add(
        'Câu nói thứ hai',
        language: 'vi',
        now: DateTime(2026, 9, 16, 9, 30),
      );

      expect(first, isNotNull);
      expect(second, isNotNull);

      final notes = store.load();
      expect(notes.length, 2);
      // mới nhất trước
      expect(notes.first.text, 'Câu nói thứ hai');
      expect(notes.last.text, 'Câu nói đầu tiên');
      expect(notes.first.language, 'vi');

      await store.delete(second!.id);
      expect(store.load().map((n) => n.text), ['Câu nói đầu tiên']);
    });

    test('nội dung rỗng không tạo ghi chú', () async {
      final kv = _MemoryKv();
      final store = QuickCaptureNoteStore(read: kv.read, write: kv.write);

      expect(await store.add('   '), isNull);
      expect(store.load(), isEmpty);
    });

    test('dữ liệu hỏng trong storage → danh sách rỗng, không ném', () {
      final kv = _MemoryKv()..values[QuickCaptureNoteStore.storageKey] = '{oops';
      final store = QuickCaptureNoteStore(read: kv.read, write: kv.write);

      expect(store.load(), isEmpty);
    });

    test('giới hạn số ghi chú giữ lại', () async {
      final kv = _MemoryKv();
      final store = QuickCaptureNoteStore(
        read: kv.read,
        write: kv.write,
        maxNotes: 3,
      );
      for (var i = 0; i < 5; i++) {
        await store.add('ghi chú $i', now: DateTime(2026, 9, 16, 10, i));
      }
      final notes = store.load();
      expect(notes.length, 3);
      expect(notes.first.text, 'ghi chú 4');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  group('QuickCaptureSaver + WordList thật (Hive temp)', () {
    late Directory tempDir;
    late VocabularyProvider provider;
    late QuickCaptureSaver saver;
    late _MemoryKv kv;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('in4up_home_quick_test');
      Hive.init(tempDir.path);
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    setUp(() async {
      provider = VocabularyProvider();
      await provider.loadData();
      VocabularyBridge.init(provider);
      kv = _MemoryKv();
      saver = QuickCaptureSaver(
        notes: QuickCaptureNoteStore(read: kv.read, write: kv.write),
      );
    });

    tearDown(() async {
      await provider.clearAllData();
    });

    test('lưu transcript → entry THẬT trong WordList (mở lại vẫn còn)',
        () async {
      expect(saver.isWordListReady, isTrue);

      final result = saver.saveToWordList(
        text: '  Hôm nay tôi học tiếng Việt  ',
        language: 'vi',
      );

      expect(result.success, isTrue);
      expect(result.isNewEntry, isTrue);
      expect(result.entry, isNotNull);
      expect(result.entry!.word, 'Hôm nay tôi học tiếng Việt');
      expect(result.entry!.language, 'vi');
      expect(
        result.entry!.vocabType,
        VocabularyType.sentence,
        reason: 'câu nhiều từ phải được phân loại sentence, không phải word',
      );
      expect(result.entry!.contexts, hasLength(1));
      expect(result.entry!.contexts.single.sourceType, 'manual');
      expect(
        result.entry!.contexts.single.surroundingText,
        'Hôm nay tôi học tiếng Việt',
      );

      // hiện ngay trong provider đang sống (= WordList đang mở)
      expect(provider.hasWord('Hôm nay tôi học tiếng Việt'), isTrue);

      // và vẫn còn sau khi nạp lại từ Hive (restart app)
      final reopened = VocabularyProvider();
      await reopened.loadData();
      expect(reopened.hasWord('Hôm nay tôi học tiếng Việt'), isTrue);
      final reloaded = reopened.findByWord('Hôm nay tôi học tiếng Việt')!;
      expect(reloaded.language, 'vi');
      expect(reloaded.contexts, hasLength(1));
    });

    test('nói lại câu đã lưu → bổ sung ngữ cảnh, không nhân đôi entry', () {
      saver.saveToWordList(text: 'Chào bạn', language: 'vi');
      final again = saver.saveToWordList(text: 'Chào bạn', language: 'vi');

      expect(again.success, isTrue);
      expect(again.isNewEntry, isFalse);
      expect(
        provider.allWords
            .where((w) => w.word.toLowerCase() == 'chào bạn')
            .length,
        1,
      );
      expect(again.entry!.contexts.length, greaterThanOrEqualTo(2));
    });

    test('transcript rỗng → không lưu', () {
      final result = saver.saveToWordList(text: '   ', language: 'vi');
      expect(result.success, isFalse);
      expect(result.reason, 'empty_transcript');
      expect(provider.allWords, isEmpty);
    });

    test('lưu ghi chú nói → đọc lại được từ kho ghi chú', () async {
      final note = await saver.saveNote(
        text: ' Ý tưởng cho bài viết ngày mai ',
        language: 'vi',
      );

      expect(note, isNotNull);
      expect(note!.text, 'Ý tưởng cho bài viết ngày mai');

      final notes = saver.notes.load();
      expect(notes, hasLength(1));
      expect(notes.single.id, note.id);
      expect(notes.single.preview, 'Ý tưởng cho bài viết ngày mai');

      // ghi chú KHÔNG tự biến thành từ vựng
      expect(provider.allWords, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  testWidgets('HebbianInputCard: hai nút nối flow thật + chrome theo locale',
      (tester) async {
    var captureTaps = 0;
    var suggestionTaps = 0;

    await tester.pumpWidget(
      material.MaterialApp(
        locale: const material.Locale('en'),
        supportedLocales: const [
          material.Locale('en'),
          material.Locale('vi'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: material.Scaffold(
          body: HebbianInputCard(
            onStartVoiceCapture: () => captureTaps++,
            onShowSuggestion: () => suggestionTaps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rule #5: locale ≠ vi → chrome không còn tiếng Việt
    expect(find.text('QUICK KNOWLEDGE INPUT'), findsOneWidget);
    expect(find.text('Voice note'), findsOneWidget);
    expect(find.text('Suggest'), findsOneWidget);
    expect(find.text('NẠP TRI THỨC NHANH'), findsNothing);

    await tester.tap(find.text('Voice note'));
    await tester.pump();
    expect(captureTaps, 1);
    expect(suggestionTaps, 0);

    await tester.tap(find.text('Suggest'));
    await tester.pump();
    expect(suggestionTaps, 1);
  });
}
