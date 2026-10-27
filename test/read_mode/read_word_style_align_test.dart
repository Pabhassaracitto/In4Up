// READ-WORDSTYLE-001 + READ-ALIGN-001 (owner 2026-10-25, mục 4 và 5).
//
// Owner:
//   • "Cho phép người dùng chọn cách hiển thị các từ, ví như có người chỉ muốn
//     đổi màu chữ thôi thay vì có màu nền… vẫn có thể điều chỉnh được ở
//     setting."
//   • "Mặc định văn bản căn chỉnh ở giữa thay vì bên trái."
//
// Sandbox không có Flutter SDK ⇒ test này là source-scan + unit thuần (enum),
// chạy được bằng `flutter test` trên CI. Mục đích là "máy bắt" cho 2 quy tắc
// dễ bị lùi: (1) kiểu hiển thị phải áp ở CẢ HAI đường vẽ chữ của tab Đọc,
// (2) mặc định căn lề là GIỮA và lựa chọn phải được LƯU (bản cũ ghi chú
// "Tạm thời bỏ qua" nên mở lại app là mất).
import 'dart:io';

import 'package:flutter/material.dart' show TextAlign;
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/models/word_color_style.dart';

void main() {
  group('WordColorStyle — kiểu hiển thị từ', () {
    test('có đúng 3 kiểu: nền màu / chỉ màu chữ / gạch chân', () {
      expect(WordColorStyle.values.map((s) => s.name).toList(),
          <String>['fill', 'textOnly', 'underline']);
      expect(WordColorStyle.fill.label, 'Nền màu');
      expect(WordColorStyle.textOnly.label, 'Chỉ màu chữ');
      expect(WordColorStyle.underline.label, 'Gạch chân');
      for (final style in WordColorStyle.values) {
        expect(style.description.trim(), isNotEmpty,
            reason: 'màn Cài đặt cần mô tả ngắn cho từng kiểu');
      }
    });

    test('fromStorage: giá trị lạ / rỗng ⇒ mặc định chỉ màu chữ', () {
      expect(WordColorStyle.fromStorage(null), WordColorStyle.textOnly);
      expect(WordColorStyle.fromStorage(''), WordColorStyle.textOnly);
      expect(WordColorStyle.fromStorage('khong_ton_tai'), WordColorStyle.textOnly);
      expect(WordColorStyle.fromStorage('textOnly'), WordColorStyle.textOnly);
      expect(WordColorStyle.fromStorage('underline'), WordColorStyle.underline);
    });
  });

  group('READ-WORDSTYLE-001 — áp ở CẢ HAI đường vẽ chữ', () {
    final coloredText = File(
            'lib/screens/read_mode/widgets/colored_text_widget.dart')
        .readAsStringSync();
    final textLine =
        File('lib/screens/read_mode/widgets/text_line_widget.dart')
            .readAsStringSync();
    final settings =
        File('lib/services/reader_display_settings.dart').readAsStringSync();
    final textProvider =
        File('lib/providers/text_provider.dart').readAsStringSync();
    final settingsSheet =
        File('lib/screens/read_mode/sheets/read_settings_sheet.dart')
            .readAsStringSync();

    test('chế độ Ô CHỮ: "chỉ màu chữ" bỏ nền, "gạch chân" thêm underline', () {
      expect(coloredText.contains('WordColorStyle.fill'), isTrue);
      expect(coloredText.contains('colorStyle: colorStyle'), isTrue);
      expect(
        coloredText.contains(': (filled ? baseBackground : Colors.transparent)'),
        isTrue,
        reason: 'không nền khi người dùng chọn "chỉ màu chữ"/"gạch chân"',
      );
      expect(coloredText.contains('underlined || hasNestedUnderline'), isTrue);
      expect(coloredText.contains('decorationThickness'), isTrue);
    });

    test('chế độ BÔI CHỮ (SelectableText.rich): cùng một luật', () {
      expect(textLine.contains('wordColorStyle: tp.wordColorStyle'), isTrue,
          reason: '_LineData phải truyền kiểu hiển thị xuống spans');
      expect(textLine.contains('fillBackground'), isTrue);
      expect(textLine.contains('TextDecoration.underline'), isTrue);
    });

    test('kiểu hiển thị được LƯU và đổi được từ TextProvider', () {
      expect(settings.contains("'reader_word_color_style'"), isTrue);
      expect(settings.contains('WordColorStyle.fromStorage'), isTrue);
      expect(textProvider.contains('WordColorStyle get wordColorStyle'), isTrue);
      expect(textProvider.contains('setWordColorStyle'), isTrue);
    });

    test('màn Cài đặt tab Đọc có bộ chọn kiểu hiển thị từ', () {
      expect(settingsSheet.contains('_WordColorStyleSelector'), isTrue);
      expect(settingsSheet.contains('Kiểu hiển thị từ'), isTrue);
      expect(
        settingsSheet.contains('for (final style in WordColorStyle.values)'),
        isTrue,
        reason: 'mỗi kiểu một chip chọn — không hard-code một kiểu',
      );
    });
  });

  group('READ-ALIGN-001 — mặc định căn GIỮA + lưu bền', () {
    final textProvider =
        File('lib/providers/text_provider.dart').readAsStringSync();
    final storage = File('lib/services/storage_service.dart').readAsStringSync();
    final textLine =
        File('lib/screens/read_mode/widgets/text_line_widget.dart')
            .readAsStringSync();

    test('mặc định là TextAlign.center', () {
      expect(textProvider.contains('TextAlign _textAlign = TextAlign.center;'),
          isTrue);
      expect(textProvider.contains('TextAlign _textAlign = TextAlign.left;'),
          isFalse);
    });

    test('lựa chọn căn lề được lưu và khôi phục (hết "Tạm thời bỏ qua")', () {
      expect(textProvider.contains('saveReadTextAlign('), isTrue);
      expect(textProvider.contains('getReadTextAlign('), isTrue);
      expect(
        textProvider.contains('Tạm thời bỏ qua'),
        isFalse,
        reason: 'đó chính là lý do lựa chọn của người dùng biến mất',
      );

      expect(storage.contains("'read_text_align'"), isTrue);
      expect(storage.contains('readTextAlignCenter'), isTrue);
      expect(storage.contains('readTextAlignLeft'), isTrue);

      // Giá trị lạ/rỗng ⇒ GIỮA (không rơi về trái).
      expect(
        textProvider.contains('value == StorageService.readTextAlignLeft'),
        isTrue,
      );
    });

    test('dòng chữ mặc định (khi chưa có dữ liệu) cũng canh giữa', () {
      expect(
        RegExp(r'textAlign = TextAlign\.center,')
            .hasMatch(textLine),
        isTrue,
        reason: '_LineData.empty phải cùng mặc định với provider',
      );
    });

    test('giá trị enum dùng để so sánh vẫn là TextAlign của Flutter', () {
      expect(TextAlign.center.index, isNot(TextAlign.left.index));
    });
  });
}
