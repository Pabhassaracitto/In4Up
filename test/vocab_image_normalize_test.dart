// PLAN-041 mục 4 — chuẩn hoá dung lượng ảnh minh hoạ khi lưu: thu cạnh
// dài nhất ≤1024px, JPEG q80 (PNG khi có alpha), Lottie/GIF/bytes lạ giữ
// nguyên. Pin bằng ảnh sinh tại chỗ bằng chính gói `image`.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:in4up/features/vocab_image/vocab_image_normalize.dart';

Uint8List _pngBytes(int w, int h, {int channels = 3}) {
  final image = img.Image(width: w, height: h, numChannels: channels);
  // Tô hoa văn xác định (không phải màu đặc) để nén hoạt động như ảnh thật.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (channels == 4) {
        image.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 128);
      } else {
        image.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('ảnh lớn 2000x1000 → thu về cạnh 1024 và thành JPEG', () {
    final out = normalizeVocabImageBytes(_pngBytes(2000, 1000));
    // Magic JPEG FF D8 FF
    expect(out[0], 0xFF);
    expect(out[1], 0xD8);
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, kVocabImageMaxEdge);
    expect(decoded.height, 512); // giữ tỉ lệ 2:1
  });

  test('ảnh cao 900x1800 → thu theo chiều cao', () {
    final out = normalizeVocabImageBytes(_pngBytes(900, 1800));
    final decoded = img.decodeImage(out)!;
    expect(decoded.height, kVocabImageMaxEdge);
    expect(decoded.width, 512);
  });

  test('ảnh có alpha → giữ PNG (không mất trong suốt) nhưng vẫn thu nhỏ', () {
    final out = normalizeVocabImageBytes(_pngBytes(1600, 800, channels: 4));
    // Magic PNG 89 50 4E 47
    expect(out.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, kVocabImageMaxEdge);
    expect(decoded.numChannels, 4);
  });

  test('Lottie JSON giữ nguyên từng byte', () {
    final lottie = Uint8List.fromList(
        '{"v":"5.7.4","fr":30,"layers":[]}'.codeUnits);
    expect(normalizeVocabImageBytes(lottie), same(lottie));
  });

  test('GIF giữ nguyên (tránh giết ảnh động)', () {
    final gif = Uint8List.fromList('GIF89a-fake-but-magic-ok'.codeUnits);
    expect(normalizeVocabImageBytes(gif), same(gif));
  });

  test('bytes không giải mã được → giữ nguyên (không làm hỏng dữ liệu)', () {
    final junk = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(normalizeVocabImageBytes(junk), same(junk));
    expect(normalizeVocabImageBytes(Uint8List(0)), isEmpty);
  });

  test('ảnh nhỏ dưới ngưỡng: kích thước không đổi dù có mã hoá lại hay không', () {
    final out = normalizeVocabImageBytes(_pngBytes(120, 90));
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 120);
    expect(decoded.height, 90);
  });
}
