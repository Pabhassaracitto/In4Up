// AUDIT-1.21.0 — máy bắt cho phần code KHÔNG chạy được trên host VM
// (native Kotlin, overlay, provider..., theo pattern source-scan pin sẵn có
// trong test/cabin/cabin_audio_completeness_test.dart).
//
// Mỗi `contains` dưới đây là một bước sửa; ai gỡ là CI đỏ ngay. Các bài test
// THUẦN logic nằm ở các file riêng cùng đợt (overlay_layout_audit_test.dart,
// cabin_finalization_dedup_test.dart, pdf_open_preflight_test.dart, ...).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Thiếu file để pin: $path');
  return file.readAsStringSync();
}

void main() {
  final overlay = _read(
    'android/app/src/main/kotlin/com/in4up/screentranslate/TranslationOverlayView.kt',
  );
  final controller = _read(
    'lib/features/screen_translate/screen_translate_controller.dart',
  );
  final cabin = _read('lib/features/cabin/services/stts_cabin_service.dart');
  final pdfScreen =
      _read('lib/features/pdf_reader/pdf_reader_screen.dart');
  final library =
      _read('lib/screens/read_mode/widgets/library_screen.dart');
  final wordPop =
      _read('lib/screens/read_mode/widgets/word_mini_pop.dart');
  final deeplx = _read('lib/features/translation/engines/deeplx_engine.dart');
  final service = _read('lib/features/translation/translation_service.dart');
  final toolbar = _read('lib/features/translation/translation_toolbar.dart');
  final piper = _read('lib/features/tts/engines/piper_tts_engine.dart');
  final sttMixin = _read('lib/providers/player/player_stt_mixin.dart');
  final listen = _read('lib/screens/listen_mode/listen_mode_screen.dart');
  final presets = _read('lib/models/loop_presets.dart');

  group('#1 — overlay nhiều khối', () {
    test('native KHÔNG còn phình khung xuống dưới', () {
      expect(overlay.contains('val boxHeight = maxOf('), isFalse);
      expect(overlay.contains('canvas.clipRect('), isTrue);
      expect(overlay.contains('TextUtils.TruncateAt.END'), isTrue);
    });
    test('controller gọi layout + bỏ khối OCR chỉ có link', () {
      expect(controller.contains('layoutTranslatedBlocks('), isTrue);
      expect(controller.contains('isLinkOnlyText('), isTrue);
    });
  });

  group('#2 + #7 — cụm model/offline', () {
    test('Piper có preflight trước mọi lời gọi native', () {
      expect(piper.contains('assessOfflineModel('), isTrue);
      expect(piper.contains('[TTS-NATIVE]'), isTrue);
    });
    test('đường tạo LRC sherpa có preflight riêng', () {
      expect(sttMixin.contains('_sherpaLrcPreflight('), isTrue);
      expect(sttMixin.contains('asrFilesPlausible('), isTrue);
    });
    test('chip offline tự tắt khi model biến mất', () {
      expect(listen.contains('_sherpaVerdict('), isTrue);
      expect(listen.contains('if (_useSherpa && _sherpaLanguages().isEmpty)'),
          isTrue);
    });
  });

  group('#3 — Cabin', () {
    test('deduper được nối vào finalization, bỏ delayed 3s', () {
      expect(cabin.contains('CabinFinalizationDeduper'), isTrue);
      expect(cabin.contains('_deduper.begin(text)'), isTrue);
      expect(cabin.contains('whenComplete('), isTrue);
      expect(cabin.contains('Future.delayed(const Duration(seconds: 3)'),
          isFalse);
    });
  });

  group('#4 — PDF «Gần đây»', () {
    test('preflight ở cả thư viện lẫn màn đọc', () {
      expect(library.contains('inspectPdfForOpen('), isTrue);
      expect(pdfScreen.contains('inspectPdfForOpen('), isTrue);
      expect(pdfScreen.contains('pdfFriendlyError('), isTrue);
    });
  });

  group('#5 — pop từ vựng tab Đọc', () {
    test('4 chip Dễ / Vừa / Khó / Rất khó + lưu phân loại', () {
      expect(wordPop.contains('kWordMiniPopDifficultyLabels'), isTrue);
      expect(wordPop.contains("'Vừa'"), isTrue);
      expect(wordPop.contains('DifficultyLevel.values'), isTrue);
      expect(wordPop.contains('markWordDifficulty('), isTrue);
      expect(wordPop.contains('_buildDifficultyChips(context)'), isTrue);
    });
  });

  group('#6 — link / DeepLX', () {
    test('engine + service + toolbar cùng dùng một verdict', () {
      expect(deeplx.contains('assessDeepLXEndpoint(serverUrl)'), isTrue);
      expect(service.contains('isLinkOnlyText(trimmed)'), isTrue);
      expect(service.contains('deeplxConfigError'), isTrue);
      expect(toolbar.contains('assessDeepLXEndpoint(raw)'), isTrue);
    });
    test('nút Thử kết nối luôn hạ cờ (không kẹt)', () {
      expect(toolbar.contains('_testingDeeplx = false;'), isTrue);
    });
  });

  group('#8 — A-B loop', () {
    test('chỉ 1 ∞ + điều khiển ngay popup bên ngoài', () {
      expect(presets.contains('[-1, 0, 1, 3, 5, 7, 10, 15, 20]'), isFalse);
      expect(listen.contains('LoopCountChips('), isTrue);
      expect(listen.contains('_ABLoopWithSilencePanel'), isTrue);
    });
  });
}
