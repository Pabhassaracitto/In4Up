// OCR-001 (ADR-0009) — test phần THUẦN TUÝ của OCR, không cần native/ML Kit.
//
// Chạy trên host VM (Linux) nên `OcrService.platformSupported == false`:
// đây chính là điều kiện để kiểm chứng guard desktop/web mà không cần thiết bị.
// Phần native (TextRecognizer/DocumentScanner thật) là QA tay trên máy — xem
// AT trong docs/project/KANBAN.md card OCR-001.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/features/ocr/ocr_block.dart';
import 'package:in4up/features/ocr/ocr_flow.dart';
import 'package:in4up/features/ocr/ocr_image_picker.dart';
import 'package:in4up/features/ocr/ocr_service.dart';
import 'package:in4up/models/vocab_context.dart';

void main() {
  group('OcrService.normalizeOcrText — dọn kết quả OCR (thuần tuý)', () {
    test('chuẩn hoá \\r\\n và \\r về \\n', () {
      expect(
        OcrService.normalizeOcrText('dòng một\r\ndòng hai\rdòng ba'),
        'dòng một\ndòng hai\ndòng ba',
      );
    });

    test('cắt khoảng trắng thừa cuối mỗi dòng (OCR hay đệm space)', () {
      expect(OcrService.normalizeOcrText('Nam Mô   \nA Di Đà  '), 'Nam Mô\nA Di Đà');
    });

    test('gộp 3+ dòng trống liên tiếp thành đúng một dòng trống', () {
      expect(OcrService.normalizeOcrText('a\n\n\n\n\nb'), 'a\n\nb');
    });

    test('GIỮ ngắt dòng đôi có nghĩa (kệ/câu) — không gộp mất', () {
      // Sách Pāḷi & Pháp thoại ngắt dòng có nghĩa: gộp sai sẽ phá pipeline
      // ngắt câu của TextProvider. Đây là hành vi cố ý, không phải bug.
      expect(OcrService.normalizeOcrText('kệ một\n\nkệ hai'), 'kệ một\n\nkệ hai');
    });

    test('CỐ Ý không nối dòng — mỗi dòng OCR giữ nguyên', () {
      expect(
        OcrService.normalizeOcrText('Sabbe saṅkhārā\naniccā'),
        'Sabbe saṅkhārā\naniccā',
      );
    });

    test('giữ dấu tiếng Việt + dấu Pāḷi Roman nguyên vẹn', () {
      const src = 'Tiếng Việt có dấu\nPāḷi: Saṅkhāra, Aniccā, Ñāṇa, Ṭhāna';
      expect(OcrService.normalizeOcrText(src), src);
    });

    test('chuỗi rỗng → rỗng; chỉ khoảng trắng/dòng trống → rỗng', () {
      expect(OcrService.normalizeOcrText(''), '');
      expect(OcrService.normalizeOcrText('   \n\n  \n'), '');
    });

    test('idempotent — dọn hai lần không đổi kết quả', () {
      const src = 'a   \n\n\n\nb  \r\nc';
      final once = OcrService.normalizeOcrText(src);
      expect(OcrService.normalizeOcrText(once), once);
    });
  });

  group('OcrService — guard nền tảng (rule: desktop/web isAvailable == false)', () {
    test('host VM (không phải Android/iOS) → platformSupported false', () {
      // Test chạy trên Linux/macOS/Windows CI → không bao giờ là mobile.
      expect(OcrService.platformSupported, isFalse);
      expect(OcrService.instance.isAvailable, isFalse);
    });

    test('Document Scanner chỉ Android → false trên host VM', () {
      expect(OcrService.documentScannerSupported, isFalse);
    });

    test('availableSources không chứa scanner khi nền tảng không hỗ trợ', () {
      final sources = OcrService.instance.availableSources;
      expect(sources.contains(OcrImageSource.documentScanner), isFalse);
      // Gallery vẫn luôn có mặt trên nền tảng OCR hỗ trợ.
      expect(sources, contains(OcrImageSource.gallery));
    });

    test('recognizeFile trên nền tảng không hỗ trợ → failure rõ ràng, không throw',
        () async {
      final result = await OcrService.instance.recognizeFile('/khong/quan/trong.jpg');
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, isNotEmpty);
      expect(result.text, isEmpty);
    });

    test('recognizeFile với path rỗng → failure (không gọi native)', () async {
      final result = await OcrService.instance.recognizeFile('   ');
      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
    });

    test('recognizeFiles([]) → failure, không trả kết quả nửa vời', () async {
      final result = await OcrService.instance.recognizeFiles(const <String>[]);
      expect(result.isSuccess, isFalse);
    });

    test('scanDocumentPages trên nền tảng không có scanner → UnsupportedError',
        () async {
      expect(
        () => OcrService.instance.scanDocumentPages(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('OcrResult', () {
    test('isEmpty chỉ true khi thành công mà không có chữ', () {
      expect(const OcrResult(text: '  ').isEmpty, isTrue);
      expect(const OcrResult(text: 'chữ').isEmpty, isFalse);
      // Thất bại KHÔNG được coi là "ảnh không có chữ" — hai thông báo khác nhau.
      expect(OcrResult.failure(error: 'lỗi').isEmpty, isFalse);
      expect(OcrResult.failure(error: 'lỗi').isSuccess, isFalse);
    });

    test('failure giữ lại sourceImagePath để UI còn báo ảnh nào lỗi', () {
      final r = OcrResult.failure(sourceImagePath: '/a/b.jpg', error: 'x');
      expect(r.sourceImagePath, '/a/b.jpg');
    });
  });

  group('OcrImagePicker — seam để test không cần plugin', () {
    tearDown(() => OcrImagePicker.pick = _realPick);

    test('pickImages trả về đường dẫn từ implementation đã gán', () async {
      OcrImagePicker.pick = ({bool allowMultiple = true}) async =>
          <String>['/a.jpg', '/b.jpg'];
      expect(await OcrImagePicker.pickImages(), ['/a.jpg', '/b.jpg']);
    });

    test('user hủy → danh sách rỗng, không throw', () async {
      OcrImagePicker.pick = ({bool allowMultiple = true}) async => const <String>[];
      expect(await OcrService.instance.pickImagesFromDevice(), isEmpty);
      expect(await OcrService.instance.pickImageFromDevice(), isNull);
    });

    test('picker throw → service nuốt lỗi, trả rỗng (không crash UI)', () async {
      OcrImagePicker.pick = ({bool allowMultiple = true}) async =>
          throw Exception('plugin chết');
      expect(await OcrService.instance.pickImagesFromDevice(), isEmpty);
      expect(await OcrService.instance.pickImageFromDevice(), isNull);
    });

    test('pickImageFromDevice lấy phần tử đầu', () async {
      OcrImagePicker.pick = ({bool allowMultiple = true}) async => <String>['/only.jpg'];
      expect(await OcrService.instance.pickImageFromDevice(), '/only.jpg');
    });
  });

  group('Provenance OCR (rule vàng #3 — reopen đúng nguồn)', () {
    VocabContext ctx(String refType) => VocabContext(
          id: 'ctx-1',
          sourceType: 'ocr',
          sourceRef: '/storage/emulated/0/scan.jpg',
          sourceRefType: refType,
          surroundingText: 'Sabbe saṅkhārā aniccā',
          encounteredAt: DateTime(2026, 9, 16),
        );

    test('refType ocrImage → nhãn reopen là "Quét lại ảnh", không phải mở file',
        () {
      // Nếu rơi vào 'localText' thì chỗ reopen sẽ gọi loadTextFile(ảnh) →
      // readAsString() trên JPEG throw → bấm nút không có tác dụng.
      expect(ctx('ocrImage').reopenActionLabel, 'Quét lại ảnh');
      expect(ctx('localText').reopenActionLabel, 'Mở vào Đọc');
    });

    test('nhãn reopen OCR dịch được sang en (rule #5, không rơi về vi)', () {
      final label = ctx('ocrImage').reopenActionLabel;
      final english = AppUITranslations.translate(label, 'en');
      expect(english, isNot(label),
          reason: 'Nhãn reopen OCR chưa đăng ký catalog → sẽ hiện tiếng Việt '
              'ở locale ≠ vi (vi phạm rule vàng #5)');
      expect(english, 'Rescan image');
    });

    test('đủ ảnh nguồn thì canReopenSource true', () {
      expect(ctx('ocrImage').canReopenSource, isTrue);
    });

    test('sourceType ocr có icon riêng (📷) — không rơi vào default', () {
      expect(ctx('ocrImage').sourceIcon, '📷');
    });
  });

  group('OcrFlow.suggestTitleFor — tiêu đề từ tên ảnh (không hard-code chuỗi Việt)',
      () {
    test('bỏ extension, lấy tên file', () {
      expect(OcrFlow.suggestTitleFor('/storage/emulated/0/DCIMG/trang-12.jpg'),
          'trang-12');
    });

    test('đường dẫn Windows cũng xử lý được', () {
      expect(OcrFlow.suggestTitleFor(r'C:\Users\me\Pictures\scan.png'), 'scan');
    });

    test('cắt ngắn tiêu đề quá dài (giống LocalTextEntryDialog: 48 ký tự)', () {
      final long = 'a' * 80;
      final title = OcrFlow.suggestTitleFor('/x/$long.jpg');
      expect(title.length, lessThanOrEqualTo(51)); // 48 + '...'
      expect(title.endsWith('...'), isTrue);
    });

    test('file không có extension → dùng nguyên tên', () {
      expect(OcrFlow.suggestTitleFor('/x/IMG_0001'), 'IMG_0001');
    });
  });

  group('PSRC-210 — OCR bỏ qua vùng trống và nhiễu mép scan', () {
    Uint8List solidBgra(int w, int h, int gray) {
      final buf = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        buf[i * 4] = gray;
        buf[i * 4 + 1] = gray;
        buf[i * 4 + 2] = gray;
        buf[i * 4 + 3] = 255;
      }
      return buf;
    }

    void paintInkRect(
      Uint8List pixels,
      int imageWidth, {
      required int left,
      required int top,
      required int right,
      required int bottom,
      int gray = 20,
    }) {
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          final off = (y * imageWidth + x) * 4;
          pixels[off] = gray;
          pixels[off + 1] = gray;
          pixels[off + 2] = gray;
          pixels[off + 3] = 255;
        }
      }
    }

    test('trang giấy trắng/xám đồng màu hoặc nhiễu hạt mờ được coi là trống', () {
      final whitePage = solidBgra(400, 600, 252);
      expect(
        isVisuallyBlankBgraBitmap(pixels: whitePage, width: 400, height: 600),
        isTrue,
      );

      // Chỉ một vùng có nét chữ đen rõ ràng trên trang → KHÔNG còn coi là trống
      paintInkRect(
        whitePage,
        400,
        left: 60,
        top: 120,
        right: 180,
        bottom: 136,
        gray: 18,
      );
      expect(
        isVisuallyBlankBgraBitmap(pixels: whitePage, width: 400, height: 600),
        isFalse,
      );
    });

    test('makeOcrBlock loại bỏ khối nằm đè lên vùng trống không có nét mực', () {
      final page = solidBgra(400, 600, 250);
      // Vẽ nét chữ thật ở nửa trên (y: 80..110), để nửa dưới hoàn toàn trống.
      paintInkRect(page, 400, left: 50, top: 88, right: 210, bottom: 100);

      final realBlock = makeOcrBlock(
        text: 'Sabbe saṅkhārā aniccā',
        left: 40,
        top: 80,
        right: 240,
        bottom: 112,
        imageWidth: 400,
        imageHeight: 600,
        bgraPixels: page,
      );
      expect(realBlock, isNotNull);
      expect(realBlock!.text, 'Sabbe saṅkhārā aniccā');

      final ghostOnBlankArea = makeOcrBlock(
        text: 'ao giac vung trong',
        left: 40,
        top: 360,
        right: 260,
        bottom: 410,
        imageWidth: 400,
        imageHeight: 600,
        bgraPixels: page,
      );
      expect(ghostOnBlankArea, isNull,
          reason: 'Khối ML Kit trả về trên vùng nền trống không có độ tương phản phải bị bỏ');
    });

    test('loại bỏ sọc dọc mép scan, bụi < 4px và dòng chỉ toàn dấu nhiễu', () {
      // Sọc đen mép gáy sách 3x500 bị ML Kit đọc nhầm thành "I" hoặc "1"
      expect(
        makeOcrBlock(
          text: 'I',
          left: 2,
          top: 20,
          right: 5,
          bottom: 520,
          imageWidth: 1000,
          imageHeight: 1400,
        ),
        isNull,
      );

      // Hạt bụi nhỏ 2x3
      expect(
        makeOcrBlock(
          text: 'i',
          left: 100,
          top: 100,
          right: 102,
          bottom: 103,
          imageWidth: 1000,
          imageHeight: 1400,
        ),
        isNull,
      );

      // Dòng chỉ có ký tự kẻ dòng / gạch mép trên vùng trống bị lọc sạch, giữ dòng chữ thật
      expect(
        cleanOcrBlockLines('| | |\nChánh niệm tỉnh giác\n. . . .\n---\nÑāṇa'),
        'Chánh niệm tỉnh giác\nÑāṇa',
      );
    });
  });
}

/// Implementation thật của picker — khôi phục sau mỗi test để không rò rỉ
/// stub sang test khác.
final OcrPickImagesFn _realPick = OcrImagePicker.pick;
