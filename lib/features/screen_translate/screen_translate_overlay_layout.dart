// lib/features/screen_translate/screen_translate_overlay_layout.dart
//
// XLAT-SCR-006 — bong bóng dịch: KHUNG PHẢI ĐỦ CHỖ CHO CHỮ, và các khối vẫn
// KHÔNG được chồng lên nhau.
//
// ════════════════════════════════════════════════════════════════════════════
// Lịch sử quyết định (đọc để không đảo lại lần thứ ba):
//
//  • Trước AUDIT-1.21.0 #1: native vẽ `boxHeight = max(height, layout.height)`
//    ⇒ khối TRÊN phình xuống đè khối DƯỚI ⇒ chữ chồng nhau.
//  • AUDIT-1.21.0 #1 (bản trước file này): sửa bằng cách CẮT khung khối trên
//    đúng mép khối dưới ⇒ hết chồng, nhưng bản dịch (VI thường dài hơn EN
//    ~1.3×) không còn chỗ ⇒ native thu nhỏ tới 9sp rồi ellipsize ⇒ **mất chữ,
//    chữ bé không đọc được**. Đây là lỗi owner báo 2026-11-11 (ảnh chụp).
//
// ⇒ Hợp đồng (owner 2026-11-11): "chữ hiện đầy đủ, không bị bóp nhỏ/ẩn do
//   khung nhỏ, nhưng cũng không để các lớp dịch chồng lên nhau".
//
//  • XLAT-SCR-006 thực hiện hợp đồng đó bằng "nới cao rồi ĐẨY khối dưới xuống;
//    tràn màn hình thì thu nhỏ đều, chia ngân sách, bỏ khối". Hệ quả owner báo
//    ở PSRC-211 (audit v1.28.0): **bỏ sót nhiều khối, bản dịch sai vị trí,
//    khung thừa khoảng trống bên dưới**. Bốn nguyên nhân gốc, đều ở file này:
//      1. Cỡ chữ đo theo chiều cao CẢ KHỐI: đoạn văn 3 dòng 14sp bị tính
//         thành 28sp ⇒ cần gấp ~4 lần diện tích.
//      2. Cỡ chữ quên chia `fontScale`: máy bật cỡ chữ hệ thống 1.3× vẽ bản
//         dịch to gấp 1.3 lần chữ gốc.
//      3. Bộ ước lượng coi `\n` là khoảng trắng, native (`StaticLayout`) thì
//         xuống dòng thật ⇒ Dart cấp thiếu chỗ ⇒ native bỏ vẽ khối.
//      4. Chính sách "đẩy trước": MỘT khối cần thêm chỗ là MỌI khối bên dưới
//         bị lệch khỏi chữ gốc của nó; dồn tới đáy màn hình thì bị bỏ.
//
// ⇒ PSRC-211 GIỮ nguyên hợp đồng trên (đủ chữ, ≥ 10sp, không chồng) và thêm:
//   **mỗi bản dịch nằm ĐÚNG CHỖ chữ gốc của nó**. Thứ tự ưu tiên khi thiếu chỗ:
//     nới rộng → dùng khoảng trống ngay bên dưới → THU NHỎ riêng khối đó (sàn
//     [kOverlayMinReadableSp]) → mới đến đẩy khối dưới → hết màn hình thì bỏ
//     vẽ khối không nổi NGUYÊN bản dịch (để lộ chữ gốc, KHÔNG cắt, KHÔNG `…`).
//   Khối bị đẩy tự thu nhỏ để "nuốt" độ lệch ⇒ lệch không lan xuống dưới.
//
// Vẫn giữ nguyên tinh thần ADR-0011: Dart xếp chỗ (thuần, test được), native
// chỉ vẽ trong khung được cấp. Dart không đo được font thật nên dùng bộ ước
// lượng bên dưới — cố tình ước DƯ (1.06×) để native không bao giờ thiếu chỗ.
// Phần dư đó KHÔNG còn hiện ra thành khoảng trống: native vẽ nền ôm sát chữ
// thật (xem `ScreenBlock.coverBottom` / `maxTextSizeSp`).
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;

import 'screen_translate_geometry.dart';
import 'screen_translate_models.dart';
import 'screen_translate_text_flow.dart';

/// Dưới ngưỡng này coi là frame giả / màn hình không phải thiết bị thật.
const int kOverlayRealScreenMinPx = 200;

/// Chiều cao tối thiểu (dp) để còn vẽ được 1 dòng chữ + padding.
const double kOverlayMinBoxHeightDp = 11.0;

/// Khe hở giữa 2 khung kề nhau (dp).
const double kOverlayBoxGapDp = 2.0;

/// Hai khung coi là "giao nhau theo chiều ngang" khi phần giao ≥ tỉ lệ này
/// của khung hẹp hơn. Hai cột chữ cạnh nhau (giao 1-2px do OCR lệch) KHÔNG
/// bị đẩy nhầm.
const double kOverlayHorizontalOverlapRatio = 0.25;

/// Hai khung cùng nội dung coi là "trùng" khi phần giao ≥ tỉ lệ này.
const double kOverlayDuplicateRatio = 0.55;

/// Padding trong khung, PIXEL. PHẢI khớp `TranslationOverlayView.padding`.
const double kOverlayTextPaddingPx = 4.0;

/// Cỡ chữ nhỏ nhất còn đọc được. Không bao giờ vẽ nhỏ hơn — nhỏ hơn thì chữ
/// thành vệt xám, đúng lỗi owner báo.
const double kOverlayMinReadableSp = 10.0;

/// Hệ số chiều cao dòng / cỡ chữ với `setLineSpacing(0f, 1.0f)` của
/// `StaticLayout` (~1.17–1.25 tuỳ font hệ thống) ⇒ lấy 1.30 cho chắc (thừa chỗ
/// tốt hơn thiếu chỗ).
///
/// ⚠ Khi máy bật **cỡ chữ hệ thống lớn** (Accessibility → font scale 1.3–2.0),
/// `TypedValue.applyDimension(SP, …)` nhân thêm `scaledDensity/density` ⇒ dòng
/// cao hơn hẳn hệ số này. Vì vậy mọi phép đo PHẢI đi qua
/// [effectiveOverlayFontScale] — xem `OverlayFontMetrics`.
const double kOverlayLineHeightFactor = 1.30;

/// Lề đáy (dp) — không vẽ sát vạch điều hướng.
const double kOverlayBottomMarginDp = 8.0;

/// Bước thu nhỏ (sp) khi dò cỡ chữ vừa chỗ trống của một khối.
const double kOverlayShrinkStepSp = 0.5;

/// Hệ số an toàn của bộ ước lượng chiều cao (ước dư 6%).
const double kOverlayHeightSafety = 1.06;

/// Kích thước tối thiểu của **chip thu gọn** (dp) - PSRC-211 vòng 2.
///
/// Mục 3 của `L4-hub-tra-loi.md`: khi khung không còn chỗ cho bản dịch ngay cả
/// ở sàn [kOverlayMinReadableSp], khối KHÔNG bị bỏ vẽ nữa mà thành một chip nhỏ
/// ở góc trên-phải khối gốc. Chạm chip -> native mở popup hiện ĐỦ bản dịch ở cỡ
/// chữ đọc được (>= 10sp). Nhờ vậy "không khối chữ nào bị bỏ im lặng".
const double kOverlayChipWidthDp = 26.0;
const double kOverlayChipHeightDp = 20.0;

