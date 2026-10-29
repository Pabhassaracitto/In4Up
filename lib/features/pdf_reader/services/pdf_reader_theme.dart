// Chủ đề đọc cho màn PDF (Wave 1.5 — xem docs/pdf_reader_readera_upgrade.md §4.2).
//
// Tách khỏi widget vì: (1) bảng màu + thứ tự lớp phủ là logic thuần nên test
// được bằng `flutter test`, và CI của repo không chạy test widget; (2) màn đọc
// đã quá dài. Đây cũng là mô hình ADR-0004 đã chọn cho Wave 1: service thuần +
// widget/screen chỉ nối dây.
//
// CƠ CHẾ: pdfrx 2.2.24 không có API "reading theme" cho PDF (PDF là nội dung
// cố định, không reflow được), nhưng `PdfViewerParams.pagePaintCallbacks` cho
// phép vẽ lên trên vùng trang SAU khi trang đã render. Mỗi chủ đề = một tập lớp
// phủ màu đơn sắc (veil) với blend mode xác định, vẽ theo đúng thứ tự trong
// danh sách. Nền quanh trang dùng `PdfViewerParams.backgroundColor`.
//
// Hai hệ quả phải nhớ khi nối dây (đã verify trong nguồn pdfrx 2.2.24):
//  * `pagePaintCallbacks` KHÔNG nằm trong `doChangesRequireReload` ⇒ đổi theme
//    một mình không làm viewer vẽ lại; screen phải gọi `controller.invalidate()`.
//  * Thứ tự trong danh sách là thứ tự vẽ ⇒ veil phải đứng TRƯỚC callback tô sáng
//    kết quả tìm kiếm, nếu không highlight bị sepia/đảo màu theo.
import 'package:shared_preferences/shared_preferences.dart';

/// Các chủ đề đọc. Thứ tự = thứ tự hiện trong bảng chọn.
enum PdfReaderTheme { dark, day, sepia, night }

/// Kiểu hoà màu của một lớp phủ. Có chủ ý KHÔNG dùng `BlendMode` của dart:ui ở
/// đây: service phải biên dịch được mà không kéo Flutter vào (dễ test, và widget
/// là chỗ duy nhất map sang `BlendMode`).
enum PdfVeilBlend {
  /// Nhân màu — làm trang tối và ám màu đi (sepia). Không làm mất chữ đen.
  multiply,

  /// Phủ bán trong suốt — dùng để che mờ dần (giảm sáng trang).
  over,

  /// Cộng màu — kéo trang về phía trắng (tăng sáng trang).
  plus,

  /// |dst - src| với src = trắng ⇒ đảo màu đúng nghĩa (chế độ Đêm).
  difference,
}

/// Một lớp phủ màu đơn sắc lên toàn bộ vùng trang đã render.
final class PdfPageVeil {
  const PdfPageVeil({
    required this.colorArgb,
    required this.alpha,
    required this.blend,
  });

  /// Màu ARGB gốc, CHƯA nhân alpha.
  final int colorArgb;

  /// 0..1. Với [PdfVeilBlend.difference] phải là 1.0 để đảo màu sạch.
  final double alpha;

  final PdfVeilBlend blend;

  @override
  bool operator ==(Object other) =>
      other is PdfPageVeil &&
      other.colorArgb == colorArgb &&
      other.alpha == alpha &&
      other.blend == blend;

  @override
  int get hashCode => Object.hash(colorArgb, alpha, blend);

  @override
  String toString() =>
      'PdfPageVeil(0x${colorArgb.toRadixString(16)}, a=${alpha.toStringAsFixed(2)}, ${blend.name})';
}

/// Trạng thái đọc: chủ đề + độ sáng trang, đã hiệu chỉnh về miền hợp lệ.
final class PdfReaderThemeState {
  const PdfReaderThemeState({
    required this.theme,
    required this.brightness,
  });

  /// Mặc định = giao diện hiện tại của app, không thêm lớp phủ nào ⇒ nâng cấp
  /// Wave 1.5 không được làm đổi hình dạng của người dùng cũ.
  static const PdfReaderThemeState defaults = PdfReaderThemeState(
    theme: PdfReaderTheme.dark,
    brightness: 0,
  );

  final PdfReaderTheme theme;

