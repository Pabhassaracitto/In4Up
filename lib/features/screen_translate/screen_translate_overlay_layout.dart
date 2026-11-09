// lib/features/screen_translate/screen_translate_overlay_layout.dart
//
// AUDIT-1.21.0 #1 — bong bóng dịch NHIỀU KHỐI bị chữ chồng lên nhau.
//
// Nguyên nhân (đọc từ code, không đoán): `TranslationOverlayView.onDraw()`
// vẽ MỖI khối với chiều cao `max(height gốc, layout.height + padding)`. Bản
// dịch thường DÀI hơn bản gốc (VI dài hơn EN ~1.3×) ⇒ ô của khối trên phình
// xuống, đè lên khối dưới; khối dưới lại vẽ sau ⇒ chữ hai khối chồng lên
// nhau. Thêm vào đó OCR (ML Kit) hay trả 2 bbox giao nhau cho cùng một dòng
// ⇒ hai bản dịch cùng nội dung được vẽ đè lên đúng một chỗ.
//
// Quyết định: dời toàn bộ việc "xếp chỗ" sang Dart (thuần, test được), native
// chỉ vẽ ĐÚNG khung đã được cấp và KHÔNG BAO GIỜ phình khung xuống dưới nữa
// (xem `TranslationOverlayView.kt`). Một công thức, một chỗ — đúng tinh thần
// `mapCaptureRectToOverlay` của ADR-0011.
//
// Hợp đồng:
//  • Giữ NGUYÊN số khối + thứ tự đọc (kể cả khối dịch hỏng/translation rỗng)
//    vì controller test + native dùng danh sách này để biết đủ vị trí OCR.
//    Khối bị loại khỏi vẽ ⇒ `translation = ''` (native bỏ qua, chữ gốc hiện
//    nguyên bên dưới).
//  • Không đổi toạ độ khi không có giao nhau (tránh sửa méo các test hình học
//    và các màn hình OCR sạch).
//  • Khung của khối TRÊN bị cắt đúng tại mép trên của khối NGAY DƯỚI nó
//    (trừ một khe hở nhỏ theo density) ⇒ không bao giờ chồng khung.
//  • Hai khối cùng nội dung + bbox giao nhau ⇒ chỉ giữ một ô (khối đầu).
//  • Cỡ chữ được tính lại theo chiều cao KHUNG ĐÃ CẮT, native vẫn thu nhỏ
//    tiếp + ellipsize nếu vẫn không vừa.

import 'dart:math' as math;

import 'screen_translate_geometry.dart';
import 'screen_translate_models.dart';

/// Dưới ngưỡng này coi là frame giả / màn hình không phải thiết bị thật.
const int kOverlayRealScreenMinPx = 200;

/// Chiều cao tối thiểu (dp) để còn vẽ được 1 dòng chữ 9sp + padding.
const double kOverlayMinBoxHeightDp = 11.0;

/// Khe hở giữa 2 khung kề nhau (dp).
const double kOverlayBoxGapDp = 2.0;

/// Hai khung coi là "giao nhau theo chiều ngang" khi phần giao ≥ tỉ lệ này
/// của khung hẹp hơn. Hai cột chữ cạnh nhau (giao 1-2px do OCR lệch) KHÔNG
/// bị cắt nhầm.
const double kOverlayHorizontalOverlapRatio = 0.25;

/// Hai khung cùng nội dung coi là "trùng" khi phần giao ≥ tỉ lệ này.
const double kOverlayDuplicateRatio = 0.55;

class _Slot {
  _Slot(this.index, this.block, this.left, this.top, this.right, this.bottom);

  final int index;
  final ScreenBlock block;
  final int left;
  final int top;
  final int right;
  int bottom;