/// Trần của `fontScale` được áp vào phép đo.
///
/// Native đọc cỡ chữ người dùng qua `TypedValue` (sp). Cỡ chữ hệ thống lớn
/// (Accessibility) làm chữ cao hơn ~1.3–2.0×; nếu Dart vẫn ước theo 1.0× thì
/// khung cấp thiếu ⇒ native phải cắt. Kẹp ở 2.0 để một giá trị rác từ native
/// (`fontScale = 0` hoặc 10) không làm tràn cả màn hình.
const double kOverlayMaxFontScale = 2.0;

/// `fontScale` dùng trong phép đo — luôn ≥ 1 (cỡ chữ hệ thống KHÔNG BAO GIỜ
/// làm chữ nhỏ đi so với 1.0) và ≤ [kOverlayMaxFontScale].
double effectiveOverlayFontScale(double rawFontScale) {
  if (!rawFontScale.isFinite || rawFontScale <= 1.0) return 1.0;
  return rawFontScale > kOverlayMaxFontScale
      ? kOverlayMaxFontScale
      : rawFontScale;
}

/// Thông số font THẬT của thiết bị cho bộ ước lượng.
///
/// `devicePixelRatio` = `displayMetrics.density` (không đổi theo cỡ chữ).
/// [fontScale] = `configuration.fontScale` — bắt buộc truyền vào, vì
/// `TypedValue.applyDimension(SP, …)` của native nhân thêm tỉ lệ này.
///
/// Thiếu [fontScale] (mặc định 1.0) là đúng cho máy để cỡ chữ chuẩn; với máy
/// bật cỡ chữ lớn, **chính đây là lý do khung cấp thiếu chỗ** dù bộ ước lượng
/// đã ước dư 6%.
class OverlayFontMetrics {
  final double devicePixelRatio;
  final double fontScale;

  const OverlayFontMetrics({
    required this.devicePixelRatio,
    this.fontScale = 1.0,
  });

  factory OverlayFontMetrics.fromGeometry(ScreenCaptureGeometry geometry) {
    return OverlayFontMetrics(
      devicePixelRatio: geometry.devicePixelRatio,
      fontScale: geometry.fontScale,
    );
  }

  double get dpr => devicePixelRatio > 0 ? devicePixelRatio : 1.0;

  /// Hệ số quy đổi sp → px mà native sẽ dùng.
  double get pxPerSp => dpr * effectiveOverlayFontScale(fontScale);

  /// Số dòng tối đa **còn đọc được** trong [availableHeightPx].
  int maxReadableLines(double availableHeightPx) {
    if (availableHeightPx <= 0) return 1;
    return math.max(1, (availableHeightPx / pxPerSp).floor());
  }
}

class _Slot {
  _Slot(
    this.index,
    this.block,
    this.left,
    this.top,
    this.right,
    this.bottom,
    OverlayFontMetrics metrics,
  )   : origTop = top,
        origBottom = bottom,
        coverBottom = bottom,
        baseSp = _baseTextSizeSp(block, metrics);

  /// Cỡ chữ gốc (sp) của khối — chốt MỘT LẦN từ khung OCR ban đầu, theo chiều
  /// cao MỘT DÒNG và đã chia `fontScale` (xem [_baseTextSizeSp]).
  ///
  /// KHÔNG lấy lại `suggestedTextSizeSp(height)` sau khi xếp chỗ: khung được
  /// nới cao hơn ⇒ hàm đó cho số LỚN hơn ⇒ cần thêm chỗ ⇒ vòng lặp tự sinh
  /// (CI 42908858046 bắt đúng lỗi "khung đơn cần 538.5px, có 198.0px").
  final double baseSp;

  final int index;
  final ScreenBlock block;

  /// Mép trái của khung. Chỉ ĐỔI khi khối bị thu gọn thành chip ([collapseTo]):
  /// chip hẹp 26dp nên nó dời mép trái vào trong, còn cạnh phải/đỉnh vẫn là
  /// của khối gốc.
  int left;

  /// Vị trí GỐC (từ OCR) — mốc để `_pack` đặt khối đúng chỗ chữ gốc và để
  /// tính "trần" của khối phía trên. Không bao giờ đổi.
  final int origTop;
  final int origBottom;

  int top;

  /// Có thể NỚI sang phải (khi điều đó giảm số dòng) — xem
  /// `_expandHorizontally`. Không bao giờ vượt khối bên phải cùng hàng.
  int right;
  int bottom;

  /// Cỡ chữ dùng để vẽ (sp) — sau khi nới/ thu nhỏ.
  double textSizeSp = 14.0;

  /// Đáy của chữ gốc bên trong khung đã xếp — xem `ScreenBlock.coverBottom`.
  int coverBottom;

  /// Khối bị THU GỌN thành chip (PSRC-211 vòng 2). `rect` của slot khi đó là
  /// hình chữ nhật của CHIP, không phải khung chữ dịch.
  bool collapsed = false;

  /// Chuyển slot sang trạng thái CHIP với hình chữ nhật [rect]. Giữ cờ
  /// `collapsed` + cỡ chữ sàn trong MỘT chỗ (đừng tự gán 4 cạnh rời rạc ở
  /// nhiều nơi — dễ quên `coverBottom`).
  void collapseTo(OverlayRect rect, {required double textSizeSp}) {
    collapsed = true;
    left = rect.left;
    right = rect.right;
    top = rect.top;
    bottom = rect.bottom;
    this.textSizeSp = textSizeSp;
    coverBottom = rect.bottom;
  }

  int get width => math.max(1, right - left);
  int get height => math.max(1, bottom - top);

  bool overlapsHorizontally(_Slot other) {
    final overlap = math.min(right, other.right) - math.max(left, other.left);
    if (overlap <= 0) return false;
    final narrow = math.min(width, other.width);
    return overlap / narrow >= kOverlayHorizontalOverlapRatio;
  }

  /// Diện tích giao / diện tích khung nhỏ hơn.
  double overlapRatio(_Slot other) {
    final w = math.min(right, other.right) - math.max(left, other.left);
    final h = math.min(bottom, other.bottom) - math.max(top, other.top);
    if (w <= 0 || h <= 0) return 0.0;
    final smaller = math.min(
      width * math.max(1, bottom - top),
      other.width * math.max(1, other.bottom - other.top),
    );
    if (smaller <= 0) return 0.0;
    return (w * h) / smaller;
  }
}

/// Cỡ chữ gốc của [block]: chiều cao MỘT dòng ÷ số pixel của 1sp trên máy.
///
/// Số dòng lấy từ chữ GỐC (`original`, OCR nối dòng bằng `\n`) — không phải
/// từ bản dịch: ta đang đo chữ đang nằm trên màn hình.
double _baseTextSizeSp(ScreenBlock block, OverlayFontMetrics metrics) {
  return suggestedTextSizeSp(
    block.rect,
    metrics.dpr,
    lineCount: countTextLines(block.original),
    fontScale: metrics.fontScale,
  );
}

