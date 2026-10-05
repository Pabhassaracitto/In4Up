// lib/features/screen_translate/screen_translate_geometry.dart
//
// Quy đổi toạ độ + định dạng pixel cho lane "dịch màn hình toàn hệ thống"
// (XLAT-SCR-002 · ADR-0011). THUẦN DART — chạy được trên host VM.
//
// Hai bài toán duy nhất của file này (đừng nhét thêm việc khác vào):
//
// 1. **Toạ độ.** Ảnh chụp theo PIXEL vật lý (vd 1080×2400) nhưng overlay
//    native vẽ theo dp (`WindowManager.LayoutParams` dùng pixel của màn hình,
//    còn `TextView.setTextSize(SP)` theo density). Một hàm map DUY NHẤT —
//    `mapCaptureRectToOverlay` — để không có hai công thức lệch nhau.
//    Có cả trường hợp ảnh bị DOWNSCALE trước khi OCR (tiết kiệm RAM): tỉ lệ
//    capture→screen không nhất thiết là 1.0.
//
// 2. **Định dạng pixel.** `ImageReader`/`PixelCopy` cho ARGB_8888 — trong bộ
//    nhớ byte đi theo thứ tự R,G,B,A — còn `InputImage.fromBitmap` khai
//    `bgra8888`. Phải hoán kênh R↔B trước khi đưa sang ML Kit (cùng ghi chú
//    iOS trong `ocr_service.dart`). Thêm nữa, hàng của ImageReader có PADDING
//    (`rowStride > width*4`) nên phải cắt bỏ phần thừa, nếu không ảnh bị
//    "xiên" và OCR ra rác.

import 'dart:math' as math;
import 'dart:typed_data';

import '../ocr/ocr_block.dart';

/// Khung chữ nhật theo đơn vị PIXEL MÀN HÌNH (y-down) mà overlay native vẽ.
class OverlayRect {
  final int left;
  final int top;
  final int right;
  final int bottom;

  const OverlayRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  int get width => right - left;
  int get height => bottom - top;

  Map<String, Object?> toMap() => <String, Object?>{
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };

  @override
  bool operator ==(Object other) =>
      other is OverlayRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'OverlayRect($left,$top,$right,$bottom)';
}

/// Thông số hình học của một lần chụp.
///
/// [captureWidth]/[captureHeight]: kích thước ảnh ĐÃ đưa vào OCR.
/// [screenWidth]/[screenHeight]: kích thước vùng overlay phủ (pixel màn hình).
/// [devicePixelRatio]: `displayMetrics.density` — dùng để đổi pixel → dp cho
/// cỡ chữ, KHÔNG dùng để đổi vị trí (vị trí đã là pixel màn hình).
class ScreenCaptureGeometry {
  final int captureWidth;
  final int captureHeight;
  final int screenWidth;
  final int screenHeight;
  final double devicePixelRatio;

  const ScreenCaptureGeometry({
    required this.captureWidth,
    required this.captureHeight,
    required this.screenWidth,
    required this.screenHeight,
    this.devicePixelRatio = 1.0,
  });

  bool get isValid =>
      captureWidth > 0 &&
      captureHeight > 0 &&
      screenWidth > 0 &&
      screenHeight > 0 &&
      devicePixelRatio > 0;

  /// Hệ số nhân theo trục X khi đưa toạ độ ảnh → toạ độ màn hình.
  double get scaleX => isValid ? screenWidth / captureWidth : 1.0;

  /// Hệ số nhân theo trục Y.
  ///
  /// Tách riêng X/Y có chủ đích: khi xoay ngang mà service chưa kịp tạo lại
  /// VirtualDisplay, tỉ lệ hai trục khác nhau — dùng một hệ số chung sẽ lệch
  /// chữ. Thà vẽ hơi méo còn hơn vẽ sai chỗ.
  double get scaleY => isValid ? screenHeight / captureHeight : 1.0;

  Map<String, Object?> toMap() => <String, Object?>{
        'captureWidth': captureWidth,
        'captureHeight': captureHeight,
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
        'devicePixelRatio': devicePixelRatio,
      };

  static ScreenCaptureGeometry fromMap(Map<Object?, Object?> map) {
    double toDouble(Object? v, double fallback) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    int toInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final captureWidth = toInt(map['captureWidth'] ?? map['width']);
    final captureHeight = toInt(map['captureHeight'] ?? map['height']);
    return ScreenCaptureGeometry(
      captureWidth: captureWidth,
      captureHeight: captureHeight,
      screenWidth: toInt(map['screenWidth']) > 0
          ? toInt(map['screenWidth'])
          : captureWidth,
      screenHeight: toInt(map['screenHeight']) > 0
          ? toInt(map['screenHeight'])
          : captureHeight,
      devicePixelRatio: toDouble(map['devicePixelRatio'], 1.0),
    );
  }
}

