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
// → cuối cùng mới bỏ vẽ khối tràn (để lộ chữ gốc, KHÔNG hiện chữ cụt).
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

/// Hệ số chiều cao dòng / cỡ chữ. `StaticLayout` với
/// `setLineSpacing(0f, 1.0f)` cho ~1.17–1.25 tuỳ font hệ thống ⇒ lấy 1.30 cho
/// chắc (thừa chỗ tốt hơn thiếu chỗ).
const double kOverlayLineHeightFactor = 1.30;

/// Lề đáy (dp) — không vẽ sát vạch điều hướng.
const double kOverlayBottomMarginDp = 8.0;

/// Mức thu nhỏ nhỏ nhất khi phải nhồi cho vừa màn hình (so với cỡ gốc).
const double kOverlayMinShrink = 0.78;

/// Hệ số an toàn của bộ ước lượng chiều cao (ước dư 6%).
const double kOverlayHeightSafety = 1.06;

class _Slot {
  _Slot(this.index, this.block, this.left, this.top, this.right, this.bottom)
      : origTop = top,
        origBottom = bottom;

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
///  • Nếu tổng vượt đáy màn hình ⇒ thu nhỏ đều (tới [kOverlayMinShrink] và
///    không dưới [kOverlayMinReadableSp]) rồi xếp lại.
///  • Vẫn tràn ⇒ bỏ vẽ đúng những khối vượt đáy (KHÔNG vẽ chữ cụt).
List<ScreenBlock> layoutTranslatedBlocks(
  List<ScreenBlock> blocks, {
  int screenWidth = 0,
  int screenHeight = 0,
  double devicePixelRatio = 1.0,
}) {
  if (blocks.isEmpty) return <ScreenBlock>[];
  if (blocks.length == 1) {
    return _layoutSingle(blocks, screenWidth, screenHeight, devicePixelRatio);
  }
  // Frame giả trong test / màn hình nhỏ bất thường: đừng áp ngưỡng dp của
  // thiết bị thật vào khung chỉ vài pixel.
  final fakeFrame =
      (screenWidth > 0 && screenWidth < kOverlayRealScreenMinPx) ||
          (screenHeight > 0 && screenHeight < kOverlayRealScreenMinPx);
  if (fakeFrame) return List<ScreenBlock>.of(blocks);

  final dpr = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
  final gap = math.max(1, (kOverlayBoxGapDp * dpr).round());
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
      maxY == null ? top : math.max(0, math.min(maxY, top)),
      maxX == null ? right : math.min(maxX, right),
      maxY == null ? bottom : math.min(maxY, bottom),
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
  _expandHorizontally(visible, gap: gap, dpr: dpr, limitRight: maxX);

  // (c) Ước nhu cầu chiều cao ở cỡ chữ ưa thích, rồi đóng gói có đẩy xuống.
  final pack = _pack(visible, dpr: dpr, gap: gap, scale: 1.0);

  // (d) Tràn đáy màn hình ⇒ thu nhỏ ĐỀU (không dưới cỡ đọc được) rồi xếp lại.
  if (limitY != null && pack.maxBottom > limitY) {
    for (var shrink = 0.95;
        shrink >= kOverlayMinShrink - 1e-9;
        shrink -= 0.05) {
      if (_pack(visible, dpr: dpr, gap: gap, scale: shrink).maxBottom <=
          limitY) {
        break;
      }
    }
  }

  // (e) Vẫn tràn ⇒ bỏ vẽ phần vượt đáy (giữ chữ gốc, không hiện chữ cụt).
  if (limitY != null) {
    for (final slot in visible) {
      if (slot.bottom > limitY) dropped.add(slot.index);
    }
  }

  // (f) Khung quá mỏng (không thể hiện nổi 1 dòng) ⇒ bỏ vẽ.
  for (final slot in visible) {
    if (slot.height < minHeight) dropped.add(slot.index);
  }

  return _emit(blocks, slots, dropped, dpr);
}

/// Khối đơn lẻ: không cần chống chồng, nhưng VẪN phải đủ chỗ cho chữ.
List<ScreenBlock> _layoutSingle(
  List<ScreenBlock> blocks,
  int screenWidth,
  int screenHeight,
  double devicePixelRatio,
) {
  final block = blocks.first;
  final dpr = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
  if (block.translation.trim().isEmpty) return List<ScreenBlock>.of(blocks);
  if ((screenWidth > 0 && screenWidth < kOverlayRealScreenMinPx) ||
      (screenHeight > 0 && screenHeight < kOverlayRealScreenMinPx)) {
    return List<ScreenBlock>.of(blocks);
  }

  final sizeSp = suggestedTextSizeSp(block.rect, dpr);
  final fontPx = sizeSp * dpr;
  final needed = estimateTranslationTextHeightPx(
        block.translation,
        math.max(1, block.rect.width - 2 * kOverlayTextPaddingPx),
        fontPx,
      ) +
      2 * kOverlayTextPaddingPx;
  final height = math.max(block.rect.height, needed.ceil());
  var bottom = block.rect.top + height;
  final maxY = screenHeight > 0 ? screenHeight : null;
  if (maxY != null) bottom = math.min(bottom, maxY);
  final rect = OverlayRect(
    left: block.rect.left,
    top: block.rect.top,
    right: block.rect.right,
    bottom: math.max(block.rect.top + 1, bottom),
  );
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

/// Nới bề ngang sang phải vào khoảng trống, nếu giúp GIẢM số dòng.
///
/// Đây là cách RẺ NHẤT để chữ không bị cắt: khung gốc do OCR cắt sát chữ gốc,
/// trong khi bản dịch tiếng Việt dài hơn ⇒ chỉ cần lấy thêm bề ngang là đủ,
/// không phải thu nhỏ chữ hay đẩy khối khác xuống.
void _expandHorizontally(
  List<_Slot> visible, {
  required int gap,
  required double dpr,
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

    final sizeSp = suggestedTextSizeSp(slot.block.rect, dpr);
    final baseLines = _linesAtWidth(slot, slot.width, sizeSp, dpr);
    if (baseLines <= 1) continue; // đã 1 dòng ⇒ nới rộng vô nghĩa

    // Thử nới dần; dừng ở mức ĐẦU TIÊN giảm được số dòng.
    for (final factor in const <double>[1.0, 0.75, 0.5, 0.35, 0.25]) {
      final tryRight =
          slot.right + ((allowedRight - slot.right) * factor).round();
      if (tryRight <= slot.right) continue;
      final lines = _linesAtWidth(slot, tryRight - slot.left, sizeSp, dpr);
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
  double dpr,
) {
  final usable = math.max(1.0, widthPx - 2 * kOverlayTextPaddingPx);
  // ⚠ PHẢI quy đổi sp → px: bề ngang ở đây là PIXEL màn hình. Trộn đơn vị sẽ
  // ước lượng thiếu số dòng (chữ thật dài hơn tưởng) ⇒ không nới rộng.
  return estimateTranslationLineCount(
    slot.block.translation,
    usable,
    sizeSp * dpr,
  );
}

class _PackResult {
  _PackResult(this.maxBottom);

  final int maxBottom;
}

/// Xếp các slot theo cột dọc, ĐẨY khối sau xuống khi khối trước cần thêm chỗ.
_PackResult _pack(
  List<_Slot> visible, {
  required double dpr,
  required int gap,
  required double scale,
}) {
  var maxBottom = 0;
  // Đặt theo thứ tự đọc; mỗi khối chỉ bị đẩy bởi khối GIAO NGANG với nó.
  final placed = <_Slot>[];
  for (final slot in visible) {
    final sizeSp = (suggestedTextSizeSp(slot.block.rect, dpr) * scale)
        .clamp(kOverlayMinReadableSp, 28.0)
        .toDouble();
    slot.textSizeSp = sizeSp;
    final fontPx = sizeSp * dpr;
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
      translation: original.translation,
      textSizeSp: slot.textSizeSp <= 0
          ? suggestedTextSizeSp(rect, dpr)
          : slot.textSizeSp,
    ));
  }
  return out;
}
