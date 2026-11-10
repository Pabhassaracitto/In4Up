// XLAT-SCR-006 — bong bóng dịch: KHUNG PHẢI ĐỦ CHỖ CHO CHỮ, và các khối vẫn
// KHÔNG chồng lên nhau.
//
// Vì sao có test này (đọc để không đảo lại lần thứ ba):
//   • AUDIT-1.21.0 #1 sửa "chữ chồng nhau" bằng cách CẮT khung khối trên đúng
//     mép khối dưới ⇒ hết chồng nhưng bản dịch (VI dài hơn EN ~1.3×) hết chỗ,
//     native thu nhỏ tới 9sp rồi ellipsize ⇒ MẤT CHỮ, chữ bé không đọc được.
//   • Owner báo 2026-11-11 (kèm ảnh chụp): "khung bị nhỏ hơn nội dung chữ nên
//     bị mất phần… Đảm bảo chữ hiện đầy đủ không bị bóp nhỏ, ẩn do khung nhỏ
//     nhưng cũng không để các lớp dịch bị chồng lên nhau."
//
// Hợp đồng mới được đo bằng 4 bất biến (không phụ thuộc số pixel cụ thể):
//   1. KHÔNG hai khung nào giao nhau.
//   2. Mỗi khung CAO ĐỦ cho chữ của nó (theo `estimateTranslationTextHeightPx`).
//   3. Cỡ chữ không bao giờ dưới `kOverlayMinReadableSp`.
//   4. Danh sách trả về GIỮ NGUYÊN số khối + thứ tự (khối bỏ vẽ ⇒ translation rỗng).
//
// Test THUẦN trên host VM — không cần thiết bị / MediaProjection.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/screen_translate/screen_translate_geometry.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/screen_translate/screen_translate_overlay_layout.dart';

const double _dpr = 2.75; // Pixel 7 kiểu
const int _screenW = 1080;
const int _screenH = 2400;

ScreenBlock _b(
  int top,
  int bottom,
  String translation, {
  int left = 60,
  int right = 1020,
}) {
  return ScreenBlock(
    rect: OverlayRect(left: left, top: top, right: right, bottom: bottom),
    original: 'original',
    translation: translation,
    textSizeSp: 14,
  );
}

/// Hai khung KHÔNG được giao nhau (tính cả cạnh chung).
///
/// [tolerancePx] dùng cho ca bbox OCR gốc đã giao nhau vài pixel (hai cột chữ
/// lệch 1–2px) — mức đó nằm trong padding nên không nhìn thấy, và layout cố ý
/// KHÔNG xê dịch toạ độ gốc của khối không liên quan.
List<String> _overlaps(List<ScreenBlock> blocks, {int tolerancePx = 0}) {
  final bad = <String>[];
  for (var i = 0; i < blocks.length; i++) {
    if (!blocks[i].hasTranslation) continue;
    for (var j = i + 1; j < blocks.length; j++) {
      if (!blocks[j].hasTranslation) continue;
      final a = blocks[i].rect;
      final b = blocks[j].rect;
      final w = math.min(a.right, b.right) - math.max(a.left, b.left);
      final h = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
      if (w > tolerancePx && h > tolerancePx) {
        bad.add('#$i($a) ∩ #$j($b) = ${w}×$h');
      }
    }
  }
  return bad;
}

/// Khung có ĐỦ cao cho chữ của nó không (theo cùng bộ ước lượng).
List<String> _tooShort(List<ScreenBlock> blocks) {
  final bad = <String>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (!block.hasTranslation) continue;
    final need = estimateTranslationTextHeightPx(
          block.translation,
          math.max(1.0, block.rect.width - 2 * kOverlayTextPaddingPx),
          block.textSizeSp * _dpr,
        ) +
        2 * kOverlayTextPaddingPx;
    final have = block.rect.height.toDouble();
    if (have + 0.5 < need) {
      bad.add('#$i cần ${need.toStringAsFixed(1)}px, có ${have}px '
          '(${block.translation.length} ký tự)');
    }
  }
  return bad;
}

