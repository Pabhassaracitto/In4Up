// test/perf/memory_diagnostics_guard_test.dart
//
// PERF-001-C (màn chẩn đoán CHỈ debug) + PERF-001-B bước 3 (công tắc Settings
// theo rule #5 + sàn T2).
//
// Source-scan thuần: không cần thiết bị, không plugin. Vì `kReleaseMode` là
// hằng compile-time, "pin" đúng cách là: (a) widget chẩn đoán CHỈ được dựng
// trong nhánh `!kReleaseMode`, (b) không có `dart:developer`/`print` số liệu
// RAM ở nhánh release.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Thiếu file: $path');
  return file.readAsStringSync();
}

/// Các chuỗi MỚI của PERF-001 (khoá = câu tiếng Việt gốc, đúng như `uiText()`
/// yêu cầu — KHÔNG phải tên ARB key).
const List<String> _newUiTextStrings = [
  'Hiệu năng & bộ nhớ',
  'Nhả model khi rảnh (tiết kiệm RAM)',
  'Tự giải phóng model AI/dịch/TTS sau 5 phút không dùng. '
      'Lần dùng sau sẽ nạp lại (chậm hơn lần đầu).',
  'Chẩn đoán bộ nhớ',
  'Bộ nhớ ảnh (ImageCache)',
  'Số ảnh đang giữ',
  'RAM tiến trình',
  'Số lần cache bị trim',
];

void main() {
  group('PERF-001-C — màn chẩn đoán bộ nhớ CHỈ ở build debug', () {
    test('widget chẩn đoán chỉ được dựng trong nhánh !kReleaseMode', () {
      final source = _read('lib/screens/settings/stt_model_settings_screen.dart');
      expect(source.contains('if (!kReleaseMode)'), isTrue,
          reason: 'nhánh hiển thị chẩn đoán phải có guard `!kReleaseMode`');
      // Guard phải ĐỨNG TRƯỚC chỗ dựng sheet chẩn đoán.
      final guardAt = source.indexOf('if (!kReleaseMode)');
      final sheetAt = source.indexOf('_MemoryDiagnosticsSheet()');
      expect(guardAt, greaterThan(-1));
      expect(sheetAt, greaterThan(guardAt),
          reason: 'sheet chẩn đoán phải nằm SAU guard kReleaseMode');
    });

    test('chẩn đoán đọc đúng 3 số liệu yêu cầu + đếm lần trim', () {
      final source = _read('lib/screens/settings/stt_model_settings_screen.dart');
      expect(source.contains('currentSizeBytes'), isTrue);
      expect(source.contains('liveImageCount'), isTrue);
      expect(source.contains('ProcessInfo.currentRss'), isTrue,
          reason: 'RAM tiến trình lấy qua dart:io ProcessInfo');
      expect(source.contains('ImageCachePolicy.evictionCount'), isTrue);
    });

    test('không có màn chẩn đoán nào khác bị lộ ra ngoài Settings', () {
      // Nếu ai đó import màn chẩn đoán ở chỗ khác thì guard vẫn đúng, nhưng
      // test này nhắc rằng chỉ có 1 điểm vào (Settings → Model AI).
      final hits = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        if (src.contains('_MemoryDiagnosticsSheet') &&
            !entity.path.endsWith('stt_model_settings_screen.dart')) {
          hits.add(entity.path);
        }
      }
      expect(hits, isEmpty, reason: 'widget private không được dùng nơi khác');
    });
  });

  group('PERF-001-B/rule #5 — chuỗi mới khai đủ 3 nơi', () {
    test('priority_ui_overrides.dart có đủ 5 locale cho mọi chuỗi mới', () {
      final source = _read('lib/core/language/priority_ui_overrides.dart');
      for (final text in _newUiTextStrings) {
        // Khoá xuất hiện dưới dạng Dart string literal (escape \' nếu có).
        final literal = "'${text.replaceAll("'", r"\'")}'";
        final at = source.indexOf(literal);
        expect(at, greaterThan(-1),
            reason: 'Thiếu khoá trong priority_ui_overrides: $text');
        final block = source.substring(
          at,
          (at + 900).clamp(0, source.length),
        );
        for (final locale in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
          expect(block.contains("'$locale':"), isTrue,
              reason: "Thiếu locale '$locale' cho: $text");
        }
      }
    });

    test('generated_legacy_ui_fallbacks.dart + legacy_ui_english_overrides.json',
        () {
      final fallbacks =
          _read('lib/core/language/generated_legacy_ui_fallbacks.dart');
      final overrides = jsonDecode(
        _read('tool/legacy_ui_english_overrides.json'),
      ) as Map<String, dynamic>;
      for (final text in _newUiTextStrings) {
        expect(fallbacks.contains(text.split('\n').first), isTrue,
            reason: 'Thiếu English fallback: $text');
        expect(overrides.containsKey(text), isTrue,
            reason: 'Thiếu trong tool/legacy_ui_english_overrides.json: $text');
        final english = overrides[text] as String;
        expect(english.trim(), isNotEmpty);
        // Rule #5: bản English không được còn ký tự tiếng Việt.
        expect(
          RegExp(r'[đĐơƠưƯảạằắẳẵặầấẩẫậẻẽẹềếểễệỉĩịỏọồốổỗộờớởỡợủũụừứửữựỳỷỹỵ]')
              .hasMatch(english),
          isFalse,
          reason: 'English còn tiếng Việt: $english',
        );
      }
    });

    test('công tắc dùng ĐÚNG 1 khoá lưu, đọc ở main() + ghi ở Settings', () {
      final key = 'perf_model_idle_unload_enabled';
      expect(_read('lib/services/model_idle_watchdog.dart').contains(key),
          isTrue);
      final mainDart = _read('lib/main.dart');
      expect(mainDart.contains('ModelIdleWatchdog.prefEnabledKey'), isTrue);
      expect(mainDart.contains('_restoreModelIdleWatchdogSetting'), isTrue);
      final settings =
          _read('lib/screens/settings/stt_model_settings_screen.dart');
      expect(settings.contains('ModelIdleWatchdog.prefEnabledKey'), isTrue);
      expect(settings.contains('prefs.setBool'), isTrue);
      // Mặc định BẬT theo yêu cầu PERF-001-B.
      expect(
        _read('lib/services/model_idle_watchdog.dart')
            .contains('static const bool defaultEnabled = true;'),
        isTrue,
      );
    });
  });
}
