// lib/features/ocr/ocr_flow.dart
//
// Điều phối toàn bộ luồng OCR (ADR-0009 · KANBAN OCR-001 · PLAN-033):
//
//   chọn nguồn → lấy ảnh → ML Kit Text Recognition → preview/SỬA → nạp
//   vào TextProvider (TextSourceType.ocr, localPath = ẢNH GỐC)
//
// Nạp qua `TextProvider.loadFromString` để KẾ THỪA nguyên vẹn pipeline phân
// tích sẵn có (ngắt dòng, CEFR, SyntaxHighlighter, TextDocument) — không xây
// pipeline song song.
//
// Rule vàng #3: `localPath` giữ đường dẫn ảnh gốc → `currentContextSourceRefType`
// trả 'ocrImage' để chỗ reopen QUÉT LẠI ảnh, không gọi loadTextFile trên JPEG.
//
// Desktop/web: `OcrService.isAvailable == false` → [start] trả về false ngay;
// UI cũng ẩn nút nên bình thường không tới được đây.

import 'dart:async' show unawaited;
import 'dart:typed_data' show Uint8List;

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../providers/text_provider.dart';
import 'ocr_result_dialog.dart';
import 'ocr_service.dart';
import 'ocr_source_sheet.dart';

class OcrFlow {
  OcrFlow._();

  /// Luồng đầy đủ từ đầu: hỏi nguồn → lấy ảnh → OCR → preview → nạp.
  ///
  /// Trả về true khi văn bản đã được nạp vào TextProvider.
  static Future<bool> start(BuildContext context) async {
    final service = OcrService.instance;
    if (!service.isAvailable) {
      _snack(context, 'OCR chỉ chạy trên Android/iOS');
      return false;
    }

    final source = await OcrSourceSheet.show(context);
    if (source == null || !context.mounted) return false;

    final paths = await _acquireImages(context, source);
    if (paths.isEmpty || !context.mounted) return false;

    return runOnImages(context, paths);
  }

  /// OCR một ảnh ĐÃ BIẾT đường dẫn — bỏ qua bước hỏi nguồn.
  ///
  /// PDF Reader dùng đường này khi trang không có text layer
  /// (`PdfReaderController.pageHasNoTextLayer`): render trang ra ảnh rồi đưa
  /// thẳng vào đây.
  static Future<bool> startWithImage(BuildContext context, String imagePath) {
    if (!OcrService.instance.isAvailable) {
      _snack(context, 'OCR chỉ chạy trên Android/iOS');
      return Future.value(false);
    }
    if (imagePath.trim().isEmpty) return Future.value(false);
    return runOnImages(context, <String>[imagePath]);
  }