String _normalized(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

// ─────────────────────────────────────────────────────────────────────────────
// Bộ ước lượng kích thước chữ (thuần Dart — native mới đo được font thật,
// nhưng Dart cần biết trước để XẾP CHỖ. Ước dư tốt hơn thiếu.)
// ─────────────────────────────────────────────────────────────────────────────

/// Bề rộng tương đối của một ký tự, tính theo `em` (1.0 em = 1 cỡ chữ).
///
/// Bám theo bộ ký tự Latin + dấu tiếng Việt: dấu đi kèm nguyên âm nên KHÔNG
/// cộng thêm bề rộng (font dựng sẵn glyph). Số liệu là trung bình của font
/// sans hệ thống (Roboto) — chính xác tuyệt đối không cần, chỉ cần không hụt.
double _charWidthEm(int c) {
  // Khoảng trắng
  if (c == 0x20) return 0.30;
  // Hẹp
  if ('iljtfrI.,:;\'`!|'.codeUnits.contains(c)) return 0.32;
  if ('1'.codeUnits.contains(c)) return 0.50;
  // Rộng
  if ('mwMW'.codeUnits.contains(c)) return 0.90;
  if ('@%'.codeUnits.contains(c)) return 0.95;
  // Hoa (rộng hơn thường)
  if (c >= 0x41 && c <= 0x5A) return 0.66;
  // Số
  if (c >= 0x30 && c <= 0x39) return 0.55;
  // PSRC-211: chữ TOÀN ÔM (Hán, Kana, Hangul, dạng full-width) rộng đúng 1em.
  // Trước đây rơi vào nhánh 0.56 bên dưới ⇒ ước thiếu gần nửa bề ngang ⇒ đích
  // dịch là tiếng Trung/Nhật/Hàn thì native cần gấp đôi số dòng Dart cấp ⇒
  // khối bị bỏ vẽ.
  if (_isFullWidth(c)) return 1.0;
  // Latin-1 / Latin Extended (tiếng Việt có dấu nằm ở đây)
  if (c > 0x7F) return 0.56;
  // Chữ thường còn lại
  return 0.53;
}

bool _isFullWidth(int c) {
  return (c >= 0x1100 && c <= 0x11FF) || // Hangul Jamo
      (c >= 0x2E80 && c <= 0x9FFF) || // CJK bộ thủ, Kana, chữ Hán
      (c >= 0xAC00 && c <= 0xD7AF) || // Hangul âm tiết
      (c >= 0xF900 && c <= 0xFAFF) || // chữ Hán tương thích
      (c >= 0xFE30 && c <= 0xFE4F) || // dấu câu CJK dọc
      (c >= 0xFF00 && c <= 0xFF60) || // Latin/dấu câu full-width
      (c >= 0xFFE0 && c <= 0xFFE6);
}

double _textWidthEm(String text) {
  var sum = 0.0;
  for (final unit in text.codeUnits) {
    sum += _charWidthEm(unit);
  }
  return sum;
}

/// Ước lượng SỐ DÒNG khi ngắt theo TỪ ở bề ngang [maxWidthPx].
///
/// Ngắt theo từ (không theo ký tự) để khớp `StaticLayout`; một từ dài hơn cả
/// dòng thì tính số mảnh nó bị bẻ ra.
///
/// PSRC-211: `\n` là XUỐNG DÒNG THẬT. `StaticLayout` của native bắt đầu dòng
/// mới ở mỗi `\n`; bản trước tách theo `\s+` nên coi `\n` như dấu cách ⇒ bản
/// dịch 3 dòng ngắn được đếm là 1 dòng ⇒ khung cấp thiếu ⇒ native bỏ vẽ khối.
/// Giờ đếm từng đoạn rồi cộng lại; dòng trống giữa hai `\n` vẫn chiếm 1 dòng.
int estimateTranslationLineCount(
  String text,
  double maxWidthPx,
  double fontPx,
) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  if (maxWidthPx <= 0 || fontPx <= 0) return 1;

  var total = 0;
  for (final paragraph in trimmed.replaceAll('\r', '').split('\n')) {
    total += _wrappedLineCount(paragraph, maxWidthPx, fontPx);
  }
  return math.max(1, total);
}

/// Số dòng của MỘT đoạn không chứa `\n` (≥ 1 — đoạn rỗng vẫn là một dòng).
int _wrappedLineCount(String paragraph, double maxWidthPx, double fontPx) {
  var lines = 1;
  var current = 0.0;
  const spaceEm = 0.30;
  final spacePx = spaceEm * fontPx;

  for (final word in paragraph.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final w = _textWidthEm(word) * fontPx;
    if (current <= 0) {
      // Từ đầu dòng.
      if (w <= maxWidthPx) {
        current = w;
      } else {
        // Từ dài hơn dòng: native sẽ xuống dòng trong từ.
        final pieces = (w / maxWidthPx).ceil().clamp(1, 64);
        lines += pieces - 1;
        current = w - (pieces - 1) * maxWidthPx;
      }
      continue;
    }
    if (current + spacePx + w <= maxWidthPx) {
      current += spacePx + w;
    } else {
      lines++;
      current = w <= maxWidthPx ? w : maxWidthPx;
      if (w > maxWidthPx) {
        final extra = (w / maxWidthPx).ceil() - 1;
        lines += extra.clamp(0, 64);
      }
    }
  }
  return math.max(1, lines);
}

/// Chiều cao (px) cần để hiện ĐỦ [text] trên bề ngang [maxWidthPx], KHÔNG gồm
/// padding. Đã nhân hệ số an toàn [kOverlayHeightSafety].
double estimateTranslationTextHeightPx(
  String text,
  double maxWidthPx,
  double fontPx,
) {
  final lines = estimateTranslationLineCount(text, maxWidthPx, fontPx);
  if (lines <= 0) return 0;
  return lines * fontPx * kOverlayLineHeightFactor * kOverlayHeightSafety;
}

/// Số dòng **tối đa** mà native có thể vẽ cho [text] trong khung cao
/// [availableHeightPx] (đã trừ padding), ở cỡ chữ [fontPx].
///
/// Native KHÔNG được cắt chữ (owner 2026-11-11): nếu không đủ chỗ thì khung
/// phải được nới, hoặc khối bị bỏ vẽ. Hàm này để test/layout biết "còn thiếu
/// bao nhiêu dòng" và để native chỉ ellipsize khi bất khả kháng.
int estimateTranslationMaxLines(
  String text,
  double maxWidthPx,
  double fontPx,
  double availableHeightPx,
) {
  if (availableHeightPx <= 0) return 0;
  final lineHeight = fontPx * kOverlayLineHeightFactor;
  if (lineHeight <= 0) return 0;
  final capacity = (availableHeightPx / lineHeight).floor();
  if (capacity <= 0) return 0;
  final needed = estimateTranslationLineCount(text, maxWidthPx, fontPx);
  return math.min(capacity, needed);
}

