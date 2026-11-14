// AUDIT-1.21.0 — máy bắt cho phần code KHÔNG chạy được trên host VM
// (native Kotlin, overlay, provider..., theo pattern source-scan pin sẵn có
// trong test/cabin/cabin_audio_completeness_test.dart).
//
// Mỗi `contains` dưới đây là một bước sửa; ai gỡ là CI đỏ ngay. Các bài test
// THUẦN logic nằm ở các file riêng cùng đợt (overlay_layout_audit_test.dart,
// cabin_finalization_dedup_test.dart, pdf_open_preflight_test.dart, ...).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/loop_presets.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Thiếu file để pin: $path');
  return file.readAsStringSync();
}

/// Bỏ comment TRƯỚC khi quét: nếu không, một chú thích nhắc tới tên biến cũ
/// sẽ làm pin "đã xoá biến X" báo đỏ sai (bài học PSRC-179 lần đầu chạy CI).
String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
  return withoutBlocks
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx >= 0 ? line.substring(0, idx) : line;
      })
      .join('\n');
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
  final abControls = _read('lib/widgets/ab_loop_controls.dart');
  final loopMixin = _read('lib/providers/player/player_loop_mixin.dart');

  // Pin trên source ĐÃ BỎ COMMENT: chú thích "KHÔNG setMaxLines" không được
  // làm pin "đã xoá setMaxLines" báo đỏ sai.
  final overlayCode = _stripComments(overlay);

  group('#1 — overlay nhiều khối', () {
    test('native KHÔNG còn phình khung xuống dưới', () {
      expect(overlayCode.contains('val boxHeight = maxOf('), isFalse);
      expect(overlayCode.contains('canvas.clipRect('), isTrue);
      // XLAT-SCR-006 (owner 2026-11-11): ellipsize "…" bị BÁC — nó làm mất
      // nội dung bản dịch. Không vừa khung ⇒ bỏ vẽ khối, để lộ chữ gốc.
      expect(overlayCode.contains('TextUtils.TruncateAt.END'), isFalse,
          reason: 'Cắt chữ bằng "…" = mất nội dung owner đã bác.');
      expect(overlayCode.contains('setMaxLines'), isFalse,
          reason: 'Giới hạn số dòng cũng là cắt chữ.');
      // Hợp đồng mới: không vừa khung ⇒ BỎ VẼ + log, KHÔNG cắt.
      expect(overlayCode.contains('buildLayout('), isTrue);
      expect(overlayCode.contains('continue'), isTrue);
      expect(overlayCode.contains('LOG_TAG'), isTrue);
      // Cỡ chữ phải đi qua TypedValue(SP) — khớp `fontScale` bên Dart.
      expect(overlayCode.contains('TypedValue.applyDimension'), isTrue);
    });
    test('native không bỏ khối khi chữ không vừa: vẽ chip (PSRC-211 vòng 2)', () {
      // Bản trước `continue` ⇒ khối biến mất khỏi màn hình. Giờ phải vẽ chip.
      expect(overlayCode.contains('drawCollapsedChip('), isTrue);
      expect(overlayCode.contains('chipWidthPx()'), isTrue);
      expect(overlayCode.contains('chipHeightPx()'), isTrue);
      // Vẫn KHÔNG được cắt chữ để nhét cho vừa.
      expect(overlayCode.contains('TruncateAt.END'), isFalse);
    });

    test('controller gọi layout + bỏ khối OCR chỉ có link', () {
      expect(controller.contains('layoutTranslatedBlocks('), isTrue);
      expect(controller.contains('isLinkOnlyText('), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // PSRC-211 vòng 2 — § 7 ports từ nhánh tham chiếu `490294ed` + chuỗi UI mới.
  // Phần Kotlin không biên dịch/test được trên host VM ⇒ pin bằng source-scan
  // (gỡ ra là CI đỏ ngay). Máy bắt hành vi nằm ở test/screen_translate/.
  // ───────────────────────────────────────────────────────────────────────
  final serviceCode = _stripComments(
    _read(
      'android/app/src/main/kotlin/com/in4up/screentranslate/'
      'ScreenTranslateService.kt',
    ),
  );
  final regionCode = _stripComments(
    _read(
      'android/app/src/main/kotlin/com/in4up/screentranslate/'
      'RegionSelectView.kt',
    ),
  );

  group('PSRC-211 vòng 2 — § 7 (port từ 490294ed)', () {
    test('cửa sổ overlay phủ cả tai thỏ / thanh điều hướng', () {
      expect(serviceCode.contains('layoutInDisplayCutoutMode'), isTrue);
      expect(
        serviceCode
            .contains('LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS'),
        isTrue,
      );
      expect(serviceCode.contains('fitInsetsTypes = 0'), isTrue);
      expect(serviceCode.contains('maximumWindowMetrics'), isTrue);
    });

    test('xoay máy/đổi kích thước làm mới VirtualDisplay', () {
      expect(serviceCode.contains('syncWarmDisplayIfSizeChanged()'), isTrue);
      expect(serviceCode.contains('onConfigurationChanged'), isTrue);
    });

    test('chọn vùng: quy đổi getLocationOnScreen trước khi trả khung', () {
      expect(regionCode.contains('getLocationOnScreen'), isTrue);
      final i = regionCode.indexOf('getLocationOnScreen');
      expect(i, greaterThan(-1));
      // Chỉ 400 ký tự sau lời gọi: đủ để thấy `offset(...)` ngay dưới nó. Kẹp
      // lại theo độ dài file — file ngắn mà cắt quá tay là RangeError.
      final end = i + 400 > regionCode.length ? regionCode.length : i + 400;
      expect(
        regionCode.substring(i, end).contains('offset('),
        isTrue,
        reason: 'thiếu offset ⇒ khung chọn lệch đúng phần tai thỏ/status bar',
      );
    });

    test('controller lọc số/ký hiệu/link TRƯỚC khi cắt hạn mức 32', () {
      final iWorth = controller.indexOf('worthTranslating');
      final iRank = controller.indexOf('rankBlocksForTranslate(');
      expect(iWorth, greaterThan(-1));
      expect(iRank, greaterThan(iWorth),
          reason: 'xếp hạng phải chạy trên tập đã lọc, không phải toàn bộ khối');
      expect(controller.contains('const int kScreenTranslateMaxBlocks = 32;'),
          isTrue,
          reason: 'trần khối vẫn là 32 — hub § 4 bác phương án 64');
    });
  });

  group('PSRC-211 vòng 2 — chuỗi native đủ 8 locale', () {
    const locales = <String>[
      'hi',
      'zh-rCN',
      'zh-rTW',
      'si',
      'my',
      'th',
      'ja',
    ];
    const names = <String>[
      'screen_translate_collapsed_title',
      'screen_translate_collapsed_note',
      'screen_translate_pending_chip',
      'screen_translate_pending_tap',
    ];
    test('mỗi locale có đủ 4 chuỗi chip thu gọn / Dịch tiếp', () {
      for (final locale in locales) {
        final file = _read(
          'android/app/src/main/res/values-$locale/'
          'strings_screen_translate.xml',
        );
        for (final name in names) {
          expect(file.contains('name="$name"'), isTrue,
              reason: 'values-$locale thiếu $name');
        }
        // `%1$d` phải còn nguyên: chuỗi mất placeholder ⇒ chip không có số.
        expect(file.contains(r'%1$d'), isTrue,
            reason: 'values-$locale mất placeholder số khối');
      }
    });

    test('chip "Dịch tiếp" có nhãn trợ năng riêng (không đọc chữ trên chip)',
        () {
      expect(
        serviceCode.contains('screen_translate_pending_tap'),
        isTrue,
        reason: 'thiếu contentDescription ⇒ TalkBack đọc "còn N khối" mà '
            'không nói bấm để làm gì',
      );
    });

    test('bản tiếng Anh mặc định + tiếng Việt có cùng bộ khoá', () {
      for (final path in <String>[
        'android/app/src/main/res/values/strings_screen_translate.xml',
        'android/app/src/main/res/values-vi/strings_screen_translate.xml',
      ]) {
        final file = _read(path);
        for (final name in names) {
          expect(file.contains('name="$name"'), isTrue,
              reason: '$path thiếu $name');
        }
      }
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
    test('recheck Cabin: câu bị bỏ qua không bị nhớ ⇒ không mất câu', () {
      expect(cabin.contains('_deduper.finish('), isTrue);
      expect(cabin.contains('createdCaption: outcome.createdCaption'), isTrue);
      expect(cabin.contains('outcome?.createdCaption = true;'), isTrue);
      expect(cabin.contains('_deduper.complete(text)'), isFalse,
          reason: 'complete() mù quáng ở whenComplete từng nuốt replay final');
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
    test('chip dùng CÙNG setter với dropdown có sẵn (không lệch repeatTrack)',
        () {
      // `setLoopCount()` khác `setMaxLoopCount()` ở chỗ bật/tắt `_repeatTrack`
      // khi chưa có `loopStart`; đổi riêng chip sẽ làm 2 control lệch nhau.
      expect(abControls.contains('player.setMaxLoopCount(value)'), isTrue);
      expect(listen.contains('onChanged: player.setMaxLoopCount'), isTrue);
      expect(abControls.contains('setLoopCount('), isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // PSRC-178 — nhãn "lặp phần tiếp theo" phải khớp VIỆC NÓ LÀM:
  //   có lời (LRC)  ⇒ nhảy sang **câu** kế tiếp theo mốc thời gian;
  //   chưa có lời    ⇒ dịch một **đoạn** cùng độ dài A–B, bắt đầu tại B.
  // Nhãn cũ "Lặp câu tiếp" cho cả hai trường hợp khiến người dùng tưởng app
  // nhảy sai khi file chưa có lời.
  // ───────────────────────────────────────────────────────────────────────
  final abControlsCode = _stripComments(abControls);
  final listenCode = _stripComments(listen);
  final loopMixinCode = _stripComments(loopMixin);

  group('PSRC-178 — nhãn nút lặp phần tiếp theo', () {
    test('hàm nhãn thuần: có lời → "câu", không lời → "đoạn"', () {
      expect(LoopPresets.nextRepeatLabel(hasLyrics: true), 'Lặp câu tiếp');
      expect(LoopPresets.nextRepeatLabel(hasLyrics: false), 'Lặp đoạn tiếp');
    });

    test('nút A–B dùng hàm nhãn + đọc trạng thái lời', () {
      expect(abControlsCode.contains('LoopPresets.nextRepeatLabel('), isTrue);
      expect(abControlsCode.contains('lrcLines.isNotEmpty'), isTrue);
      // Hard-code nhãn cũ ⇒ file chưa có lời vẫn ghi "câu" (đúng lỗi PSRC-178).
      expect(abControlsCode.contains("label: 'Lặp câu tiếp'"), isFalse);
    });

    test('rule #5 — 2 nhãn có đủ 8 locale + English fallback', () {
      final pack = jsonDecode(_read('tool/priority_native_pack.json'))
          as Map<String, dynamic>;
      final overrides = jsonDecode(_read('tool/legacy_ui_english_overrides.json'))
          as Map<String, dynamic>;
      final vietnamese =
          RegExp(r'[đĐơƠưƯảạằắẳẵặầấẩẫậẻẽẹềếểễệỉĩịỏọồốổỗộờớởỡợủũụừứửữựỳỷỹỵ]');
      for (final key in ['Lặp câu tiếp', 'Lặp đoạn tiếp']) {
        final entry = pack[key];
        expect(entry, isNotNull, reason: 'thiếu "$key" trong pack ưu tiên');
        final values = (entry as Map).cast<String, String>();
        for (final locale in [
          'en',
          'zh',
          'zh_TW',
          'hi',
          'si',
          'my',
          'th',
          'ja',
        ]) {
          expect(values[locale], isNotNull,
              reason: '"$key" thiếu locale $locale');
          if (locale == 'en') continue;
          expect(vietnamese.hasMatch(values[locale]!), isFalse,
              reason: '"$key" [$locale] còn chữ Việt');
        }
        expect(overrides[key], isNotNull,
            reason: '"$key" thiếu English fallback cho locale chưa dịch');
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // PSRC-179 — "khoảng lặng" của popup A–B ngoài và slider trong sheet "Thêm"
  // phải là MỘT nguồn: `gapDuration`. Bản cũ có thêm `_silenceDuration` mà
  // engine không đọc ⇒ chip ở ngoài vô tác dụng và hai chỗ hiển thị lệch nhau.
  // ───────────────────────────────────────────────────────────────────────
  group('PSRC-179 — khoảng lặng đồng bộ một nguồn', () {
    test('không còn biến khoảng lặng thứ hai', () {
      expect(loopMixinCode.contains('_silenceDuration'), isFalse);
    });

    test('silenceDuration đọc từ gapDuration, setter đi qua setGapDuration', () {
      final iGetter = loopMixinCode.indexOf('Duration get silenceDuration');
      expect(iGetter, greaterThan(-1));
      expect(
        loopMixinCode.substring(iGetter, loopMixinCode.indexOf(';', iGetter)),
        contains('_gapDuration'),
      );
      final iSetter = loopMixinCode.indexOf('void setSilenceDuration(');
      expect(iSetter, greaterThan(-1));
      expect(
        loopMixinCode.substring(iSetter, loopMixinCode.indexOf('\n  }', iSetter)),
        contains('setGapDuration('),
      );
    });

    test('chip khoảng lặng ở popup A–B ghi vào gapDuration', () {
      final iBox = listenCode.indexOf('class _SilenceOptionsBox');
      expect(iBox, greaterThan(-1));
      final box = listenCode.substring(iBox);
      expect(box.contains('player.setGapDuration('), isTrue);
      expect(box.contains('setSilenceDuration('), isFalse);
    });

    test('nút mở panel hiện giá trị đang dùng (không phải mở ra mới biết)', () {
      final iPanel = listenCode.indexOf('class _ABLoopWithSilencePanel');
      final iBox = listenCode.indexOf('class _SilenceOptionsBox');
      expect(iPanel, greaterThan(-1));
      expect(listenCode.substring(iPanel, iBox).contains('player.gapDuration'),
          isTrue);
    });
  });
}
