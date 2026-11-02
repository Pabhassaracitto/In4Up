// PLAN-041 mục 4 (IMG-WEB-002, phần dung lượng) — chuẩn hoá ảnh minh hoạ
// TRƯỚC khi lưu vào app storage: thu cạnh dài nhất về [kVocabImageMaxEdge]
// và mã hoá lại (JPEG q80 cho ảnh thường, PNG khi có kênh alpha).
//
// Vì sao: trước đây ảnh tải về được lưu NGUYÊN bytes (Pexels `large2x`,
// Unsplash `full`, trần 8MB) dù flashcard/danh sách chỉ hiện vài trăm px —
// vài trăm từ là thư mục ảnh phình hàng trăm MB. Mục tiêu: ~80–250KB/ảnh,
// mắt thường không phân biệt được trên thẻ.
//
// Hàm THUẦN (bytes vào → bytes ra) để test được và chạy trong isolate qua
// `compute` ở phía service. Kỷ luật an toàn dữ liệu: bất cứ lúc nào không
// chắc (không giải mã được, mã hoá lại không nhỏ hơn mà cũng không thu
// nhỏ) thì GIỮ NGUYÊN bytes gốc — chuẩn hoá chỉ được làm ảnh nhẹ đi, không
// bao giờ làm mất/hỏng ảnh của người dùng.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Cạnh dài nhất tối đa của ảnh minh hoạ đã lưu.
const int kVocabImageMaxEdge = 1024;

/// Chất lượng JPEG khi mã hoá lại (điểm ngọt rõ/nhẹ cho ảnh thẻ).
const int kVocabImageJpegQuality = 80;

/// Chuẩn hoá [bytes] ảnh để lưu trữ nhẹ. Lottie (.json/.lottie) và GIF
/// (có thể là ảnh động) được giữ nguyên tuyệt đối.
Uint8List normalizeVocabImageBytes(Uint8List bytes) {
  if (bytes.isEmpty) return bytes;

  // Lottie JSON ('{') và dotLottie (zip 'PK\x03\x04') — không phải ảnh raster.
  if (bytes[0] == 0x7B) return bytes;
  if (bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04) {
    return bytes;
  }
  // GIF: giữ nguyên (mã hoá lại thành JPEG sẽ giết ảnh động).
  if (bytes.length >= 3 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return bytes;
  }

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return bytes;
  }
  if (decoded == null) return bytes;

  var image = decoded;
  final maxEdge = image.width > image.height ? image.width : image.height;
  var resized = false;
  if (maxEdge > kVocabImageMaxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: kVocabImageMaxEdge)
        : img.copyResize(image, height: kVocabImageMaxEdge);
    resized = true;
  }

  List<int> encoded;
  try {
    encoded = image.numChannels == 4
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: kVocabImageJpegQuality);
  } catch (_) {
    return bytes;
  }

  // Không thu nhỏ mà mã hoá lại còn nặng hơn (vd ảnh đã nén tối ưu sẵn)
  // thì giữ bản gốc — chuẩn hoá không được làm tình hình tệ đi.
  if (!resized && encoded.length >= bytes.length) return bytes;
  return Uint8List.fromList(encoded);
}
