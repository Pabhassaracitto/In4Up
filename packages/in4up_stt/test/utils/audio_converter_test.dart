import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/audio_converter.dart';

/// Unit test cho [AudioConverter.sanitizeFileName] — phần logic thuần (pure),
/// không phụ thuộc nền tảng, xác minh đúng yêu cầu "xóa khoảng trắng" và xử lý
/// các ký tự nguy hiểm với command string của FFmpegKit.
void main() {
  group('AudioConverter.sanitizeFileName', () {
    test('thay khoảng trắng bằng dấu gạch dưới', () {
      expect(AudioConverter.sanitizeFileName('My Audio File'), 'My_Audio_File');
    });

    test('gộp nhiều khoảng trắng liên tiếp thành 1 gạch dưới', () {
      expect(AudioConverter.sanitizeFileName('a   b\tc'), 'a_b_c');
    });

    test('giữ nguyên ký tự unicode (tiếng Việt)', () {
      expect(
        AudioConverter.sanitizeFileName('Bài giảng số 1'),
        'Bài_giảng_số_1',
      );
    });

    test('xóa dấu ngoặc kép và backslash (nguy hiểm cho command string)', () {
      expect(AudioConverter.sanitizeFileName('file"na\\"me'), 'filename');
    });

    test('xóa newline / tab', () {
      expect(
        AudioConverter.sanitizeFileName('foo\r\nbar\tbaz'),
        'foo_bar_baz',
      );
    });

    test('cắt dấu `_` dư ở đầu/cuối', () {
      expect(AudioConverter.sanitizeFileName('  hello  '), 'hello');
      expect(AudioConverter.sanitizeFileName('_hi_'), 'hi');
    });

    test('trả về "audio" nếu tên rỗng sau khi sanitize', () {
      expect(AudioConverter.sanitizeFileName('   '), 'audio');
      expect(AudioConverter.sanitizeFileName('""'), 'audio');
    });

    test('không thay đổi tên đã sạch', () {
      expect(AudioConverter.sanitizeFileName('recording_001'), 'recording_001');
    });
  });
}
