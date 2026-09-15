// Phím tắt là chính sách, không phải widget: test bảng ưu tiên (Esc luôn thắng,
// modifier nhường hệ thống, đang tìm thì Space/F/T nhường ô nhập) và đảm bảo mọi
// nhãn trong dialog trợ giúp đều có bản dịch (rule #5) — nếu thiếu, người dùng
// `en` sẽ thấy chữ Việt thô trong hộp "Phím tắt".
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/features/pdf_reader/services/pdf_shortcuts.dart';

PdfReaderShortcut? r({
  required LogicalKeyboardKey key,
  bool isPdfView = true,
  bool searchOpen = false,
  bool hasModifier = false,
}) =>
    resolvePdfReaderShortcut(
      key: key,
      isPdfView: isPdfView,
      searchOpen: searchOpen,
      hasModifier: hasModifier,
    );

void main() {
  group('resolvePdfReaderShortcut', () {
    test('lật trang: mũi tên + PageUp/PageDown', () {
      expect(r(key: LogicalKeyboardKey.arrowRight), PdfReaderShortcut.nextPage);
      expect(r(key: LogicalKeyboardKey.pageDown), PdfReaderShortcut.nextPage);
      expect(r(key: LogicalKeyboardKey.arrowLeft),
          PdfReaderShortcut.previousPage);
      expect(
          r(key: LogicalKeyboardKey.pageUp), PdfReaderShortcut.previousPage);
      expect(r(key: LogicalKeyboardKey.home), PdfReaderShortcut.firstPage);
      expect(r(key: LogicalKeyboardKey.end), PdfReaderShortcut.lastPage);
    });

    test('Esc thắng mọi ngữ cảnh: đang tìm, kể cả Text Mode, kể cả modifier', () {
      expect(r(key: LogicalKeyboardKey.escape),
          PdfReaderShortcut.closeSearchOrScreen);
      expect(
          r(key: LogicalKeyboardKey.escape, searchOpen: true, isPdfView: false),
          PdfReaderShortcut.closeSearchOrScreen);
      expect(r(key: LogicalKeyboardKey.escape, hasModifier: true),
          PdfReaderShortcut.closeSearchOrScreen);
    });

    test('Text Mode không có viewer ⇒ không lật trang/zoom', () {
      expect(r(key: LogicalKeyboardKey.arrowRight, isPdfView: false), isNull);
      expect(r(key: LogicalKeyboardKey.space, isPdfView: false), isNull);
      expect(r(key: LogicalKeyboardKey.keyF, isPdfView: false), isNull);
    });

    test('Ctrl/Cmd/Alt nhường trình duyệt, trừ +/− để phóng to', () {
      expect(r(key: LogicalKeyboardKey.keyF, hasModifier: true), isNull);
      expect(r(key: LogicalKeyboardKey.arrowRight, hasModifier: true), isNull);
      expect(r(key: LogicalKeyboardKey.equal, hasModifier: true),
          PdfReaderShortcut.zoomIn);
      expect(r(key: LogicalKeyboardKey.numpadAdd, hasModifier: true),
          PdfReaderShortcut.zoomIn);
      expect(r(key: LogicalKeyboardKey.minus, hasModifier: true),
          PdfReaderShortcut.zoomOut);
    });

    test('đang mở ô tìm: Space/F/T nhường việc gõ chữ, B và mũi tên vẫn chạy', () {
      expect(r(key: LogicalKeyboardKey.space, searchOpen: true), isNull);
      expect(r(key: LogicalKeyboardKey.keyF, searchOpen: true), isNull);
      expect(r(key: LogicalKeyboardKey.keyT, searchOpen: true), isNull);
      expect(r(key: LogicalKeyboardKey.keyB, searchOpen: true),
          PdfReaderShortcut.toggleBookmark);
      expect(r(key: LogicalKeyboardKey.arrowRight, searchOpen: true),
          PdfReaderShortcut.nextPage);
    });

    test('phím lạ -> null (không nuốt sự kiện vô nghĩa)', () {
      expect(r(key: LogicalKeyboardKey.keyZ), isNull);
      expect(r(key: LogicalKeyboardKey.tab), isNull);
    });
  });

  group('bảng trợ giúp', () {
    test('mọi hành vi đều có dòng trong dialog, không hành vi mồ côi', () {
      final covered = pdfReaderShortcutHelp.map((e) => e.action).toSet();
      expect(covered, equals(PdfReaderShortcut.values.toSet()),
          reason: 'thêm PdfReaderShortcut mà quên thêm vào pdfReaderShortcutHelp '
              'thì người dùng không bao giờ biết tới phím đó');
      for (final row in pdfReaderShortcutHelp) {
        expect(row.keys, isNotEmpty);
      }
    });

    test('nhãn trợ giúp phải có bản dịch (rule #5: locale khác không thấy chữ Việt)',
        () {
      for (final action in PdfReaderShortcut.values) {
        final label = pdfShortcutHelpLabelKey(action);
        expect(label, isNotEmpty);
        final english = AppUITranslations.translate(label, 'en');
        expect(english, isNot(equals(label)),
            reason: '"$label" chưa có key trong catalog — người dùng en/hi/zh sẽ '
                'thấy nguyên văn tiếng Việt trong hộp Phím tắt. Thêm vào '
                'lib/core/language/priority_ui_overrides.dart');
      }
    });

    test('bản dịch en/hi/zh/si của nhãn trợ giúp không còn dấu tiếng Việt', () {
      // Đúng tinh thần rule #5: ở locale khác, chrome phải là tiếng Anh (hoặc
      // bản dịch), không phải tiếng Việt rơi lại. Test này bắt cả trường hợp
      // "key có nhưng value chép nguyên tiếng Việt".
      final vi = RegExp(
        r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
        caseSensitive: false,
      );
      for (final action in PdfReaderShortcut.values) {
        final label = pdfShortcutHelpLabelKey(action);
        for (final lang in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
          final value = AppUITranslations.translate(label, lang);
          expect(
            vi.hasMatch(value),
            isFalse,
            reason: '"$label" [$lang] = "$value" — vẫn là tiếng Việt ở locale '
                '$lang. Sửa lib/core/language/priority_ui_overrides.dart',
          );
        }
      }
    });
  });
}
