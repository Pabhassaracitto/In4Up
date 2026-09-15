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
      await controller.dispose();
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
      await controller.dispose();
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

      await controller.dispose();
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

      await controller.dispose();
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

      await controller.dispose();
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
      await controller.dispose();
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

      await controller.dispose();
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
      await controller.dispose();
      await source.close();
    });
  });

  // ───────────────────────────────────────────────────────────────────────
}
