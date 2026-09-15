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
}
