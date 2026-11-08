// test/perf/parse_isolate_equivalence_test.dart
//
// PERF-001-D — máy bắt cho "parse văn bản/LRC trong isolate".
//
// Chỉ đổi CHỖ chạy (luồng UI → isolate), KHÔNG đổi thuật toán ⇒ máy bắt phải
// chứng minh: cùng input ⇒ output GIỐNG HỆT đường đồng bộ, trên cả các ca
// biên đã từng làm hỏng repo (`[125:03.45]` — video ≥ 60 phút).
//
// Đồng thời pin NGƯỠNG bằng counter (không đo thời gian ⇒ không flaky).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/providers/text_provider.dart'
    show
        splitTextLinesSync,
        splitTextOffThreadIfLarge,
        plainTextIsolateThresholdChars,
        plainTextOffThreadSplitCount;
import 'package:in4up/services/lrc_time_parser.dart';

/// So sánh 2 danh sách dòng LRC bằng chuỗi (LrcLine không override ==).
List<String> _asStrings(List<LrcLine> lines) =>
    lines.map((l) => '${l.start.inMilliseconds}|${l.text}').toList();

/// Sinh nội dung LRC dài ≥ [minChars] với đủ loại mốc thời gian.
String _longLrc({int minChars = 80 * 1024}) {
  final buffer = StringBuffer()
    ..writeln('[ti:Bài kiểm tra PERF-001-D]')
    ..writeln('[ar:In4Up]');
  var i = 0;
  while (buffer.length < minChars) {
    final mm = (i ~/ 60).toString().padLeft(2, '0');
    final ss = (i % 60).toString().padLeft(2, '0');
    switch (i % 6) {
      case 0:
        buffer.writeln('[$mm:$ss.45] Dòng thường số $i');
      case 1:
        // Video ≥ 60 phút — mốc 3 chữ số phút (bug `[125:03.45]`).
        buffer.writeln('[1$mm:$ss.45] Phút tuyệt đối $i');
      case 2:
        buffer.writeln('[$mm:$ss,50] Dấu phẩy kiểu SRT $i');
      case 3:
        buffer.writeln('[01:$mm:$ss.123] Dạng hh:mm:ss $i');
      case 4:
        buffer.writeln('[$mm:$ss.45]<00:12.34>Karaoke <00:13.00>từ $i');
      default:
        buffer.writeln('[$mm:$ss.45] Ký tự lạ: 日本語 · हिन्दी · සිංහල · '
            'ဗမာ — $i');
    }
    i++;
  }
  return buffer.toString();
}

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Thiếu file: $path');
  return file.readAsStringSync();
}