/// Xếp lại [blocks] để bản dịch hiện ĐỦ CHỮ, ĐÚNG CHỖ và các ô KHÔNG chồng nhau.
///
/// [screenWidth]/[screenHeight] dùng để cắt biên + biết khi nào tràn màn hình;
/// truyền `0` (hoặc giá trị nhỏ hơn khung, như frame giả trong test) để tắt.
///
/// Hợp đồng:
///  • Giữ NGUYÊN số khối + thứ tự (native/controller dựa vào danh sách này).
///    Khối không vẽ được ⇒ `translation = ''` (native bỏ qua, chữ gốc hiện).
///  • Hai khối cùng nội dung + bbox giao nhau ⇒ chỉ giữ khối đầu.
///  • Cỡ chữ ưa thích = cỡ chữ GỐC (một dòng, đã chia `fontScale`).
///  • Khung được nới RỘNG (sang phải, vào khoảng trống) khi điều đó giảm số
///    dòng — đây là cách rẻ nhất để không phải thu nhỏ chữ.
///  • Đỉnh khung = đỉnh chữ gốc. Khung được nới CAO xuống tới sát khối kế tiếp
///    bên dưới; chưa đủ thì THU NHỎ riêng khối đó (không dưới
///    [kOverlayMinReadableSp]); vẫn chưa đủ mới ĐẨY khối dưới xuống (kèm khe
///    [kOverlayBoxGapDp]). Khối bị đẩy cũng tự thu nhỏ trước khi đẩy tiếp.
///  • Chạm đáy màn hình ⇒ dịch khung LÊN nếu phía trên còn trống; không được
///    thì THU GỌN thành chip (không cắt chữ, không bỏ khối). Các khối đã đặt
///    phía trên giữ nguyên.
///  • Bước CHỐT: khối nào khung vẫn thấp hơn nhu cầu ⇒ chip thu gọn
///    (`collapsed = true`, bản dịch vẫn nguyên vẹn). KHÔNG BAO GIỜ vẽ chữ cụt.
///  • [fontScale] = `configuration.fontScale` của thiết bị. Máy bật cỡ chữ hệ
///    thống lớn thì native vẽ chữ CAO hơn ⇒ Dart phải ước theo đúng tỉ lệ,
///    nếu không khung cấp thiếu chỗ và chữ bị cắt (lỗi owner báo 2026-11-11).
///  • Khung trả về là chỗ GIỮ cho khối (ước dư). `coverBottom`/`maxTextSizeSp`
///    cho native biết phải phủ tới đâu và được vẽ chữ to tới mức nào.
List<ScreenBlock> layoutTranslatedBlocks(
  List<ScreenBlock> blocks, {
  int screenWidth = 0,
  int screenHeight = 0,
  double devicePixelRatio = 1.0,
  double fontScale = 1.0,
}) {
  if (blocks.isEmpty) return <ScreenBlock>[];
  final metrics = OverlayFontMetrics(
    devicePixelRatio: devicePixelRatio,
    fontScale: fontScale,
  );
  if (blocks.length == 1) {
    return _layoutSingle(blocks, screenWidth, screenHeight, metrics);
  }
  // Frame giả trong test / màn hình nhỏ bất thường: đừng áp ngưỡng dp của
  // thiết bị thật vào khung chỉ vài pixel.
  final fakeFrame =
      (screenWidth > 0 && screenWidth < kOverlayRealScreenMinPx) ||
          (screenHeight > 0 && screenHeight < kOverlayRealScreenMinPx);
  if (fakeFrame) return List<ScreenBlock>.of(blocks);

  final dpr = metrics.dpr;
  final gap = math.max(1, (kOverlayBoxGapDp * dpr).round());

  // Trần cứng của mọi khung: không vẽ đè lên vạch điều hướng.
  final minHeight = math.max(6, (kOverlayMinBoxHeightDp * dpr).round());
  final bottomMargin = math.max(0, (kOverlayBottomMarginDp * dpr).round());
  final maxX = screenWidth > 0 ? screenWidth : null;
  final maxY = screenHeight > 0 ? screenHeight : null;
  final limitY = maxY == null ? null : math.max(1, maxY - bottomMargin);

  final slots = <_Slot>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final left = block.rect.left;
    final top = block.rect.top;
    final right = math.max(left + 1, block.rect.right);
    final bottom = math.max(top + 1, block.rect.bottom);
    final slot = _Slot(
      i,
      block,
      maxX == null ? left : math.max(0, math.min(maxX, left)),
      maxY == null ? top : math.min(maxY, top),
      maxX == null ? right : math.min(maxX, right),
      maxY == null ? bottom : math.min(maxY, bottom),
      metrics,
    );
    slots.add(slot);
  }

  // Thứ tự đọc: trên → dưới, trái → phải; `index` phá thế hoà cho ổn định.
  final ordered = List<_Slot>.of(slots)
    ..sort((a, b) {
      final byTop = a.top.compareTo(b.top);
      if (byTop != 0) return byTop;
      final byLeft = a.left.compareTo(b.left);
      if (byLeft != 0) return byLeft;
      return a.index.compareTo(b.index);
    });

  final dropped = <int>{};
  final visible = <_Slot>[];
  for (final slot in ordered) {
    if (slot.block.translation.trim().isEmpty) continue; // dịch hỏng: giữ nguyên
    // (a) Gộp khối TRÙNG nội dung + bbox giao nhau đáng kể.
    var duplicate = false;
    for (final other in visible) {
      if (_normalized(other.block.translation) !=
          _normalized(slot.block.translation)) {
        continue;
      }
      if (slot.overlapRatio(other) >= kOverlayDuplicateRatio) {
        duplicate = true;
        break;
      }
    }
    if (duplicate) {
      dropped.add(slot.index);
      continue;
    }
    visible.add(slot);
  }

  if (visible.isEmpty) {
    return _emit(blocks, slots, dropped);
  }

  // (b) Nới RỘNG trước — rẻ hơn nới cao vì không đụng tới khối nào khác.
  _expandHorizontally(visible, gap: gap, metrics: metrics, limitRight: maxX);

  // (c) Xếp chỗ TẠI CHỖ: mỗi khối giữ đỉnh gốc, thu nhỏ riêng nó khi chật, chỉ
  // đẩy khối dưới khi đã ở cỡ chữ sàn mà vẫn thiếu chỗ. Khối không còn chỗ
  // trên màn hình ⇒ CHIP THU GỌN (mục 3), không bỏ vẽ.
  dropped.addAll(_pack(visible, metrics: metrics, gap: gap, limitY: limitY));

  // (d) CHỐT HỢP ĐỒNG "không vẽ chữ cụt": khối nào khung vẫn thấp hơn nhu cầu
  // của chính chuỗi sẽ vẽ (đo lại bằng ĐÚNG bộ ước lượng + đúng cỡ chữ đã
  // chốt) ⇒ CHIP THU GỌN. Nhờ vậy bất biến "đủ chỗ" không phụ thuộc việc
  // `_pack` có tính khớp hay không — sai số ở đâu cũng thành chip (mở ra đọc
  // đủ), không bao giờ thành "chữ bị cắt" và cũng không còn "bỏ khối"
  // Lặp tới khi ổn định: một khối vừa thu gọn thành chip có thể trả lại chỗ
  // cho khối phía dưới (khung dưới không còn bị nó chiếm), nhờ vậy khối đó có
  // thể hiện ĐẦY ĐỦ thay vì cũng thành chip. Số vòng có trần (mỗi vòng thu
  // gọn ít nhất một khối) nên luôn kết thúc.
  for (var pass = 0; pass <= visible.length; pass++) {
    var changed = false;
    for (final slot in visible) {
      if (dropped.contains(slot.index)) continue;
      if (slot.collapsed) continue; // chip chỉ cần ~20dp, không đo theo chữ
      final tooShort = slot.height < minHeight;
      final needed = _slotNeededHeight(slot, slot.textSizeSp, metrics);
      if (!tooShort && slot.height + 0.5 >= needed) continue;
      // PSRC-211 vòng 2: KHÔNG bỏ khối im lặng nữa - thu gọn thành chip để
      // người dùng vẫn mở được bản dịch đầy đủ (mục 3). Giữ NGUYÊN khung đã
      // xếp: xê dịch ở bước chốt sẽ tạo chồng lấn với khối đã đặt. `dropped`
      // giờ chỉ còn dành cho khối trùng nội dung ở bước (a).
      _collapseInPlace(slot, metrics, limitY: limitY);
      changed = true;
    }
    if (!changed) break;
    _pack(visible, metrics: metrics, gap: gap, limitY: limitY);
  }

  return _emit(blocks, slots, dropped);
}

