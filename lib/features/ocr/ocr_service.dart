// lib/features/ocr/ocr_service.dart
//
// ML Kit Text Recognition v2 (OCR) — ảnh → văn bản, on-device, offline.
// ADR-0009 · KANBAN OCR-001 · PLAN-033.
//
// Luật phiên (bắt buộc — cùng bộ quy tắc với mlkit_engine.dart):
// - KHÔNG tải model lúc bootstrap / main() / ensureModel. OCR model ship kèm
//   Google Play services (Android) và SDK (iOS) nên KHÔNG có bước "Tải về"
//   nào để gọi — khác Translation (phải download model theo cặp ngôn ngữ).
// - Desktop (Windows/Linux) + web: isAvailable() == false → UI ẨN nút OCR.
//   Import file này không crash: plugin chỉ là MethodChannel wrapper.
// - Document Scanner: CHỈ Android (Google Beta, phát qua Play services).
//   Không cần quyền camera — scanner dùng camera của Play services.
//   iOS: chọn ảnh có sẵn qua file_picker, KHÔNG có scanner.
// - OCR là best-effort: kết quả LUÔN đi qua màn preview + ô sửa được
//   (ocr_screen.dart) trước khi nạp vào TextProvider — không nạp thô.
//
// Script: chỉ dùng `TextRecognitionScript.latin`. Tiếng Việt có dấu và
// Pāḷi Roman đều thuộc Latin script → nhận dạng được. ML Kit KHÔNG coi
// Pāḷi là một ngôn ngữ, và các script chinese/devanagiri/japanese/korean
// cần thêm dependency native riêng (chưa cần — ngoài phạm vi ADR-0009).
//
// API package `google_mlkit_text_recognition` (0.16.x — pin vì 0.17.x đòi
// Dart SDK ^3.12, CI là Flutter 3.44.1 / Dart 3.11.5; API 0.16 == 0.17,
// đã đối chiếu source flutter-ml/google_ml_kit_flutter):
//   TextRecognizer(script: TextRecognitionScript.latin).processImage(image)
//     → RecognizedText { text, blocks }
//   InputImage.fromFilePath(path)   (re-export từ google_mlkit_commons)
// `google_mlkit_document_scanner` (0.5.x — 0.6.x đòi Dart ^3.12):
//   DocumentScanner(options: DocumentScannerOptions(...)).scanDocument()
//     → DocumentScanningResult { images: List<String>, pdf }

import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_image_picker.dart';

/// Kết quả một lần nhận dạng chữ từ ảnh.
///
/// [text] là văn bản ĐÃ dọn nhẹ (xuống dòng chuẩn hoá, dòng thừa gộp lại)
/// nhưng VẪN phải cho user xem/sửa trước khi nạp — OCR không đảm bảo đúng
/// chính tả với phông lạ, ảnh mờ, trang nghiêng.
class OcrResult {
  /// Văn bản nhận dạng được (rỗng nếu ảnh không có chữ).
  final String text;

  /// Đường dẫn ảnh NGUỒN đã quét — dùng làm evidence (`localPath`) để giữ
  /// khả năng "mở lại đúng nguồn" (rule vàng #3, AGENTS.md).
  final String? sourceImagePath;

  /// Thời gian nhận dạng (đo để log / hiển thị khi cần chẩn đoán).
  final Duration elapsed;

  /// Thông báo lỗi (tiếng Việt = chuỗi nguồn, UI dịch qua shim/ARB).
  /// null nghĩa là thành công.
  final String? error;

  const OcrResult({
    required this.text,
    this.sourceImagePath,
    this.elapsed = Duration.zero,
    this.error,
  });

  bool get isSuccess => error == null;

  /// True khi chạy xong nhưng ảnh không có chữ nào.
  bool get isEmpty => isSuccess && text.trim().isEmpty;

  factory OcrResult.failure({String? sourceImagePath, required String error}) {
    return OcrResult(text: '', sourceImagePath: sourceImagePath, error: error);
  }
}

/// Nguồn ảnh mà user chọn để OCR.
enum OcrImageSource {
  /// Document Scanner (CHỈ Android): camera + tự dò mép + crop + lọc ảnh.
  documentScanner,

  /// Chọn ảnh đã có trong máy / thư viện ảnh (mọi nền tảng được hỗ trợ).
  gallery,
}

/// OCR on-device bằng ML Kit Text Recognition v2 (script Latin).
///
/// Singleton không trạng thái: mỗi lần gọi tạo `TextRecognizer` riêng rồi
/// `close()` ngay trong `finally` — không giữ instance native sống lâu
/// (tránh rò rỉ tài nguyên ML Kit, cùng bài học với STT native).
class OcrService {
  OcrService._();

  static final OcrService instance = OcrService._();