void main() {
  group('PERF-001-D — LRC: isolate == đồng bộ (golden)', () {
    test('file 2 giờ (>80 KB) — kết quả giống hệt', () async {
      final content = _longLrc();
      expect(content.length, greaterThan(lrcIsolateThresholdChars));

      final sync = _asStrings(parseLrcContent(content));
      final offThread = _asStrings(await parseLrcContentOffThread(content));

      expect(sync.length, greaterThan(1000),
          reason: 'phải thật sự nhiều dòng thì mới đáng đo');
      expect(offThread, sync);
    });

    test('các ca biên: rỗng / 1 dòng / mốc 125 phút / SRT / hh:mm:ss', () async {
      final cases = <String>[
        '',
        '\n\n\n',
        '[00:01.00] Một dòng duy nhất',
        '[125:03.45] Phút tuyệt đối (YT-LRC-LONG-001)',
        '[00:01,50] Dấu phẩy\n[00:02.75] Dấu chấm',
        '[01:02:03.123] Ba tầng thời gian',
        '[00:05.00]<00:05.00>Karaoke <00:06.00>nhiều mốc',
        '[ti:Chỉ metadata]\n[00:03.10] Sau metadata',
        '[00:00.00] 日本語 · हिन्दी · සිංහල · ဗမာ · tiếng Việt',
      ];
      for (final content in cases) {
        expect(
          _asStrings(await parseLrcContentOffThread(content)),
          _asStrings(parseLrcContent(content)),
          reason: 'lệch ở input: ${content.replaceAll('\n', r'\n')}',
        );
      }
    });

    test('ngưỡng: nội dung nhỏ đi đường ĐỒNG BỘ, lớn mới lên isolate', () async {
      resetLrcOffThreadParseCount();
      expect(lrcIsolateThresholdChars, greaterThanOrEqualTo(16 * 1024));

      // 10 KB < 64 KB ⇒ không spawn isolate, vẫn trả đúng kết quả.
      final small = _longLrc(minChars: 10 * 1024);
      expect(small.length, lessThan(lrcIsolateThresholdChars));
      await parseLrcContentOffThread(small);
      expect(lrcOffThreadParseCount, 0);

      // ≥ 64 KB ⇒ đúng 1 lần lên isolate.
      final big = _longLrc(minChars: 70 * 1024);
      await parseLrcContentOffThread(big);
      expect(lrcOffThreadParseCount, 1);
    });
  });

  group('PERF-001-D — văn bản thường: isolate == đồng bộ', () {
    test('file 1 MB (đại diện file lớn) — giống hệt đường đồng bộ', () async {
      final paragraph =
          'Đây là một đoạn văn dài để kiểm tra việc tách dòng. It has English '
          'sentences too! Và câu hỏi? Rồi mệnh đề, nối tiếp; kết thúc.\n\n';
      final buffer = StringBuffer();
      // 1 MB là đủ để vượt ngưỡng 64 KB và đủ lớn để lộ khác biệt; dùng
      // 5 MB chỉ làm CI chậm mà không chứng minh thêm điều gì.
      while (buffer.length < 1 * 1024 * 1024) {
        buffer.write(paragraph);
      }
      final content = buffer.toString();
      expect(content.length, greaterThan(plainTextIsolateThresholdChars));

      final syncLines = splitTextLinesSync(content, autoSplit: true);
      final offThread = await splitTextOffThreadIfLarge(content, autoSplit: true);

      expect(offThread, isNotNull);
      expect(offThread, syncLines);
      expect(syncLines.length, greaterThan(1000));

      // Chế độ KHÔNG auto-split (chia theo dòng) cũng phải khớp.
      final syncRaw = splitTextLinesSync(content, autoSplit: false);
      final offRaw = await splitTextOffThreadIfLarge(content, autoSplit: false);
      expect(offRaw, syncRaw);
    });

    test('nội dung nhỏ ⇒ trả null (caller chia đồng bộ, hành vi cũ)', () async {
      final before = plainTextOffThreadSplitCount;
      final result = await splitTextOffThreadIfLarge('một dòng ngắn');
      expect(result, isNull);
      expect(plainTextOffThreadSplitCount, before);
    });
  });

  group('PERF-001-D — hàm gửi isolate phải THUẦN (source-scan)', () {
    /// Cắt phần thân 1 hàm top-level theo tên (đủ dùng cho máy bắt này).
    String extractFunction(String source, String name) {
      final start = source.indexOf('$name(');
      expect(start, greaterThan(-1), reason: 'Không thấy hàm $name');
      final end = source.indexOf('\n}', start);
      return source.substring(start, end > 0 ? end : source.length);
    }

    test('splitTextOffThreadIfLarge + splitTextLinesSync không đụng plugin/UI',
        () {
      final source = _read('lib/providers/text_provider.dart');
      for (final name in ['splitTextLinesSync', 'splitTextOffThreadIfLarge']) {
        final body = extractFunction(source, name);
        for (final forbidden in [
          'SharedPreferences',
          'path_provider',
          'MethodChannel',
          'BuildContext',
          'ChangeNotifier',
          'notifyListeners',
        ]) {
          expect(
            body.contains(forbidden),
            isFalse,
            reason: '$name gửi sang isolate KHÔNG được dùng $forbidden '
                '(isolate mới không có plugin/UI)',
          );
        }
      }
    });

    test('parseLrcContent là hàm THUẦN (không I/O, không state)', () {
      final source = _read('lib/services/lrc_time_parser.dart');
      final body = extractFunction(source, 'List<LrcLine> parseLrcContent');
      for (final forbidden in [
        'File(',
        'SharedPreferences',
        'path_provider',
        'MethodChannel',
      ]) {
        expect(body.contains(forbidden), isFalse,
            reason: 'parseLrcContent phải thuần — thấy $forbidden');
      }
      // Và cả file chỉ được gửi đúng nó vào isolate.
      final offThread =
          extractFunction(source, 'Future<List<LrcLine>> parseLrcContentOffThread');
      expect(offThread.contains('parseLrcContent(content)'), isTrue);
    });

    test('text_provider dùng parseLrcContentOffThread (không parse trên UI)',
        () {
      final source = _read('lib/providers/text_provider.dart');
      expect(source.contains('await parseLrcContentOffThread(content)'), isTrue);
      expect(source.contains('splitTextOffThreadIfLarge'), isTrue);
      expect(source.contains('preSplitLines'), isTrue);
    });
  });
}