/// Khối đơn lẻ: không cần chống chồng, nhưng VẪN phải đủ chỗ cho chữ.
///
/// Xếp theo đúng thứ tự ưu tiên của cả pipeline (đừng đảo lại — owner
/// 2026-11-11: "chữ hiện đầy đủ, không bị bóp nhỏ/ẩn do khung nhỏ"):
///   1. Nới RỘNG sang phải nếu điều đó giảm số dòng (không lấn khối khác vì
///      đây là khối duy nhất).
///   2. Nới CAO tới đúng nhu cầu chữ ở cỡ chữ gốc.
///   3. Nếu đáy vượt màn hình ⇒ **dịch khung lên** (giữ nguyên chiều cao, chữ
///      không bị cắt) tới khi vừa màn hình.
///   4. Vẫn không vừa ⇒ **thu nhỏ ĐỀU** nhưng không dưới [kOverlayMinReadableSp].
///   5. Vẫn không vừa (màn hình quá thấp) ⇒ **chip thu gọn** ở góc trên-phải
///      khối gốc (`collapsed = true`, bản dịch vẫn nguyên vẹn) — KHÔNG bao giờ
///      vẽ chữ cụt và KHÔNG bỏ khối im lặng (PSRC-211 vòng 2).
List<ScreenBlock> _layoutSingle(
  List<ScreenBlock> blocks,
  int screenWidth,
  int screenHeight,
  OverlayFontMetrics metrics,
) {
  final block = blocks.first;
  final dpr = metrics.dpr;
  if (block.translation.trim().isEmpty) return List<ScreenBlock>.of(blocks);
  if ((screenWidth > 0 && screenWidth < kOverlayRealScreenMinPx) ||
      (screenHeight > 0 && screenHeight < kOverlayRealScreenMinPx)) {
    return List<ScreenBlock>.of(blocks);
  }

  var left = math.max(0, block.rect.left);
  var right = block.rect.right;
  if (screenWidth > 0) right = math.min(screenWidth, right);
  if (right <= left) right = left + 1;

  // PSRC-211: cỡ chữ theo MỘT dòng + đã chia fontScale (xem `_baseTextSizeSp`).
  final baseSp = _baseTextSizeSp(block, metrics);

  // (1) Nới rộng sang phải nếu bớt được dòng — miễn phí, không đẩy gì.
  final limitRight = screenWidth > 0 ? screenWidth : right + (1 << 20);
  var lines = _linesFor(block.translation, left, right, baseSp, metrics);
  if (lines > 1) {
    for (final factor in const <double>[1.0, 0.75, 0.5, 0.35, 0.25]) {
      final tryRight = right + ((limitRight - right) * factor).round();
      if (tryRight <= right) continue;
      final tryLines =
          _linesFor(block.translation, left, tryRight, baseSp, metrics);
      if (tryLines < lines) {
        right = tryRight;
        lines = tryLines;
        break;
      }
    }
  }

  final top = math.max(0, block.rect.top);
  // int (không phải double) — `OverlayRect` nhận pixel nguyên.
  final int? limitY = screenHeight > 0
      ? math.max(1, screenHeight - (kOverlayBottomMarginDp * dpr).round())
      : null;
  // PSRC-211: KHÔNG giữ sàn `origHeight` - khung chỉ cần cao đúng phần chữ
  // dịch (phần dư của bbox OCR là thứ tạo ra "khoảng trống thừa bên dưới",
  // đúng triệu chứng PSRC-211). Native vẫn phủ tới `coverBottom` nên chữ gốc
  // không bị lòi ra.

  // (2) Chiều cao ở cỡ chữ ưu tiên.
  var sizeSp = baseSp;
  var height = _neededHeight(block.translation, left, right, sizeSp, metrics);

  // (3) Nới CAO rồi DỊCH khung LÊN cho vừa màn hình — chữ vẫn nguyên cỡ.
  var rectTop = top;
  var fits = true;
  if (limitY != null && rectTop + height > limitY) {
    rectTop = math.max(0, (limitY - height).floor());
    fits = rectTop + height <= limitY;
  }

  // (4) Không còn chỗ dù đã dịch lên ⇒ thu nhỏ ĐỀU, sàn `kOverlayMinReadableSp`.
  if (!fits && limitY != null) {
    while (sizeSp > kOverlayMinReadableSp) {
      final next = math.max(kOverlayMinReadableSp, sizeSp - 1.0);
      final nextHeight =
          _neededHeight(block.translation, left, right, next, metrics);
      if (nextHeight >= height) break; // thu nhỏ không giúp gì ⇒ dừng
      sizeSp = next;
      height = nextHeight;
      rectTop = math.max(0, (limitY - height).floor());
      if (rectTop + height <= limitY) {
        fits = true;
        break;
      }
    }
  }

  final rect = OverlayRect(
    left: left,
    top: rectTop,
    right: right,
    bottom: math.max(rectTop + 1, (rectTop + height).ceil()),
  );

  // (5) Vẫn tràn đáy ⇒ KHÔNG vẽ chữ cụt, cũng KHÔNG bỏ khối (PSRC-211 vòng 2):
  //     thu gọn thành chip ở góc trên-phải khối gốc, chạm chip mở popup đọc đủ.
  if (!fits) {
    final slot = _Slot(
      0,
      block,
      left,
      math.max(0, block.rect.top),
      right,
      math.max(math.max(0, block.rect.top) + 1, block.rect.bottom),
      metrics,
    );
    _collapseToChipAt(
      slot,
      metrics,
      top: math.max(0, block.rect.top),
      limitRight: screenWidth > 0 ? screenWidth : null,
      limitY: limitY,
    );
    return <ScreenBlock>[
      ScreenBlock(
        rect: OverlayRect(
          left: slot.left,
          top: slot.top,
          right: slot.right,
          bottom: slot.bottom,
        ),
        original: block.original,
        translation: block.translation,
        textSizeSp: kOverlayMinReadableSp,
        collapsed: true,
      ),
    ];
  }

  // Đáy chữ gốc, kẹp vào trong khung vừa xếp (khung có thể đã dịch lên).
  final cover = math.min(rect.bottom, math.max(rect.top, block.rect.bottom));

  return <ScreenBlock>[
    ScreenBlock(
      rect: rect,
      original: block.original,
      translation: block.translation,
      // ⚠ GIỮ cỡ chữ đã dùng để TÍNH chiều cao. Nếu tính lại từ `rect` (đã
      // nới cao) thì `suggestedTextSizeSp` cho số lớn hơn ⇒ cần thêm chỗ nữa
      // ⇒ vòng lặp tự sinh (CI bắt được: "cần 538.5px, có 198.0px").
      textSizeSp: sizeSp,
      maxTextSizeSp: baseSp > sizeSp ? baseSp : null,
      coverBottom: cover < rect.bottom ? cover : null,
    ),
  ];
}