/// HÀM MAP DUY NHẤT: khung OCR (pixel ảnh) → khung overlay (pixel màn hình).
///
/// Kết quả luôn nằm trong màn hình (clamp) và có diện tích ≥ 1px để native
/// không phải tự phòng thủ.
OverlayRect mapCaptureRectToOverlay(
  OcrBlockRect rect,
  ScreenCaptureGeometry geometry,
) {
  final sx = geometry.scaleX;
  final sy = geometry.scaleY;
  final maxX = geometry.isValid ? geometry.screenWidth : rect.right;
  final maxY = geometry.isValid ? geometry.screenHeight : rect.bottom;

  int clampX(num v) => v.round().clamp(0, maxX);
  int clampY(num v) => v.round().clamp(0, maxY);

  final left = clampX(rect.left * sx);
  final top = clampY(rect.top * sy);
  final right = math.max(left + 1, clampX(rect.right * sx));
  final bottom = math.max(top + 1, clampY(rect.bottom * sy));
  return OverlayRect(left: left, top: top, right: right, bottom: bottom);
}

/// Cỡ chữ (sp) gợi ý để bản dịch vừa chiều cao khung gốc.
///
/// Native có thể bỏ qua, nhưng tính ở Dart thì test được: chiều cao khối chia
/// density = dp; chừa 18% cho padding/leading; kẹp trong [10, 28] sp để chữ
/// không bé xíu cũng không tràn.
double suggestedTextSizeSp(OverlayRect rect, double devicePixelRatio) {
  if (devicePixelRatio <= 0) return 14.0;
  final heightDp = rect.height / devicePixelRatio;
  final raw = heightDp * 0.82;
  return raw.clamp(10.0, 28.0).toDouble();
}

/// Bỏ padding cuối mỗi hàng của `ImageReader` (rowStride) → mảng đặc
/// `width*height*4`.
///
/// Trả về chính [source] khi không có padding (tránh copy thừa).
/// Ném [ArgumentError] khi dữ liệu ngắn hơn mức tối thiểu — im lặng ở đây
/// đồng nghĩa ML Kit đọc tràn bộ nhớ ở tầng dưới.
Uint8List removeRowPadding(
  Uint8List source, {
  required int width,
  required int height,
  required int rowStride,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Kích thước ảnh không hợp lệ: ${width}x$height');
  }
  final rowBytes = width * 4;
  if (rowStride < rowBytes) {
    throw ArgumentError(
      'rowStride $rowStride nhỏ hơn ${rowBytes} byte/hàng của ${width}px',
    );
  }
  final needed = rowStride * (height - 1) + rowBytes;
  if (source.length < needed) {
    throw ArgumentError(
      'Dữ liệu ${source.length} byte thiếu so với $needed byte cần thiết',
    );
  }
  if (rowStride == rowBytes && source.length == rowBytes * height) {
    return source;
  }
  final out = Uint8List(rowBytes * height);
  for (var y = 0; y < height; y++) {
    final srcStart = y * rowStride;
    out.setRange(
      y * rowBytes,
      (y + 1) * rowBytes,
      source,
      srcStart,
    );
  }
  return out;
}

/// Hoán kênh R↔B tại chỗ-ảo: RGBA (ARGB_8888 của Android trong bộ nhớ) →
/// BGRA8888 (định dạng `InputImage.fromBitmap` khai báo).
///
/// Trả về mảng MỚI (không sửa [source]) để caller còn giữ ảnh gốc nếu muốn
/// lưu bằng chứng. Ném [ArgumentError] khi độ dài không chia hết cho 4.
Uint8List swapRedBlue(Uint8List source) {
  if (source.length % 4 != 0) {
    throw ArgumentError(
      'Độ dài ${source.length} không phải bội số của 4 (RGBA/BGRA)',
    );
  }
  final out = Uint8List.fromList(source);
  for (var i = 0; i < out.length; i += 4) {
    final r = out[i];
    out[i] = out[i + 2];
    out[i + 2] = r;
  }
  return out;
}

/// Chuẩn hoá một frame thô từ native về đúng thứ gì ML Kit nhận:
/// bỏ padding hàng + hoán R/B.
///
/// [alreadyBgra] = true khi native đã tự hoán kênh (tiết kiệm một vòng lặp
/// trên ảnh 1080×2400 ≈ 10MB) — khi đó chỉ cắt padding.
Uint8List normalizeCaptureFrame(
  Uint8List source, {
  required int width,
  required int height,
  required int rowStride,
  bool alreadyBgra = false,
}) {
  final packed = removeRowPadding(
    source,
    width: width,
    height: height,
    rowStride: rowStride,
  );
  if (alreadyBgra) {
    // Luôn trả bản copy khi packed trùng source: caller (và native) có thể
    // tái dùng buffer cho frame sau.
    return identical(packed, source) ? Uint8List.fromList(packed) : packed;
  }
  return swapRedBlue(packed);
}
