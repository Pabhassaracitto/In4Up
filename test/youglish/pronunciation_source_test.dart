// test/youglish/pronunciation_source_test.dart
//
// PRON-002 — cổng CI của "nguồn phát âm".
//
// Vì sao test thuần Dart + scan nguồn mà KHÔNG có widget test: `4b4965f` ghi
// lại bài học run 40229976121 — widget test chạm plugin (webview/Hive) TREO
// >8 phút trên runner ⇒ machine-check của PRON phải chạy được bằng logic thuần.
// Nghiệm thu thật trên thiết bị do owner chạy (KANBAN PRON-002).
//
// Hai nhóm:
//   1) `PronunciationSourcePolicy` — bảng sự thật của D1 (nguồn nào được chọn,
//      bật thoái lui) mà mọi surface trong app dùng chung.
//   2) Scan nguồn — các ràng buộc KHÔNG đo được bằng logic: WebView chỉ dựng
//      khi bấm, pop dismiss trước khi mở sheet, kill-switch tắt là ẩn hẳn,
//      chrome mới phải có 'en' (rule #5 trong AGENTS.md).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/word_lookup/pronunciation_source.dart';

const _kRow = 'lib/features/word_lookup/widgets/word_pronunciation_row.dart';
const _kMiniSheet = 'lib/screens/tools/youglish/youglish_mini_sheet.dart';
const _kView = 'lib/screens/tools/youglish/youglish_view.dart';
const _kPop = 'lib/screens/read_mode/widgets/word_mini_pop.dart';
const _kSheet = 'lib/screens/read_mode/sheets/word_actions_sheet.dart';
const _kOverrides = 'lib/core/language/priority_ui_overrides.dart';
const _kGenerated = 'lib/core/language/generated_ui_translations.dart';
const _kLegacy = 'lib/core/language/generated_legacy_ui_fallbacks.dart';

String _read(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: 'thiếu file $path');
  return f.readAsStringSync();
}

const _kAlways = PronunciationAvailability(); // everything available
const _kOffline = PronunciationAvailability(networkAvailable: false);
const _kKillSwitch = PronunciationAvailability(youglishEnabled: false);
const _kDictOnly = PronunciationAvailability(
  youglishEnabled: false,
  dictionaryHasAudio: true,
);

/// Chữ có dấu tiếng Việt (Latin Ext-A/B: ơ ư đ â ê ô + mọi precomposed tone
/// 1EA0–1EF3) — dùng để bắt chrome chưa được localize (rule #5).
final _kVietnameseOnly = RegExp(r'[\u00C0-\u024F\u1EA0-\u1EF3]');

