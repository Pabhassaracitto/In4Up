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

import 'dart:typed_data' show Uint8List;

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../providers/text_provider.dart';
import 'ocr_cancel_token.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    final token = OcrCancelToken();
    final progress = _OcrProgressHandle.show(context, token);

    final result = await OcrService.instance.recognizeFiles(
      paths,
      cancelToken: token,
    );
    progress.close();

    // Qua await rồi mới đụng context → phải guard (use_build_context_synchronously).
    if (!context.mounted) return false;
    if (_reportInterrupted(context, messenger, result)) return false;
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
    final messenger = ScaffoldMessenger.of(context);
    final token = OcrCancelToken();
    final progress = _OcrProgressHandle.show(context, token);

    final result = await OcrService.instance.recognizeBitmap(
      pixels: pixels,
      width: width,
      height: height,
      cancelToken: token,
    );
    progress.close();

    if (!context.mounted) return false;
    if (_reportInterrupted(context, messenger, result)) return false;
    return presentResult(context, result, suggestedTitle: suggestedTitle);
  }

  /// Hủy / hết giờ KHÔNG phải "lỗi OCR" — nói đúng chuyện rồi dừng, để
  /// `presentResult` chỉ còn lo hai ca thật (có chữ / không có chữ).
  ///
  /// Trả về true nếu đã xử lý xong (caller phải dừng lại).
  static bool _reportInterrupted(
    BuildContext context,
    ScaffoldMessengerState messenger,
    OcrResult result,
  ) {
    if (result.isCancelled) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_tr(context, 'Đã hủy nhận dạng chữ')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    }
    if (result.isTimeout) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_tr(
            context,
            'Quá lâu không nhận dạng xong — thử ảnh nhỏ hơn hoặc rõ hơn',
          )),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    }
    return false;
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

    // Dịch nhãn TRƯỚC khi await: sau await không được đụng context nữa
    // (use_build_context_synchronously). messenger/tp đã capture ở đầu hàm.
    final loadedMessage = _tr(context, 'Đã nạp văn bản từ ảnh');

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
        content: Text(loadedMessage),
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

/// Điều khiển dialog tiến trình: MỘT chỗ mở, MỘT chỗ đóng.
///
/// Trước đây flow gọi thẳng `navigator.pop()` sau khi OCR xong. Nếu dialog đã
/// biến mất vì lý do khác (route bị pop, màn hình đóng) thì lệnh pop đó ăn vào
/// MÀN HÌNH PHÍA DƯỚI — người dùng bị đá khỏi PDF Reader. Handle này nhớ route
/// mình đã đẩy và chỉ gỡ đúng route đó, đúng một lần.
class _OcrProgressHandle {
  _OcrProgressHandle._(this._navigator, this._route);

  final NavigatorState _navigator;
  final DialogRoute<void> _route;
  bool _closed = false;

  static _OcrProgressHandle show(BuildContext context, OcrCancelToken token) {
    final navigator = Navigator.of(context, rootNavigator: true);
    // Giữ theme/locale của cây đang mở (showDialog làm đúng việc này bằng
    // InheritedTheme.capture; ta tự đẩy route nên phải tự capture).
    final themes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      themes: themes,
      builder: (_) => _OcrProgress(onCancel: token.cancel),
    );
    navigator.push(route);
    return _OcrProgressHandle._(navigator, route);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_route.isActive) {
      _navigator.removeRoute(_route);
    }
  }
}

/// Overlay trạng thái đang nhận dạng — chặn tương tác để user không bấm lần 2,
/// NHƯNG luôn có đường thoát: nút Hủy (F2 — không spinner vô hạn).
class _OcrProgress extends StatefulWidget {
  const _OcrProgress({required this.onCancel});

  final VoidCallback onCancel;

  @override
  State<_OcrProgress> createState() => _OcrProgressState();
}

class _OcrProgressState extends State<_OcrProgress> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Nút Back của Android không được pop dialog này: chỉ `close()` của
      // handle mới gỡ route, nếu không trạng thái UI và route lệch nhau.
      canPop: false,
      child: Dialog(
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
                _cancelling ? 'Đang hủy...' : 'Đang nhận dạng chữ...',
                style: TextStyle(color: Colors.grey[300], fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _cancelling
                    ? null
                    : () {
                        setState(() => _cancelling = true);
                        widget.onCancel();
                      },
                child: Text(
                  'Hủy',
                  style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
