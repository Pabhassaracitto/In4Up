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
// ⇒ Hợp đồng MỚI (owner 2026-11-11): "chữ hiện đầy đủ, không bị bóp nhỏ/ẩn do
//   khung nhỏ, nhưng cũng không để các lớp dịch chồng lên nhau".
//
// Thuật toán: đo nhu cầu chữ → nới rộng → nới cao → ĐẨY khối dưới xuống →
// nếu vẫn tràn màn hình thì thu nhỏ ĐỀU nhưng không dưới [kOverlayMinReadableSp]
// → vẫn tràn thì chia đều chỗ cho từng khối → cuối cùng bỏ vẽ khối không nổi
// NGUYÊN bản dịch (để lộ chữ gốc, KHÔNG cắt chữ, KHÔNG thêm `…`).
//
// Vẫn giữ nguyên tinh thần ADR-0011: Dart xếp chỗ (thuần, test được), native
// chỉ vẽ đúng khung được cấp. Dart không đo được font thật nên dùng bộ ước
// lượng bên dưới — cố tình ước DƯ (1.06×) để native không bao giờ thiếu chỗ.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:math' as math;

import 'screen_translate_geometry.dart';
import 'screen_translate_models.dart';

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

/// Mức thu nhỏ nhỏ nhất khi phải nhồi cho vừa màn hình (so với cỡ gốc).
const double kOverlayMinShrink = 0.78;

