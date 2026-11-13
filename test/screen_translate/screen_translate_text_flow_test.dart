// PSRC-211 — test đơn vị cho các mảnh MỚI của bản sửa "bong bóng dịch bỏ sót
// khối + sai vị trí + khung thừa khoảng trống".
//
// Nghiệm thu đầu-cuối (đủ bong bóng, lệch ≤ 4dp, không đè) nằm ở
// `psrc_211_bubble_coverage_test.dart`. File này ghim TỪNG nguyên nhân gốc để
// không ai vô tình mở lại:
//   A. Dòng / đoạn của chữ OCR  (`screen_translate_text_flow.dart`)
//   B. Cỡ chữ đo theo MỘT dòng và chia `fontScale`  (`suggestedTextSizeSp`)
//   C. Bộ ước lượng tôn trọng `\n` + chữ toàn ôm  (`estimateTranslation…`)
//   D. Layout đặt khối TẠI CHỖ, báo cho native chỗ cần phủ  (`coverBottom`,
//      `maxTextSizeSp`)
//   E. Hai đầu giao thức Dart ↔ Kotlin dùng cùng tên khoá (quét source —
//      Kotlin không chạy được trên host VM).
//
// THUẦN host VM.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/ocr/ocr_block.dart';
import 'package:in4up/features/screen_translate/screen_translate_geometry.dart';
import 'package:in4up/features/screen_translate/screen_translate_models.dart';
import 'package:in4up/features/screen_translate/screen_translate_overlay_layout.dart';
import 'package:in4up/features/screen_translate/screen_translate_text_flow.dart';

const double _dpr = 2.75;
const int _screenW = 1080;
const int _screenH = 2400;

OcrBlock _ocr(String text, int left, int top, int right, int bottom) =>
    OcrBlock(
      text: text,
      rect: OcrBlockRect(left: left, top: top, right: right, bottom: bottom),
    );

ScreenBlock _block(
  int top,
  int bottom,
  String translation, {
  String original = 'original',
  int left = 60,
  int right = 1020,
}) {
  return ScreenBlock(
    rect: OverlayRect(left: left, top: top, right: right, bottom: bottom),
    original: original,
    translation: translation,
  );
}

List<ScreenBlock> _layout(List<ScreenBlock> blocks, {double fontScale = 1.0}) {
  return layoutTranslatedBlocks(
    blocks,
    screenWidth: _screenW,
    screenHeight: _screenH,
    devicePixelRatio: _dpr,
    fontScale: fontScale,
  );
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Thiếu file để pin: $path');
  return file.readAsStringSync();
}

