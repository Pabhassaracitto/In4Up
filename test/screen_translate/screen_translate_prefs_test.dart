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

  // XLAT-SCR-005 — ngôn ngữ NGUỒN + chế độ kéo chọn vùng.
  group('normalizeScreenTranslateSource', () {
    test('rỗng / null ⇒ AUTO', () {
      expect(normalizeScreenTranslateSource(null), 'AUTO');
      expect(normalizeScreenTranslateSource('  '), 'AUTO');
    });

    test('mã hợp lệ được chuẩn hoá hoa/thường', () {
      expect(normalizeScreenTranslateSource(' en '), 'EN');
      expect(normalizeScreenTranslateSource('ja'), 'JA');
      expect(normalizeScreenTranslateSource('zh-tw'), 'ZH-TW');
    });

    test('AUTO/SYSTEM giữ nguyên nghĩa tự nhận diện', () {
      expect(normalizeScreenTranslateSource('auto'), 'AUTO');
      expect(normalizeScreenTranslateSource('system'), 'AUTO');
    });

    test('mã lạ ⇒ AUTO (KHÔNG đoán bừa sang EN)', () {
      expect(normalizeScreenTranslateSource('klingon'), 'AUTO');
    });

    test('khoá lưu là hằng số ổn định', () {
      expect(kScreenTranslateSourcePrefKey, 'screen_translate_source_lang');
      expect(
        kScreenTranslateSelectRegionPrefKey,
        'screen_translate_select_region',
      );
    });
  });

  group('defaultScreenTranslateTargetForLocale', () {
    test('locale ứng dụng ⇒ đúng ngôn ngữ đích gợi ý', () {
      expect(defaultScreenTranslateTargetForLocale('vi'), 'VI');
      expect(defaultScreenTranslateTargetForLocale('ja'), 'JA');
      expect(defaultScreenTranslateTargetForLocale('zh-TW'), 'ZH-TW');
    });

    test('locale lạ / null ⇒ VI (mặc định lịch sử)', () {
      expect(defaultScreenTranslateTargetForLocale('xx'), 'VI');
      expect(defaultScreenTranslateTargetForLocale(null), 'VI');
    });
  });
}
