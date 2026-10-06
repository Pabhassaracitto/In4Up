// READ-ACT-001 — luật phân giải đoạn cho 4 hành động văn bản của tab Đọc.
//
// Bug gốc (audit 0.10.3 mục 1.b): handler cũ đòi `selectedText` không rỗng,
// mà các chế độ hiển thị theo ô/interlinear của tab Đọc không hề tạo
// selection ⇒ bấm Dịch/Ngữ pháp/Phát âm luôn nhận "Bạn cần bôi chọn một
// đoạn trước", kể cả khi người dùng vừa bôi chọn xong.
//
// Thứ tự phải là: đoạn bôi chọn → dòng đang đọc → dòng đầu tiên có chữ.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/read_mode/services/read_text_action_runner.dart';

void main() {
  const lines = <String>['', 'Dòng một', 'Dòng hai', 'Dòng ba'];

  ReadActionTarget? call({
    String? selectedText,
    String? providerSelection,
    List<String> source = lines,
    int currentLineIndex = -1,
  }) =>
      resolveReadActionTarget(
        selectedText: selectedText,
        providerSelection: providerSelection,
        lines: source,
        currentLineIndex: currentLineIndex,
      );

  group('resolveReadActionTarget', () {
    test('ưu tiên đoạn truyền thẳng từ nút/thanh hành động', () {
      final target = call(selectedText: 'Dòng hai', currentLineIndex: 1)!;
      expect(target.text, 'Dòng hai');
      expect(target.fromSelection, isTrue);
      expect(target.lineIndex, 2, reason: 'phải tìm đúng dòng chứa đoạn');
    });

    test('không có đoạn truyền vào thì lấy selection của provider', () {
      final target = call(providerSelection: '  Dòng ba  ')!;
      expect(target.text, 'Dòng ba');
      expect(target.fromSelection, isTrue);
      expect(target.lineIndex, 3);
    });

    test('chưa bôi chọn gì thì lùi về dòng đang đọc (bug 1.b)', () {
      final target = call(currentLineIndex: 2)!;
      expect(target.text, 'Dòng hai');
      expect(target.fromSelection, isFalse);
      expect(target.lineIndex, 2);
    });

    test('chưa có dòng đang đọc thì lấy dòng đầu tiên có chữ', () {
      final target = call()!;
      expect(target.text, 'Dòng một');
      expect(target.lineIndex, 1, reason: 'dòng 0 rỗng nên bị bỏ qua');
      expect(target.fromSelection, isFalse);
    });

    test('dòng đang đọc rỗng thì vẫn tìm được dòng có chữ', () {
      final target = call(currentLineIndex: 0)!;
      expect(target.text, 'Dòng một');
      expect(target.fromSelection, isFalse);
    });

    test('selection toàn khoảng trắng bị bỏ qua', () {
      final target = call(selectedText: '   ', currentLineIndex: 3)!;
      expect(target.text, 'Dòng ba');
      expect(target.fromSelection, isFalse);
    });

    test('tài liệu rỗng → null (chỉ lúc này mới được báo lỗi)', () {
      expect(call(source: const []), isNull);
      expect(call(source: const ['', '   ']), isNull);
    });

    test('currentLineIndex ngoài biên không làm vỡ', () {
      final target = call(source: lines, currentLineIndex: 99)!;
      expect(target.text, 'Dòng một');
      expect(target.fromSelection, isFalse);
    });

    test('đoạn nằm giữa một dòng vẫn ánh xạ về đúng dòng', () {
      final target = call(
        selectedText: 'hai',
        source: const ['alpha', 'Dòng hai dài hơn'],
      )!;
      expect(target.lineIndex, 1);
      expect(target.fromSelection, isTrue);
    });
  });
}
