// lib/features/ocr/ocr_block.dart
//
// Khối chữ OCR + khung bao (bbox) theo TOẠ ĐỘ PIXEL của ảnh nguồn.
// XLAT-SCR-002 (dịch màn hình toàn hệ thống) · ADR-0011.
//
// Vì sao tách file riêng: `OcrResult` hiện tại CHỈ trả chuỗi văn bản phẳng và
// PDF Reader đang dùng (`recognizeBitmap`) — KHÔNG được đổi. Lane dịch màn hình
// cần bbox để vẽ bản dịch đè đúng chỗ, nên thêm một lớp dữ liệu mới bên cạnh.
//
// File này THUẦN DART: không import plugin ML Kit, không chạm MethodChannel →
// test chạy được trên host VM (sandbox không có Android/iOS).

import 'dart:math' as math;

/// Khung bao của một khối chữ, theo pixel của ảnh đã OCR.
///
/// Quy ước y-DOWN (0 ở mép trên) — đúng với bitmap/ảnh chụp màn hình.
/// KHÁC quy ước y-up của PDF (`pdf_geometry.dart`, ADR-0003): đừng trộn hai
/// hệ với nhau, ảnh chụp màn hình không phải trang PDF.
class OcrBlockRect {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const OcrBlockRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  int get width => right - left;
  int get height => bottom - top;

  /// Khung hợp lệ khi có diện tích dương (ML Kit đôi khi trả khung rỗng).
  bool get isValid => width > 0 && height > 0;

  Map<String, Object?> toMap() => <String, Object?>{
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };

  static OcrBlockRect? fromMap(Map<Object?, Object?> map) {
    final left = _asInt(map['left']);
    final top = _asInt(map['top']);
    final right = _asInt(map['right']);
    final bottom = _asInt(map['bottom']);
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return OcrBlockRect(left: left, top: top, right: right, bottom: bottom);
  }

  @override
  String toString() => 'OcrBlockRect($left,$top,$right,$bottom)';

  @override
  bool operator ==(Object other) =>
      other is OcrBlockRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Một khối chữ ML Kit nhận ra: nội dung + khung bao (pixel ảnh nguồn).
class OcrBlock {
  final String text;
  final OcrBlockRect rect;

  const OcrBlock({required this.text, required this.rect});

  Map<String, Object?> toMap() => <String, Object?>{
        'text': text,
        ...rect.toMap(),
      };

  @override
  String toString() => 'OcrBlock("$text", $rect)';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Dựng một [OcrBlock] đã được LÀM SẠCH từ dữ liệu thô của ML Kit.
///
/// Trả về null khi khối không dùng được:
/// - text rỗng sau khi trim (ML Kit thỉnh thoảng trả block chỉ có khoảng trắng),
/// - khung bao đảo chiều hoặc không có diện tích,
/// - khung nằm hoàn toàn ngoài ảnh.
///
/// Khung được CLAMP về trong ảnh ([imageWidth] × [imageHeight]) — ML Kit có
/// thể trả toạ độ âm/vượt mép khi chữ dính sát viền, mà overlay native vẽ
/// thẳng theo số này.
OcrBlock? makeOcrBlock({
  required String text,
  required int left,
  required int top,
  required int right,
  required int bottom,
  required int imageWidth,
  required int imageHeight,
}) {
  final cleaned = text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  if (cleaned.isEmpty) return null;
  if (imageWidth <= 0 || imageHeight <= 0) return null;

  // Chấp nhận dữ liệu đảo chiều (right < left) bằng cách sắp lại — thà vẽ
  // đúng chỗ còn hơn bỏ mất khối chữ.
  final l = math.min(left, right);
  final r = math.max(left, right);
  final t = math.min(top, bottom);
  final b = math.max(top, bottom);

  final clampedLeft = l.clamp(0, imageWidth);
  final clampedRight = r.clamp(0, imageWidth);
  final clampedTop = t.clamp(0, imageHeight);
  final clampedBottom = b.clamp(0, imageHeight);

  final rect = OcrBlockRect(
    left: clampedLeft,
    top: clampedTop,
    right: clampedRight,
    bottom: clampedBottom,
  );
  if (!rect.isValid) return null;
  return OcrBlock(text: cleaned, rect: rect);
}

/// Sắp các khối theo thứ tự ĐỌC (trên→dưới, trái→phải).
///
/// [rowTolerance] = sai số pixel để coi hai khối là CÙNG HÀNG: chữ trên một
/// dòng hiếm khi có `top` bằng nhau tuyệt đối. Mặc định 24px hợp với mật độ
/// điện thoại phổ thông; caller có thể nâng lên cho màn hình 2K/4K.
List<OcrBlock> sortOcrBlocksForReading(
  List<OcrBlock> blocks, {
  int rowTolerance = 24,
}) {
  final sorted = List<OcrBlock>.of(blocks);
  sorted.sort((a, b) {
    final dy = a.rect.top - b.rect.top;
    if (dy.abs() > rowTolerance) return dy;
    return a.rect.left - b.rect.left;
  });
  return sorted;
}