  /// -1 (tối nhất) .. 1 (sáng nhất), 0 = giữ nguyên màu trang.
  final double brightness;

  bool get isDefault => theme == PdfReaderTheme.dark && brightness == 0;

  List<PdfPageVeil> get pageVeils =>
      pdfReaderPageVeils(theme: theme, brightness: brightness);

  int get surroundColorArgb => pdfReaderSurroundColorArgb(theme);

  String get labelKey => pdfReaderThemeLabelKey(theme);

  PdfReaderThemeState copyWith({
    PdfReaderTheme? theme,
    double? brightness,
  }) =>
      PdfReaderThemeState(
        theme: theme ?? this.theme,
        brightness: brightness == null
            ? this.brightness
            : clampPdfPageBrightness(brightness),
      );

  @override
  bool operator ==(Object other) =>
      other is PdfReaderThemeState &&
      other.theme == theme &&
      other.brightness == brightness;

  @override
  int get hashCode => Object.hash(theme, brightness);

  @override
  String toString() => 'PdfReaderThemeState(${theme.name}, $brightness)';
}

const double kPdfPageBrightnessMin = -1;
const double kPdfPageBrightnessMax = 1;

/// Độ sáng trang nằm trong thanh trượt ⇒ phải kẹp, vì `Slider` trả về double và
/// giá trị cũ từ prefs có thể bị hỏng/NaN.
double clampPdfPageBrightness(double raw) {
  if (raw.isNaN || raw.isInfinite) return 0;
  return raw.clamp(kPdfPageBrightnessMin, kPdfPageBrightnessMax).toDouble();
}

const PdfPageVeil _sepiaPageVeil = PdfPageVeil(
  colorArgb: 0xFFF6E7C8,
  alpha: 0.32,
  blend: PdfVeilBlend.multiply,
);

/// Trắng, alpha 1, difference = đảo màu trang. Ảnh trong trang cũng bị đảo —
/// đó là đánh đổi đã báo trước trong [pdfReaderThemeNoteKey].
const PdfPageVeil _nightPageVeil = PdfPageVeil(
  colorArgb: 0xFFFFFFFF,
  alpha: 1.0,
  blend: PdfVeilBlend.difference,
);

/// Danh sách lớp phủ theo đúng thứ tự vẽ: ám màu trước, chỉnh độ sáng sau.
///
/// `dark` và `day` không ám màu trang (`day` chỉ đổi nền quanh trang + chữ vẫn
/// là chữ đen trên nền trắng), nên với brightness 0 danh sách rỗng ⇒ screen
/// không truyền callback nào, tiết kiệm một lớp composite.
List<PdfPageVeil> pdfReaderPageVeils({
  required PdfReaderTheme theme,
  required double brightness,
}) {
  final veils = <PdfPageVeil>[
    if (theme == PdfReaderTheme.sepia) _sepiaPageVeil,
    if (theme == PdfReaderTheme.night) _nightPageVeil,
  ];
  final b = clampPdfPageBrightness(brightness);
  // 0.85/0.6 là trần thực dụng: che đen quá 0.85 thì chữ không còn đọc được,
  // cộng trắng quá 0.6 thì nền trang cháy thành một mảng trắng.
  if (b < 0) {
    veils.add(
      PdfPageVeil(
        colorArgb: 0xFF000000,
        alpha: -b * 0.85,
        blend: PdfVeilBlend.over,
      ),
    );
  } else if (b > 0) {
    veils.add(
      PdfPageVeil(
        colorArgb: 0xFFFFFFFF,
        alpha: b * 0.6,
        blend: PdfVeilBlend.plus,
      ),
    );
  }
  return List<PdfPageVeil>.unmodifiable(veils);
}

/// Màu nền VŨNG QUANH trang (canvas của PdfView), không phải màu trang.
int pdfReaderSurroundColorArgb(PdfReaderTheme theme) => switch (theme) {
      PdfReaderTheme.dark => 0xFF1A1A2E,
      PdfReaderTheme.day => 0xFFE6E6E9,
      PdfReaderTheme.sepia => 0xFFC9B48F,
      PdfReaderTheme.night => 0xFF000000,
    };

