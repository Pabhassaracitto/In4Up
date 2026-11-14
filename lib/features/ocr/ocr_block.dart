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
import 'dart:typed_data';

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

/// Có ít nhất một chữ cái hoặc chữ số Unicode thật (Latin, Việt, Pāḷi có dấu,
/// Sinhala, Myanmar, Thái, Devanagari, Hán/Nhật, số…). Các khối/dòng chỉ gồm
/// dấu gạch đứng mép scan `|`, chấm lửng `...`, gạch kẻ `---`, ký hiệu rác
/// trên nền trống sẽ bị loại (PSRC-210).
final RegExp _readableGlyphPattern = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Nhiễu mép trang scan rất phổ biến của ML Kit: chỉ gồm các ký tự sọc dọc
/// mảnh (`|`, `¦`, `\`, `/`, `!`, `~`, `_`) và dấu chấm/gạch lặp lại.
final RegExp _scanBorderNoisePattern =
    RegExp(r'^[\s|¦\\/!~_.,:;•·\-–—+*^"`´]+$');

/// Kiểm tra chuỗi có chứa chữ/số đọc được thực sự (không phải nhiễu vùng trống).
bool hasMeaningfulOcrText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  if (_scanBorderNoisePattern.hasMatch(trimmed)) return false;
  return _readableGlyphPattern.hasMatch(trimmed);
}

/// Lọc từng dòng của một khối chữ ML Kit: bỏ dòng rỗng và dòng chỉ chứa ký tự
/// nhiễu mép trang / kẻ dòng trên vùng không có chữ, giữ nguyên xuống dòng hợp lệ.
String cleanOcrBlockLines(String raw) {
  if (raw.trim().isEmpty) return '';
  final kept = <String>[];
  for (final rawLine in raw.split('\n')) {
    final line = rawLine.replaceAll(RegExp(r'[ \t\r]+'), ' ').trim();
    if (!hasMeaningfulOcrText(line)) continue;
    kept.add(line);
  }
  return kept.join('\n').trim();
}

/// Kiểm tra khung bao có hình học hợp lý của chữ thật (loại hạt bụi li ti
/// < 4px hoặc sọc đen mép scan cao vọt nhưng chỉ sinh ra 1–3 ký tự rác như `I`/`1`).
bool isPlausibleOcrTextRect({
  required OcrBlockRect rect,
  required String cleanedText,
}) {
  if (!rect.isValid) return false;
  if (rect.width < 4 || rect.height < 4) return false;
  final compact = cleanedText.replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) return false;

  if (rect.height >= rect.width * 18 && compact.length <= 3) {
    return false;
  }
  if (rect.width >= rect.height * 35 && compact.split('').toSet().length == 1) {
    return false;
  }
  return true;
}

int _bgraLumaAt(Uint8List pixels, int byteOffset) {
  final a = pixels[byteOffset + 3];
  if (a < 16) return 255;
  final b = pixels[byteOffset];
  final g = pixels[byteOffset + 1];
  final r = pixels[byteOffset + 2];
  return (77 * r + 150 * g + 29 * b) >> 8;
}