  /// Phần dùng chung: OCR danh sách ảnh → preview/sửa → nạp.
  static Future<bool> runOnImages(BuildContext context, List<String> paths) async {
    // Capture TRƯỚC mọi await: dùng context sau async là nguồn bug kinh điển
    // (use_build_context_synchronously). Provider read một lần, dùng lại.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // --- Bước nhận dạng: chặn tương tác, hiện trạng thái ---
    // Không await: đóng bằng navigator.pop() ngay sau khi OCR xong.
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OcrProgress(),
    ));

    final result = await OcrService.instance.recognizeFiles(paths);
    navigator.pop(); // đóng progress

    return presentResult(
      context,
      result,
      suggestedTitle: suggestTitleFor(paths.first),
    );
  }

  /// OCR từ pixels thô (BGRA8888) — PDF Reader dùng đường này khi trang không
  /// có text layer: `PdfPage.render()` của pdfrx trả về đúng BGRA8888 thô nên
  /// đưa thẳng vào `InputImage.fromBitmap` được, KHÔNG cần ghi file ảnh tạm
  /// (tránh phải encode PNG trong tiến trình Dart).
  ///
  /// [suggestedTitle] bắt buộc vì không có tên file để suy ra.
  static Future<bool> runOnBitmap(
    BuildContext context, {
    required Uint8List pixels,
    required int width,
    required int height,
    required String suggestedTitle,
  }) async {
    final navigator = Navigator.of(context);

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OcrProgress(),
    ));

    final result = await OcrService.instance
        .recognizeBitmap(pixels: pixels, width: width, height: height);
    navigator.pop();

    return presentResult(context, result, suggestedTitle: suggestedTitle);
  }

  /// Preview + cho user SỬA + nạp vào TextProvider. Tách riêng để cả đường
  /// ảnh-file và đường pixels-PDF dùng chung một hành vi (cùng một chỗ kiểm
  /// soát "không nạp thô").
  ///
  /// `result.sourceImagePath == null` (đường PDF bitmap) → `localPath` null →
  /// vocab lưu từ văn bản này KHÔNG có nút reopen. Đó là degradation trung
  /// thực: không trỏ ref vào một file không tồn tại để rồi bấm không ăn.
  static Future<bool> presentResult(
    BuildContext context,
    OcrResult result, {
    required String suggestedTitle,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final tp = context.read<TextProvider>();

    if (!result.isSuccess) {
      messenger.showSnackBar(
        SnackBar(
          // 'Lỗi: {value0}' đã có trong overrides → uiText dịch được template.
          content: Text(_tr(context, 'Lỗi: ${result.error}')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (result.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_tr(
            context,
            'Không tìm thấy chữ trong ảnh. Thử ảnh rõ hơn, đủ sáng.',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    // --- Preview + cho user sửa trước khi nạp (bắt buộc) ---
    final draft = await OcrResultDialog.show(
      context,
      text: result.text,
      suggestedTitle: suggestedTitle,
      imagePath: result.sourceImagePath,
    );
    if (draft == null) return false;

    tp.loadFromString(
      draft.content,
      title: draft.title,
      sourceType: TextSourceType.ocr,
      // Ảnh gốc = evidence để reopen đúng nguồn (rule vàng #3). Null khi
      // nguồn là pixels PDF (không có file ảnh) — xem doc presentResult.
      localPath: draft.imagePath,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(_tr(context, 'Đã nạp văn bản từ ảnh')),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return true;
  }

  /// Lấy ảnh theo nguồn user chọn. Trả về rỗng nếu user hủy hoặc lỗi.
  static Future<List<String>> _acquireImages(
    BuildContext context,
    OcrImageSource source,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (source == OcrImageSource.documentScanner) {
        final pages = await OcrService.instance.scanDocumentPages();
        return pages ?? const <String>[];
      }
      return await OcrService.instance.pickImagesFromDevice();
    } catch (e) {
      // Scanner có thể fail khi thiết bị thiếu Google Play services bản mới —
      // báo rõ thay vì im lặng, và KHÔNG crash.
      messenger.showSnackBar(
        SnackBar(
          content: Text(_tr(context, 'Lỗi: $e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return const <String>[];
    }
  }

  /// Tiêu đề đề xuất = tên file ảnh bỏ extension.
  ///
  /// Cố ý KHÔNG dùng chuỗi hard-code ('Ảnh mới'…): tên file là nội dung máy,
  /// không phải chrome UI → không cần dịch, và tránh thêm literal phải phân
  /// loại cho generator rule #5.
  static String suggestTitleFor(String imagePath) {
    final name = imagePath.split('/').last.split('\\').last;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final trimmed = base.trim();
    if (trimmed.isEmpty) return name;
    return trimmed.length > 48 ? '${trimmed.substring(0, 48).trim()}...' : trimmed;
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tr(context, message)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Dịch qua shim. Tách ra để dùng lại sau các `await` (context có thể
  /// đã unmount — khi đó trả nguyên chuỗi nguồn, không throw).
  static String _tr(BuildContext context, String source) {
    if (!context.mounted) return source;
    return context.uiText(source);
  }
}

/// Overlay trạng thái đang nhận dạng — chặn tương tác để user không bấm lần 2.
class _OcrProgress extends StatelessWidget {
  const _OcrProgress();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1520),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF26C6DA)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Đang nhận dạng chữ...',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
