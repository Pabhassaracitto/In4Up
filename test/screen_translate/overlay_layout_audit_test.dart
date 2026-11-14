// XLAT-SCR-006 (PSRC-190) — bong bóng dịch: KHUNG PHẢI ĐỦ CHỖ CHO CHỮ, và các
// khối vẫn KHÔNG được chồng lên nhau.
//
// Vì sao có test này (đọc để không đảo lại lần thứ tư):
//   • AUDIT-1.21.0 #1 sửa "chữ chồng nhau" bằng cách CẮT khung khối trên đúng
//     mép khối dưới ⇒ hết chồng nhưng bản dịch (VI dài hơn EN ~1.3×) hết chỗ,
//     native thu nhỏ tới 9sp rồi ellipsize ⇒ MẤT CHỮ.
//   • Bản sửa kế tiếp (nới rộng → nới cao → đẩy khối dưới) vẫn cấp thiếu chỗ
//     trên MÁY THẬT vì native vẽ bằng `TypedValue(SP)` = sp × density ×
//     **fontScale**, còn Dart chỉ nhân `density`. Máy bật cỡ chữ hệ thống lớn
//     (1.3–2.0×) ⇒ thiếu đúng bằng tỉ lệ đó ⇒ chữ bị cắt.
//
// Hợp đồng hiện tại — 6 bất biến, đo bằng ĐÚNG bộ ước lượng của layout:
//   1. KHÔNG hai khung nào giao nhau.
//   2. Khối CÒN VẼ thì khung CAO ĐỦ cho chính chuỗi nó vẽ (đúng `textSizeSp`).
//   3. Cỡ chữ không dưới `kOverlayMinReadableSp` (native kẹp cứng cùng sàn —
//      layout không bao giờ cấp khung đo theo cỡ nhỏ hơn, vì native sẽ bỏ).
//   4. Giữ NGUYÊN số khối + thứ tự.
//   5. Cùng bộ dữ liệu, tăng `fontScale` ⇒ không bao giờ có thêm khối bị cắt.
//   6. PSRC-211 vòng 2 — KHÔNG khối nào bị bỏ im lặng: hết chỗ thì
//      `collapsed = true` (chip), người dùng chạm chip để đọc đủ bản dịch.
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

/// Chip thu gọn (mục 3) đại diện cho MỘT khối: hai khối khác nhau không được
/// ra cùng một hình chip (lỗi "nhiều khối hoá một" khi bản trước ghim chip vào
/// đáy màn hình), và chip phải nằm gọn trong màn hình.
List<String> _chipProblems(List<ScreenBlock> blocks, {int screenHeight = 0}) {
  final bad = <String>[];
  final seen = <String, int>{};
  for (var i = 0; i < blocks.length; i++) {
    final chip = blocks[i];
    if (!chip.collapsed) continue;
    final key = '${chip.rect.left},${chip.rect.top},'
        '${chip.rect.right},${chip.rect.bottom}';
    final first = seen[key];
    if (first != null) {
      bad.add('#$i và #$first trùng hình chip (${chip.rect})');
    } else {
      seen[key] = i;
    }
    if (chip.rect.width <= 0 || chip.rect.height <= 0) {
      bad.add('#$i chip rỗng (${chip.rect})');
    }
    if (chip.rect.left < 0 || chip.rect.top < 0) {
      bad.add('#$i chip ngoài màn hình (${chip.rect})');
    }
    if (screenHeight > 0 && chip.rect.bottom > screenHeight) {
      bad.add('#$i chip vượt đáy màn hình (${chip.rect})');
    }
  }
  return bad;
}