void main() {
  group('Bộ ước lượng số dòng', () {
    test('rỗng ⇒ 0 dòng; 1 từ ngắn ⇒ 1 dòng', () {
      expect(estimateTranslationLineCount('', 300, 34), 0);
      expect(estimateTranslationLineCount('   ', 300, 34), 0);
      expect(estimateTranslationLineCount('Xin chào', 300, 34), 1);
    });

    test('càng hẹp càng nhiều dòng (đơn điệu)', () {
      const text =
          'Xin chào, bạn muốn học gì về tiếng Anh hôm nay vậy? Mình giúp nhé.';
      final wide = estimateTranslationLineCount(text, 600, 34);
      final narrow = estimateTranslationLineCount(text, 200, 34);
      expect(narrow, greaterThan(wide));
    });

    test('chữ to hơn ⇒ nhiều dòng hơn', () {
      const text = 'Bản dịch tiếng Việt dài hơn bản gốc tiếng Anh đáng kể.';
      final small = estimateTranslationLineCount(text, 400, 26);
      final big = estimateTranslationLineCount(text, 400, 44);
      expect(big, greaterThanOrEqualTo(small));
    });

    test('từ dài hơn cả dòng vẫn trả ≥ 1 (không ÂM, không vòng lặp vô hạn)', () {
      final lines = estimateTranslationLineCount(
        'https://example.com/mot-duong-dan-tieng-viet-rat-dai-khong-co-khoang-trang',
        120,
        34,
      );
      expect(lines, greaterThanOrEqualTo(2));
      expect(lines, lessThan(1000));
    });

    test('chiều cao ước lượng tăng theo số dòng', () {
      const text =
          'Một hai ba bốn năm sáu bảy tám chín mười mười một mười hai mười ba';
      final h1 = estimateTranslationTextHeightPx(text, 900, 34);
      final h2 = estimateTranslationTextHeightPx(text, 200, 34);
      expect(h2, greaterThan(h1));
    });
  });

  group('layoutTranslatedBlocks — chữ đầy đủ VÀ không chồng', () {
    test('khối đơn: nới cao cho đủ chữ (trước đây bị cắt)', () {
      // Khung gốc 1 dòng 56px nhưng bản dịch dài ⇒ phải cao lên.
      final out = layoutTranslatedBlocks(
        [
          _b(
            300,
            356,
            'Đây là bản dịch tiếng Việt dài hơn hẳn bản gốc nên khung phải '
            'cao lên để hiện đủ chữ, không được cắt bớt.',
          ),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(1));
      expect(out.single.hasTranslation, isTrue);
      expect(out.single.rect.top, 300, reason: 'giữ nguyên đỉnh gốc');
      expect(out.single.rect.height, greaterThan(56),
          reason: 'phải nới cao vì chữ dài hơn khung gốc');
      expect(_tooShort(out), isEmpty);
      expect(out.single.textSizeSp,
          greaterThanOrEqualTo(kOverlayMinReadableSp));
    });

    test('khối TRÊN giữ đủ chữ, khối DƯỚI bị ĐẨY xuống (không cắt chữ)', () {
      final out = layoutTranslatedBlocks(
        [
          _b(100, 156, 'Bản dịch thứ nhất dài hơn khung gốc của nó rất nhiều.'),
          _b(150, 206, 'Bản dịch thứ hai cũng dài, nằm sát khối trên.'),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(2));
      // Khối trên KHÔNG bị cắt ⇒ giữ đủ chiều cao cho chữ của nó.
      expect(_tooShort(out), isEmpty, reason: 'không được cắt chữ khối nào');
      // Và hai khối không chồng nhau ⇒ khối dưới đã bị đẩy xuống.
      expect(_overlaps(out), isEmpty);
      expect(out[1].rect.top, greaterThan(out[0].rect.top));
      expect(out[0].rect.bottom, lessThanOrEqualTo(out[1].rect.top));
    });

    test('nhiều khối dày đặc: không chồng + đủ chữ (ca như ảnh chụp)', () {
      final blocks = <ScreenBlock>[];
      var y = 200;
      for (var i = 0; i < 10; i++) {
        blocks.add(_b(
          y,
          y + 56,
          'Bản dịch tiếng Việt dài hơn khoảng một phẩy ba lần so với câu gốc '
          'số $i, nên cần thêm chỗ.',
        ));
        y += 64;
      }
      final out = layoutTranslatedBlocks(
        blocks,
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(10), reason: 'giữ nguyên số khối theo hợp đồng');
      expect(_overlaps(out), isEmpty, reason: 'KHÔNG được chồng khung');
      expect(_tooShort(out), isEmpty, reason: 'KHÔNG được cắt chữ');
      for (final block in out) {
        expect(block.textSizeSp, greaterThanOrEqualTo(kOverlayMinReadableSp),
            reason: 'không được bóp chữ nhỏ hơn sàn đọc được');
      }
    });

    test('khung HẸP được nới sang phải, không vượt khối bên phải', () {
      final out = layoutTranslatedBlocks(
        [
          _b(
            300,
            356,
            'Xin chào, bạn muốn học gì về tiếng Anh hôm nay vậy?',
            left: 60,
            right: 300,
          ),
          _b(300, 356, 'Cột phải có chữ riêng', left: 700, right: 1020),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(2));
      expect(out[0].rect.right, greaterThan(300),
          reason: 'khung hẹp phải được nới sang phải để bớt số dòng');
      expect(out[0].rect.right, lessThanOrEqualTo(700),
          reason: 'không được lấn sang khối bên phải');
      expect(_overlaps(out), isEmpty);
    });

    test('hai bbox OCR trùng nội dung ⇒ chỉ vẽ MỘT ô', () {
      final out = layoutTranslatedBlocks(
        [
          _b(100, 180, 'Cùng một dòng'),
          _b(110, 190, 'Cùng một dòng'),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(2), reason: 'giữ nguyên số khối');
      expect(out[0].hasTranslation, isTrue);
      expect(out[1].translation, isEmpty,
          reason: 'khối trùng bị loại khỏi vẽ (native bỏ qua)');
    });

    test('hai CỘT chữ cạnh nhau không bị đẩy/cắt nhầm', () {
      final out = layoutTranslatedBlocks(
        [
          _b(100, 156, 'Cột trái', left: 0, right: 300),
          _b(100, 156, 'Cột phải', left: 298, right: 600),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out[0].hasTranslation, isTrue);
      expect(out[1].hasTranslation, isTrue);
      expect(_overlaps(out, tolerancePx: 4), isEmpty,
          reason: 'bbox gốc đã giao 2px (OCR lệch); mức đó nằm trong padding');
      // Hai cột cùng hàng: không cái nào bị đẩy xuống xa.
      expect((out[1].rect.top - out[0].rect.top).abs(), lessThan(40));
    });

    test('khối dịch hỏng (rỗng) giữ nguyên để native bỏ qua', () {
      final out = layoutTranslatedBlocks(
        [
          _b(100, 156, 'Có dịch'),
          _b(300, 356, ''),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(2));
      expect(out[1].translation, isEmpty);
      expect(out[1].rect.top, 300, reason: 'khối rỗng không bị xê dịch');
    });

    test('frame giả trong test (màn < 200px) không áp ngưỡng thiết bị', () {
      final blocks = [_b(10, 30, 'A'), _b(20, 40, 'B')];
      final out = layoutTranslatedBlocks(
        blocks,
        screenWidth: 120,
        screenHeight: 80,
      );
      expect(out[0].rect.top, 10);
      expect(out[0].rect.bottom, 30);
      expect(out[1].rect.bottom, 40);
    });

    test('tràn đáy màn hình ⇒ bỏ vẽ khối vượt đáy (KHÔNG vẽ chữ cụt)', () {
      // 30 khối, mỗi khối cách 30px: bản dịch cần ~120px/khối ở cỡ chữ nhỏ
      // nhất ⇒ tổng vượt xa 2400px ⇒ buộc phải bỏ bớt (không thể vẽ đủ).
      final blocks = <ScreenBlock>[];
      var y = 100;
      for (var i = 0; i < 30; i++) {
        blocks.add(_b(
          y,
          y + 36,
          'Đây là bản dịch rất dài cho dòng số $i, dài gấp đôi bản gốc tiếng '
          'Anh để buộc thuật toán phải thu nhỏ hoặc bỏ bớt khi không còn chỗ '
          'trên màn hình.',
        ));
        y += 30;
      }
      final out = layoutTranslatedBlocks(
        blocks,
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(30), reason: 'giữ nguyên số khối');
      expect(_overlaps(out), isEmpty);
      expect(_tooShort(out), isEmpty,
          reason: 'khối nào còn vẽ thì phải hiện đủ chữ');
      // Số khối bị bỏ phải > 0 (chứng minh nhánh tràn có tác dụng) nhưng
      // không bỏ hết.
      final drawn = out.where((b) => b.hasTranslation).length;
      expect(drawn, greaterThan(0));
      expect(drawn, lessThan(30), reason: 'phải bỏ bớt khi không thể vẽ đủ');
      // Mọi khối còn vẽ phải nằm trong màn hình.
      for (final block in out) {
        if (!block.hasTranslation) continue;
        expect(block.rect.bottom, lessThanOrEqualTo(_screenH));
      }
    });

    test('không phụ thuộc thứ tự đầu vào: kết quả vẫn không chồng', () {
      final blocks = [
        _b(500, 556, 'Khối ba ở dưới'),
        _b(100, 156, 'Khối một ở trên'),
        _b(300, 356, 'Khối hai ở giữa'),
      ];
      final out = layoutTranslatedBlocks(
        blocks,
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(_overlaps(out), isEmpty);
      expect(_tooShort(out), isEmpty);
      expect(out, hasLength(3));
    });
  });
}
