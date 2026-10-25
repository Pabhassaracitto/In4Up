// Priority-locale native pack — máy bắt cho ADR-0002 / quy tắc vàng #5.
//
// Ngôn ngữ ưu tiên của người sở hữu: Trung (zh, zh_TW), Myanmar (my),
// Sinhala (si), Hindi (hi), Thái (th), Nhật (ja). Với các locale này chrome
// legacy KHÔNG được rơi về English khi đã có bản dịch trong pack, và tuyệt đối
// không được hiện tiếng Việt.
//
// Pack được sinh từ `tool/priority_native_pack.json` bằng
// `python3 tool/generate_priority_native_pack.py` — sửa JSON, đừng sửa file
// generated.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/core/language/generated_priority_native_pack.dart';

/// Ký tự chỉ có ở tiếng Việt (không trùng chữ có dấu của Romance languages).
final RegExp _vietnameseOnly = RegExp(
  r'[đĐơƠưƯ]|[ảạằắẳẵặầấẩẫậ]|[ẻẽẹềếểễệ]|[ỉĩị]|[ỏọồốổỗộờớởỡợ]|[ủũụừứửữự]|[ỳỷỹỵ]',
);

final RegExp _placeholder = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

const _priorityLocales = ['zh', 'zh_TW', 'hi', 'si', 'my', 'th', 'ja'];

void main() {
  group('Priority native pack — cấu trúc', () {
    test('có entry và mọi entry đủ en + 7 locale ưu tiên', () {
      expect(generatedPriorityNativePack, isNotEmpty);
      final violations = <String>[];
      generatedPriorityNativePack.forEach((source, entry) {
        if ((entry['en'] ?? '').trim().isEmpty) {
          violations.add('$source → thiếu en');
        }
        for (final locale in _priorityLocales) {
          if ((entry[locale] ?? '').trim().isEmpty) {
            violations.add('$source → thiếu $locale');
          }
        }
      });
      expect(violations, isEmpty, reason: violations.take(10).join('\n'));
    });

    test('không có tiếng Việt trong bản dịch locale ≠ vi', () {
      final violations = <String>[];
      generatedPriorityNativePack.forEach((source, entry) {
        entry.forEach((locale, value) {
          if (locale == 'vi') return;
          final match = _vietnameseOnly.firstMatch(value);
          if (match != null) {
            violations.add("'$source' [$locale] → '$value' ('${match.group(0)}')");
          }
        });
      });
      expect(
        violations,
        isEmpty,
        reason: 'Rule #5 — locale ≠ vi không được hiện tiếng Việt:\n'
            '${violations.take(10).join('\n')}',
      );
    });

    test('giữ nguyên placeholder {valueN} ở mọi locale', () {
      final violations = <String>[];
      generatedPriorityNativePack.forEach((source, entry) {
        final expected =
            _placeholder.allMatches(source).map((m) => m.group(1)!).toSet();
        if (expected.isEmpty) return;
        entry.forEach((locale, value) {
          final actual =
              _placeholder.allMatches(value).map((m) => m.group(1)!).toSet();
          final missing = expected.difference(actual);
          if (missing.isNotEmpty) {
            violations.add("'$source' [$locale] thiếu $missing");
          }
        });
      });
      expect(
        violations,
        isEmpty,
        reason: 'Mất placeholder = mất dữ liệu người dùng khi render:\n'
            '${violations.take(10).join('\n')}',
      );
    });
  });

  group('Priority native pack — hoà vào AppUITranslations', () {
    test('chuỗi chrome legacy trả bản địa, không phải English', () {
      const cases = [
        'Dừng tối ưu mức sử dụng pin',
        'Từ đến hạn ôn',
        'Có phụ đề',
        'Chọn thư mục video',
        'Bài nghe đang dở',
        'Hướng dẫn đọc theo dòng',
      ];
      for (final source in cases) {
        final english = generatedPriorityNativePack[source]!['en']!;
        for (final locale in _priorityLocales) {
          final resolved = AppUITranslations.translate(source, locale);
          expect(
            resolved,
            generatedPriorityNativePack[source]![locale],
            reason: '$source [$locale]',
          );
          expect(
            resolved,
            isNot(english),
            reason: '$source [$locale] rơi về English dù pack đã có bản dịch',
          );
          expect(
            _vietnameseOnly.hasMatch(resolved),
            isFalse,
            reason: '$source [$locale] còn tiếng Việt',
          );
        }
      }
    });

    test('chuỗi chrome English cũng được bản địa hoá', () {
      expect(AppUITranslations.translate('Import', 'zh'), '导入');
      expect(AppUITranslations.translate('Captions', 'th'), 'คำบรรยาย');
      expect(AppUITranslations.translate('Video', 'ja'), '動画');
      expect(AppUITranslations.translate('Smart Study', 'my'), isNot('Smart Study'));
    });

    test('template runtime dịch được qua uiText (translate có template)', () {
      expect(
        AppUITranslations.translate('Tải Whisper SMALL?', 'zh'),
        '要下载 Whisper SMALL 吗？',
      );
      expect(
        AppUITranslations.translate('12 từ', 'zh'),
        '12 个词',
      );
      expect(
        AppUITranslations.translate('3 ngày liên tiếp', 'ja'),
        '3 日連続',
      );
    });

    test('locale ngoài danh sách ưu tiên vẫn rơi về English (rule #5)', () {
      const source = 'Dừng tối ưu mức sử dụng pin';
      final english = generatedPriorityNativePack[source]!['en']!;
      expect(AppUITranslations.translate(source, 'de'), english);
      expect(AppUITranslations.translate(source, 'fr'), english);
    });

    test('tiếng Việt giữ nguyên nguồn', () {
      const source = 'Dừng tối ưu mức sử dụng pin';
      expect(AppUITranslations.translate(source, 'vi'), source);
    });

    test('Text shim dịch được chuỗi exact của pack', () {
      // translateExact (shim) không bật template — chuỗi exact vẫn phải dịch.
      expect(
        AppUITranslations.translateExact('Chưa có video nào', 'zh'),
        '还没有视频',
      );
    });
  });
}
