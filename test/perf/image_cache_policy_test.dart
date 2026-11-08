// test/perf/image_cache_policy_test.dart
//
// PERF-001-A — máy bắt cho "hạn mức cache ảnh + giải phóng khi rời màn".
//
// Thuần Dart + source-scan (giống `test/cabin/cabin_audio_completeness_test.dart`):
// không cần thiết bị, không plugin, không mạng.
//
// Pin 3 việc:
//   1. Hằng số hạn mức nằm trong DẢI HỢP LÝ (đọc từ code, không hard-code 2 lần).
//   2. Mọi widget ảnh trong các list DÀY (vocab_image / youtube / web_reader)
//      có `cacheWidth` hoặc `cacheHeight` ⇒ không decode ảnh 1280 px cho ô 56 px.
//   3. `PdfReaderScreen.dispose()` + `WebReaderScreen.dispose()` gọi nhả ảnh,
//      và `main()` áp hạn mức.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/image_cache_policy.dart';

/// Đọc 1 file nguồn, chuẩn hoá xuống dòng.
String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Thiếu file: $path');
  return file.readAsStringSync();
}

/// Trả về các dòng (1-based) có widget ảnh mà KHÔNG có cacheWidth/cacheHeight
/// trong vòng [lookahead] dòng ngay sau khai báo.
List<String> _imageWidgetsWithoutCachedWidth(String source, String path) {
  final pattern = RegExp(
    r'Image\.(network|file|memory|asset)\s*\(|FadeInImage\.|DecorationImage\(',
  );
  final lines = source.split('\n');
  final missing = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // Bỏ qua dòng chỉ là chú thích: nhiều chỗ nhắc `Image.network` trong
    // comment giải thích (không phải widget).
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
    if (!pattern.hasMatch(line)) continue;
    final window = lines
        .sublist(i, (i + 14).clamp(0, lines.length))
        .join('\n');
    if (window.contains('cacheWidth') || window.contains('cacheHeight')) {
      continue;
    }
    missing.add('$path:${i + 1} → ${line.trim()}');
  }
  return missing;
}

