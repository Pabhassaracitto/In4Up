// Chủ đề đọc (Wave 1.5) là bảng màu + thứ tự lớp phủ, không phải widget: test
// logic thuần để (1) mặc định KHÔNG đổi hình dạng app cũ, (2) veil vẽ đúng thứ
// tự (ám màu trước, sáng/tối sau) và (3) mọi nhãn trong sheet có bản dịch,
// không rơi lại tiếng Việt ở locale khác (rule #5).
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/features/pdf_reader/services/pdf_reader_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mặc định phải giữ nguyên giao diện cũ', () {
    test('defaults: không lớp phủ, nền đúng màu viewer hiện tại', () {
      expect(PdfReaderThemeState.defaults.isDefault, isTrue);
      expect(PdfReaderThemeState.defaults.pageVeils, isEmpty);
      expect(
        PdfReaderThemeState.defaults.surroundColorArgb,
        0xFF1A1A2E,
        reason: 'đây là backgroundColor đang dùng trong PdfViewerParams — đổi '
            'giá trị này là đổi diện mạo app cho mọi người dùng cũ',
      );
    });

    test('dark + day không ám màu trang (day chỉ đổi nền quanh trang)', () {
      for (final theme in [PdfReaderTheme.dark, PdfReaderTheme.day]) {
        expect(pdfReaderPageVeils(theme: theme, brightness: 0), isEmpty,
            reason: '$theme không được phủ màu lên trang');
      }
      expect(pdfReaderSurroundColorArgb(PdfReaderTheme.day),
          isNot(pdfReaderSurroundColorArgb(PdfReaderTheme.dark)));
    });
  });

  group('lớp phủ màu', () {
    test('sepia = multiply; night = difference trắng alpha 1 (đảo màu sạch)', () {
      final sepia =
          pdfReaderPageVeils(theme: PdfReaderTheme.sepia, brightness: 0);
      expect(sepia, hasLength(1));
      expect(sepia.single.blend, PdfVeilBlend.multiply);
      expect(sepia.single.alpha, greaterThan(0));
      expect(sepia.single.alpha, lessThan(1));

      final night = pdfReaderPageVeils(theme: PdfReaderTheme.night, brightness: 0);
      expect(night, hasLength(1));
      expect(night.single.blend, PdfVeilBlend.difference);
      expect(night.single.colorArgb, 0xFFFFFFFF);
      // alpha < 1 với difference cho ra nửa vời: vừa không đảo sạch vừa mất tương phản.
      expect(night.single.alpha, 1.0);
    });

    test('thứ tự vẽ: ám màu TRƯỚC, chỉnh độ sáng SAU', () {
      final veils =
          pdfReaderPageVeils(theme: PdfReaderTheme.sepia, brightness: 0.5);
      expect(veils.map((v) => v.blend).toList(),
          [PdfVeilBlend.multiply, PdfVeilBlend.plus]);
      expect(
          pdfReaderPageVeils(theme: PdfReaderTheme.night, brightness: -0.5)
              .map((v) => v.blend)
              .toList(),
          [PdfVeilBlend.difference, PdfVeilBlend.over]);
    });

    test('độ sáng: âm = che đen, dương = cộng trắng, 0 = không có lớp phủ', () {
      final dim = pdfReaderPageVeils(
          theme: PdfReaderTheme.dark, brightness: -0.5)
          .single;
      expect(dim.colorArgb, 0xFF000000);
      expect(dim.blend, PdfVeilBlend.over);
      expect(dim.alpha, closeTo(0.425, 1e-9));

      final bright = pdfReaderPageVeils(
          theme: PdfReaderTheme.dark, brightness: 0.5)
          .single;
      expect(bright.colorArgb, 0xFFFFFFFF);
      expect(bright.blend, PdfVeilBlend.plus);
      expect(bright.alpha, closeTo(0.3, 1e-9));

      // Trần thực dụng: quá 0.85 thì chữ biến mất, quá 0.6 thì trang cháy trắng.
      expect(pdfReaderPageVeils(theme: PdfReaderTheme.dark, brightness: -1).single.alpha,
          closeTo(0.85, 1e-9));
      expect(pdfReaderPageVeils(theme: PdfReaderTheme.dark, brightness: 1).single.alpha,
          closeTo(0.6, 1e-9));
      expect(
          pdfReaderPageVeils(theme: PdfReaderTheme.night, brightness: 0), hasLength(1));
    });
  });

  group('miền giá trị', () {
    test('clampPdfPageBrightness kẹp 2 đầu và cứu NaN/vô cực', () {
      expect(clampPdfPageBrightness(5), 1);
      expect(clampPdfPageBrightness(-5), -1);
      expect(clampPdfPageBrightness(0.25), 0.25);
      expect(clampPdfPageBrightness(double.nan), 0);
      expect(clampPdfPageBrightness(double.infinity), 0);
      expect(clampPdfPageBrightness(-double.infinity), 0);
    });

    test('copyWith cũng kẹp (Slider có thể đưa giá trị ngoài)', () {
      expect(const PdfReaderThemeState(theme: PdfReaderTheme.day, brightness: 0)
          .copyWith(brightness: 9)
          .brightness,
          1);
    });

    test('name <-> parse: giá trị lạ về dark, không ném', () {
      for (final theme in PdfReaderTheme.values) {
        expect(parsePdfReaderThemeName(pdfReaderThemeName(theme)), theme);
      }
      expect(parsePdfReaderThemeName(null), PdfReaderTheme.dark);
      expect(parsePdfReaderThemeName(''), PdfReaderTheme.dark);
      expect(parsePdfReaderThemeName('vintage'), PdfReaderTheme.dark);
      expect(parsePdfReaderThemeName('dark'), PdfReaderTheme.dark);
    });

    test('tên lưu trong prefs là chuỗi cố định, không phụ thuộc thứ tự enum', () {
      expect(pdfReaderThemeName(PdfReaderTheme.dark), 'dark');
      expect(pdfReaderThemeName(PdfReaderTheme.day), 'day');
      expect(pdfReaderThemeName(PdfReaderTheme.sepia), 'sepia');
      expect(pdfReaderThemeName(PdfReaderTheme.night), 'night');
    });

    test('summary: chỉ thêm % khi độ sáng khác 0', () {
      expect(
          pdfReaderThemeSummary(const PdfReaderThemeState(
                  theme: PdfReaderTheme.sepia, brightness: 0))
              .suffix,
          isNull);
      expect(
          pdfReaderThemeSummary(const PdfReaderThemeState(
                  theme: PdfReaderTheme.sepia, brightness: 0.5))
              .suffix,
          '+50%');
      expect(
          pdfReaderThemeSummary(const PdfReaderThemeState(
                  theme: PdfReaderTheme.night, brightness: -0.3))
              .suffix,
          '-30%');
    });
  });

  group('prefs', () {
    test('round-trip theme + độ sáng, và độ sáng 0 thì xoá key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await savePdfReaderThemeState(const PdfReaderThemeState(
          theme: PdfReaderTheme.night, brightness: 0.4));
      var loaded = await loadPdfReaderThemeState();
      expect(loaded.theme, PdfReaderTheme.night);
      expect(loaded.brightness, closeTo(0.4, 1e-9));
      expect(loaded.isDefault, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(kPdfReaderPageBrightnessPrefsKey), isNotNull);

      await savePdfReaderThemeState(
          const PdfReaderThemeState(theme: PdfReaderTheme.day, brightness: 0));
      expect(prefs.getDouble(kPdfReaderPageBrightnessPrefsKey), isNull,
          reason: 'brightness 0 không nên để lại key rác trong prefs');
      loaded = await loadPdfReaderThemeState();
      expect(loaded,
          const PdfReaderThemeState(theme: PdfReaderTheme.day, brightness: 0));
    });

    test('prefs hỏng/NaN -> mặc định, không crash', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPdfReaderThemePrefsKey: 'hologram',
        kPdfReaderPageBrightnessPrefsKey: double.nan,
      });
      expect(await loadPdfReaderThemeState(), PdfReaderThemeState.defaults);
    });

    test('reset xoá cả hai key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await savePdfReaderThemeState(const PdfReaderThemeState(
          theme: PdfReaderTheme.sepia, brightness: -0.5));
      await resetPdfReaderThemeState();
      expect(await loadPdfReaderThemeState(), PdfReaderThemeState.defaults);
    });
  });

  group('i18n (rule #5)', () {
    test('mọi chủ đề có nhãn, và label key đúng là key catalog', () {
      expect(PdfReaderTheme.values.map(pdfReaderThemeLabelKey).toSet().length,
          PdfReaderTheme.values.length);
      for (final theme in PdfReaderTheme.values) {
        final label = pdfReaderThemeLabelKey(theme);
        expect(AppUITranslations.translate(label, 'en'), isNot(equals(label)),
            reason: '"$label" chưa có trong catalog — người dùng en sẽ thấy '
                'nguyên văn tiếng Việt trong sheet Chủ đề đọc');
      }
      final note = pdfReaderThemeNoteKey(PdfReaderTheme.night);
      expect(note, isNotNull);
      expect(AppUITranslations.translate(note!, 'en'), isNot(equals(note)),
          reason: 'cảnh báo đảo màu phải dịch được');
      expect(pdfReaderThemeNoteKey(PdfReaderTheme.day), isNull);
    });

    test('bản dịch en/hi/zh/zh_TW/si của chrome theme không còn dấu tiếng Việt',
        () {
      final vi = RegExp(
        r'[àảãáạăằắẳẵặâầấẩẫậèẻẽéẹêềếểễệìỉĩíịòọỏõóôồốổỗộơờớởỡợùủũúụừứửữựỳỷỹđ]',
        caseSensitive: false,
      );
      final labels = <String>[
        ...PdfReaderTheme.values.map(pdfReaderThemeLabelKey),
        pdfReaderThemeNoteKey(PdfReaderTheme.night)!,
        'Chủ đề đọc',
        'Độ sáng trang',
        'Đặt lại',
        'Sáng',
        'Tối',
      ];
      for (final label in labels) {
        for (final lang in ['en', 'hi', 'zh', 'zh_TW', 'si']) {
          final value = AppUITranslations.translate(label, lang);
          expect(vi.hasMatch(value), isFalse,
              reason: '"$label" [$lang] = "$value" — vẫn là tiếng Việt ở locale '
                  '$lang. Sửa lib/core/language/priority_ui_overrides.dart');
        }
      }
    });
  });
}