  /// ML Kit chỉ tồn tại trên Android/iOS. Web + Windows/Linux/macOS → false.
  static bool get platformSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Document Scanner là tính năng Beta CHỈ có trên Android.
  static bool get documentScannerSupported => !kIsWeb && Platform.isAndroid;

  /// UI dùng để quyết định có hiện nút OCR hay không.
  ///
  /// Đồng bộ (không async) để build widget không phải chờ — platform check
  /// là hằng số theo nền tảng.
  bool get isAvailable => platformSupported;

  /// Nguồn ảnh khả dụng trên nền tảng hiện tại (để dựng sheet chọn nguồn).
  List<OcrImageSource> get availableSources => <OcrImageSource>[
        if (documentScannerSupported) OcrImageSource.documentScanner,
        OcrImageSource.gallery,
      ];

  /// Nhận dạng chữ từ một file ảnh đã có trên máy.
  ///
  /// Trả về [OcrResult] — KHÔNG throw: mọi lỗi (file không tồn tại, native
  /// fail, platform không hỗ trợ) đều thành `OcrResult.failure` có thông báo
  /// rõ ràng để UI hiện cho user, không im lặng và không crash.
  Future<OcrResult> recognizeFile(String imagePath) async {
    if (!platformSupported) {
      return OcrResult.failure(
        sourceImagePath: imagePath,
        error: 'OCR chỉ chạy trên Android/iOS',
      );
    }
    if (imagePath.trim().isEmpty) {
      return OcrResult.failure(error: 'Không có ảnh để nhận dạng');
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      return OcrResult.failure(
        sourceImagePath: imagePath,
        error: 'Không tìm thấy ảnh: $imagePath',
      );
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final stopwatch = Stopwatch()..start();
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(input);
      stopwatch.stop();
      final cleaned = normalizeOcrText(recognized.text);
      debugPrint(
        '✅ OCR: ${cleaned.length} ký tự / '
        '${recognized.blocks.length} block trong ${stopwatch.elapsedMilliseconds}ms',
      );
      return OcrResult(
        text: cleaned,
        sourceImagePath: imagePath,
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ OCR recognizeFile: $e');
      return OcrResult.failure(
        sourceImagePath: imagePath,
        error: 'Lỗi nhận dạng chữ: $e',
      );
    } finally {
      // Giống mlkit_engine: close() có thể throw nếu native đã giải phóng.
      await recognizer.close().catchError((_) {});
    }
  }

  /// Nhận dạng chữ từ nhiều ảnh (Document Scanner trả về nhiều trang).
  ///
  /// Các trang ghép bằng một dòng trống — giữ cấu trúc trang để pipeline
  /// ngắt dòng của TextProvider xử lý tự nhiên. Dừng sớm nếu một trang lỗi
  /// để không trả về kết quả nửa vời khó hiểu.
  Future<OcrResult> recognizeFiles(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return OcrResult.failure(error: 'Không có ảnh để nhận dạng');
    }
    if (imagePaths.length == 1) {
      return recognizeFile(imagePaths.first);
    }

    final stopwatch = Stopwatch()..start();
    final pages = <String>[];
    for (final path in imagePaths) {
      final result = await recognizeFile(path);
      if (!result.isSuccess) {
        return OcrResult.failure(sourceImagePath: path, error: result.error!);
      }
      pages.add(result.text);
    }
    stopwatch.stop();
    return OcrResult(
      text: normalizeOcrText(pages.join('\n\n')),
      sourceImagePath: imagePaths.first,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Nhận dạng chữ từ pixels thô BGRA8888 — không cần file ảnh.
  ///
  /// PDF Reader dùng đường này: `PdfPage.render()` của pdfrx trả về
  /// `PdfImage.pixels` = BGRA8888 thô (xem ghi chú đầu
  /// `services/pdf_snapshot_burn.dart`), và `InputImage.fromBitmap` khai đúng
  /// `InputImageFormat.bgra8888` → khớp nhau, không phải encode PNG.
  ///
  /// Native cả Android lẫn iOS đều xử lý type `bitmap` (đã đối chiếu
  /// `MLKVisionImage+FlutterPlugin.m` phía iOS). iOS đọc pixels theo RGBA nên
  /// kênh đỏ/lam bị hoán vị — VÔ HẠI cho OCR vì chữ là đen-trên-trắng.
  ///
  /// `sourceImagePath` = null: không có file ảnh nào tồn tại, nên không có
  /// evidence để reopen (caller phải nói rõ điều này cho user).
  Future<OcrResult> recognizeBitmap({
    required Uint8List pixels,
    required int width,
    required int height,
  }) async {
    if (!platformSupported) {
      return OcrResult.failure(error: 'OCR chỉ chạy trên Android/iOS');
    }
    if (width <= 0 || height <= 0) {
      return OcrResult.failure(error: 'Kích thước ảnh không hợp lệ');
    }
    if (pixels.length != width * height * 4) {
      // Sai độ dài = caller đưa nhầm stride/format. Báo rõ thay vì để native
      // đọc tràn bộ nhớ.
      return OcrResult.failure(
        error: 'Dữ liệu ảnh ${pixels.length} byte không khớp ${width}x$height BGRA',
      );
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final stopwatch = Stopwatch()..start();
    try {
      final input = InputImage.fromBitmap(
        bitmap: pixels,
        width: width,
        height: height,
      );
      final recognized = await recognizer.processImage(input);
      stopwatch.stop();
      final cleaned = normalizeOcrText(recognized.text);
      debugPrint(
        '✅ OCR bitmap ${width}x$height: ${cleaned.length} ký tự trong '
        '${stopwatch.elapsedMilliseconds}ms',
      );
      return OcrResult(text: cleaned, elapsed: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      debugPrint('❌ OCR recognizeBitmap: $e');
      return OcrResult.failure(error: 'Lỗi nhận dạng chữ: $e');
    } finally {
      await recognizer.close().catchError((_) {});
    }
  }

  /// Mở Document Scanner (CHỈ Android) → trả về danh sách ảnh trang đã quét.
  ///
  /// Scanner tự lo camera + dò mép + crop + lọc bóng, và cho phép user nhập
  /// từ thư viện ảnh ngay trong flow của nó (`isGalleryImport: true`).
  /// KHÔNG cần quyền camera từ app (dùng camera của Play services).
  ///
  /// Trả về null khi user hủy. Ném [UnsupportedError] nếu gọi trên nền tảng
  /// không có scanner — UI phải check [documentScannerSupported] trước.
  Future<List<String>?> scanDocumentPages({int pageLimit = 10}) async {
    if (!documentScannerSupported) {
      throw UnsupportedError(
        'Document Scanner chỉ khả dụng trên Android (Google Beta)',
      );
    }

    final options = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full,
      pageLimit: pageLimit,
      isGalleryImport: true,
    );
    final scanner = DocumentScanner(options: options);
    try {
      final result = await scanner.scanDocument();
      // User bấm back/hủy → native trả về kết quả rỗng, không phải exception.
      if (result.images.isEmpty) return null;
      return result.images;
    } catch (e) {
      debugPrint('❌ OCR scanDocumentPages: $e');
      rethrow;
    } finally {
      await scanner.close().catchError((_) {});
    }
  }

  /// Chọn ảnh có sẵn trong máy (mọi nền tảng OCR hỗ trợ).
  ///
  /// Tách ra hàm riêng để UI không phải biết file_picker; trả về null khi
  /// user hủy. Dùng `file_picker` ĐÃ CÓ sẵn trong pubspec (cùng cách
  /// `vocab_image_service.dart` đang chọn ảnh) → không thêm dependency.
  Future<String?> pickImageFromDevice() async {
    return pickImagesFromDevice(allowMultiple: false).then(
      (paths) => paths.isEmpty ? null : paths.first,
    );
  }

  /// Như [pickImageFromDevice] nhưng cho phép chọn nhiều ảnh.
  Future<List<String>> pickImagesFromDevice({bool allowMultiple = true}) async {
    try {
      final result = await OcrImagePicker.pickImages(
        allowMultiple: allowMultiple,
      );
      return result;
    } catch (e) {
      debugPrint('❌ OCR pickImagesFromDevice: $e');
      return const <String>[];
    }
  }

  /// Dọn nhẹ văn bản OCR — THUẦN TUÝ, test được không cần native.
  ///
  /// Chỉ làm những việc KHÔNG thể sai:
  /// - chuẩn hoá xuống dòng (`\r\n`, `\r` → `\n`);
  /// - cắt khoảng trắng thừa cuối mỗi dòng (OCR hay đệm space);
  /// - gộp 3+ dòng trống liên tiếp thành đúng 1 dòng trống (giữ ngắt đoạn);
  /// - trim hai đầu.
  ///
  /// Cố ý KHÔNG nối dòng / KHÔNG đoán đoạn: sách Pāḷi & Pháp thoại có ngắt
  /// dòng có nghĩa (kệ, câu), gộp sai sẽ phá pipeline ngắt câu của TextProvider.
  static String normalizeOcrText(String raw) {
    if (raw.isEmpty) return '';
    final lines = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        // NBSP (U+00A0) hay lẫn trong OCR — đổi hết về space thường, nếu
        // không pipeline ngắt từ của TextProvider sẽ coi nó là một phần của từ.
        .map((line) => line.replaceAll('\u00a0', ' ').trimRight());
    final joined = lines.join('\n');
    // 3+ newline liên tiếp → 2 (tức đúng một dòng trống ngăn đoạn).
    final collapsed = joined.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return collapsed.trim();
  }
}