void main() {
  const paragraphLines = <String>[
    'Download a language pack once and the app keeps',
    'working without a connection. Translations, the',
    'dictionary and text to speech all run on your',
    'phone, so nothing you read ever leaves the device.',
  ];

  group('A1 — dòng của một khối OCR', () {
    test('countTextLines đếm dòng có chữ, bỏ dòng trống', () {
      expect(countTextLines(''), 0);
      expect(countTextLines('   \n  '), 0);
      expect(countTextLines('Một dòng'), 1);
      expect(countTextLines('Một\nHai\nBa'), 3);
      expect(countTextLines('Một\r\n\r\nHai\n'), 2);
      expect(splitTextLines('  a  \n b '), <String>['a', 'b']);
    });

    test('isSoftWrap: câu đang dở + dòng dưới viết thường ⇒ nối', () {
      expect(isSoftWrap(paragraphLines[0], paragraphLines[1]), isTrue);
      expect(isSoftWrap(paragraphLines[1], paragraphLines[2]), isTrue);
      expect(isSoftWrap(paragraphLines[2], paragraphLines[3]), isTrue);
    });

    test('isSoftWrap: KHÔNG nối nhãn ngắn, câu đã kết, đề mục, mục danh sách',
        () {
      // Nhãn ngắn (dưới 16 ký tự / dưới 3 từ) không bao giờ là dòng bị ngắt.
      expect(isSoftWrap('Send feedback', 'to the team'), isFalse);
      expect(isSoftWrap('Notifications settings', 'and sounds'), isFalse);
      // Dòng trên đã kết câu.
      expect(isSoftWrap('This sentence is complete.', 'and this is new'),
          isFalse);
      expect(isSoftWrap('Is this sentence complete?', 'yes it is'), isFalse);
      expect(isSoftWrap('The options are as follows:', 'first option'),
          isFalse);
      // Dòng dưới viết hoa, dòng trên không có dấu nối ⇒ mục riêng.
      expect(isSoftWrap('Storage and downloaded data', 'Display and text'),
          isFalse);
      // Dòng dưới mở đầu một mục danh sách.
      expect(isSoftWrap('Things you will need to bring', '- a charger'),
          isFalse);
      expect(isSoftWrap('Things you will need to bring', '• a charger'),
          isFalse);
      expect(isSoftWrap('Things you will need to bring,', '2. a charger'),
          isFalse);
      // Rỗng.
      expect(isSoftWrap('', 'anything'), isFalse);
      expect(isSoftWrap('A long enough line of text', ''), isFalse);
    });

    test('isSoftWrap: dấu phẩy / gạch nối cuối dòng ⇒ nối kể cả khi viết hoa',
        () {
      expect(isSoftWrap('Available in Hanoi, Da Nang,', 'Hue and Can Tho.'),
          isTrue);
      expect(isSoftWrap('This is a very well-', 'Known problem'), isTrue);
    });

    test('reflowOcrText: đoạn 4 dòng ⇒ MỘT câu liền, không còn xuống dòng',
        () {
      expect(reflowOcrText(paragraphLines.join('\n')),
          paragraphLines.join(' '));
    });

    test('reflowOcrText: giữ ngắt THẬT (menu, hết câu, danh sách)', () {
      expect(reflowOcrText('Settings\nHelp\nAbout'), 'Settings\nHelp\nAbout');
      expect(
        reflowOcrText('Each pack holds one language pair and\n'
            'nothing else at all.\n'
            'Add more packs whenever you start\n'
            'reading in another language.'),
        'Each pack holds one language pair and nothing else at all.\n'
        'Add more packs whenever you start reading in another language.',
      );
      expect(
        reflowOcrText('Things you will need to bring\n- a charger\n- a map'),
        'Things you will need to bring\n- a charger\n- a map',
      );
    });

    test('reflowOcrText: gạch nối dính chữ ⇒ nối không chèn khoảng trắng', () {
      expect(reflowOcrText('This is a very well-\nknown problem'),
          'This is a very well-known problem');
      // Gạch ngang đứng riêng (có khoảng trắng trước) ⇒ vẫn chèn khoảng trắng.
      expect(reflowOcrText('Open from Monday to Friday -\nclosed on Sunday'),
          'Open from Monday to Friday - closed on Sunday');
    });

    test('reflowOcrText: một dòng / rỗng', () {
      expect(reflowOcrText('  Hello world  '), 'Hello world');
      expect(reflowOcrText(''), '');
      expect(reflowOcrText(' \n '), '');
    });

    test('normalizeOverlayText: bỏ dòng trống + khoảng trắng thừa, giữ \\n',
        () {
      expect(normalizeOverlayText(' Xin  chào \r\n\r\n thế\tgiới '),
          'Xin chào\nthế giới');
      expect(normalizeOverlayText('Một dòng'), 'Một dòng');
      expect(normalizeOverlayText('\n\n'), '');
    });
  });

  group('A2 — gộp các khối là DÒNG của cùng một đoạn văn', () {
    // Toạ độ PIXEL ẢNH (540×1200): dòng cao 20, dòng cách dòng 27.
    List<OcrBlock> paragraphAsLines() => <OcrBlock>[
          for (var i = 0; i < paragraphLines.length; i++)
            _ocr(
              paragraphLines[i],
              22,
              180 + i * 27,
              i == 3 ? 500 : 518,
              200 + i * 27,
            ),
        ];

    test('4 khối một dòng của một câu ⇒ 1 khối, khung là hợp, chữ giữ \\n', () {
      final merged = mergeWrappedBlocks(paragraphAsLines());
      expect(merged, hasLength(1));
      expect(merged.single.text, paragraphLines.join('\n'));
      expect(
        merged.single.rect,
        const OcrBlockRect(left: 22, top: 180, right: 518, bottom: 281),
      );
      // Cỡ chữ vẫn đo theo MỘT dòng nhờ số `\n` còn nguyên.
      expect(countTextLines(merged.single.text), 4);
    });

    test('menu / danh sách nhãn ngắn KHÔNG bị gộp', () {
      final menu = <OcrBlock>[
        _ocr('Language packs', 90, 150, 244, 174),
        _ocr('Reading history', 90, 227, 255, 251),
        _ocr('Notifications and sounds', 90, 304, 354, 328),
      ];
      final merged = mergeWrappedBlocks(menu);
      expect(merged, hasLength(3));
      for (var i = 0; i < menu.length; i++) {
        expect(identical(merged[i], menu[i]), isTrue);
      }
    });

    test('đủ điều kiện chữ nhưng HÌNH HỌC không khớp ⇒ không gộp', () {
      const upper = 'Download a language pack once and the app keeps';
      const lower = 'working without a connection for a long time';
      final base = _ocr(upper, 22, 180, 518, 200);

      // Cách nhau quá xa (hơn 0.9 dòng).
      expect(
        mergeWrappedBlocks(<OcrBlock>[base, _ocr(lower, 22, 240, 500, 260)]),
        hasLength(2),
      );
      // Cỡ chữ khác hẳn (dòng dưới cao gấp rưỡi).
      expect(
        mergeWrappedBlocks(<OcrBlock>[base, _ocr(lower, 22, 207, 518, 237)]),
        hasLength(2),
      );
      // Lệch lề trái (cột khác).
      expect(
        mergeWrappedBlocks(<OcrBlock>[base, _ocr(lower, 80, 207, 518, 227)]),
        hasLength(2),
      );
      // Dòng trên hẹp hơn hẳn dòng dưới ⇒ là mục ngắn đứng riêng.
      expect(
        mergeWrappedBlocks(<OcrBlock>[
          _ocr(upper, 22, 180, 300, 200),
          _ocr(lower, 22, 207, 518, 227),
        ]),
        hasLength(2),
      );
      // Đối chứng: cùng cặp chữ, hình học khớp ⇒ gộp.
      expect(
        mergeWrappedBlocks(<OcrBlock>[base, _ocr(lower, 22, 207, 500, 227)]),
        hasLength(1),
      );
    });

    test('hai cột chữ cạnh nhau không bị trộn vào nhau', () {
      const leftA = 'The left column starts a sentence that';
      const leftB = 'continues on the next line of the column';
      const rightA = 'The right column has its own text which';
      const rightB = 'also wraps onto a second line below it';
      // Thứ tự đọc: theo hàng (trái, phải, trái, phải).
      final merged = mergeWrappedBlocks(<OcrBlock>[
        _ocr(leftA, 20, 100, 250, 120),
        _ocr(rightA, 290, 100, 520, 120),
        _ocr(leftB, 20, 127, 250, 147),
        _ocr(rightB, 290, 127, 520, 147),
      ]);
      expect(merged, hasLength(2));
      expect(merged[0].text, '$leftA\n$leftB');
      expect(merged[1].text, '$rightA\n$rightB');
      expect(merged[0].rect.right, 250);
      expect(merged[1].rect.left, 290);
    });

    test('ít hơn 2 khối ⇒ trả bản sao nguyên vẹn', () {
      expect(mergeWrappedBlocks(const <OcrBlock>[]), isEmpty);
      final one = _ocr('Hello', 0, 0, 10, 10);
      expect(mergeWrappedBlocks(<OcrBlock>[one]).single, same(one));
    });
  });

  group('B — cỡ chữ gốc: MỘT dòng, đã chia fontScale', () {
    test('đoạn 4 dòng cao 202px ⇒ ~15sp (trước đây chạm trần 28sp)', () {
      const rect = OverlayRect(left: 44, top: 360, right: 1036, bottom: 562);
      expect(suggestedTextSizeSp(rect, _dpr), 28.0,
          reason: 'mặc định 1 dòng = hành vi cũ cho khối một dòng');
      expect(suggestedTextSizeSp(rect, _dpr, lineCount: 4),
          closeTo(15.06, 0.01));
      expect(suggestedTextSizeSp(rect, _dpr, lineCount: 0), 28.0,
          reason: 'số dòng rác ⇒ coi là 1');
    });

    test('fontScale 1.3 ⇒ sp nhỏ đi đúng 1.3× (px vẽ ra bằng chữ gốc)', () {
      const rect = OverlayRect(left: 0, top: 0, right: 600, bottom: 62);
      final normal = suggestedTextSizeSp(rect, _dpr);
      final large = suggestedTextSizeSp(rect, _dpr, fontScale: 1.3);
      expect(normal, closeTo(18.49, 0.01));
      expect(large * 1.3, closeTo(normal, 1e-9));
    });

    test('fontScale rác: ≤ 1 / NaN coi là 1.0; quá lớn kẹp 2.0', () {
      const rect = OverlayRect(left: 0, top: 0, right: 600, bottom: 80);
      final base = suggestedTextSizeSp(rect, _dpr);
      expect(base, closeTo(23.85, 0.01));
      expect(suggestedTextSizeSp(rect, _dpr, fontScale: 0.85), base);
      expect(suggestedTextSizeSp(rect, _dpr, fontScale: 0), base);
      expect(suggestedTextSizeSp(rect, _dpr, fontScale: double.nan), base);
      expect(suggestedTextSizeSp(rect, _dpr, fontScale: 2.0),
          closeTo(base / 2, 1e-9));
      expect(
        suggestedTextSizeSp(rect, _dpr, fontScale: 9),
        suggestedTextSizeSp(rect, _dpr, fontScale: 2.0),
      );
    });

    test('layout dùng số dòng của chữ GỐC để chọn cỡ chữ', () {
      // Cùng khung 202px: chữ gốc 4 dòng ⇒ ~15sp; chữ gốc 1 dòng ⇒ 28sp.
      final paragraph = _layout(<ScreenBlock>[
        _block(360, 562, 'Bản dịch ngắn.',
            original: paragraphLines.join('\n')),
        _block(1500, 1556, 'Khối khác'),
      ]);
      expect(paragraph[0].textSizeSp, closeTo(15.06, 0.01));

      final banner = _layout(<ScreenBlock>[
        _block(360, 562, 'Bản dịch ngắn.', original: 'BANNER'),
        _block(1500, 1556, 'Khối khác'),
      ]);
      expect(banner[0].textSizeSp, 28.0);
    });

    test('khối đơn cũng đo theo dòng + fontScale', () {
      final out = _layout(
        <ScreenBlock>[
          _block(360, 562, 'Bản dịch ngắn.',
              original: paragraphLines.join('\n')),
        ],
        fontScale: 1.3,
      );
      expect(out.single.textSizeSp, closeTo(15.06 / 1.3, 0.01));
    });
  });

  group('C — bộ ước lượng', () {
    test('\\n là xuống dòng THẬT (native StaticLayout cũng vậy)', () {
      expect(estimateTranslationLineCount('Một\nHai\nBa', 900, 34), 3);
      expect(estimateTranslationLineCount('Một Hai Ba', 900, 34), 1);
      // Dòng trống giữa hai \n vẫn chiếm một dòng.
      expect(estimateTranslationLineCount('Một\n\nHai', 900, 34), 3);
      // \r\n của engine không được tính thành hai lần xuống dòng.
      expect(estimateTranslationLineCount('Một\r\nHai', 900, 34), 2);
    });

    test('mỗi đoạn tự gãy dòng rồi mới cộng lại', () {
      const long = 'Một hai ba bốn năm sáu bảy tám chín mười';
      final one = estimateTranslationLineCount(long, 200, 34);
      expect(one, greaterThan(1));
      expect(estimateTranslationLineCount('$long\n$long', 200, 34), one * 2);
      expect(
        estimateTranslationTextHeightPx('$long\n$long', 200, 34),
        closeTo(2 * estimateTranslationTextHeightPx(long, 200, 34), 1e-9),
      );
    });

    test('chữ toàn ôm (Hán/Kana/Hangul) rộng 1em, không phải 0.56em', () {
      // 30 chữ × 34px = 1020px trên bề ngang 340px ⇒ đúng 3 dòng. Bản cũ tính
      // 0.56em ⇒ 2 dòng ⇒ native (3 dòng thật) không vừa khung ⇒ bỏ vẽ khối.
      expect(estimateTranslationLineCount('漢' * 30, 340, 34), 3);
      expect(estimateTranslationLineCount('あ' * 30, 340, 34), 3);
      expect(estimateTranslationLineCount('한' * 30, 340, 34), 3);
      // Latin có dấu (tiếng Việt) giữ nguyên bề rộng cũ.
      expect(estimateTranslationLineCount('ế' * 30, 340, 34), 2);
    });
  });

  group('D — layout đặt khối TẠI CHỖ', () {
    test('bản dịch cần thêm chỗ ⇒ dùng khoảng trống bên dưới, đỉnh giữ nguyên',
        () {
      final out = _layout(<ScreenBlock>[
        _block(300, 356,
            'Đây là bản dịch tiếng Việt dài hơn bản gốc nên cần hai dòng chữ.'),
        _block(700, 756, 'Khối bên dưới ở khá xa'),
      ]);
      expect(out[0].rect.top, 300);
      expect(out[0].rect.bottom, greaterThan(356));
      expect(out[0].rect.bottom, lessThan(700));
      expect(out[1].rect.top, 700, reason: 'khối dưới không bị động tới');
      // Native được báo chữ gốc kết thúc ở đâu ⇒ nền ôm sát, không tô dư.
      expect(out[0].coverBottom, 356);
      expect(out[0].maxTextSizeSp, isNull,
          reason: 'không phải thu nhỏ ⇒ không cần cỡ chữ thay thế');
    });

    test('chật ⇒ thu nhỏ RIÊNG khối đó, khối dưới đứng yên', () {
      final out = _layout(<ScreenBlock>[
        _block(300, 356,
            'Đây là bản dịch tiếng Việt dài hơn bản gốc nên cần hai dòng chữ.'),
        _block(420, 476, 'Ngắn'),
      ]);
      expect(out.every((b) => b.hasTranslation), isTrue);
      expect(out[0].rect.top, 300);
      expect(out[1].rect.top, 420, reason: 'không bị đẩy');
      expect(out[0].rect.bottom, lessThanOrEqualTo(420));
      expect(out[0].textSizeSp, lessThan(out[1].textSizeSp),
          reason: 'chỉ khối chật bị thu nhỏ');
      expect(out[0].textSizeSp, greaterThanOrEqualTo(kOverlayMinReadableSp));
      expect(out[0].maxTextSizeSp, closeTo(16.70, 0.01),
          reason: 'native đo được font thật ⇒ được thử lại từ cỡ chữ gốc');
      expect(out[1].maxTextSizeSp, isNull);
    });

    test('đã ở cỡ sàn vẫn thiếu ⇒ mới đẩy, và độ lệch không lan xuống dưới',
        () {
      // Ba hàng dày: khối đầu không thể vừa hàng của nó kể cả ở 10sp ⇒ khối
      // giữa bị đẩy vài px, nhưng nó vẫn kết thúc TRƯỚC khối cuối nên khối
      // cuối đứng yên (bản cũ: mọi khối bên dưới trôi dần).
      final out = _layout(<ScreenBlock>[
        _block(300, 344, 'Quyền riêng tư và bảo mật', right: 520),
        _block(350, 394, 'Trợ giúp và phản hồi', right: 520),
        _block(420, 464, 'Giới thiệu', right: 520),
      ]);
      expect(out.every((b) => b.hasTranslation), isTrue);
      expect(countOverlappingPairs(out), 0);
      expect(out[0].textSizeSp, kOverlayMinReadableSp);
      expect(out[1].rect.top, greaterThan(350));
      expect(out[1].rect.top - 350, lessThanOrEqualTo(11),
          reason: 'lệch không quá 4dp');
      expect(out[2].rect.top, 420, reason: 'độ lệch không lan xuống dưới');
    });

    test('khung không bao giờ thấp hơn chữ gốc khi còn chỗ (không lòi chữ gốc)',
        () {
      final out = _layout(<ScreenBlock>[
        _block(300, 500, 'Ngắn', original: 'a\nb\nc\nd'),
        _block(700, 756, 'Khối khác'),
      ]);
      expect(out[0].rect.top, 300);
      expect(out[0].rect.bottom, 500);
      expect(out[0].coverBottom, isNull,
          reason: 'khung giữ chỗ trùng chữ gốc ⇒ native phủ kín như cũ');
    });

    test('bản dịch có \\n được cấp đủ chiều cao cho TỪNG dòng', () {
      final out = _layout(<ScreenBlock>[
        _block(300, 356, 'Dòng một\nDòng hai\nDòng ba'),
        _block(900, 956, 'Khối khác'),
      ]);
      final block = out[0];
      expect(block.hasTranslation, isTrue);
      final threeLines = estimateTranslationTextHeightPx(
            'Dòng một\nDòng hai\nDòng ba',
            block.rect.width - 2 * kOverlayTextPaddingPx,
            block.textSizeSp * _dpr,
          ) +
          2 * kOverlayTextPaddingPx;
      expect(block.rect.height + 0.5, greaterThanOrEqualTo(threeLines));
      expect(block.rect.height, greaterThan(56 * 2),
          reason: 'ba dòng không thể nằm trong khung một dòng');
    });
  });

  group('E — giao thức Dart ↔ Kotlin (PSRC-211)', () {
    test('ScreenBlock.toMap chỉ thêm khoá mới khi có giá trị', () {
      const plain = ScreenBlock(
        rect: OverlayRect(left: 1, top: 2, right: 3, bottom: 40),
        original: 'Hello',
        translation: 'Xin chào',
      );
      expect(plain.toMap().containsKey('coverBottom'), isFalse);
      expect(plain.toMap().containsKey('maxTextSizeSp'), isFalse);

      const full = ScreenBlock(
        rect: OverlayRect(left: 1, top: 2, right: 3, bottom: 40),
        original: 'Hello',
        translation: 'Xin chào',
        textSizeSp: 11,
        maxTextSizeSp: 14.5,
        coverBottom: 30,
      );
      final map = full.toMap();
      expect(map['coverBottom'], 30);
      expect(map['maxTextSizeSp'], 14.5);

      final restored = ScreenBlock.fromMap(map)!;
      expect(restored.coverBottom, 30);
      expect(restored.maxTextSizeSp, 14.5);
      expect(restored.textSizeSp, 11);

      final legacy = ScreenBlock.fromMap(plain.toMap())!;
      expect(legacy.coverBottom, isNull);
      expect(legacy.maxTextSizeSp, isNull);
    });

    test('Kotlin đọc đúng hai khoá và vẽ nền ôm sát chữ', () {
      final service = _read(
        'android/app/src/main/kotlin/com/in4up/screentranslate/'
        'ScreenTranslateService.kt',
      );
      final overlay = _read(
        'android/app/src/main/kotlin/com/in4up/screentranslate/'
        'TranslationOverlayView.kt',
      );
      // Sai một tên khoá là native lặng lẽ dùng giá trị mặc định ⇒ khung lại
      // thừa khoảng trống mà không test Dart nào thấy.
      expect(service.contains('map["coverBottom"]'), isTrue);
      expect(service.contains('map["maxTextSizeSp"]'), isTrue);
      expect(overlay.contains('val coverBottom: Int = bottom'), isTrue,
          reason: 'payload cũ (thiếu khoá) phải giữ hành vi cũ');
      expect(overlay.contains('val maxTextSizeSp: Float = textSizeSp'), isTrue);
      // Nền ôm sát chữ thật, không vượt trần Dart cấp.
      expect(overlay.contains('block.coverBottom.toFloat()'), isTrue);
      expect(overlay.contains('block.bottom.toFloat()'), isTrue);
      // Toạ độ màn hình → toạ độ view.
      expect(overlay.contains('getLocationOnScreen('), isTrue);
    });
  });
}
