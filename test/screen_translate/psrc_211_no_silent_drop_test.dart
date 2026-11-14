// PSRC-211 vòng 2 (hub 2026-11-13, `docs/project/beta-1.29.0/L4-hub-tra-loi.md`)
// — KHÔNG KHỐI CHỮ NÀO BỊ BỎ IM LẶNG.
//
// Mỗi khối OCR có bản dịch phải ra đúng MỘT trong ba thứ:
//   • khung vẽ tại chỗ, đủ chữ (≥ 10sp, không cắt, không "…");
//   • chip THU GỌN chạm được — bản dịch nguyên vẹn nằm trong popup (§ 3);
//   • nằm trong hàng CHỜ "Còn N khối · Dịch tiếp" khi vượt trần 32 khối/lượt
//     (§ 4).
//
// Hai đường làm mất khối mà vòng 1 còn để lại, và test nào khoá nó:
//   A. Cỡ chữ hệ thống 2.0× trên màn hình dày chữ: layout hết chỗ ⇒ khối bị bỏ
//      vẽ (`translation` rỗng) ⇒ người dùng không biết có chữ chưa dịch.
//      → nhóm "§ 3".
//   B. Hơn 32 khối: `selectBlocksToTranslate` `take(32)` rồi vứt phần dư.
//      → nhóm "§ 4".
//
// Kèm theo (bảng quyết định #3 của hub): phép cộng lề hệ thống với lề giả
// 0 / 24 / 48 dp, màn dọc + ngang.
//
// Test THUẦN trên host VM — không cần thiết bị / MediaProjection.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_block.dart';
import 'package:in4up/features/ocr/ocr_service.dart';
import 'package:in4up/features/screen_translate/screen_translate_channel.dart';
import 'package:in4up/features/screen_translate/screen_translate_controller.dart';
import 'package:in4up/features/screen_translate/screen_translate_geometry.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/screen_translate/screen_translate_overlay_layout.dart';
import 'package:in4up/features/translation/engines/translation_engine.dart';

const double _dpr = 2.75; // Pixel 7 kiểu
const int _screenW = 1080;
const int _screenH = 2400;

/// Ảnh chụp bằng nửa màn hình (như service thu nhỏ khi cạnh dài > 1280).
const int _captureScale = 2;

/// Tám locale ưu tiên mà chuỗi UI mới PHẢI có bản dịch (README lane § 4).
const List<String> _priorityLocales = <String>[
  'en',
  'hi',
  'zh',
  'zh_TW',
  'si',
  'my',
  'th',
  'ja',
];

ScreenBlock _b(
  int top,
  int bottom,
  String translation, {
  int left = 60,
  int right = 1020,
}) {
  return ScreenBlock(
    rect: OverlayRect(left: left, top: top, right: right, bottom: bottom),
    original: 'original $top',
    translation: translation,
    textSizeSp: 14,
  );
}

/// Màn hình DÀY CHỮ, khung THẤP: 12 hàng danh sách cao 60px (≈ 22dp), cách
/// nhau 12px, dồn về nửa dưới màn hình. Ở cỡ chữ 1.0× mỗi bản dịch vừa một
/// dòng trong hàng của nó; ở 2.0× mỗi bản dịch cần ~160px ⇒ 12 hàng cần gấp
/// đôi chỗ còn lại trên màn hình.
List<ScreenBlock> _denseScreen() => <ScreenBlock>[
      for (var i = 0; i < 12; i++)
        _b(
          1500 + i * 72,
          1560 + i * 72,
          'Dòng dịch số ${i + 1} của màn hình dày chữ',
        ),
    ];

List<ScreenBlock> _layout(List<ScreenBlock> blocks, {double fontScale = 1.0}) =>
    layoutTranslatedBlocks(
      blocks,
      screenWidth: _screenW,
      screenHeight: _screenH,
      devicePixelRatio: _dpr,
      fontScale: fontScale,
    );

bool _intersects(OverlayRect a, OverlayRect b) =>
    a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;

OcrBlock _ocr(
  String text, {
  required int left,
  required int top,
  int width = 200,
  int height = 24,
}) =>
    OcrBlock(
      text: text,
      rect: OcrBlockRect(
        left: left,
        top: top,
        right: left + width,
        bottom: top + height,
      ),
    );

/// Chữ của khối thứ [number] (từ 1) trong [_ocrGrid]. Số luôn 2 chữ số ⇒ mọi
/// khối CÙNG độ dài, cùng kích thước ⇒ "độ đáng dịch" hoà nhau và lượt đầu lấy
/// đúng 32 khối ĐẦU theo thứ tự đọc.
String _entry(int number) =>
    'Settings entry number ${number.toString().padLeft(2, '0')}.';