/// Phát hiện nhanh ảnh/trang BGRA8888 hoàn toàn trống hoặc đồng màu (giấy trắng,
/// nền xám/đen trơn, bóng đổ mịn không có nét mực chữ) để bỏ qua ML Kit ngay,
/// tránh tốn CPU và tránh ML Kit ảo giác ký tự trên vùng trống (PSRC-210).
bool isVisuallyBlankBgraBitmap({
  required Uint8List pixels,
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0) return true;
  if (pixels.length < width * height * 4) return true;

  final stepX = math.max(1, width ~/ 96);
  final stepY = math.max(1, height ~/ 96);
  final bins = List<int>.filled(16, 0);
  var minY = 255;
  var maxY = 0;
  var samples = 0;

  for (var y = 0; y < height; y += stepY) {
    final rowOffset = y * width * 4;
    for (var x = 0; x < width; x += stepX) {
      final luma = _bgraLumaAt(pixels, rowOffset + x * 4);
      if (luma < minY) minY = luma;
      if (luma > maxY) maxY = luma;
      bins[(luma >> 4).clamp(0, 15)]++;
      samples++;
    }
  }

  if (samples == 0 || maxY - minY < 22) return true;

  var dominantBin = 0;
  for (var i = 1; i < 16; i++) {
    if (bins[i] > bins[dominantBin]) dominantBin = i;
  }
  final bgCenter = dominantBin * 16 + 8;

  var contrastCount = 0;
  for (var y = 0; y < height; y += stepY) {
    final rowOffset = y * width * 4;
    for (var x = 0; x < width; x += stepX) {
      final luma = _bgraLumaAt(pixels, rowOffset + x * 4);
      if ((luma - bgCenter).abs() >= 26) {
        contrastCount++;
      }
    }
  }

  return contrastCount < 3 || contrastCount * 10000 < samples * 4;
}

/// Kiểm tra bên trong [rect] của ảnh BGRA8888 có thực sự tồn tại độ tương phản
/// nét chữ so với nền cục bộ hay chỉ là vùng trống / bóng mờ đồng nhất (PSRC-210).
bool hasForegroundContrastInBgraRect({
  required Uint8List pixels,
  required int imageWidth,
  required int imageHeight,
  required OcrBlockRect rect,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) return false;
  if (pixels.length < imageWidth * imageHeight * 4) return false;
  if (!rect.isValid) return false;

  final left = rect.left.clamp(0, imageWidth - 1);
  final right = rect.right.clamp(left + 1, imageWidth);
  final top = rect.top.clamp(0, imageHeight - 1);
  final bottom = rect.bottom.clamp(top + 1, imageHeight);
  final w = right - left;
  final h = bottom - top;

  final stepX = math.max(1, w ~/ 48);
  final stepY = math.max(1, h ~/ 32);
  final bins = List<int>.filled(16, 0);
  var minY = 255;
  var maxY = 0;
  var samples = 0;

  for (var y = top; y < bottom; y += stepY) {
    final rowOffset = y * imageWidth * 4;
    for (var x = left; x < right; x += stepX) {
      final luma = _bgraLumaAt(pixels, rowOffset + x * 4);
      if (luma < minY) minY = luma;
      if (luma > maxY) maxY = luma;
      bins[(luma >> 4).clamp(0, 15)]++;
      samples++;
    }
  }

  if (samples == 0 || maxY - minY < 24) return false;

  var dominantBin = 0;
  for (var i = 1; i < 16; i++) {
    if (bins[i] > bins[dominantBin]) dominantBin = i;
  }
  final bgCenter = dominantBin * 16 + 8;

  var inkSamples = 0;
  for (var y = top; y < bottom; y += stepY) {
    final rowOffset = y * imageWidth * 4;
    for (var x = left; x < right; x += stepX) {
      final luma = _bgraLumaAt(pixels, rowOffset + x * 4);
      if ((luma - bgCenter).abs() >= 24) {
        inkSamples++;
      }
    }
  }

  return inkSamples >= 2 && inkSamples * 100 >= samples;
}

/// Dựng một [OcrBlock] đã được LÀM SẠCH từ dữ liệu thô của ML Kit.
///
/// Trả về null khi khối không dùng được:
/// - text rỗng hoặc chỉ chứa ký tự nhiễu vùng trống sau khi làm sạch,
/// - khung bao đảo chiều không có diện tích hoặc hạt bụi / sọc mép scan,
/// - khung nằm hoàn toàn ngoài ảnh hoặc vùng pixel không có độ tương phản chữ.
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
  Uint8List? bgraPixels,
}) {
  final cleaned = cleanOcrBlockLines(text);
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
  if (!isPlausibleOcrTextRect(rect: rect, cleanedText: cleaned)) return null;
  if (bgraPixels != null &&
      !hasForegroundContrastInBgraRect(
        pixels: bgraPixels,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        rect: rect,
      )) {
    return null;
  }
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