int _linesFor(
  String translation,
  int left,
  int right,
  double sizeSp,
  OverlayFontMetrics metrics,
) {
  return estimateTranslationLineCount(
    translation,
    math.max(1.0, (right - left) - 2 * kOverlayTextPaddingPx),
    sizeSp * metrics.pxPerSp,
  );
}

/// Chiều cao (px, gồm padding) mà native CẦN để vẽ đủ chữ ở [sizeSp].
double _neededHeight(
  String translation,
  int left,
  int right,
  double sizeSp,
  OverlayFontMetrics metrics,
) {
  return estimateTranslationTextHeightPx(
        translation,
        math.max(1.0, (right - left) - 2 * kOverlayTextPaddingPx),
        sizeSp * metrics.pxPerSp,
      ) +
      2 * kOverlayTextPaddingPx;
}

/// Nới bề ngang sang phải vào khoảng trống, nếu giúp GIẢM số dòng.
///
/// Đây là cách RẺ NHẤT để chữ không bị cắt: khung gốc do OCR cắt sát chữ gốc,
/// trong khi bản dịch tiếng Việt dài hơn ⇒ chỉ cần lấy thêm bề ngang là đủ,
/// không phải thu nhỏ chữ hay đẩy khối khác xuống.
void _expandHorizontally(
  List<_Slot> visible, {
  required int gap,
  required OverlayFontMetrics metrics,
  int? limitRight,
}) {
  for (final slot in visible) {
    final text = slot.block.translation.trim();
    if (text.isEmpty) continue;

    // Giới hạn phải: mép trái của khối gần nhất bên phải CÓ GIAO DỌC.
    // Khối ở hàng khác không chặn (hai cột chữ khác dòng vẫn nới được).
    var allowedRight = limitRight ?? (slot.right + (1 << 20));
    for (final other in visible) {
      if (identical(other, slot)) continue;
      if (other.left < slot.right) continue;
      final overlap =
          math.min(slot.bottom, other.bottom) - math.max(slot.top, other.top);
      if (overlap <= 0) continue;
      allowedRight = math.min(allowedRight, other.left - gap);
    }
    if (allowedRight <= slot.right) continue;

    final sizeSp = slot.baseSp;
    final baseLines = _linesAtWidth(slot, slot.width, sizeSp, metrics);
    if (baseLines <= 1) continue; // đã 1 dòng ⇒ nới rộng vô nghĩa

    // Thử nới dần; dừng ở mức ĐẦU TIÊN giảm được số dòng.
    for (final factor in const <double>[1.0, 0.75, 0.5, 0.35, 0.25]) {
      final tryRight =
          slot.right + ((allowedRight - slot.right) * factor).round();
      if (tryRight <= slot.right) continue;
      final lines = _linesAtWidth(slot, tryRight - slot.left, sizeSp, metrics);
      if (lines < baseLines) {
        slot.right = tryRight;
        break;
      }
    }
  }
}

/// Đưa [slot] về trạng thái **THU GỌN** mà GIỮ NGUYÊN khung hiện tại.
///
/// Vì sao có bước này (PSRC-211 vòng 2, mục 3 của `L4-hub-tra-loi.md`): luật
/// owner 2026-11-11 cấm vẽ dưới [kOverlayMinReadableSp] và cấm cắt chữ, nên bản
/// trước BỎ VẼ khối không đủ chỗ - tức vẫn "bỏ sót khối" (đúng lỗi PSRC-211).
/// Chip là **trạng thái thứ ba**: chữ không bị cắt, không bị bóp; người dùng
/// chạm chip để native mở popup hiện ĐỦ bản dịch ở cỡ chữ đọc được.
///
/// Bản "giữ nguyên khung" này dùng ở bước chốt hợp đồng, nơi khung đã được xếp
/// và không được xê dịch nữa (xê dịch lúc đó mới là thứ tạo ra chồng lấn).
void _collapseInPlace(_Slot slot, OverlayFontMetrics metrics, {int? limitY}) {
  // Chip nhỏ (~26×20dp) ở góc trên-phải khung ĐÃ XẾP: nhờ vậy nó không đè
  // khối khác (khung đó đã né các khối trước) mà vẫn đánh dấu đúng chỗ.
  _collapseToChipAt(
    slot,
    metrics,
    top: slot.top,
    limitRight: slot.right,
    limitY: limitY,
  );
}

/// Kích thước chip (px) theo mật độ màn hình — native dùng cùng công thức.
({int width, int height}) overlayChipSize(OverlayFontMetrics metrics) {
  final dpr = metrics.dpr;
  return (
    width: math.max(8, (kOverlayChipWidthDp * dpr).round()),
    height: math.max(8, (kOverlayChipHeightDp * dpr).round()),
  );
}

