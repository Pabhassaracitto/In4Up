import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';

void main() {
  test('READ-GRAM-001 chrome strings có fallback en + priority locales', () {
    const keys = [
      'Cấu trúc câu',
      'Cụm từ',
      'Cụm rộng hơn',
      'Công thức câu',
      'Cụm danh từ',
      'Cụm động từ',
      'Cụm tính từ',
      'Cụm trạng từ',
      'Cụm giới từ',
      'Cụm danh động từ',
      'Cụm động từ nguyên thể',
      'Cụm phân từ',
      'Cụm động từ ghép',
      'Câu hỏi',
      'Câu khẳng định',
      'Phủ định',
      'Câu mệnh lệnh',
      'Câu cảm thán',
      'Hỏi đuôi',
      'Hiện tại',
      'Quá khứ',
      'Tương lai',
      'đơn',
      'tiếp diễn',
      'hoàn thành',
      'hoàn thành tiếp diễn',
      'chủ động',
      'bị động',
      'Câu có thể tiếp tục ở dòng dưới',
      'Chưa đủ tin cậy để phân tích',
      'Chưa hỗ trợ phân tích cấu trúc cho ngôn ngữ này',
    ];
    const locales = ['en', 'hi', 'zh', 'zh_TW', 'si'];

    for (final key in keys) {
      for (final locale in locales) {
        final translated = AppUITranslations.translate(key, locale);
        expect(translated, isNot(key), reason: '$key thiếu bản dịch $locale');
        expect(_vietnameseOnly.hasMatch(translated), isFalse,
            reason: '$key [$locale] còn ký tự Việt: $translated');
      }
    }
  });
}

final RegExp _vietnameseOnly = RegExp(
  r'[đĐơƠưƯ]'
  r'|[ảạằắẳẵặầấẩẫậ]'
  r'|[ẻẽẹềếểễệ]'
  r'|[ỉĩị]'
  r'|[ỏọồốổỗộờớởỡợ]'
  r'|[ủũụừứửữự]'
  r'|[ỳỷỹỵ]',
);
