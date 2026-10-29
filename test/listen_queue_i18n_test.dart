import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';

void main() {
  const labels = [
    'Danh sách đang phát',
    'Chưa có bài trong danh sách phát',
    'Bài không còn trong thư viện',
    'Không phát được bài này',
    'Bài trước',
    'Bài sau',
    'Lùi 10 giây',
    'Tiến 10 giây',
    'Đang tải bài',
    'Chỉ giữ bài hiện tại',
    'Dữ liệu cũ chưa xác minh',
    'Dữ liệu cũ cùng tên được giữ nguyên. Chỉ liên kết nếu bạn chắc đây là đúng file âm thanh.',
    'Dữ liệu cũ được giữ nguyên, nhưng không thể liên kết an toàn vì cache cũ khác nội dung hoặc đã thuộc nguồn khác.',
    'Liên kết dữ liệu cũ',
    'Đã liên kết dữ liệu cũ',
    'Không thể liên kết dữ liệu cũ',
  ];

  test('new queue chrome is native for priority locales and has English fallback', () {
    for (final label in labels) {
      expect(AppUITranslations.translate(label, 'vi'), label);
      final english = AppUITranslations.translate(label, 'en');
      expect(english, isNot(label), reason: label);
      expect(AppUITranslations.translate(label, 'es'), english, reason: label);
      for (final locale in ['hi', 'zh', 'zh_TW', 'si', 'my', 'th', 'ja']) {
        final translation = AppUITranslations.translate(label, locale);
        expect(translation, isNot(label), reason: '$locale: $label');
        expect(translation, isNot(english), reason: '$locale: $label');
      }
    }
  });
}