void main() {
  group('PronunciationSourcePolicy.resolve — D1 (một nút, nguồn tự chọn)', () {
    test('mặc định: YouGlish thắng (người dùng chưa chọn gì)', () {
      expect(
        PronunciationSourcePolicy.resolve(availability: _kAlways),
        PronunciationSource.youglish,
      );
    });

    test('kill-switch youglish.enabled tắt ⇒ tự rớt xuống bậc kế, không chết',
        () {
      expect(
        PronunciationSourcePolicy.resolve(availability: _kKillSwitch),
        PronunciationSource.tts,
      );
      expect(
        PronunciationSourcePolicy.resolve(availability: _kDictOnly),
        PronunciationSource.dictionary,
      );
    });

    test('mất mạng ⇒ không chọn YouGlish (D3: không có khung trắng chờ chết)',
        () {
      expect(
        PronunciationSourcePolicy.resolve(availability: _kOffline),
        PronunciationSource.tts,
      );
    });

    test('PRON-002 chưa bật âm thanh từ điển ⇒ dictionary không bao giờ được chọn',
        () {
      expect(
        PronunciationSourcePolicy.resolve(availability: _kAlways),
        isNot(PronunciationSource.dictionary),
      );
      expect(_kAlways.isAvailable(PronunciationSource.dictionary), isFalse);
    });

    test('lựa chọn đã nhớ THẮNG, nhưng chỉ khi còn khả dụng', () {
      const p = PronunciationSourcePolicy.resolve;
      expect(
        p(remembered: PronunciationSource.tts, availability: _kAlways),
        PronunciationSource.tts,
      );
      expect(
        p(
          remembered: PronunciationSource.youglish,
          availability: _kOffline,
        ),
        PronunciationSource.tts,
      );
      expect(
        p(
          remembered: PronunciationSource.dictionary,
          availability: _kAlways,
        ),
        PronunciationSource.youglish,
      );
    });

    test('luôn luôn có MỘT nguồn (TTS không bao giờ bị loại)', () {
      const none = PronunciationAvailability(
        youglishEnabled: false,
        networkAvailable: false,
        dictionaryHasAudio: false,
      );
      expect(
        PronunciationSourcePolicy.resolve(availability: none),
        PronunciationSource.tts,
      );
      expect(none.available, [PronunciationSource.tts]);
    });
  });

  group('nextFallback — bậc thoái lui khi nguồn thất bại lúc chạy', () {
    test('youglish lỗi ⇒ dictionary nếu có audio, không thì tts', () {
      expect(
        PronunciationSourcePolicy.nextFallback(
          PronunciationSource.youglish,
          _kDictOnly,
        ),
        PronunciationSource.dictionary,
      );
      expect(
        PronunciationSourcePolicy.nextFallback(
          PronunciationSource.youglish,
          _kAlways,
        ),
        PronunciationSource.tts,
      );
    });

    test('dictionary lỗi ⇒ tts; tts lỗi ⇒ hết (không vòng lại, tránh lặp)', () {
      expect(
        PronunciationSourcePolicy.nextFallback(
          PronunciationSource.dictionary,
          _kAlways,
        ),
        PronunciationSource.tts,
      );
      expect(
        PronunciationSourcePolicy.nextFallback(
          PronunciationSource.tts,
          _kAlways,
        ),
        isNull,
      );
      expect(
        PronunciationSourcePolicy.nextFallback(
          PronunciationSource.youglish,
          const PronunciationAvailability(
            youglishEnabled: true,
            networkAvailable: true,
          ),
        ),
        PronunciationSource.tts,
      );
    });
  });

  group('prefCode — key `pronunciation.source` phải round-trip', () {
    test('mọi nguồn có mã ổn định', () {
      for (final s in PronunciationSource.values) {
        expect(
          PronunciationSource.fromPrefCode(s.prefCode),
          s,
          reason: 'round-trip hỏng cho $s',
        );
      }
      expect(PronunciationSource.fromPrefCode('youtube'), isNull);
      expect(PronunciationSource.fromPrefCode(null), isNull);
    });
  });

  group('Scan nguồn — các ràng buộc không đo được bằng logic', () {
    test('row KHÔNG tự dựng WebView: chỉ gọi YouGlishMiniSheet qua session', () {
      final row = _read(_kRow);
      expect(row.contains('YouGlishView('), isFalse,
          reason: 'WebView chỉ được tạo trong YouGlishView/_MiniSheet');
      expect(row.contains('webview_flutter'), isFalse);
      expect(row.contains('YouGlishMiniSheet.show('), isTrue);
      // D4: mọi đường vào sheet phải đi qua wrapRead (pause & restore).
      expect(row.contains('PronunciationSession.wrapRead('), isTrue);
      // "Một nút lười": không preload WebView, không mở sheet khi dựng widget.
      expect(row.contains('addPostFrameCallback'), isFalse);
      final init = row.substring(
        row.indexOf('void initState()'),
        row.indexOf('Future<void> _load()'),
      );
      expect(init.contains('_openYouGlish'), isFalse);
      expect(init.contains('_load()'), isTrue);
    });

    test('sheet WordActionsSheet dùng row compact, bỏ nút loa cô độc', () {
      final sheet = _read(_kSheet);
      expect(sheet.contains('WordPronunciationRowMode.compact'), isTrue);
      expect(sheet.contains('// Speak button'), isFalse,
          reason: 'header phải dùng row chung, không còn GestureDetector TTS');
      expect(sheet.contains("import 'package:webview_flutter"), isFalse);
      expect(sheet.contains('YouGlishView('), isFalse);
    });

    test('pop không-modal: THÊM 1 icon, dismiss trước khi mở, không WebView',
        () {
      final pop = _read(_kPop);
      expect(pop.contains('wordMiniPopYouGlishKey'), isTrue);
      expect(pop.contains('WordPronunciationRowMode.youglishIconOnly'), isTrue);
      // ADR-0016: pop là OverlayEntry ⇒ phải dismiss trước khi đè modal, nếu
      // không pop vẽ trên sheet và nuốt mọi cú chạm.
      expect(pop.contains('onBeforeOpen: WordMiniPop.dismiss'), isTrue);
      expect(pop.contains('import \'../../../features/word_lookup/widgets/'),
          isTrue);
      expect(pop.contains('YouGlishView('), isFalse);
      expect(pop.contains('showModalBottomSheet'), isFalse,
          reason: 'pop không tự mở sheet — mọi thứ qua row');
      // Nút ▶ cũ (TTS) phải còn nguyên để không đổi hành vi đã nghiệm thu.
      expect(pop.contains('wordMiniPopSpeakKey'), isTrue);
    });

    test('mini sheet: watchdog 8 s + banner 3 hành động, hook đã nối', () {
      final mini = _read(_kMiniSheet);
      expect(mini.contains('loadBudget = Duration(seconds: 8)'), isTrue);
      expect(mini.contains('onLoadError: _onLoadError'), isTrue);
      expect(mini.contains('onLoaded: _onLoaded'), isTrue);
      expect(mini.contains('_fallbackToTts()'), isTrue);
      expect(mini.contains('LaunchMode.externalApplication'), isTrue,
          reason: 'banner phải có lối thoát "Mở trình duyệt"');
      expect(_read(_kView).contains('widget.onLoaded?.call()'), isTrue,
          reason: 'YouGlishView phải báo onPageFinished cho watchdog');
    });

    test('kill-switch: YouGlish bị tắt thì affordance ẩn, không phải đổi nhãn',
        () {
      final row = _read(_kRow);
      expect(row.contains('if (!_youglishEnabled) return const SizedBox.shrink();'),
          isTrue);
      expect(row.contains('prefs.enabled'), isTrue,
          reason: 'nguồn sự thật của kill-switch là YouGlishPrefs.enabled');
    });

    test('nợ PRON-001 đã trả: inline playback iOS đặt ở tham số khởi tạo', () {
      final view = _read(_kView);
      final init = view.substring(
          view.indexOf('void _initMobile()'),
          view.indexOf('..setNavigationDelegate(NavigationDelegate(',
              view.indexOf('void _initMobile()')));
      // Tên API đã đối chiếu source `webview_flutter_wkwebview 3.25.1`:
      // tham số khởi tạo TÊN LÀ `WebKitWebViewControllerCreationParams` (bản
      // 4.x mới đổi thành `WKWebViewParams`), và bản 3.x KHÔNG có
      // `mediaPlaybackRequiresUserGesture` — thay bằng set rỗng của
      // `mediaTypesRequiringUserAction`.
      expect(
          init.contains(
              'WebKitWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams'),
          isTrue,
          reason: 'phải là tham số khởi tạo, không phải setter');
      expect(init.contains('allowsInlineMediaPlayback: true'), isTrue);
      expect(init.contains('mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{}'),
          isTrue);
      expect(init.contains('..mediaPlaybackRequiresUserGesture'), isFalse,
          reason: 'không được cascade cái này: API không tồn tại ở 3.25.1 — '
              'CI PRON-001 từng đỏ vì `setMediaPlaybackRequiresUserGesture`');
      // `WinWebViewController()` (nhánh Windows) vẫn hợp lệ ⇒ chỉ soi khối
      // `_initMobile`, kẻo bắt sai bằng chứng.
      expect(init.contains('WebViewController.fromPlatformCreationParams'), isTrue);
      expect(init.contains('WebViewController()'), isFalse,
          reason: 'không được dựng controller trần — mất params iOS');
      expect(_read('pubspec.yaml').contains('webview_flutter_wkwebview:'), isTrue,
          reason: 'cần direct dep thì mới import được WKWebViewParams');
    });

    test('rule #5: chrome Việt mới thêm phải có mục dịch (kèm en)', () {
      // Ba catalog mà `AppUITranslations.translate` thực sự đọc
      // (app_ui_translations.dart:29/34 + legacy fallbacks). Catalog dẹt chỉ có
      // English ⇒ chuỗi nào chỉ nằm ở đó vẫn đạt rule #5 nhưng KHÔNG có hi/zh/
      // zh_TW/si — PRON-002 ưu tiên thêm vào `priority_ui_overrides`.
      final catalogs = '${_read(_kOverrides)}\n${_read(_kGenerated)}'
          '\n${_read(_kLegacy)}';
      final pending = <String>[];
      for (final path in [_kRow, _kMiniSheet]) {
        final src = _read(path);
        final finder = RegExp(
            r"uiText\(\s*'([^']+)'|loadingMessage:\s*'([^']+)'");
        for (final m in finder.allMatches(src)) {
          final literal = m.group(1) ?? m.group(2)!;
          if (!_kVietnameseOnly.hasMatch(literal)) continue; // tên riêng/EU
          final hasEntry = catalogs.contains("'$literal': {") ||
              catalogs.contains("'$literal': '");
          if (!hasEntry) pending.add('$path → $literal');
          expect(hasEntry, isTrue,
              reason: 'rule #5: thêm chuỗi Việt vào priority_ui_overrides '
                  '(en/hi/zh/zh_TW/si) — thiếu: $literal ($path)');
        }
      }
      expect(pending, isEmpty);
    });
  });
}