/// Đặt [slot] thành CHIP ở góc trên-phải khối gốc, bắt đầu từ [top].
///
/// [top] là đỉnh đã xếp (>= đỉnh gốc, sau khi né các khối đã đặt phía trên) nên
/// chip không bao giờ đè lên khối khác; các khối SAU sẽ né chip vì nó được thêm
/// vào danh sách đã đặt (bán kính nhỏ, chỉ ~26×20dp).
void _collapseToChipAt(
  _Slot slot,
  OverlayFontMetrics metrics, {
  required int top,
  int? limitRight,
  int? limitY,
}) {
  final chip = overlayChipSize(metrics);
  var right = slot.right;
  if (limitRight != null && right > limitRight) right = limitRight;
  var left = right - chip.width;
  if (left < slot.left) left = slot.left;
  if (left >= right) left = math.max(0, right - chip.width);
  // Đỉnh chip, theo thứ tự ưu tiên:
  //  1. [top] = chỗ XẾP hiện tại — đã né mọi khối đặt trước, nên chip không đè
  //     khung chữ dịch của ai và không che nội dung của khối khác.
  //  2. đỉnh GỐC của khối — màn hình CỰC dày (30 khối, fontScale 2.0×) không
  //     còn chỗ nào trống; khi đó chip nằm trên chính chữ gốc của nó, đúng mục
  //     3 ("góc trên-phải khối gốc"). Hai chip có thể chồng nhau một phần, cả
  //     hai vẫn bấm được và vẫn đại diện đúng khối của mình.
  //  3. sát đáy màn hình — chỉ khi cả đỉnh gốc cũng đã ở dưới đáy.
  //
  // Bản trước luôn kẹp về `limitY - chiều cao chip` ⇒ MỌI khối sát đáy ra
  // CÙNG một hình chip (nhiều khối "hoá" thành một) rồi bị đẩy ra ngoài màn
  // hình (không bấm được). Vì vậy thứ tự trên là bắt buộc.
  var chipTop = math.max(0, top);
  if (limitY != null && chipTop + chip.height > limitY) {
    if (slot.origTop + chip.height <= limitY) {
      chipTop = math.max(0, slot.origTop);
    } else {
      chipTop = math.max(0, limitY - chip.height);
    }
  }
  slot.collapseTo(
    OverlayRect(
      left: left,
      top: chipTop,
      right: math.max(left + 1, right),
      bottom: math.max(chipTop + 1, chipTop + chip.height),
    ),
    textSizeSp: kOverlayMinReadableSp,
  );
}

int _linesAtWidth(
  _Slot slot,
  int widthPx,
  double sizeSp,
  OverlayFontMetrics metrics,
) {
  final usable = math.max(1.0, widthPx - 2 * kOverlayTextPaddingPx);
  // ⚠ PHẢI quy đổi sp → px qua [OverlayFontMetrics.pxPerSp]: bề ngang ở đây là
  // PIXEL màn hình, và native vẽ bằng `TypedValue(SP)` nên `fontScale` của máy
  // cũng vào cuộc. Trộn/thiếu đơn vị ⇒ ước lượng thiếu số dòng ⇒ chữ bị cắt.
  return estimateTranslationLineCount(
    slot.block.translation,
    usable,
    sizeSp * metrics.pxPerSp,
  );
}

/// Khối CHIP THU GỌN tại toạ độ màn hình ([x], [y]) — `null` nếu không trúng.
///
/// Đây là "máy bắt" cho yêu cầu "chip chạm được" của mục 3: native hỏi hàm này
/// (cùng công thức) rồi mở popup bản dịch đầy đủ. Layout thuần Dart nên test
/// được trên host VM, không cần thiết bị.
///
/// Khi nhiều chip chồng nhau (hiếm: hai bbox OCR giao nhau), trả chip có diện
/// tích NHỎ nhất — chip nhỏ là cái dễ bị che, ưu tiên nó để không ai bấm hụt.
ScreenBlock? collapsedBlockAt(List<ScreenBlock> blocks, int x, int y) {
  ScreenBlock? best;
  var bestArea = 1 << 30;
  for (final block in blocks) {
    if (!block.collapsed) continue;
    final rect = block.rect;
    if (x < rect.left || x > rect.right) continue;
    if (y < rect.top || y > rect.bottom) continue;
    final area = math.max(1, rect.width).toInt() * math.max(1, rect.height).toInt();
    if (area < bestArea) {
      bestArea = area;
      best = block;
    }
  }
  return best;
}

/// Thêm nhanh cho tập slot lớn: đếm số khung GIAO NHAU theo từng trục.
///
/// Chỉ dùng cho test/telemetry (không ảnh hưởng layout) — nhưng rất cần để
/// chứng minh "không chồng lớp" mà không phải dựng màn hình thật.
int countOverlappingPairs(List<ScreenBlock> blocks) {
  var count = 0;
  for (var i = 0; i < blocks.length; i++) {
    if (!blocks[i].hasTranslation) continue;
    for (var j = i + 1; j < blocks.length; j++) {
      if (!blocks[j].hasTranslation) continue;
      final a = blocks[i].rect;
      final b = blocks[j].rect;
      final w = math.min(a.right, b.right) - math.max(a.left, b.left);
      final h = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
      if (w > 0 && h > 0) count++;
    }
  }
  return count;
}

/// Chiều cao (px, gồm padding) [slot] cần để vẽ đủ bản dịch ở cỡ [sizeSp].
double _slotNeededHeight(
  _Slot slot,
  double sizeSp,
  OverlayFontMetrics metrics,
) {
  return estimateTranslationTextHeightPx(
        slot.block.translation,
        math.max(1.0, slot.width - 2 * kOverlayTextPaddingPx),
        sizeSp * metrics.pxPerSp,
      ) +
      2 * kOverlayTextPaddingPx;
}