void main() {
  group('PERF-001-A — hằng số hạn mức ImageCache', () {
    test('maximumSizeBytes nằm trong dải 32 MB … 96 MB', () {
      const mb32 = 32 * 1024 * 1024;
      const mb96 = 96 * 1024 * 1024;
      expect(ImageCachePolicy.maxBytes, greaterThanOrEqualTo(mb32));
      expect(ImageCachePolicy.maxBytes, lessThanOrEqualTo(mb96));
      // Phải NHỎ hơn mặc định Flutter (100 MB) thì mới là "giảm RAM".
      expect(ImageCachePolicy.maxBytes, lessThan(100 * 1024 * 1024));
    });

    test('maximumSize (số ảnh) nằm trong dải 100 … 300 ảnh', () {
      expect(ImageCachePolicy.maxImages, greaterThanOrEqualTo(100));
      expect(ImageCachePolicy.maxImages, lessThanOrEqualTo(300));
      // Mặc định Flutter là 1000 ảnh.
      expect(ImageCachePolicy.maxImages, lessThan(1000));
    });

    test('cacheWidth thumbnail dùng cho ô 56–96 px (không decode full)', () {
      expect(ImageCachePolicy.thumbCacheWidth, greaterThanOrEqualTo(96));
      expect(ImageCachePolicy.thumbCacheWidth, lessThanOrEqualTo(192));
      expect(
        ImageCachePolicy.cardCacheWidth,
        greaterThan(ImageCachePolicy.thumbCacheWidth),
        reason: 'ảnh card lớn hơn thumbnail phải có cacheWidth lớn hơn',
      );
      expect(
        ImageCachePolicy.previewCacheWidth,
        greaterThan(ImageCachePolicy.cardCacheWidth),
      );
    });

    test('main() áp hạn mức + PdfReader/WebReader nhả ảnh khi rời màn', () {
      final mainDart = _read('lib/main.dart');
      expect(
        mainDart.contains('ImageCachePolicy.apply()'),
        isTrue,
        reason: 'main() phải đặt hạn mức tường minh (PERF-001-A bước 1)',
      );

      final pdf = _read('lib/features/pdf_reader/pdf_reader_screen.dart');
      final pdfDispose = RegExp(
        r'void dispose\(\)\s*\{[\s\S]{0,1200}?\n  \}',
      ).firstMatch(pdf);
      expect(pdfDispose, isNotNull, reason: 'Không tìm thấy dispose() của PDF');
      expect(
        pdfDispose!.group(0)!.contains('trimAfterHeavyScreenExit') ||
            pdfDispose.group(0)!.contains('imageCache'),
        isTrue,
        reason: 'PdfReaderScreen.dispose() phải nhả ảnh (evict/clear)',
      );

      final web = _read('lib/features/web_reader/web_reader_screen.dart');
      final webDispose = RegExp(
        r'void dispose\(\)\s*\{[\s\S]{0,1200}?\n  \}',
      ).firstMatch(web);
      expect(webDispose, isNotNull);
      expect(
        webDispose!.group(0)!.contains('trimAfterHeavyScreenExit') ||
            webDispose.group(0)!.contains('imageCache'),
        isTrue,
        reason: 'WebReaderScreen.dispose() phải nhả ảnh (evict/clear)',
      );
    });
  });

  group('PERF-001-A — log khi cache bị trim (đo được về sau)', () {
    test('cơ chế dò trim tồn tại + được gọi ở màn chẩn đoán', () {
      // Flutter 3.44.1 KHÔNG có `ImageCache.onEvict` ⇒ dùng observe() so
      // kích thước. Pin để lần sau không ai xoá mất phần "đo được".
      final policy = _read('lib/services/image_cache_policy.dart');
      expect(policy.contains('static bool observe('), isTrue);
      expect(policy.contains("[in4up-perf] image-cache trim"), isTrue);
      expect(policy.contains('static int evictionCount'), isTrue);
      // Không được quay lại API không tồn tại (đã làm đỏ CI ở build 835e53a).
      expect(policy.contains('onEvict'), isFalse,
          reason: 'Flutter 3.44.1 không có setter onEvict');
      final settings =
          _read('lib/screens/settings/stt_model_settings_screen.dart');
      expect(settings.contains('ImageCachePolicy.observe()'), isTrue);
    });
  });

  group('PERF-001-A — widget ảnh trong list DÀY có cacheWidth', () {
    const dirs = [
      'lib/features/vocab_image',
      'lib/features/youtube',
      'lib/features/web_reader',
    ];

    test('vocab_image / youtube / web_reader: không ảnh nào decode full size',
        () {
      final violations = <String>[];
      for (final dir in dirs) {
        final directory = Directory(dir);
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          violations.addAll(
            _imageWidgetsWithoutCachedWidth(source, entity.path),
          );
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Widget ảnh thiếu cacheWidth/cacheHeight (PERF-001-A bước 2):\n'
            '${violations.join('\n')}',
      );
    });

    test('web_reader dùng WebView (không có widget ảnh Flutter) — ghi nhận',
        () {
      // Nếu sau này web_reader thêm widget ảnh Flutter thì test trên đã bắt
      // cacheWidth; test này chỉ chốt lại SỰ THẬT hiện tại để người đọc không
      // tưởng bước 2 của PERF-001-A bị bỏ sót.
      final files = Directory('lib/features/web_reader')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final withImages = files.where((f) =>
          f.readAsStringSync().contains('Image.network') ||
          f.readAsStringSync().contains('Image.file'));
      // web_reader hiện render ảnh trong WebView ⇒ không có ⇒ danh sách rỗng.
      expect(withImages, isEmpty);
    });
  });
}