/// Hai khung KHÔNG được giao nhau (tính cả cạnh chung).
///
/// [tolerancePx] dùng cho ca bbox OCR gốc đã giao nhau vài pixel (hai cột chữ
/// lệch 1–2px) — mức đó nằm trong padding nên không nhìn thấy, và layout cố ý
/// KHÔNG xê dịch toạ độ gốc của khối không liên quan.
List<String> _overlaps(List<ScreenBlock> blocks, {int tolerancePx = 0}) {
  final bad = <String>[];
  for (var i = 0; i < blocks.length; i++) {
    if (!blocks[i].isExpanded) continue;
    for (var j = i + 1; j < blocks.length; j++) {
      if (!blocks[j].isExpanded) continue;
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

/// Khung có ĐỦ cao cho chính chuỗi nó vẽ không (theo cùng bộ ước lượng, CÙNG
/// `fontScale` như native)?
List<String> _tooShort(
  List<ScreenBlock> blocks, {
  double fontScale = 1.0,
}) {
  final bad = <String>[];
  final pxPerSp = _dpr * effectiveOverlayFontScale(fontScale);
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    // Chip không vẽ chữ trong khung gốc ⇒ không đo theo nhu cầu bản dịch.
    if (!block.isExpanded) continue;
    final need = estimateTranslationTextHeightPx(
          block.translation,
          math.max(1.0, block.rect.width - 2 * kOverlayTextPaddingPx),
          block.textSizeSp * pxPerSp,
        ) +
        2 * kOverlayTextPaddingPx;
    final have = block.rect.height.toDouble();
    if (have + 0.5 < need) {
      bad.add('#$i cần ${need.toStringAsFixed(1)}px, có $have px '
          '(${block.translation.length} ký tự, ${block.textSizeSp} sp)');
    }
  }
  return bad;
}

/// Mọi khung còn vẽ phải nằm trong màn hình.
List<String> _outside(List<ScreenBlock> blocks, {int screenH = _screenH}) {
  final bad = <String>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    if (!block.hasTranslation) continue;
    // Chip được phép thò xuống dưới cùng của màn hình một chút khi khối gốc
    // nằm sát đáy (chip cao 20dp, native vẫn vẽ/bấm được); bong bóng đầy đủ
    // thì tuyệt đối không.
    final slack = block.collapsed ? (kOverlayChipHeightDp * _dpr).round() : 0;
    if (block.rect.top < 0 || block.rect.bottom > screenH + slack) {
      bad.add('#$i ${block.rect} ngoài màn hình cao $screenH');
    }
  }
  return bad;
}

/// Layout KHÔNG được sửa/bóp chữ: khối còn vẽ phải mang ĐÚNG bản dịch đầu vào
/// (không `…`, không cắt từ). Owner 2026-11-11: đọc nửa câu tệ hơn đọc chữ gốc.
List<String> _alteredText(
  List<ScreenBlock> input,
  List<ScreenBlock> output,
) {
  final bad = <String>[];
  for (var i = 0; i < output.length && i < input.length; i++) {
    final shown = output[i].translation;
    if (shown.isEmpty) continue; // khối bị bỏ vẽ
    if (shown != input[i].translation) {
      bad.add('#$i nội dung bị sửa: \'$shown\' ≠ \'${input[i].translation}\'');
    }
    if (shown.trim().endsWith('…')) bad.add('#$i vẫn còn bị ellipsize');
  }
  return bad;
}

void main() {
  group('PSRC-211 · mục 7.3 — không còn cấp khung đo theo `origHeight`', () {
    test('bản dịch ngắn hơn khối gốc ⇒ khung ÔM SÁT chữ, không giữ đáy trống',
        () {
      // Khối gốc cao 400px (đoạn nhiều dòng) nhưng bản dịch chỉ 1 dòng ngắn:
      // giữ sàn `origHeight` sẽ để lại khoảng trống rỗng bên dưới (đúng
      // triệu chứng "khung thừa khoảng trống" của PSRC-211).
      final out = layoutTranslatedBlocks(
        const <ScreenBlock>[
          ScreenBlock(
            rect: OverlayRect(left: 60, top: 300, right: 1020, bottom: 700),
            original: 'A long original paragraph',
            translation: 'Ngắn',
          ),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out.single.hasTranslation, isTrue);
      expect(out.single.rect.height, lessThan(400),
          reason: 'khung phải ôm sát bản dịch, không giữ chiều cao bbox OCR');
      expect(_tooShort(out), isEmpty, reason: 'nhưng vẫn đủ chỗ cho chữ');
    });
  });

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

    test('estimateTranslationMaxLines: kẹp theo chỗ thật, không vượt nhu cầu',
        () {
      const text = 'Một hai ba bốn năm sáu bảy tám chín mười';
      final needed =
          estimateTranslationLineCount(text, 200, 34);
      expect(estimateTranslationMaxLines(text, 200, 34, 10000), needed);
      expect(estimateTranslationMaxLines(text, 200, 34, 0), 0);
      expect(estimateTranslationMaxLines(text, 200, 34, 100), 2);
    });
  });

  group('Font scale (PSRC-190 — nguyên nhân gốc trên máy thật)', () {
    test('fontScale < 1 hoặc rác ⇒ coi là 1.0; > 2 ⇒ kẹp 2.0', () {
      expect(effectiveOverlayFontScale(0.85), 1.0);
      expect(effectiveOverlayFontScale(0), 1.0);
      expect(effectiveOverlayFontScale(double.nan), 1.0);
      expect(effectiveOverlayFontScale(1.3), closeTo(1.3, 1e-9));
      expect(effectiveOverlayFontScale(5), kOverlayMaxFontScale);
    });

    test('pxPerSp = density × fontScale (khớp TypedValue.applyDimension)', () {
      const metrics = OverlayFontMetrics(devicePixelRatio: 2.75, fontScale: 1.3);
      expect(metrics.pxPerSp, closeTo(3.575, 1e-9));
      expect(metrics.maxReadableLines(100), greaterThan(0));
    });

    test('máy bật cỡ chữ lớn ⇒ khung được cấp CAO HƠN (cùng một khối)', () {
      final blocks = <ScreenBlock>[
        _b(300, 356, 'Đây là bản dịch tiếng Việt dài hơn hẳn bản gốc.'),
      ];
      final normal = layoutTranslatedBlocks(
        blocks,
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      ).single;
      final large = layoutTranslatedBlocks(
        blocks,
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
        fontScale: 2.0,
      ).single;
      expect(large.rect.height, greaterThan(normal.rect.height),
          reason: 'Quên fontScale ⇒ đây là lý do chữ bị cắt trên máy thật.');
      expect(_tooShort([large], fontScale: 2.0), isEmpty);
    });

    test('payload native thiếu fontScale vẫn đọc được (mặc định 1.0)', () {
      final geometry = ScreenCaptureGeometry.fromMap(<Object?, Object?>{
        'width': 1080,
        'height': 2400,
        'devicePixelRatio': 2.75,
      });
      expect(geometry.fontScale, 1.0);
      expect(geometry.toMap()['fontScale'], 1.0);
    });

    test('payload native có fontScale ⇒ đọc đúng', () {
      final geometry = ScreenCaptureGeometry.fromMap(<Object?, Object?>{
        'width': 1080,
        'height': 2400,
        'devicePixelRatio': 2.75,
        'fontScale': 1.3,
      });
      expect(geometry.fontScale, closeTo(1.3, 1e-9));
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

    test('khối đơn sát đáy: DỊCH khung lên, KHÔNG cắt chữ', () {
      final out = layoutTranslatedBlocks(
        [
          _b(
            _screenH - 90,
            _screenH - 34,
            'Bản dịch dài nằm sát đáy màn hình nên nếu không dịch khung lên '
            'thì chữ sẽ bị cắt mất phần dưới.',
          ),
        ],
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
      );
      expect(out, hasLength(1));
      expect(out.single.hasTranslation, isTrue);
      expect(out.single.rect.bottom, lessThanOrEqualTo(_screenH));
      expect(_tooShort(out), isEmpty, reason: 'dịch khung lên, không cắt chữ');
      expect(_outside(out), isEmpty);
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
        if (!block.hasTranslation) continue;
        expect(block.textSizeSp, greaterThanOrEqualTo(kOverlayMinReadableSp),
            reason: 'không được bóp chữ nhỏ hơn sàn đọc được');
      }
    });

    test('CỠ CHỮ HỆ THỐNG LỚN (fontScale 1.3/2.0): vẫn đủ chỗ, không chồng',
        () {
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
      for (final fontScale in <double>[1.3, 1.6, 2.0]) {
        final out = layoutTranslatedBlocks(
          blocks,
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
          fontScale: fontScale,
        );
        expect(out, hasLength(10));
        expect(_overlaps(out), isEmpty, reason: 'fontScale $fontScale');
        expect(_tooShort(out, fontScale: fontScale), isEmpty,
            reason: 'fontScale $fontScale — chữ không được vượt khung');
        expect(_outside(out), isEmpty, reason: 'fontScale $fontScale');
        // Không được "trắng trơn": phải còn khối đọc được (owner 2026-11-11).
        expect(out.where((b) => b.hasTranslation), isNotEmpty,
            reason: 'fontScale $fontScale — bỏ hết khối là mất bản dịch');
        expect(_alteredText(blocks, out), isEmpty);
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
      expect(_tooShort(out), isEmpty);
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
      final drawn = out.where((b) => b.hasTranslation).length;
      expect(drawn, 1, reason: 'khối trùng bị loại, không vẽ hai lần');
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

    test('tràn đáy màn hình (30 khối) ⇒ KHÔNG chồng, KHÔNG chữ cụt', () {
      // 30 khối, mỗi khối cách 30px: bản dịch cần ~120px/khối ở cỡ chữ nhỏ
      // nhất ⇒ tổng vượt xa 2400px. Từ PSRC-211 vòng 2, khối không còn chỗ
      // KHÔNG bị bỏ nữa mà thành CHIP (mục 3) — người dùng chạm chip để đọc đủ.
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
          reason: 'khối nào còn vẽ thì phải hiện đủ chữ của chính nó');
      expect(_alteredText(blocks, out), isEmpty,
          reason: 'không được cắt/bóp nội dung — chỉ được bỏ khối');
      expect(_outside(out), isEmpty);
      // Không còn đường nào bỏ khối im lặng: khối không đủ chỗ thành chip.
      expect(out.where((b) => !b.hasTranslation), isEmpty,
          reason: 'mỗi khối phải có đầu ra (bong bóng hoặc chip)');
      final collapsed = out.where((b) => b.collapsed).length;
      expect(collapsed, greaterThan(0),
          reason: 'nhánh tràn phải thật sự chạy (nếu không test vô nghĩa)');
      final drawn = out.where((b) => b.isExpanded).length;
      expect(drawn, greaterThan(0));
      for (final block in out) {
        if (!block.hasTranslation) continue;
        expect(block.textSizeSp, greaterThanOrEqualTo(kOverlayMinReadableSp));
      }
      // Màn hình cực dày: chip phải phân biệt được (không dồn về một toạ độ),
      // nằm trong màn hình, và KHÔNG đè lên khung chữ dịch của khối khác —
      // nếu đè thì người dùng mất nội dung của khối kia, đúng lỗi PSRC-211.
      expect(_chipProblems(out, screenHeight: _screenH), isEmpty);
    });

    test('tràn đáy + cỡ chữ hệ thống rất lớn: vẫn còn khối đọc được', () {
      final blocks = <ScreenBlock>[];
      var y = 100;
      for (var i = 0; i < 30; i++) {
        blocks.add(_b(
          y,
          y + 36,
          'Đây là bản dịch rất dài cho dòng số $i, dài gấp đôi bản gốc tiếng '
          'Anh để buộc thuật toán phải thu nhỏ hoặc bỏ bớt.',
        ));
        y += 30;
      }
      final out = layoutTranslatedBlocks(
        blocks,
        screenWidth: _screenW,
        screenHeight: _screenH,
        devicePixelRatio: _dpr,
        fontScale: 2.0,
      );
      expect(_overlaps(out), isEmpty);
      expect(_tooShort(out, fontScale: 2.0), isEmpty);
      final drawn = out.where((b) => b.hasTranslation).toList();
      expect(drawn, isNotEmpty,
          reason: 'chia ngân sách đều mà bỏ sạch thì phải lùi về "lấp từ trên"');
      for (final block in drawn) {
        // Native kẹp cứng `MIN_READABLE_SP = 10f` ⇒ Dart cũng không được cấp
        // khung nào đo theo cỡ nhỏ hơn (khung đó sẽ bị native bỏ).
        expect(block.textSizeSp,
            greaterThanOrEqualTo(kOverlayMinReadableSp));
      }
    });

    test('KHÔNG rút gọn chữ: khối không vừa thì BỎ VẼ/chip, không thêm `…`', () {
      // Owner 2026-11-11: "không vẽ chữ cụt". Trước đây (bản thử) nhánh tràn
      // cắt bớt chữ theo từ rồi thêm `…` ⇒ vi phạm hợp đồng này. PSRC-211 vòng
      // 2 thay "bỏ vẽ" bằng CHIP, nhưng chip vẫn KHÔNG cắt chữ: nhãn chip do
      // native vẽ, `translation` luôn nguyên vẹn.
      final blocks = <ScreenBlock>[];
      var y = 100;
      for (var i = 0; i < 30; i++) {
        blocks.add(_b(
          y,
          y + 36,
          'Bản dịch rất dài cho dòng $i để chắc chắn tràn màn hình.',
        ));
        y += 30;
      }
      for (final fontScale in <double>[1.0, 2.0]) {
        final out = layoutTranslatedBlocks(
          blocks,
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
          fontScale: fontScale,
        );
        expect(out.where((b) => b.translation.contains('…')), isEmpty,
            reason: 'fontScale $fontScale — layout không được chèn dấu cắt chữ');
        expect(_alteredText(blocks, out), isEmpty,
            reason: 'fontScale $fontScale');
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
      // Thứ tự danh sách = thứ tự đầu vào (native ghép theo index).
      expect(out[0].original, 'original');
      expect(out[1].rect.top, lessThan(out[2].rect.top));
    });

    // ── PSRC-211 vòng 2 · mục 3 — font scale 2.0× KHÔNG còn bỏ khối ──────
    group('PSRC-211 vòng 2 — chip thu gọn thay cho bỏ khối', () {
      /// Fixture "màn hình dày chữ, khung thấp": 10 khối sát nhau (đúng ca
      /// owner báo: font scale 2.0× làm 2/10 khối không còn chỗ).
      List<ScreenBlock> denseScreen() {
        final blocks = <ScreenBlock>[];
        var y = 180;
        for (var i = 0; i < 10; i++) {
          blocks.add(_b(
            y,
            y + 48,
            'Bản dịch cho dòng số $i dài hơn bản gốc tiếng Anh khoảng một '
            'phẩy ba lần nên cần thêm chỗ.',
          ));
          y += 52;
        }
        return blocks;
      }

      test('fontScale 2.0: slots == blocks và KHÔNG khối nào bị bỏ', () {
        final blocks = denseScreen();
        final out = layoutTranslatedBlocks(
          blocks,
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
          fontScale: 2.0,
        );
        expect(out, hasLength(blocks.length),
            reason: 'không được bỏ khối khỏi danh sách');
        expect(
          out.where((b) => !b.hasTranslation),
          isEmpty,
          reason: 'mỗi khối OCR phải có đầu ra: bong bóng đầy đủ hoặc chip',
        );
        expect(out.where((b) => b.collapsed), isNotEmpty,
            reason: 'fixture này phải thật sự chạm nhánh thu gọn (nếu không, '
                'test không chứng minh được gì)');
        expect(_chipProblems(out, screenHeight: _screenH), isEmpty,
            reason: 'mỗi khối thu gọn phải có một chip RIÊNG, đúng chỗ');
      });

      test('fontScale 1.0 cùng fixture: KHÔNG có chip (không hồi quy)', () {
        final out = layoutTranslatedBlocks(
          denseScreen(),
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
        );
        expect(out.where((b) => b.collapsed), isEmpty,
            reason: 'chế độ thu gọn chỉ được bật khi thật sự hết chỗ');
        expect(out.every((b) => b.hasTranslation), isTrue);
      });

      test('chip giữ NGUYÊN bản dịch (popup đọc đủ, không cắt chữ)', () {
        final blocks = denseScreen();
        final out = layoutTranslatedBlocks(
          blocks,
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
          fontScale: 2.0,
        );
        for (var i = 0; i < out.length; i++) {
          expect(out[i].translation, blocks[i].translation,
              reason: 'layout không được sửa/cắt nội dung của bất kỳ khối nào');
        }
        for (final chip in out.where((b) => b.collapsed)) {
          expect(chip.textSizeSp, greaterThanOrEqualTo(kOverlayMinReadableSp));
          expect(chip.rect.width, greaterThan(0));
          expect(chip.rect.height, greaterThan(0));
        }
      });

      test('chip CHẠM ĐƯỢC: collapsedBlockAt trả đúng khối theo toạ độ', () {
        final out = layoutTranslatedBlocks(
          denseScreen(),
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
          fontScale: 2.0,
        );
        final chip = out.firstWhere((b) => b.collapsed);
        final hit = collapsedBlockAt(
          out,
          (chip.rect.left + chip.rect.right) ~/ 2,
          (chip.rect.top + chip.rect.bottom) ~/ 2,
        );
        expect(hit, isNotNull, reason: 'tâm chip phải trả về chính chip đó');
        expect(hit!.rect, chip.rect);
        expect(collapsedBlockAt(out, 0, 0), isNull,
            reason: 'góc trên-trái màn hình không có chip nào');
      });

      test('chip neo đúng góc trên-phải khối GỐC (không dồn về một chỗ)',
          () {
        final blocks = denseScreen();
        final out = layoutTranslatedBlocks(
          blocks,
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
          fontScale: 2.0,
        );
        final chips = <int>[
          for (var i = 0; i < out.length; i++)
            if (out[i].collapsed) i,
        ];
        expect(chips, isNotEmpty);
        for (final i in chips) {
          final src = blocks[i].rect;
          final chip = out[i].rect;
          // Cạnh phải trùng cạnh phải khối gốc ⇒ chip nằm ở góc trên-phải, và
          // vì không dời sang khối khác nên nó không đè khung dịch bên cạnh.
          expect(chip.right, src.right,
              reason: 'chip phải neo vào mép phải khối gốc');
          // Chip nằm TRỌN trong bề ngang khối gốc (không thò sang khối bên).
          expect(chip.left, greaterThanOrEqualTo(src.left));
          // Đỉnh: ngay chỗ khối gốc bắt đầu, hoặc thấp hơn nếu phải né khối
          // phía trên đã đặt — KHÔNG BAO GIỜ vượt lên trên khối gốc.
          expect(chip.top, greaterThanOrEqualTo(src.top));
          // …và vẫn nằm trong khối gốc theo chiều dọc (không nhảy xuống khối
          // khác). Chip cao 20dp nên với khung gốc thấp hơn 20dp nó được phép
          // thò xuống dưới đáy khối, nhưng không quá chiều cao của chính nó.
          expect(chip.top, lessThanOrEqualTo(src.bottom));
          final chipHeight = (kOverlayChipHeightDp * _dpr).round();
          expect(chip.bottom - chip.top, chipHeight,
              reason: 'chip phải đúng cỡ `overlayChipSize` (native vẽ cùng số)');
          expect(chip.width, (kOverlayChipWidthDp * _dpr).round());
          // Chip hẹp hơn khối gốc ⇒ phần lớn chữ gốc vẫn đọc được.
          expect(chip.width, lessThan(src.width));
        }
        // Không hai khối nào bị "hoá" thành cùng một chip.
        expect(_chipProblems(out, screenHeight: _screenH), isEmpty);
      });

      test('payload: chỉ khối thu gọn mới có khoá `collapsed`', () {
        final out = layoutTranslatedBlocks(
          denseScreen(),
          screenWidth: _screenW,
          screenHeight: _screenH,
          devicePixelRatio: _dpr,
          fontScale: 2.0,
        );
        final chip = out.firstWhere((b) => b.collapsed);
        expect(chip.toMap()['collapsed'], isTrue);
        expect(chip.hasTranslation, isTrue);
        expect(chip.isExpanded, isFalse);
        final expanded = out.where((b) => b.isExpanded).toList();
        if (expanded.isNotEmpty) {
          expect(expanded.first.toMap().containsKey('collapsed'), isFalse,
              reason: 'payload giữ nguyên 7 khoá cũ khi không thu gọn');
        }
      });
    });

    test('countOverlappingPairs: công cụ đo dùng chung với native test', () {
      expect(
        countOverlappingPairs([
          _b(100, 200, 'A'),
          _b(150, 250, 'B'),
        ]),
        1,
      );
      expect(countOverlappingPairs([_b(100, 200, 'A'), _b(300, 400, 'B')]), 0);
      expect(
        countOverlappingPairs([_b(100, 200, 'A'), _b(150, 250, '')]),
        0,
        reason: 'khối không vẽ thì không tính là chồng',
      );
    });
  });
}