/// Xếp từng khối ĐÚNG CHỖ chữ gốc của nó. Trả về `index` các khối BỎ hẳn —
/// từ vòng 2 danh sách đó chỉ còn khối TRÙNG nội dung; khối hết chỗ thành chip.
///
/// [visible] theo thứ tự đọc (trên → dưới). Với mỗi khối:
///  1. **Đỉnh** = đỉnh gốc; chỉ lùi xuống khi một khối ĐÃ ĐẶT phía trên (giao
///     ngang) còn chiếm chỗ đó.
///  2. **Trần** = đỉnh GỐC của khối gần nhất bên dưới có giao ngang (trừ khe
///     hở), hoặc lề đáy màn hình. Khoảng từ đỉnh tới trần là chỗ khối được
///     dùng mà KHÔNG làm lệch ai.
///  3. Bản dịch ở cỡ chữ gốc cao hơn chỗ đó ⇒ hạ cỡ chữ RIÊNG khối này từng
///     [kOverlayShrinkStepSp], lấy cỡ LỚN NHẤT còn vừa. Tới sàn
///     [kOverlayMinReadableSp] vẫn không vừa ⇒ giữ cỡ sàn (gọn nhất) và để
///     khung dài quá trần: khối bên dưới sẽ bị đẩy ở bước 1 của chính nó — và
///     nó lại thử thu nhỏ để không đẩy tiếp ⇒ độ lệch tắt dần thay vì dồn.
///  4. Vượt lề đáy màn hình ⇒ dịch khung LÊN nếu phía trên còn trống; không
///     thì THU GỌN thành chip ở góc trên-phải khối gốc và đăng ký ngay vào
///     danh sách đã đặt (khối sau phải né chip), rồi đi tiếp khối sau.
///
/// Khối bị BỎ (chỉ còn khối trùng nội dung) không chiếm chỗ: nó không được
/// thêm vào danh sách đã đặt nên khối sau có thể dùng khoảng đó. Khác bản XLAT-SCR-006 (thu nhỏ ĐỀU cả màn
/// hình, chia ngân sách): một khối dài không còn kéo cỡ chữ / vị trí của các
/// khối không liên quan.
Set<int> _pack(
  List<_Slot> visible, {
  required OverlayFontMetrics metrics,
  required int gap,
  required int? limitY,
}) {
  final unfit = <int>{};
  final placed = <_Slot>[];

  // Idempotent: bước chốt (d) gọi lại hàm này sau khi thu gọn một khối, nên
  // mọi slot phải trở về trạng thái "chưa xếp" trước khi xếp lại. Khối đã bị
  // thu gọn thì GIỮ là chip (chip nhỏ nên nhường chỗ cho khối khác).
  for (final slot in visible) {
    if (slot.collapsed) {
      slot.textSizeSp = kOverlayMinReadableSp;
      continue;
    }
    slot.top = slot.origTop;
    slot.bottom = slot.origBottom;
    slot.coverBottom = slot.origBottom;
    slot.textSizeSp = slot.baseSp;
  }

  for (var i = 0; i < visible.length; i++) {
    final slot = visible[i];
    if (slot.collapsed) {
      // Chip đã có hình chữ nhật riêng; khối sau phải né nó.
      placed.add(slot);
      continue;
    }

    // (1) Đỉnh thấp nhất được phép: ngay dưới các khối đã đặt có giao ngang.
    var floorTop = 0;
    for (final earlier in placed) {
      if (!earlier.overlapsHorizontally(slot)) continue;
      final candidate = earlier.bottom + gap;
      if (candidate > floorTop) floorTop = candidate;
    }
    var top = math.max(slot.origTop, floorTop);

    // (2) Trần: không lấn vào chữ gốc của khối kế tiếp bên dưới.
    int? ceiling = limitY;
    for (var j = i + 1; j < visible.length; j++) {
      final later = visible[j];
      if (!later.overlapsHorizontally(slot)) continue;
      final candidate = later.origTop - gap;
      if (ceiling == null || candidate < ceiling) ceiling = candidate;
    }

    // (2b) PSRC-211 vòng 2: khối nằm SÁT ĐÁY màn hình mà bản dịch không thể
    // lọt vào khoảng `top..limitY` thì thu gọn NGAY thành chip tại chính chỗ
    // đó. Nếu để tới bước (4) mới thu gọn, chip bị ghim vào đáy màn hình
    // (trùng toạ độ với chip của các khối sát đáy khác) — người dùng thấy một
    // chip thay vì nhiều khối, tức là vẫn "bỏ sót".
    if (limitY != null) {
      final overflowNeed = _slotNeededHeight(slot, kOverlayMinReadableSp, metrics);
      if (top + overflowNeed > limitY) {
        _collapseToChipAt(
          slot,
          metrics,
          top: top,
          limitRight: slot.right,
          limitY: limitY,
        );
        placed.add(slot);
        continue;
      }
    }

    // (3) Cỡ chữ: ưa thích cỡ gốc; chật thì thu nhỏ riêng khối này.
    var sizeSp = slot.baseSp;
    var needed = _slotNeededHeight(slot, sizeSp, metrics);
    if (ceiling != null && top + needed > ceiling) {
      var fitted = false;
      var trial = sizeSp;
      while (trial > kOverlayMinReadableSp + 1e-9) {
        trial = math.max(kOverlayMinReadableSp, trial - kOverlayShrinkStepSp);
        final trialNeeded = _slotNeededHeight(slot, trial, metrics);
        if (top + trialNeeded <= ceiling) {
          sizeSp = trial;
          needed = trialNeeded;
          fitted = true;
          break;
        }
      }
      if (!fitted) {
        sizeSp = kOverlayMinReadableSp;
        needed = _slotNeededHeight(slot, sizeSp, metrics);
      }
    }
    final boxHeight = needed.ceil();
    // Đỉnh TRƯỚC khi bị đẩy xuống ở bước (4): nếu phải thu gọn ngay tại đây thì
    // chip đứng ở chỗ này (đã né khối trên), không phải ở đáy màn hình.
    final anchoredTop = top;

    // (4) Lề đáy màn hình.
    if (limitY != null && top + boxHeight > limitY) {
      final shifted = limitY - boxHeight;
      if (shifted < floorTop) {
        // Hết cách cho NGUYÊN bản dịch (chạm lề đáy, phía trên đã có khối
        // khác) ⇒ KHÔNG bỏ vẽ nữa (PSRC-211 vòng 2): thu gọn thành chip và
        // đăng ký NGAY vào `placed` để khối dưới không đè lên chip.
        _collapseToChipAt(
          slot,
          metrics,
          top: anchoredTop,
          limitRight: slot.right,
          limitY: limitY,
        );
        placed.add(slot);
        continue;
      }
      top = shifted;
    }

    // Khung = chỗ cho chữ dịch, và ít nhất phủ hết chữ gốc (tới trần).
    var cover = slot.origBottom;
    if (ceiling != null && cover > ceiling) cover = ceiling;
    final bottom = math.max(top + boxHeight, cover);

    slot.textSizeSp = sizeSp;
    slot.top = top;
    slot.bottom = bottom;
    slot.coverBottom = math.min(bottom, math.max(top, cover));
    placed.add(slot);
  }
  return unfit;
}

List<ScreenBlock> _emit(
  List<ScreenBlock> blocks,
  List<_Slot> slots,
  Set<int> dropped,
) {
  final out = <ScreenBlock>[];
  for (var i = 0; i < blocks.length; i++) {
    final original = blocks[i];
    if (dropped.contains(i)) {
      out.add(ScreenBlock(
        rect: original.rect,
        original: original.original,
        translation: '',
        textSizeSp: original.textSizeSp,
      ));
      continue;
    }
    final slot = slots[i];
    if (slot.collapsed) {
      out.add(ScreenBlock(
        rect: OverlayRect(
          left: slot.left,
          top: slot.top,
          right: slot.right,
          bottom: slot.bottom,
        ),
        original: original.original,
        // Bản dịch NGUYÊN VẸN: native vẽ nhãn ngắn trên chip và mở popup đọc
        // đủ khi chạm - không cắt chữ, không bóp chữ (mục 3).
        translation: original.translation,
        textSizeSp: kOverlayMinReadableSp,
        collapsed: true,
      ));
      continue;
    }
    if (slot.block.translation.trim().isEmpty) {
      out.add(original);
      continue;
    }
    final rect = OverlayRect(
      left: slot.left,
      top: slot.top,
      right: slot.right,
      bottom: slot.bottom,
    );
    out.add(ScreenBlock(
      rect: rect,
      original: original.original,
      // LUÔN là bản dịch NGUYÊN VẸN: layout không rút gọn chữ. Khối không đủ
      // chỗ đã thành chip ở trên (`collapsed = true`), khối trùng nội dung thì
      // bị bỏ (`translation` rỗng). Nhờ vậy không có đường nào để chữ bị cắt.
      translation: original.translation,
      // Cỡ chữ ĐÃ DÙNG để đo khung (đừng tính lại từ `rect` — xem `baseSp`).
      textSizeSp: slot.textSizeSp,
      // Native đo được font thật ⇒ cho phép thử lại từ cỡ chữ gốc.
      maxTextSizeSp: slot.baseSp > slot.textSizeSp ? slot.baseSp : null,
      // Chỉ gửi khi khung giữ chỗ dài hơn chữ gốc — phần dư đó native ôm sát.
      coverBottom: slot.coverBottom < slot.bottom ? slot.coverBottom : null,
    ));
  }
  return out;
}
