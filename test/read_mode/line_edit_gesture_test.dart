// IN4-36 — Tab Đọc: chạm giữ ít hữu ích + dễ XÓA NHẦM dòng.
//
// Quyết định (audit 1.10.4):
// 1. Chạm giữ KHÔNG mở thẳng bảng sửa dòng (chức năng ít dùng) — mở
//    LineActionsSheet (TTS/phát/lưu/sao chép) như chạm 2 lần;
//    "Sửa dòng…" vào qua action sheet (chủ động).
// 2. Nút Xóa trong bảng sửa KHÔNG được nằm cạnh nút đóng X (header) —
//    chuyển xuống hàng nút dưới, góc trái; dialog xác nhận giữ lại và
//    cảnh báo "không thể hoàn tác".
//
// Test source-scan (máy bắt): giữ các ràng buộc cấu trúc trên khỏi bị
// vô tình đảo lại khi refactor.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/generated_legacy_ui_fallbacks.dart';
import 'package:in4up/core/language/priority_ui_overrides.dart';

void main() {
  final lineWidget =
      File('lib/screens/read_mode/widgets/text_line_widget.dart')
          .readAsStringSync();
  final actionsSheet =
      File('lib/screens/read_mode/sheets/line_actions_sheet.dart')
          .readAsStringSync();
  final editSheet =
      File('lib/screens/read_mode/sheets/line_edit_sheet.dart').readAsStringSync();

  group('IN4-36 — cử chỉ chạm giữ (text_line_widget)', () {
    test('chạm giữ KHÔNG mở LineEditSheet trực tiếp (chức năng ít dùng)',
        () {
      final count =
          'LineEditSheet.show('.allMatches(lineWidget).length;
      expect(count, 0,
          reason:
              'text_line_widget không được gọi LineEditSheet.show trực tiếp — '
              'sửa dòng phải vào qua LineActionsSheet (chủ động).');
    });

    test('chạm giữ mở LineActionsSheet (cùng chạm 2 lần)', () {
      final count = 'LineActionsSheet.show('.allMatches(lineWidget).length;
      expect(count, greaterThanOrEqualTo(2),
          reason:
              'LineActionsSheet.show phải xuất hiện ít nhất 2 lần '
              '(onDoubleTap + onLongPress).');
    });
  });

  group('IN4-36 — "Sửa dòng…" vẫn vào được qua action sheet', () {
    test('LineActionsSheet có entry "Sửa dòng…" gọi LineEditSheet', () {
      expect(actionsSheet, contains('Sửa dòng…'));
      expect(actionsSheet, contains('LineEditSheet.show('));
      expect(actionsSheet, contains('import \'line_edit_sheet.dart\''));
    });
  });

  group('IN4-36 — nút Xóa không nằm cạnh nút đóng X (line_edit_sheet)', () {
    test('header (từ "── Header" tới "── Field:") không còn nút xóa', () {
      final headerStart = editSheet.indexOf('── Header');
      final fieldStart = editSheet.indexOf('── Field:', headerStart);
      expect(headerStart, greaterThanOrEqualTo(0));
      expect(fieldStart, greaterThan(headerStart));
      final header = editSheet.substring(headerStart, fieldStart);
      expect(
        header,
        isNot(contains('delete_outline')),
        reason: 'Nút xóa không được nằm trong header cạnh nút đóng X.',
      );
      expect(header, contains('Icons.close'));
    });

    test('nút "Xoá dòng" nằm ở HÀNG NÚT DƯỚI (sau marker "── Buttons")',
        () {
      final buttonsStart = editSheet.indexOf('── Buttons');
      expect(buttonsStart, greaterThanOrEqualTo(0));
      final idxDelete = editSheet.indexOf("'Xoá dòng'", buttonsStart);
      expect(idxDelete, greaterThan(buttonsStart),
          reason: 'Nút "Xoá dòng" phải nằm trong hàng nút dưới.');
    });

    test('xác nhận xóa vẫn có + cảnh báo không hoàn tác', () {
      expect(editSheet, contains('Xoá dòng?'));
      expect(editSheet, contains('Hành động này không thể hoàn tác.'));
      // Nút an toàn đặt làm lựa chọn mặc định (Giữ lại)
      expect(editSheet, contains("'Giữ lại'"));
    });
  });

  group('IN4-36 — i18n (rule 5: 5 locale đủ cho chuỗi mới)', () {
    const newStrings = [
      'Sửa dòng…',
      'Sửa văn bản gốc & bản dịch',
      'Xoá dòng',
      'Hành động này không thể hoàn tác.',
      'Giữ lại',
    ];
    const locales = ['en', 'hi', 'zh', 'zh_TW', 'si'];

    for (final s in newStrings) {
      test('priorityUiOverrides["$s"] đủ 5 locale', () {
        final entry = priorityUiOverrides[s];
        expect(entry, isNotNull, reason: 'Thiếu entry "$s"');
        for (final loc in locales) {
          final v = entry![loc];
          expect(v, isNotNull, reason: 'Thiếu locale $loc cho "$s"');
          expect(v!.trim(), isNotEmpty);
        }
      });
      test('generatedLegacyUiEnglishFallbacks["$s"] (en)', () {
        expect(generatedLegacyUiEnglishFallbacks[s], isNotNull,
            reason: 'Thiếu English fallback "$s"');
      });
    }
  });
}