  int get width => math.max(1, right - left);

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

/// Xếp lại [blocks] để các ô bản dịch KHÔNG chồng lên nhau.
///
/// [screenWidth]/[screenHeight] chỉ dùng để cắt khung ra ngoài màn hình;
/// truyền `0` (hoặc giá trị nhỏ hơn khung, như frame giả trong test) để tắt
/// cắt biên — toạ độ do `mapCaptureRectToOverlay` quyết định, hàm này không
/// sửa lại công thức đó.
List<ScreenBlock> layoutTranslatedBlocks(
  List<ScreenBlock> blocks, {
  int screenWidth = 0,
  int screenHeight = 0,
  double devicePixelRatio = 1.0,
}) {
  if (blocks.length < 2) return List<ScreenBlock>.of(blocks);
  // Frame giả trong test / màn hình nhỏ bất thường: đừng áp ngưỡng dp của
  // thiết bị thật vào khung chỉ vài pixel, nếu không mọi khối sẽ bị "drop".
  if ((screenWidth > 0 && screenWidth < kOverlayRealScreenMinPx) ||
      (screenHeight > 0 && screenHeight < kOverlayRealScreenMinPx)) {
    return List<ScreenBlock>.of(blocks);
  }

  final dpr = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
  final minHeight = math.max(6, (kOverlayMinBoxHeightDp * dpr).round());
  final gap = math.max(1, (kOverlayBoxGapDp * dpr).round());
  final maxX = screenWidth > 0 ? screenWidth : null;
  final maxY = screenHeight > 0 ? screenHeight : null;

  final slots = <_Slot>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    var left = block.rect.left;
    var top = block.rect.top;
    var right = math.max(left + 1, block.rect.right);
    var bottom = math.max(top + 1, block.rect.bottom);
    if (maxX != null) {
      left = math.max(0, math.min(maxX, left));
      right = math.max(left + 1, math.min(maxX, right));
    }
    if (maxY != null) {
      top = math.max(0, math.min(maxY, top));
      bottom = math.max(top + 1, math.min(maxY, bottom));
    }
    slots.add(_Slot(i, block, left, top, right, bottom));
  }

  // Thứ tự đọc: trên xuống, trái sang phải. `index` giữ nguyên thứ tự OCR
  // khi hai khối cùng toạ độ (stable sort trong Dart không bảo đảm).
  final ordered = List<_Slot>.of(slots)
    ..sort((a, b) {
      final byTop = a.top.compareTo(b.top);
      if (byTop != 0) return byTop;
      final byLeft = a.left.compareTo(b.left);
      if (byLeft != 0) return byLeft;
      return a.index.compareTo(b.index);
    });

  final placed = <_Slot>[];
  final visible = <_Slot>[];
  final dropped = <int>{};

  for (final slot in ordered) {
    final text = slot.block.translation.trim();
    if (text.isEmpty) {
      // Khối dịch hỏng: native không vẽ, nhưng vẫn giữ trong kết quả.
      continue;
    }

    // (a) Gộp khối TRÙNG: cùng nội dung dịch + bbox giao nhau đáng kể.
    // ML Kit thường tách 1 dòng thành 2 bbox chồng nhau ⇒ trước đây vẽ 2 lần
    // cùng một chữ (dày/chồng nét).
    var duplicate = false;
    for (final other in visible) {
      if (_normalized(other.block.translation) != _normalized(text)) continue;
      if (slot.overlapRatio(other) >= kOverlayDuplicateRatio) {
        duplicate = true;
        break;
      }
    }
    if (duplicate) {
      dropped.add(slot.index);
      continue;
    }

    // (b) Cắt khung của các khối ĐÃ ĐẶT ở trên khi chúng phình xuống đúng
    // chỗ khối này bắt đầu. Xử lý ở đây (khi gặp khối dưới) để không cần
    // lookahead; `placed` chứa cả khối không vẽ (đã lọc) nên an toàn.
    for (final earlier in placed) {
      if (!earlier.overlapsHorizontally(slot)) continue;
      if (earlier.top >= slot.top) continue;
      if (earlier.bottom <= slot.top) continue;
      earlier.bottom = math.max(earlier.top + 1, slot.top - gap);
    }

    // (c) Khối này cũng không được phình xuống khối đã đặt trước nó (trường
    // hợp 2 bbox cùng top nhưng lệch vài px).
    for (final earlier in placed) {
      if (!earlier.overlapsHorizontally(slot)) continue;
      if (earlier.top != slot.top) continue;
      if (slot.overlapRatio(earlier) >= kOverlayDuplicateRatio) {
        dropped.add(slot.index);
        break;
      }
    }
    if (dropped.contains(slot.index)) continue;

    placed.add(slot);
    visible.add(slot);
  }

  // (d) Khung bị cắt quá mỏng ⇒ không vẽ (tránh chữ 9sp bị nghiền nát đè
  // lên dòng kế). Chữ gốc bên dưới vẫn đọc được.
  for (final slot in placed) {
    if (slot.bottom - slot.top < minHeight) {
      dropped.add(slot.index);
    }
  }

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
      textSizeSp: suggestedTextSizeSp(rect, dpr),
    ));
  }
  return out;
}