/// [count] khối OCR xếp 2 cột trên ảnh chụp 540×1200; chữ mỗi khối kết thúc
/// bằng dấu chấm ⇒ không khối nào bị gộp thành đoạn văn với khối bên dưới.
List<OcrBlock> _ocrGrid(int count) => <OcrBlock>[
      for (var i = 0; i < count; i++)
        _ocr(
          _entry(i + 1),
          left: i.isEven ? 20 : 290,
          top: 20 + (i ~/ 2) * 30,
        ),
    ];

Map<Object?, Object?> _frame() {
  const captureW = _screenW ~/ _captureScale;
  const captureH = _screenH ~/ _captureScale;
  return <Object?, Object?>{
    'pixels': Uint8List(captureW * captureH * 4),
    'width': captureW,
    'height': captureH,
    'rowStride': captureW * 4,
    'screenWidth': _screenW,
    'screenHeight': _screenH,
    'devicePixelRatio': _dpr,
    'fontScale': 1.0,
    'targetLanguage': 'VI',
    'locale': 'en',
  };
}

ScreenTranslateController _controller(
  List<OcrBlock> screen, {
  List<String>? seen,
  String localeCode = 'en',
  bool Function(String text)? fails,
}) {
  return ScreenTranslateController(
    localeCode: localeCode,
    ocrRunner: ({
      required Uint8List pixels,
      required int width,
      required int height,
    }) async =>
        OcrBlocksResult(blocks: screen),
    translator: (text, target) async {
      seen?.add(text);
      if (fails != null && fails(text)) {
        throw StateError('engine hỏng (giả lập)');
      }
      return TranslationResult.success(
        original: text,
        translated: 'VI: $text',
        engine: 'fake-engine',
      );
    },
  );
}

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('§ 3 — cỡ chữ 2.0×: thu gọn thành chip, KHÔNG bỏ khối', () {
    test('màn hình dày chữ ở fontScale 2.0: đủ số khối, 0 khối bị bỏ', () {
      final blocks = _denseScreen();
      final out = _layout(blocks, fontScale: 2.0);

      expect(out.length, blocks.length, reason: 'mỗi khối vào ⇒ một khối ra');
      for (var i = 0; i < blocks.length; i++) {
        expect(
          out[i].translation,
          blocks[i].translation,
          reason: 'khối #$i bị bỏ (translation rỗng) hoặc bị sửa chữ — trước '
              'vòng 2 khối hết chỗ bị bỏ vẽ im lặng',
        );
        expect(out[i].original, blocks[i].original, reason: 'giữ thứ tự khối');
      }
      final inPlace = out.where((b) => b.isShownInPlace).length;
      final collapsed = out.where((b) => b.collapsed).length;
      expect(inPlace + collapsed, blocks.length,
          reason: 'mỗi khối: hoặc khung đủ chữ, hoặc chip — không có nhánh ba');
      expect(inPlace, greaterThan(0), reason: 'không thu gọn sạch cả màn hình');
      expect(countOverlappingPairs(out), 0,
          reason: 'khung và chip không được đè lên nhau');
    });

    test('cùng màn hình đó ở 2.0×: có chip thu gọn, chip hợp lệ', () {
      final blocks = _denseScreen();
      final out = _layout(blocks, fontScale: 2.0);
      final chips = out.where((b) => b.collapsed).toList();
      final boxes = out.where((b) => b.isShownInPlace).toList();

      expect(chips, isNotEmpty,
          reason: '12 hàng × ~160px không thể vừa nửa màn hình ⇒ phải có '
              'khối thu gọn (nếu rỗng: fixture không còn ép được nhánh chip)');

      final minW = (20 * _dpr).floor();
      final minH = (14 * _dpr).floor();
      for (final chip in chips) {
        // Sàn kích thước của hub: ≈ 20×14 dp.
        expect(chip.rect.width, greaterThanOrEqualTo(minW));
        expect(chip.rect.height, greaterThanOrEqualTo(minH));
        // Trong màn hình.
        expect(chip.rect.left, greaterThanOrEqualTo(0));
        expect(chip.rect.top, greaterThanOrEqualTo(0));
        expect(chip.rect.right, lessThanOrEqualTo(_screenW));
        expect(chip.rect.bottom, lessThanOrEqualTo(_screenH));
        // Bản dịch đi kèm NGUYÊN VẸN — popup hiện đủ chữ, không "…".
        expect(chip.hasTranslation, isTrue);
        expect(chip.translation.contains('…'), isFalse);
        expect(chip.textSizeSp, greaterThanOrEqualTo(kOverlayMinReadableSp));
        // Chip không mang khoá ôm-sát của khung thường.
        expect(chip.coverBottom, isNull);
        expect(chip.maxTextSizeSp, isNull);
        expect(chip.toMap()['collapsed'], isTrue);
        // Không che khung nào đang vẽ.
        for (final box in boxes) {
          expect(_intersects(chip.rect, box.rect), isFalse,
              reason: 'chip ${chip.rect} đè lên khung ${box.rect}');
        }
      }
      // Khung thường: luật 10sp vẫn giữ, payload KHÔNG có khoá `collapsed`.
      for (final box in boxes) {
        expect(box.textSizeSp, greaterThanOrEqualTo(kOverlayMinReadableSp));
        expect(box.toMap().containsKey('collapsed'), isFalse);
      }
    });

    test('cùng màn hình đó ở 1.0×: KHÔNG khối nào bị thu gọn', () {
      final blocks = _denseScreen();
      final out = _layout(blocks);

      expect(out.length, blocks.length);
      expect(out.where((b) => b.collapsed), isEmpty,
          reason: 'chip là phương án CUỐI — đủ chỗ thì phải vẽ tại chỗ');
      expect(out.where((b) => b.isShownInPlace).length, blocks.length);
      expect(countOverlappingPairs(out), 0);
    });

    test('hit-test: điểm chạm trên chip ⇒ đúng khối; ngoài chip ⇒ null', () {
      final blocks = _denseScreen();
      final out = _layout(blocks, fontScale: 2.0);
      final chips = out.where((b) => b.collapsed).toList();
      expect(chips, isNotEmpty);

      for (final chip in chips) {
        final r = chip.rect;
        // Giữa chip.
        expect(
          collapsedBlockAt(out, (r.left + r.right) ~/ 2, (r.top + r.bottom) ~/ 2),
          same(chip),
        );
        // Cạnh trái/trên TÍNH; cạnh phải/dưới KHÔNG (khớp cửa sổ chạm native).
        expect(collapsedBlockAt(out, r.left, r.top), same(chip));
        expect(collapsedBlockAt(out, r.right - 1, r.bottom - 1), same(chip));
        expect(collapsedBlockAt(out, r.right, r.top), isNot(same(chip)));
        expect(collapsedBlockAt(out, r.left, r.bottom), isNot(same(chip)));
      }

      // Chạm vào khung dịch thường / chỗ trống ⇒ không mở popup nào (cú chạm
      // rơi xuống app bên dưới).
      final box = out.firstWhere((b) => b.isShownInPlace);
      expect(
        collapsedBlockAt(out, box.rect.left + 1, box.rect.top + 1),
        isNull,
      );
      expect(collapsedBlockAt(out, 2, 2), isNull);
      expect(collapsedBlockAt(const <ScreenBlock>[], 10, 10), isNull);
    });

    test('khối ĐƠN không vừa màn hình ⇒ chip ở góc trên-phải chữ gốc', () {
      // Màn hình thấp 400px, bản dịch ~2.000 ký tự: không cỡ chữ ≥ 10sp nào
      // vừa. Trước đây khối này bị bỏ vẽ (`translation: ''`).
      final long = List<String>.generate(
        400,
        (i) => 'chữ$i',
      ).join(' ');
      final block = _b(100, 156, long);
      final out = layoutTranslatedBlocks(
        <ScreenBlock>[block],
        screenWidth: _screenW,
        screenHeight: 400,
        devicePixelRatio: _dpr,
      );

      expect(out, hasLength(1));
      final chip = out.single;
      expect(chip.collapsed, isTrue);
      expect(chip.translation, long, reason: 'bản dịch nguyên vẹn cho popup');
      expect(
        chip.rect.toMap(),
        collapsedChipRect(
          block.rect,
          devicePixelRatio: _dpr,
          screenWidth: _screenW,
          screenHeight: 400,
        ).toMap(),
      );
      expect(chip.rect.right, block.rect.right, reason: 'góc PHẢI chữ gốc');
      expect(chip.rect.top, block.rect.top, reason: 'góc TRÊN chữ gốc');
      expect(collapsedBlockAt(out, chip.rect.left, chip.rect.top), same(chip));
    });

    test('payload: `collapsed` đi qua toMap/fromMap; khối thường giữ 7 khoá', () {
      final chip = _layout(_denseScreen(), fontScale: 2.0)
          .firstWhere((b) => b.collapsed);
      final restored = ScreenBlock.fromMap(chip.toMap());
      expect(restored, isNotNull);
      expect(restored!.collapsed, isTrue);
      expect(restored.isShownInPlace, isFalse);
      expect(restored.translation, chip.translation);
      expect(restored.rect.toMap(), chip.rect.toMap());

      const plain = ScreenBlock(
        rect: OverlayRect(left: 0, top: 0, right: 10, bottom: 10),
        original: 'a',
        translation: 'b',
      );
      expect(plain.collapsed, isFalse);
      expect(plain.isShownInPlace, isTrue);
      expect(plain.toMap().keys.toSet(), <String>{
        'left',
        'top',
        'right',
        'bottom',
        'original',
        'translation',
        'textSizeSp',
      });
      expect(ScreenBlock.fromMap(plain.toMap())!.collapsed, isFalse);
    });
  });

  group('khung không đè nhau — hai HÀNG khác nhau giao ngang một dải hẹp', () {
    // Lỗi có từ trước lane (ngưỡng "cùng cột" 25%): khối hàng trên và khối
    // hàng dưới chỉ giao ngang một dải hẹp ⇒ bị coi là hai cột độc lập ⇒ khối
    // trên cao thêm vài pixel là đè lên khối dưới ngay trên dải chung đó.
    //
    //   hàng 1 (chữ nhỏ, cao 30px):  [60 ───────────── 600]
    //   hàng 2 (cách 10px):                        [540 ─────────── 1020]
    //
    // Chữ gốc hàng 1 nhỏ hơn sàn 10sp ⇒ bản dịch (vẽ ở 10sp) cần ≥ ~44px, tức
    // dài quá đỉnh hàng 2 (340) — ở MỌI cỡ chữ hệ thống.
    List<ScreenBlock> staggered() => <ScreenBlock>[
          _b(300, 330, 'Chú thích chữ nhỏ ở hàng trên', left: 60, right: 600),
          _b(340, 440, 'Khối bên phải ở hàng dưới', left: 540, right: 1020),
          _b(460, 520, 'Hàng thứ ba bình thường'),
        ];

    for (final fontScale in <double>[1.0, 1.15, 1.3, 2.0]) {
      test('fontScale $fontScale: khối dưới nhường chỗ, không khung nào đè nhau',
          () {
        final blocks = staggered();
        final out = _layout(blocks, fontScale: fontScale);

        expect(out, hasLength(3));
        expect(out.every((b) => b.isShownInPlace), isTrue,
            reason: 'màn hình thoáng — không khối nào phải thu gọn');
        expect(countOverlappingPairs(out), 0,
            reason: 'khung hàng trên ${out[0].rect} đè khung hàng dưới '
                '${out[1].rect}');

        final upper = out[0].rect;
        final lower = out[1].rect;
        expect(upper.top, 300, reason: 'khối trên giữ nguyên đỉnh');
        expect(upper.height, greaterThan(40),
            reason: 'fixture phải ép khối trên dài quá đỉnh khối dưới (340); '
                'nếu không thì test này không còn khoá được lỗi');
        // Hai khung còn giao ngang ⇒ khối dưới phải nằm HẲN dưới khối trên.
        if (lower.left < upper.right && upper.left < lower.right) {
          expect(lower.top, greaterThanOrEqualTo(upper.bottom));
        }
        expect(lower.top, greaterThanOrEqualTo(340),
            reason: 'không kéo khối dưới LÊN trên chữ gốc của nó');
      });
    }

    test('hai khối CÙNG HÀNG giao vài pixel (OCR lệch) vẫn nằm cạnh nhau', () {
      // Luật mới chỉ áp cho hai hàng KHÁC nhau; hai cột cùng hàng mà bị xếp
      // chồng thì cột phải rơi xuống dưới cột trái — sai vị trí.
      final out = _layout(<ScreenBlock>[
        _b(100, 156, 'Cột trái', left: 0, right: 300),
        _b(100, 156, 'Cột phải', left: 298, right: 600),
      ]);
      expect(out.every((b) => b.isShownInPlace), isTrue);
      expect(out[0].rect.top, 100);
      expect(out[1].rect.top, 100);
    });
  });

  group('§ 4 — trần 32 khối: phần dư CHỜ "Dịch tiếp", không bị bỏ', () {
    test('70 khối ⇒ 32 chọn + 38 chờ, giữ thứ tự đọc, không trùng', () {
      final blocks = <OcrBlock>[
        for (var i = 0; i < 70; i++)
          _ocr(
            'khối ${i.toString().padLeft(2, '0')}',
            left: 10,
            top: i * 30,
            // Kích thước xáo trộn để "khối to nhất" KHÔNG trùng thứ tự đọc.
            width: 60 + (i * 37) % 200,
          ),
      ];
      final selection =
          selectBlocksToTranslate(blocks, kScreenTranslateMaxBlocks);

      expect(kScreenTranslateMaxBlocks, 32, reason: 'hub: KHÔNG nâng trần');
      expect(selection.selected, hasLength(32));
      expect(selection.pending, hasLength(38));

      List<int> indexOf(List<OcrBlock> list) =>
          <int>[for (final b in list) blocks.indexOf(b)];
      final selected = indexOf(selection.selected);
      final pending = indexOf(selection.pending);
      List<int> sorted(List<int> list) => List<int>.of(list)..sort();

      expect(selected, sorted(selected), reason: 'lượt này giữ thứ tự đọc');
      expect(pending, sorted(pending), reason: 'phần chờ giữ thứ tự đọc');
      expect(selected.toSet().intersection(pending.toSet()), isEmpty,
          reason: 'không khối nào vừa được chọn vừa chờ');
      expect(
        <int>{...selected, ...pending},
        <int>{for (var i = 0; i < 70; i++) i},
        reason: 'chọn ∪ chờ = TOÀN BỘ khối — không mất khối nào',
      );
    });

    test('vùng nhìn phủ nửa trên ⇒ khối trong vùng nhìn được chọn trước', () {
      // 35 khối NHỎ ở nửa trên + 35 khối TO ở nửa dưới. Không có vùng nhìn thì
      // 32 khối to (nửa dưới) thắng; có vùng nhìn = nửa trên thì ngược lại.
      final blocks = <OcrBlock>[
        for (var i = 0; i < 35; i++)
          _ocr('trên $i', left: 10, top: i * 16, width: 40, height: 12),
        for (var i = 0; i < 35; i++)
          _ocr(
            'dưới $i — nội dung chính rất dài',
            left: 10,
            top: 600 + i * 16,
            width: 500,
            height: 14,
          ),
      ];
      const topHalf = OcrBlockRect(left: 0, top: 0, right: 540, bottom: 600);

      final byWeight = selectBlocksToTranslate(blocks, 32);
      expect(
        byWeight.selected.every((b) => b.text.startsWith('dưới')),
        isTrue,
        reason: 'không có vùng nhìn ⇒ xếp theo diện tích × độ dài chữ',
      );

      final byViewport = selectBlocksToTranslate(blocks, 32, viewport: topHalf);
      expect(byViewport.selected, hasLength(32));
      expect(
        byViewport.selected.every((b) => b.text.startsWith('trên')),
        isTrue,
        reason: 'khối người dùng ĐANG NHÌN phải được dịch trước khối to hơn '
            'nằm ngoài vùng nhìn',
      );
      expect(byViewport.pending, hasLength(38));
      expect(
        byViewport.pending.where((b) => b.text.startsWith('trên')),
        hasLength(3),
      );

      // Vùng nhìn chứa ÍT hơn trần ⇒ lấy hết khối trong vùng nhìn, phần còn
      // lại của trần dành cho khối to nhất bên ngoài; vẫn theo thứ tự đọc.
      const strip = OcrBlockRect(left: 0, top: 0, right: 540, bottom: 80);
      final mixed = selectBlocksToTranslate(blocks, 32, viewport: strip);
      final inStrip =
          mixed.selected.where((b) => b.text.startsWith('trên')).toList();
      expect(inStrip, hasLength(5), reason: '5 hàng đầu (top 0..64) giao dải');
      expect(mixed.selected, hasLength(32));
      expect(
        mixed.selected.skip(5).every((b) => b.text.startsWith('dưới')),
        isTrue,
      );
    });

    test('chip "Còn N khối · Dịch tiếp" CHỈ có khi còn khối chờ', () async {
      // ≤ 32 khối: không có gì chờ ⇒ không chip.
      final few = await _controller(_ocrGrid(10)).handleFrame(_frame());
      expect(few.status, ScreenTranslateStatus.ok);
      expect(few.pendingCount, 0);
      expect(few.pendingLabel, isEmpty);
      expect(few.toMap()['pendingCount'], 0);

      // 40 khối: lượt đầu dịch 32, còn 8 ⇒ có chip, nhãn mang đúng số 8.
      final seen = <String>[];
      final controller = _controller(_ocrGrid(40), seen: seen);
      final first = await controller.handleFrame(_frame());
      expect(first.status, ScreenTranslateStatus.ok);
      expect(first.blocks, hasLength(32));
      expect(first.pendingCount, 8);
      expect(first.pendingLabel, contains('8'));
      expect(first.pendingLabel, isNot(contains('{')),
          reason: 'nhãn phải được điền số, không lộ placeholder');
      expect(controller.pendingBlockCount, 8);
      expect(seen, hasLength(32), reason: 'không tự chạy lượt hai');
      expect(seen.toSet(), <String>{for (var i = 1; i <= 32; i++) _entry(i)},
          reason: 'hoà điểm ⇒ lượt đầu là 32 khối ĐẦU theo thứ tự đọc');

      // Bấm "Dịch tiếp": dịch nốt 8 khối TRÊN CÙNG ảnh, không dịch lại khối
      // cũ; kết quả gồm cả 40 khối; hết khối chờ ⇒ chip biến mất.
      final second = await controller.translatePending();
      expect(second.status, ScreenTranslateStatus.ok);
      expect(second.blocks, hasLength(40));
      expect(second.blocks.every((b) => b.hasTranslation), isTrue);
      expect(second.pendingCount, 0);
      expect(second.pendingLabel, isEmpty);
      expect(seen, hasLength(40));
      expect(seen.toSet(), hasLength(40), reason: 'không khối nào dịch 2 lần');
      expect(controller.pendingBlockCount, 0);

      // Bấm lần nữa khi đã hết ⇒ bỏ qua có thông báo, không lỗi, không dịch.
      final third = await controller.translatePending();
      expect(third.status, ScreenTranslateStatus.skipped);
      expect(third.message, isNotEmpty);
      expect(seen, hasLength(40));
    });

    test('nhiều lượt: 70 khối ⇒ 32 → 64 → 70, mỗi lượt một lần bấm', () async {
      final seen = <String>[];
      final controller = _controller(_ocrGrid(70), seen: seen);

      final first = await controller.handleFrame(_frame());
      expect(first.blocks, hasLength(32));
      expect(first.pendingCount, 38);

      final second = await controller.translatePending();
      expect(second.status, ScreenTranslateStatus.ok);
      expect(second.blocks, hasLength(64));
      expect(second.pendingCount, 6, reason: 'mỗi lượt tối đa 32 — không '
          'tự lặp tới hết (giữ mốc thời gian + quota engine)');
      expect(second.pendingLabel, contains('6'));

      final third = await controller.translatePending();
      expect(third.blocks, hasLength(70));
      expect(third.pendingCount, 0);
      expect(seen.toSet(), hasLength(70));
    });

    test('lượt "Dịch tiếp" hỏng ⇒ báo lỗi, khối chờ GIỮ NGUYÊN để bấm lại',
        () async {
      var broken = true;
      final seen = <String>[];
      // Chỉ các khối 33..40 (lượt hai) làm engine hỏng — và chỉ khi `broken`.
      final lateTexts = <String>{for (var i = 33; i <= 40; i++) _entry(i)};
      final controller = _controller(
        _ocrGrid(40),
        seen: seen,
        fails: (text) => broken && lateTexts.contains(text),
      );

      final first = await controller.handleFrame(_frame());
      expect(first.status, ScreenTranslateStatus.ok);
      expect(first.pendingCount, 8);

      final failed = await controller.translatePending();
      expect(failed.status, ScreenTranslateStatus.error);
      expect(failed.message, isNotEmpty);
      expect(controller.pendingBlockCount, 8,
          reason: 'lượt hỏng không được nuốt mất 8 khối đang chờ');

      broken = false;
      final retried = await controller.translatePending();
      expect(retried.status, ScreenTranslateStatus.ok);
      expect(retried.blocks, hasLength(40));
      expect(retried.blocks.every((b) => b.hasTranslation), isTrue);
      expect(retried.pendingCount, 0);
    });

    test('frame mới ⇒ khối chờ của ảnh CŨ bị bỏ (toạ độ đã khác)', () async {
      var now = DateTime(2026, 11, 13, 9);
      var screen = _ocrGrid(40);
      final controller = ScreenTranslateController(
        localeCode: 'en',
        gate: CaptureGate(now: () => now),
        ocrRunner: ({
          required Uint8List pixels,
          required int width,
          required int height,
        }) async =>
            OcrBlocksResult(blocks: screen),
        translator: (text, target) async => TranslationResult.success(
          original: text,
          translated: 'VI: $text',
          engine: 'fake-engine',
        ),
      );
      final first = await controller.handleFrame(_frame());
      expect(first.pendingCount, 8);

      now = now.add(const Duration(seconds: 5));
      screen = _ocrGrid(6);
      final next = await controller.handleFrame(_frame());
      expect(next.status, ScreenTranslateStatus.ok);
      expect(next.pendingCount, 0);
      expect(controller.pendingBlockCount, 0);
      expect(
        (await controller.translatePending()).status,
        ScreenTranslateStatus.skipped,
      );
    });

    test('"Dịch tiếp" không bị chặn bởi khoảng nghỉ chống bấm trùng', () {
      var now = DateTime(2026, 11, 13, 9);
      final gate = CaptureGate(
        minInterval: const Duration(milliseconds: 1500),
        now: () => now,
      );
      expect(gate.tryAcquire(), isTrue);
      gate.complete();
      now = now.add(const Duration(milliseconds: 200));
      expect(gate.tryAcquire(), isFalse, reason: 'bấm bong bóng: vẫn debounce');
      expect(gate.tryAcquire(ignoreInterval: true), isTrue);
      expect(gate.tryAcquire(ignoreInterval: true), isFalse,
          reason: 'đang bận thì vẫn từ chối');
    });
  });

  group('chuỗi UI mới — đủ 8 locale ưu tiên', () {
    test('nhãn chip và tiêu đề popup có bản dịch ở cả 8 locale', () {
      final vi = ScreenTranslateController(localeCode: 'vi');
      expect(vi.pendingLabel(5), 'Còn 5 khối · Dịch tiếp');
      expect(vi.collapsedPopupTitle, 'Bản dịch đầy đủ');
      expect(vi.pendingLabel(0), isEmpty);

      final labels = <String>{};
      final titles = <String>{};
      for (final locale in _priorityLocales) {
        final controller = ScreenTranslateController(localeCode: locale);
        final label = controller.pendingLabel(5);
        final title = controller.collapsedPopupTitle;
        expect(label, isNot('Còn 5 khối · Dịch tiếp'),
            reason: '$locale: nhãn chip chưa có bản dịch');
        expect(label, contains('5'), reason: '$locale: mất số khối');
        expect(label, isNot(contains('{')), reason: '$locale: lộ placeholder');
        expect(title, isNot('Bản dịch đầy đủ'),
            reason: '$locale: tiêu đề popup chưa có bản dịch');
        expect(title.trim(), isNotEmpty);
        labels.add(label);
        titles.add(title);
      }
      expect(labels, hasLength(_priorityLocales.length),
          reason: 'mỗi locale một bản dịch riêng (không rơi về tiếng Anh)');
      expect(titles, hasLength(_priorityLocales.length));
    });
  });

  group('lề hệ thống (hub #3) — cộng lề với lề giả 0 / 24 / 48 dp', () {
    for (final insetDp in <int>[0, 24, 48]) {
      final inset = (insetDp * _dpr).round();

      test('màn DỌC, lề trên/dưới $insetDp dp', () {
        final viewport = screenViewportFromInsets(
          screenWidth: _screenW,
          screenHeight: _screenH,
          insetTop: inset,
          insetBottom: inset,
        );
        expect(viewport, isNotNull);
        expect(viewport!.left, 0);
        expect(viewport.top, inset);
        expect(viewport.right, _screenW);
        expect(viewport.bottom, _screenH - inset);

        // Cửa sổ overlay bị dời đúng bằng lề trên ⇒ trừ gốc rồi cộng lại phải
        // ra đúng toạ độ màn hình ban đầu.
        const onScreen =
            OverlayRect(left: 60, top: 300, right: 1020, bottom: 356);
        final inWindow = screenRectToWindow(onScreen, originX: 0, originY: inset);
        expect(inWindow.left, 60);
        expect(inWindow.top, 300 - inset);
        expect(inWindow.width, onScreen.width);
        expect(inWindow.height, onScreen.height);
        expect(inWindow.top + inset, onScreen.top);
        expect(inWindow.bottom + inset, onScreen.bottom);
      });

      test('màn NGANG, tai thỏ bên trái $insetDp dp + thanh điều hướng phải',
          () {
        // Xoay ngang: rộng/cao đổi chỗ, tai thỏ thành lề TRÁI.
        final viewport = screenViewportFromInsets(
          screenWidth: _screenH,
          screenHeight: _screenW,
          insetLeft: inset,
          insetRight: inset,
        );
        expect(viewport, isNotNull);
        expect(viewport!.left, inset);
        expect(viewport.top, 0);
        expect(viewport.right, _screenH - inset);
        expect(viewport.bottom, _screenW);

        const onScreen =
            OverlayRect(left: 400, top: 200, right: 1400, bottom: 260);
        final inWindow = screenRectToWindow(onScreen, originX: inset, originY: 0);
        expect(inWindow.left, 400 - inset);
        expect(inWindow.top, 200);
        expect(inWindow.left + inset, onScreen.left);
        expect(inWindow.right + inset, onScreen.right);
        expect(inWindow.width, onScreen.width);
      });

      test('frame native gửi lề $insetDp dp ⇒ vùng nhìn theo toạ độ khối OCR',
          () {
        final frame = _frame()
          ..['insetLeft'] = 0
          ..['insetTop'] = inset
          ..['insetRight'] = 0
          ..['insetBottom'] = inset;
        final geometry = ScreenCaptureGeometry.fromMap(frame);
        final onScreen = screenViewportFromFrame(frame, geometry);
        expect(onScreen, isNotNull);
        expect(onScreen!.top, inset);
        expect(onScreen.bottom, _screenH - inset);

        // Ảnh chụp bằng nửa màn hình ⇒ vùng nhìn trên ảnh bằng nửa (nới ra
        // ngoài ≤ 1px: thà coi khối ở mép là "đang nhìn").
        final inOcr = viewportInOcrSpace(onScreen, geometry);
        expect(inOcr, isNotNull);
        expect(inOcr!.left, 0);
        expect(inOcr.right, _screenW ~/ _captureScale);
        expect(inOcr.top, (inset / _captureScale).floor());
        expect(inOcr.bottom, ((_screenH - inset) / _captureScale).ceil());
      });
    }

    test('native cũ không gửi lề ⇒ không phân biệt vùng nhìn (hành vi cũ)', () {
      final frame = _frame();
      final geometry = ScreenCaptureGeometry.fromMap(frame);
      expect(screenViewportFromFrame(frame, geometry), isNull);
      expect(viewportInOcrSpace(null, geometry), isNull);
    });

    test('lề vô lý (âm / nuốt hết màn hình) không làm hỏng vùng nhìn', () {
      final negative = screenViewportFromInsets(
        screenWidth: _screenW,
        screenHeight: _screenH,
        insetTop: -50,
        insetLeft: -1,
      );
      expect(negative, isNotNull);
      expect(negative!.top, 0);
      expect(negative.left, 0);

      expect(
        screenViewportFromInsets(
          screenWidth: _screenW,
          screenHeight: _screenH,
          insetTop: 1300,
          insetBottom: 1300,
        ),
        isNull,
      );
    });
  });

  group('cầu nối native — "Dịch tiếp" và chip', () {
    test('binding: translatePending gọi callback và trả payload', () async {
      var calls = 0;
      final binding = ScreenTranslateWorkerBinding(
        onFrame: (_) async =>
            const ScreenTranslateResult(status: ScreenTranslateStatus.ok),
        onTranslatePending: () async {
          calls++;
          return const ScreenTranslateResult(
            status: ScreenTranslateStatus.ok,
            pendingCount: 6,
            pendingLabel: 'Còn 6 khối · Dịch tiếp',
            popupTitle: 'Bản dịch đầy đủ',
          );
        },
      );
      final out = await binding.handleCall(
        const MethodCall(ScreenTranslateProtocol.methodTranslatePending),
      );
      expect(calls, 1);
      final map = out! as Map;
      expect(map['status'], 'ok');
      expect(map['pendingCount'], 6);
      expect(map['pendingLabel'], 'Còn 6 khối · Dịch tiếp');
      expect(map['popupTitle'], 'Bản dịch đầy đủ');

      final restored = ScreenTranslateResult.fromMap(map);
      expect(restored.pendingCount, 6);
      expect(restored.pendingLabel, 'Còn 6 khối · Dịch tiếp');
      expect(restored.popupTitle, 'Bản dịch đầy đủ');
    });

    test('binding chưa gắn translatePending ⇒ MissingPluginException',
        () async {
      final binding = ScreenTranslateWorkerBinding(
        onFrame: (_) async =>
            const ScreenTranslateResult(status: ScreenTranslateStatus.ok),
      );
      await expectLater(
        binding.handleCall(
          const MethodCall(ScreenTranslateProtocol.methodTranslatePending),
        ),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('payload cũ (không có khoá pending) ⇒ mặc định 0 / rỗng', () {
      final restored = ScreenTranslateResult.fromMap(<Object?, Object?>{
        'status': 'ok',
        'blocks': <Object?>[],
      });
      expect(restored.pendingCount, 0);
      expect(restored.pendingLabel, isEmpty);
      expect(restored.popupTitle, isEmpty);
    });

    test('Kotlin đọc đúng các khoá Dart gửi và không còn nhánh bỏ khối', () {
      // Chốt nối dây bằng cách đọc source (không build được APK trong test):
      // đổi tên khoá ở một phía mà quên phía kia thì chip / "Dịch tiếp" chết
      // im lặng.
      final service = _read(
        'android/app/src/main/kotlin/com/in4up/screentranslate/'
        'ScreenTranslateService.kt',
      );
      final overlay = _read(
        'android/app/src/main/kotlin/com/in4up/screentranslate/'
        'TranslationOverlayView.kt',
      );

      // Khoá payload.
      expect(service.contains('map["collapsed"]'), isTrue);
      expect(service.contains('result["pendingCount"]'), isTrue);
      expect(service.contains('result["pendingLabel"]'), isTrue);
      expect(service.contains('result["popupTitle"]'), isTrue);
      expect(
        service.contains('"${ScreenTranslateProtocol.methodTranslatePending}"'),
        isTrue,
        reason: 'tên method "Dịch tiếp" phải khớp hai phía',
      );
      for (final key in <String>[
        ScreenTranslateProtocol.frameInsetLeft,
        ScreenTranslateProtocol.frameInsetTop,
        ScreenTranslateProtocol.frameInsetRight,
        ScreenTranslateProtocol.frameInsetBottom,
      ]) {
        expect(service.contains('args["$key"]'), isTrue, reason: key);
      }

      // Lớp vẽ: `buildLayout` luôn trả kết quả (không còn `StaticLayout?` để
      // caller lặng lẽ bỏ khối), có trạng thái thu gọn + lớp chạm + popup.
      expect(overlay.contains('): StaticLayout? {'), isFalse,
          reason: 'buildLayout không được trả null nữa (hub § 3.1)');
      expect(overlay.contains('): FittedText {'), isTrue);
      expect(overlay.contains('val collapsed: Boolean = false'), isTrue,
          reason: 'payload cũ (không có khoá) phải giữ hành vi cũ');
      expect(overlay.contains('class OverlayChipLayer('), isTrue);
      expect(overlay.contains('fun showPopup('), isTrue);
      expect(overlay.contains('fun showPending('), isTrue);
      // Kích thước chip native = hằng số Dart (lệch ⇒ vùng chạm lệch chip).
      expect(
        overlay.contains('CHIP_WIDTH_DP = ${kOverlayChipWidthDp.toInt()}f'),
        isTrue,
      );
      expect(
        overlay.contains('CHIP_HEIGHT_DP = ${kOverlayChipHeightDp.toInt()}f'),
        isTrue,
      );
      // Service dựng cửa sổ chạm từ đúng danh sách chip overlay đang vẽ, và
      // gỡ chúng cùng lúc với overlay.
      expect(service.contains('layer.showChips(view.chips, popupTitle)'), isTrue);
      expect(service.contains('chipLayer?.clear()'), isTrue);
    });
  });
}
