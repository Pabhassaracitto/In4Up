// test/read_mode/line_height_test.dart
//
// AUDIT v1.30.1 (mục 4) — «Text Studio thêm thanh kéo chỉnh khoảng cách dòng
// trên/dưới, real-time».
//
// Trước đây `height` bị hard-code 1.6 ở `TextLineWidget._buildTextContent` và
// `_ColoredWord` ⇒ không có cách nào chỉnh. Test này khoá phần THUẦN của thay
// đổi: giá trị mặc định, biên clamp và việc `TextProvider` phát notify ngay
// (điều kiện để slider "real-time" thật sự vẽ lại vùng đọc).

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/providers/text_provider.dart';

void main() {
  // TextProvider cần StorageService (Hive). Chỉ đọc/ghi một khoá trong RAM nên
  // dùng `TextProvider.forTesting` nếu có; nếu không, khởi tạo trực tiếp và
  // chỉ kiểm tra phần setter/getter thuần.
  late TextProvider provider;

  setUp(() {
    provider = TextProvider();
  });

  test('mặc định 1.6 — giữ nguyên hình dáng trước khi có slider', () {
    expect(provider.readerLineHeight, 1.6);
  });

  test('đổi được và notify ngay (slider real-time)', () {
    var notifications = 0;
    provider.addListener(() => notifications++);

    provider.setReaderLineHeight(2.2);
    expect(provider.readerLineHeight, 2.2);
    expect(notifications, 1);
  });

  test('clamp trong khoảng 1.2 – 2.6', () {
    provider.setReaderLineHeight(0.5);
    expect(provider.readerLineHeight, 1.2);

    provider.setReaderLineHeight(9);
    expect(provider.readerLineHeight, 2.6);
  });

  test('gán lại cùng giá trị KHÔNG phát notify (tránh vẽ lại vô ích)', () {
    provider.setReaderLineHeight(1.8);
    var notifications = 0;
    provider.addListener(() => notifications++);
    provider.setReaderLineHeight(1.8);
    expect(notifications, 0);
  });

  test('giá trị lẻ được giữ (không làm tròn bước)', () {
    provider.setReaderLineHeight(1.7);
    expect(provider.readerLineHeight, closeTo(1.7, 1e-9));
  });
}
