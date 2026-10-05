// XLAT-SCR-002 — chuẩn hoá ngôn ngữ đích lưu cho bong bóng dịch.
//
// Engine nền và UI đọc chung một khoá SharedPreferences; nếu một bên ghi
// 'vi' còn bên kia đợi 'VI' thì bản dịch ra sai ngôn ngữ mà không báo lỗi.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/screen_translate/screen_translate_prefs.dart';

void main() {
  group('normalizeScreenTranslateTarget', () {
    test('null / rỗng ⇒ mặc định VI', () {
      expect(normalizeScreenTranslateTarget(null), 'VI');
      expect(normalizeScreenTranslateTarget('   '), 'VI');
    });

    test('không phân biệt hoa thường và khoảng trắng', () {
      expect(normalizeScreenTranslateTarget(' en '), 'EN');
      expect(normalizeScreenTranslateTarget('hi'), 'HI');
    });

    test('mã không có trong catalog ⇒ mặc định VI (không đoán bừa)', () {
      expect(normalizeScreenTranslateTarget('klingon'), 'VI');
    });

    test('khoá SharedPreferences là hằng số ổn định', () {
      expect(kScreenTranslateTargetPrefKey, 'screen_translate_target_lang');
      expect(kScreenTranslateDefaultTarget, 'VI');
    });
  });
}
