// test/tts/voice_clone_permission_split_test.dart
//
// VOICE-CLONE-PERM-001 — chốt lại việc HAI chỗ báo lỗi quyền micro phải KHÁC
// NHAU.
//
// Vì sao cần test này: CI đã đỏ hai lần liên tiếp vì hai commit "sửa" đổi
// CẢ HAI chỗ cho giống nhau:
//
//   * `c5d3617c` → cả hai thành `permissionDenied` ⇒ hỏng kỳ vọng #1
//   * `66d8f9ac` → cả hai thành `permissionRequired` ⇒ hỏng kỳ vọng #2
//
// Ngữ nghĩa đúng (và là thứ `test/voice_clone_localization_test.dart` đang đo):
//
//   | Thời điểm                                  | Câu phải hiện                                            | Enum                |
//   |--------------------------------------------|----------------------------------------------------------|---------------------|
//   | Mở màn (`_requestPermissions`)             | "Microphone access is required to record voice samples." | `permissionRequired` |
//   | Bấm Record mà quyền bị chặn (`_startRecording`) | "Microphone access has not been granted."           | `permissionDenied`   |
//
// Lý do ngữ nghĩa: lúc mở màn là **giải thích** vì sao cần quyền; lúc user chủ
// động bấm ghi mà vẫn bị chặn là **báo trạng thái** — nếu lặp lại đúng câu đầu
// thì user bấm mà không thấy phản hồi gì (đúng lỗi người dùng gặp).
//
// Test này quét NGUỒN (source-scan) nên không cần thiết bị, không cần plugin.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sourcePath =
    'lib/features/tts/widgets/voice_clone_section.dart';

/// Đọc file và cắt comment `//` để chỉ so CODE THẬT.
///
/// Nếu không cắt, chính comment giải thích trong file cũng làm test pass giả.
String _codeOnly(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Thiếu file: $path');
  return file
      .readAsLinesSync()
      .map((line) {
        final index = line.indexOf('//');
        return index >= 0 ? line.substring(0, index) : line;
      })
      .join('\n');
}

/// Lấy thân hàm `Future<void> <name>(...)` — từ dấu `{` đầu tiên tới dấu `}`
/// đóng tương ứng (đếm ngoặc, bỏ qua chuỗi).
String _functionBody(String code, String signature) {
  final start = code.indexOf(signature);
  expect(start, isNonNegative,
      reason: 'Không tìm thấy `$signature` trong $_sourcePath — '
          'hàm đã bị đổi tên/xoá?');

  final openBrace = code.indexOf('{', start);
  expect(openBrace, isNonNegative, reason: 'Không thấy `{` của `$signature`');

  var depth = 0;
  for (var i = openBrace; i < code.length; i++) {
    final ch = code[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return code.substring(openBrace, i + 1);
    }
  }
  fail('Không tìm thấy `}` đóng của `$signature` — file có thể bị hỏng cú pháp');
}

void main() {
  group('VOICE-CLONE-PERM-001 — hai chỗ báo lỗi quyền micro phải KHÁC nhau', () {
    late String code;

    setUpAll(() {
      code = _codeOnly(_sourcePath);
    });

    test('enum _RecordingIssue vẫn có đủ 3 nhánh', () {
      expect(
        RegExp(r'enum\s+_RecordingIssue\s*\{([^}]*)\}').firstMatch(code),
        isNotNull,
        reason: 'Enum `_RecordingIssue` đã bị đổi/xoá',
      );
      for (final name in const [
        'permissionRequired',
        'permissionDenied',
        'failed',
      ]) {
        expect(code.contains(name), isTrue,
            reason: 'Enum thiếu nhánh `$name` — 3 nhánh này đều được dùng để '
                'chọn câu thông báo đã dịch');
      }
    });

    test('_requestPermissions (mở màn) dùng permissionRequired', () {
      final body = _functionBody(code, 'Future<void> _requestPermissions(');
      expect(
        body.contains('_RecordingIssue.permissionRequired'),
        isTrue,
        reason: 'Khi MỞ MÀN phải báo `permissionRequired` → hiện câu '
            '"Microphone access is required to record voice samples." '
            '(kỳ vọng #1 của voice_clone_localization_test)',
      );
      expect(
        body.contains('_RecordingIssue.permissionDenied'),
        isFalse,
        reason: 'Không được dùng `permissionDenied` ở đây — đó là câu '
            'dành cho lúc user bấm Record',
      );
    });

    test('_startRecording (user bấm Record) dùng permissionDenied', () {
      final body = _functionBody(code, 'Future<void> _startRecording(');
      expect(
        body.contains('_RecordingIssue.permissionDenied'),
        isTrue,
        reason: 'Khi user CHỦ ĐỘNG bấm Record mà quyền bị chặn phải báo '
            '`permissionDenied` → hiện câu '
            '"Microphone access has not been granted." (kỳ vọng #2)',
      );
      expect(
        body.contains('_RecordingIssue.permissionRequired'),
        isFalse,
        reason: 'Nếu lặp lại `permissionRequired` thì user bấm Record mà '
            'không thấy phản hồi gì — đây đúng là lỗi CI từng đỏ ở `66d8f9ac`',
      );
    });

    test('hai chỗ phải KHÁC nhau (chống "sửa cả hai cho giống nhau")', () {
      final onOpen = _functionBody(code, 'Future<void> _requestPermissions(');
      final onRecord = _functionBody(code, 'Future<void> _startRecording(');

      final openUsesRequired =
          onOpen.contains('_RecordingIssue.permissionRequired');
      final recordUsesRequired =
          onRecord.contains('_RecordingIssue.permissionRequired');

      expect(
        openUsesRequired == recordUsesRequired,
        isFalse,
        reason: 'HAI chỗ đang dùng CÙNG một enum. Lịch sử: `c5d3617c` và '
            '`66d8f9ac` đều đổi cả hai cho giống nhau và làm Rule 5 đỏ hai '
            'lần. Mở màn = permissionRequired, bấm Record = permissionDenied.',
      );
    });

    test('mỗi enum có câu dịch tương ứng (không nhánh nào bị bỏ quên)', () {
      // Bảng switch dịch enum → chuỗi đã bản địa hoá.
      expect(code.contains('_RecordingIssue.permissionRequired =>'), isTrue);
      expect(code.contains('_RecordingIssue.permissionDenied =>'), isTrue);
      expect(code.contains('_RecordingIssue.failed =>'), isTrue);
    });
  });
}