/// Hệ số an toàn của bộ ước lượng chiều cao (ước dư 6%).
const double kOverlayHeightSafety = 1.06;

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
    double dpr,
  )   : origTop = top,
        origBottom = bottom,
        baseSp = suggestedTextSizeSp(block.rect, dpr);

  /// Cỡ chữ gốc (sp) của khối — chốt MỘT LẦN từ chiều cao khung OCR ban đầu.
  ///
  /// KHÔNG lấy lại `suggestedTextSizeSp(height)` sau mỗi lượt đóng gói:
  /// `_pack` nới khung cao hơn ⇒ hàm đó cho số LỚN hơn ⇒ cần thêm chỗ ⇒ vòng
  /// lặp tự sinh (CI 42908858046 bắt đúng lỗi "khung đơn cần 538.5px, có
  /// 198.0px"). Chốt một lần cũng làm mức thu nhỏ công bằng giữa các khối.
  final double baseSp;

  final int index;
  final ScreenBlock block;
  final int left;

  /// Vị trí GỐC (từ OCR). `_pack` chạy nhiều lượt (thu nhỏ dần) nên mỗi lượt
  /// PHẢI bắt đầu lại từ đây — nếu cộng dồn, khối sẽ trôi xuống mãi.
  final int origTop;
  final int origBottom;

  int top;

  /// Có thể NỚI sang phải (khi điều đó giảm số dòng) — xem
  /// `_expandHorizontally`. Không bao giờ vượt khối bên phải cùng hàng.
  int right;
  int bottom;

  /// Cỡ chữ dùng để vẽ (sp) — sau khi nới/ thu nhỏ.
  double textSizeSp = 14.0;

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
  // Latin-1 / Latin Extended (tiếng Việt có dấu nằm ở đây)
  if (c > 0x7F) return 0.56;
  // Chữ thường còn lại
  return 0.53;
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
/// dòng vẫn tính 1 dòng (native sẽ ellipsize chữ đó — hiếm).
int estimateTranslationLineCount(
  String text,
  double maxWidthPx,
  double fontPx,
) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  if (maxWidthPx <= 0 || fontPx <= 0) return 1;

  final widthOf = (String s) => _textWidthEm(s) * fontPx;
  var lines = 1;
  var current = 0.0;
  const spaceEm = 0.30;
  final spacePx = spaceEm * fontPx;

  for (final word in trimmed.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final w = widthOf(word);
    if (current <= 0) {
      // Từ đầu dòng.
      if (w <= maxWidthPx) {
        current = w;
      } else {
        // Từ dài hơn dòng: native sẽ xuống dòng trong từ (hoặc ellipsize).
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

/// Xếp lại [blocks] để bản dịch hiện ĐỦ CHỮ và các ô KHÔNG chồng nhau.
///
/// [screenWidth]/[screenHeight] dùng để cắt biên + biết khi nào tràn màn hình;
/// truyền `0` (hoặc giá trị nhỏ hơn khung, như frame giả trong test) để tắt.
///
/// Hợp đồng:
///  • Giữ NGUYÊN số khối + thứ tự (native/controller dựa vào danh sách này).
///    Khối không vẽ được ⇒ `translation = ''` (native bỏ qua, chữ gốc hiện).
///  • Hai khối cùng nội dung + bbox giao nhau ⇒ chỉ giữ khối đầu.
///  • Khung được nới RỘNG (sang phải, vào khoảng trống) khi điều đó giảm số
///    dòng — đây là cách rẻ nhất để không phải thu nhỏ chữ.
///  • Khung được nới CAO tới đúng nhu cầu chữ; khối phía dưới bị ĐẨY xuống
///    (kèm khe hở [kOverlayBoxGapDp]) thay vì cắt chữ của khối trên.
///  • Nếu tổng vượt đáy màn hình ⇒ thu nhỏ đều (tới [kOverlayMinShrink]) rồi
///    xếp lại; vẫn tràn thì chia NGÂN SÁCH CHIỀU CAO cho từng khối để nhiều
///    khối còn nguyên nội dung thay vì chỉ một khối chiếm hết chỗ — khối nào
///    không nổi NGUYÊN bản dịch trong ngân sách của nó thì BỎ VẼ (không cắt).
///  • Bước CHỐT: khối nào khung vẫn thấp hơn nhu cầu ⇒ bỏ vẽ (`translation`
///    rỗng, native hiện chữ gốc). KHÔNG BAO GIỜ vẽ chữ cụt.
///  • [fontScale] = `configuration.fontScale` của thiết bị. Máy bật cỡ chữ hệ
///    thống lớn thì native vẽ chữ CAO hơn ⇒ Dart phải ước theo đúng tỉ lệ,
///    nếu không khung cấp thiếu chỗ và chữ bị cắt (lỗi owner báo 2026-11-11).
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

  // Trần cứng của mọi khung: không vẽ đè lên vạch điều hướng. Dùng cho MỌI
  // nhánh bên dưới để không nhánh nào tự đặt mép khác nhau (lệch 1 nhánh là
  // chữ bị cắt — đúng lỗi owner báo).
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
      dpr,
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
    return _emit(blocks, slots, dropped, dpr);
  }

  // (b) Nới RỘNG trước — rẻ hơn nới cao vì không đẩy khối khác xuống.
  _expandHorizontally(visible, gap: gap, metrics: metrics, limitRight: maxX);

  // (c) Ước nhu cầu chiều cao ở cỡ chữ ưa thích, rồi đóng gói có đẩy xuống.
  final pack = _pack(visible, metrics: metrics, gap: gap, scale: 1.0);

  // (d) Tràn đáy màn hình ⇒ thu nhỏ ĐỀU (không dưới cỡ đọc được) rồi xếp lại.
  // Vòng lặp dừng ngay khi vừa màn hình; nếu chạy hết mà VẪN tràn thì lần lặp
  // cuối (nhỏ nhất) để lại trạng thái "còn tràn" cho nhánh (e2) xử lý.
  var shrunkFits = true;
  if (limitY != null && pack.maxBottom > limitY) {
    shrunkFits = false;
    for (var shrink = 0.95;
        shrink >= kOverlayMinShrink - 1e-9;
        shrink -= 0.05) {
      if (_pack(visible, metrics: metrics, gap: gap, scale: shrink).maxBottom <=
          limitY) {
        shrunkFits = true;
        break;
      }
    }
  }

  // (e2) Tràn đáy màn hình ⇒ phân bổ lại chỗ TRỐNG: đóng gói kiểu "khối trên
  // lấy hết chỗ" dễ "đói" — khối trên bị nới hết khiến gần như mọi khối dưới
  // bị bỏ, dù nếu chia đều thì còn vẽ được nhiều khối hơn hẳn (rõ nhất khi máy
  // bật CỠ CHỮ HỆ THỐNG lớn: mỗi dòng cao 2× ⇒ trước đây chỉ còn 1 khối).
  // KHÔNG cắt chữ: khối không nổi nguyên bản dịch trong ngân sách ⇒ bỏ vẽ.
  //
  // ⚠ `dropped` còn giữ các khối bị loại vì TRÙNG nội dung ở nhánh (a) — nên
  // nhánh này dùng tập RIÊNG rồi hợp lại, không được `clear()`.
  //
  // ⚠ CHỈ chạy khi (d) thất bại: nếu (d) đã vừa màn hình thì mọi khối hiện
  // NGUYÊN chữ. Chạy ngân sách vô điều kiện (bản trước) làm 10 khối vừa vặn ở
  // fontScale 1.6 bị cắt cụt oan dù còn thừa chỗ.
  if (limitY != null && !shrunkFits) {
    final overflow = <int>{};
    _packWithFairShare(
      visible,
      metrics: metrics,
      gap: gap,
      limitY: limitY,
      dropped: overflow,
    );

    // (e3) Ngân sách chia đều mà KHÔNG khối nào nổi một dòng (màn hình quá
    // thấp so với số khối) ⇒ quay lại cách "lấp từ trên xuống": vẽ được bao
    // nhiêu khối trọn vẹn thì vẽ, phần dư bỏ. Không bao giờ để trắng trơn chỉ
    // vì chia đều quá chặt.
    if (visible.every((slot) => overflow.contains(slot.index))) {
      overflow.clear();
      final emergencyScale = kOverlayMinReadableSp /
          math.max(kOverlayMinReadableSp, visible.first.baseSp);
      _pack(visible, metrics: metrics, gap: gap, scale: emergencyScale);
      for (final slot in visible) {
        if (slot.bottom > limitY) overflow.add(slot.index);
      }
    }
    dropped.addAll(overflow);
  }

  // (f) CHỐT HỢP ĐỒNG "không vẽ chữ cụt": khối nào khung vẫn thấp hơn nhu cầu
  // của chính chuỗi sẽ vẽ (đo lại bằng ĐÚNG bộ ước lượng + đúng cỡ chữ đã
  // chốt) ⇒ bỏ vẽ. Nhờ vậy bất biến "đủ chỗ" không phụ thuộc việc mọi nhánh
  // trên có tính khớp nhau hay không — sai số ở đâu cũng thành "bỏ khối"
  // (chữ gốc hiện) chứ không thành "chữ bị cắt".
  for (final slot in visible) {
    if (slot.height < minHeight) {
      dropped.add(slot.index);
      continue;
    }
    final text = slot.block.translation;
    final needed = estimateTranslationTextHeightPx(
          text,
          math.max(1.0, slot.width - 2 * kOverlayTextPaddingPx),
          slot.textSizeSp * metrics.pxPerSp,
        ) +
        2 * kOverlayTextPaddingPx;
    if (slot.height + 0.5 < needed) dropped.add(slot.index);
  }

  return _emit(blocks, slots, dropped, dpr);
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
///   5. Vẫn không vừa (màn hình quá thấp) ⇒ **bỏ vẽ** khối (trả `translation`
///      rỗng để native hiện chữ gốc) — KHÔNG bao giờ vẽ chữ cụt.
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

  final baseSp = suggestedTextSizeSp(block.rect, dpr);

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
  final int origHeight = math.max(1, block.rect.height);

  // (2) Chiều cao ở cỡ chữ ưu tiên.
  var sizeSp = baseSp;
  var height = math.max(
    origHeight.toDouble(),
    _neededHeight(block.translation, left, right, sizeSp, metrics),
  );

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
      height = math.max(origHeight.toDouble(), nextHeight);
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

  // (5) Vẫn tràn đáy ⇒ KHÔNG vẽ chữ cụt: trả `translation` rỗng để native hiện
  //     nguyên chữ gốc, user biết chỗ đó chưa dịch được (thay vì đọc chữ mất
  //     một nửa như lỗi owner báo).
  if (!fits) {
    return <ScreenBlock>[
      ScreenBlock(
        rect: block.rect,
        original: block.original,
        translation: '',
        textSizeSp: block.textSizeSp,
      ),
    ];
  }

  return <ScreenBlock>[
    ScreenBlock(
      rect: rect,
      original: block.original,
      translation: block.translation,
      // ⚠ GIỮ cỡ chữ đã dùng để TÍNH chiều cao. Nếu tính lại từ `rect` (đã
      // nới cao) thì `suggestedTextSizeSp` cho số lớn hơn ⇒ cần thêm chỗ nữa
      // ⇒ vòng lặp tự sinh (CI bắt được: "cần 538.5px, có 198.0px").
      textSizeSp: sizeSp,
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

class _PackResult {
  _PackResult(this.maxBottom);

  final int maxBottom;
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

/// Xếp các slot theo cột dọc, ĐẨY khối sau xuống khi khối trước cần thêm chỗ.
_PackResult _pack(
  List<_Slot> visible, {
  required OverlayFontMetrics metrics,
  required int gap,
  required double scale,
}) {
  var maxBottom = 0;
  // Đặt theo thứ tự đọc; mỗi khối chỉ bị đẩy bởi khối GIAO NGANG với nó.
  final placed = <_Slot>[];
  // Trần theo chiều cao slot: `_pack` chạy nhiều lượt với `scale` khác nhau,
  // nên KHÔNG tự cắt ở đây — việc bỏ khối vượt đáy do nhánh (e) quyết định
  // (một chỗ duy nhất, dễ kiểm).
  for (final slot in visible) {
    final sizeSp = (slot.baseSp * scale)
        .clamp(kOverlayMinReadableSp, 28.0)
        .toDouble();
    slot.textSizeSp = sizeSp;
    final fontPx = sizeSp * metrics.pxPerSp;
    final needed = estimateTranslationTextHeightPx(
          slot.block.translation,
          math.max(1.0, slot.width - 2 * kOverlayTextPaddingPx),
          fontPx,
        ) +
        2 * kOverlayTextPaddingPx;

    // BẮT ĐẦU LẠI từ vị trí gốc mỗi lượt (xem `origTop`).
    var top = slot.origTop;
    for (final earlier in placed) {
      if (!earlier.overlapsHorizontally(slot)) continue;
      final candidate = earlier.bottom + gap;
      if (candidate > top) top = candidate;
    }
    final origHeight = math.max(1, slot.origBottom - slot.origTop);
    slot.top = top;
    slot.bottom = top + math.max(origHeight, needed.ceil());
    placed.add(slot);
    if (slot.bottom > maxBottom) maxBottom = slot.bottom;
  }
  return _PackResult(maxBottom);
}

/// Đóng gói CHIA ĐỀU (fair share): mỗi khối chỉ được dùng phần chiều cao công
/// bằng của mình, phần dư của khối ngắn được nhường lại cho khối sau.
///
/// Vì sao cần: khi màn hình không đủ chỗ cho TẤT CẢ chữ (máy bật cỡ chữ hệ
/// thống lớn, màn hình thấp, 30 khối dày), đóng gói kiểu "khối trên lấy hết
/// chỗ" khiến gần như mọi khối dưới bị bỏ vẽ — user chỉ đọc được MỘT khối dù
/// còn chỗ trống ở dưới.
///
/// KHÔNG cắt chữ, KHÔNG đánh dấu `…`: khối không nổi NGUYÊN bản dịch trong
/// ngân sách của nó ⇒ bỏ vẽ (để lộ chữ gốc). Owner 2026-11-11 chốt "không vẽ
/// chữ cụt" — đọc nửa câu còn tệ hơn đọc chữ gốc, và native cũng bỏ khối chứ
/// không ellipsize (xem `TranslationOverlayView.buildLayout`).
void _packWithFairShare(
  List<_Slot> visible, {
  required OverlayFontMetrics metrics,
  required int gap,
  required int limitY,
  required Set<int> dropped,
}) {
  if (visible.isEmpty) return;
  final firstTop = visible.first.origTop;
  final totalGap = gap * (visible.length - 1);
  final available = limitY - firstTop - totalGap;
  if (available <= 0) {
    for (final slot in visible) {
      dropped.add(slot.index);
    }
    return;
  }
  final budgetPerSlot = available / visible.length;
  // Sàn chiều cao khung — khớp `minHeight` của [layoutTranslatedBlocks] để bước
  // chốt (f) không bỏ oan khối vừa được cấp chỗ.
  final minBox = math.max(6.0, kOverlayMinBoxHeightDp * metrics.dpr);

  // KHÔNG hạ sàn cỡ chữ ở đây: native (`TranslationOverlayView.MIN_READABLE_SP`)
  // kẹp cứng 10sp, nên khung đo theo 7sp sẽ bị native bỏ ⇒ vừa mất chỗ vừa
  // mất chữ. Khối không nổi một dòng 10sp trong ngân sách ⇒ bỏ vẽ (nhánh (e3)
  // lo trường hợp bỏ sạch).

  for (var i = 0; i < visible.length; i++) {
    final slot = visible[i];
    // Cỡ chữ dùng để đo khung: không nhỏ hơn sàn đọc được (native cũng kẹp
    // đúng sàn này).
    slot.textSizeSp =
        slot.textSizeSp.clamp(kOverlayMinReadableSp, 28.0).toDouble();
    final widthPx = math.max(1.0, slot.width - 2 * kOverlayTextPaddingPx);
    // ⚠ Dùng ĐÚNG công thức của bước chốt (f) — trước đây nhánh này tự nhân
    // `fontPx × kOverlayLineHeightFactor` (thiếu 6% của `kOverlayHeightSafety`)
    // ⇒ khung cấp hụt ⇒ bước chốt phải bỏ khối dù còn chỗ.
    final needed = estimateTranslationTextHeightPx(
          slot.block.translation,
          widthPx,
          slot.textSizeSp * metrics.pxPerSp,
        ) +
        2 * kOverlayTextPaddingPx;

    // Ngân sách của khối này = chia đều, nhưng một khối ngắn thì KHÔNG giữ
    // phần chỗ dư của mình: phần dư được chia lại cho các khối sau (nếu không,
    // khối ngắn làm phí chỗ và các khối dài bị cắt oan).
    final remainingSlots = visible.length - i;
    final remainingSpace = limitY -
        slot.top -
        gap * (remainingSlots - 1);
    if (remainingSpace <= 0) {
      dropped.add(slot.index);
      continue;
    }
    final share = math.max(
      budgetPerSlot,
      remainingSpace / remainingSlots,
    );

    // Đủ chỗ cho NGUYÊN khối ⇒ không cắt gì (chỉ nới cao tới nhu cầu).
    if (needed <= share) {
      slot.bottom = slot.top + math.max(minBox, needed).ceil();
      continue;
    }

    // Không đủ chỗ cho NGUYÊN khối ⇒ BỎ VẼ (để lộ chữ gốc). Cố tình KHÔNG
    // cắt chữ: owner 2026-11-11 chốt "không vẽ chữ cụt" — đọc nửa câu còn tệ
    // hơn đọc chữ gốc; và native cũng đã bỏ khối thay vì ellipsize.
    dropped.add(slot.index);
  }
}

List<ScreenBlock> _emit(
  List<ScreenBlock> blocks,
  List<_Slot> slots,
  Set<int> dropped,
  double dpr,
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
      // LUÔN là bản dịch NGUYÊN VẸN: layout không rút gọn chữ (khối không
      // đủ chỗ thì bị bỏ vẽ ở trên, `translation` rỗng). Nhờ vậy không có
      // đường nào để chữ bị cắt.
      translation: original.translation,
      textSizeSp: slot.textSizeSp <= 0
          ? suggestedTextSizeSp(rect, dpr)
          : slot.textSizeSp,
    ));
  }
  return out;
}