/// Màu trang mô phỏng trong ô xem trước của bảng chọn theme.
int pdfReaderPreviewPageColorArgb(PdfReaderTheme theme) => switch (theme) {
      PdfReaderTheme.dark => 0xFFFFFFFF,
      PdfReaderTheme.day => 0xFFFFFFFF,
      PdfReaderTheme.sepia => 0xFFEFE0C0,
      PdfReaderTheme.night => 0xFF0A0A0A,
    };

/// Màu "chữ" mô phỏng trong ô xem trước.
int pdfReaderPreviewInkColorArgb(PdfReaderTheme theme) => switch (theme) {
      PdfReaderTheme.night => 0xFFF2F2F2,
      _ => 0xFF2A2A2A,
    };

/// Key catalog cho tên chủ đề (rule #5: label luôn là key, không chuỗi ghép).
String pdfReaderThemeLabelKey(PdfReaderTheme theme) => switch (theme) {
      PdfReaderTheme.dark => 'Tối (mặc định)',
      PdfReaderTheme.day => 'Sáng',
      PdfReaderTheme.sepia => 'Giấy (sepia)',
      PdfReaderTheme.night => 'Đêm (đảo màu)',
    };

/// Ghi chú chỉ hiện khi chủ đề có tác dụng phụ đáng ngạc nhiên.
String? pdfReaderThemeNoteKey(PdfReaderTheme theme) =>
    theme == PdfReaderTheme.night
        ? 'Đảo màu làm ảnh trong trang bị đảo theo.'
        : null;

/// Tóm tắt cho dòng menu: tên theme, kèm % độ sáng nếu khác 0.
/// Trả về (labelKey, suffix) để widget dich label còn suffix là số, không cần dịch.
({String labelKey, String? suffix}) pdfReaderThemeSummary(
  PdfReaderThemeState state,
) {
  final percent = (clampPdfPageBrightness(state.brightness) * 100).round();
  return (
    labelKey: pdfReaderThemeLabelKey(state.theme),
    suffix: percent == 0 ? null : (percent > 0 ? '+$percent%' : '$percent%'),
  );
}

/// Tên bền vững trong prefs — dùng chuỗi tường minh, không dùng `enum.name` để
/// sau này đổi tên enum không làm mất cài đặt của người dùng.
String pdfReaderThemeName(PdfReaderTheme theme) => switch (theme) {
      PdfReaderTheme.dark => 'dark',
      PdfReaderTheme.day => 'day',
      PdfReaderTheme.sepia => 'sepia',
      PdfReaderTheme.night => 'night',
    };

/// Parse khoan dung: giá trị lạ/thiếu => mặc định (app không được crash vì
/// một key prefs bị hỏng giữa phiên nâng cấp).
PdfReaderTheme parsePdfReaderThemeName(String? raw) => switch (raw) {
      'day' => PdfReaderTheme.day,
      'sepia' => PdfReaderTheme.sepia,
      'night' => PdfReaderTheme.night,
      _ => PdfReaderTheme.dark,
    };

const String kPdfReaderThemePrefsKey = 'pdf_reader.theme_v1';
const String kPdfReaderPageBrightnessPrefsKey = 'pdf_reader.page_brightness_v1';

/// [prefs] chỉ để test chèn bản mock; production gọi không tham số.
Future<PdfReaderThemeState> loadPdfReaderThemeState({
  SharedPreferences? prefs,
}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  return PdfReaderThemeState(
    theme: parsePdfReaderThemeName(store.getString(kPdfReaderThemePrefsKey)),
    brightness: clampPdfPageBrightness(
      store.getDouble(kPdfReaderPageBrightnessPrefsKey) ?? 0,
    ),
  );
}

Future<void> savePdfReaderThemeState(
  PdfReaderThemeState state, {
  SharedPreferences? prefs,
}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  await store.setString(
    kPdfReaderThemePrefsKey,
    pdfReaderThemeName(state.theme),
  );
  final b = clampPdfPageBrightness(state.brightness);
  if (b == 0) {
    await store.remove(kPdfReaderPageBrightnessPrefsKey);
  } else {
    await store.setDouble(kPdfReaderPageBrightnessPrefsKey, b);
  }
}

Future<void> resetPdfReaderThemeState({SharedPreferences? prefs}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  await store.remove(kPdfReaderThemePrefsKey);
  await store.remove(kPdfReaderPageBrightnessPrefsKey);
}
