// lib/features/pdf_reader/widgets/pdf_ocr_sheet.dart
//
// Sheet chọn phạm vi quét OCR cho PDF Reader (PLAN-035 · KANBAN PDF-OCR-002).
//
// Trước đây nút "Quét chữ trang này" (thanh TTS) chỉ quét MỘT trang — sách scan
// vài trăm trang phải bấm từng trang. Sheet này cho chọn:
//   Trang hiện tại · Khoảng trang (từ… đến…) · Toàn bộ tài liệu
// kèm toggle "Bỏ qua trang đã có lớp chữ" (mặc định bật) + tổng kết số trang
// sẽ quét + ước lượng thời gian + cảnh báo tài liệu dài.
//
// Sau khi user bấm bắt đầu: sheet pop NGAY (trả `PdfOcrRequest`) và CALLER chạy
// `runPdfOcrBatchFlow` — tách vậy để context dùng cho progress dialog + preview
// là context của màn hình reader (còn sống), không phải context của sheet đã
// pop (dùng context đã dispose là bug use_build_context_synchronously).
//
// Kết quả đi qua `OcrFlow.presentResult` → preview/SỬA (bắt buộc theo
// ADR-0009: OCR là best-effort, không nạp thô) → `TextProvider.loadFromString`
// với `TextSourceType.ocr` — kế thừa nguyên vẹn pipeline phân tích + Read Mode
// có sẵn nút Dịch.

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../../ocr/ocr_cancel_token.dart';
import '../../ocr/ocr_flow.dart';
import '../../ocr/ocr_service.dart';
import '../pdf_reader_controller.dart';
import '../services/pdf_batch_ocr.dart';
import '../services/pdf_page_ocr.dart';

/// Kế hoạch quét user đã xác nhận trong sheet.
class PdfOcrRequest {
  const PdfOcrRequest({
    required this.pages,
    required this.skipPagesWithTextLayer,
  });

  /// Trang sẽ quét (0-based, đã resolve).
  final List<int> pages;

  /// Bỏ qua trang đã có lớp chữ.
  final bool skipPagesWithTextLayer;
}

class PdfOcrSheet extends StatefulWidget {
  final PdfReaderController controller;
  final PdfOcrScope initialScope;

  const PdfOcrSheet({
    super.key,
    required this.controller,
    this.initialScope = PdfOcrScope.currentPage,
  });

  /// Mở sheet. Trả về null khi user đóng; trả về kế hoạch khi bấm bắt đầu.
  static Future<PdfOcrRequest?> show(
    BuildContext context, {
    required PdfReaderController controller,
    PdfOcrScope initialScope = PdfOcrScope.currentPage,
  }) {
    return showModalBottomSheet<PdfOcrRequest>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PdfOcrSheet(
        controller: controller,
        initialScope: initialScope,
      ),
    );
  }

  @override
  State<PdfOcrSheet> createState() => _PdfOcrSheetState();
}

class _PdfOcrSheetState extends State<PdfOcrSheet> {
  PdfOcrScope _scope = PdfOcrScope.currentPage;
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  bool _skipTextLayer = true;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialScope;
    // clamp(1, totalPages) throw khi tài liệu chưa mở xong (totalPages 0) —
    // menu ⋮ có thể được bấm trong lúc loading, sheet không được crash.
    final total = widget.controller.totalPages;
    _fromController = TextEditingController(
      text: '${total > 0 ? (widget.controller.currentPage + 1).clamp(1, total) : 1}',
    );
    _toController = TextEditingController(text: '$total');
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  int get _totalPages => widget.controller.totalPages;

  List<int> get _plannedPages => resolvePdfOcrPages(
        scope: _scope,
        currentPage: widget.controller.currentPage,
        totalPages: _totalPages,
        from: int.tryParse(_fromController.text.trim()),
        to: int.tryParse(_toController.text.trim()),
      );

  /// Số trang sẽ thực sự quét sau khi trừ trang bị bỏ qua KHÔNG tính trước được
  /// (phải dò từng trang) — tổng kết trên UI dùng tổng danh sách kế hoạch.
  int get _plannedCount => _plannedPages.length;

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView: bàn phím (khoảng trang) + màn nhỏ không được làm
    // sheet tràn (overflow vàng-đen); Column min vẫn căn theo nội dung.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.document_scanner_outlined,
                  size: 18, color: Color(0xFF26C6DA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.uiText('Quét OCR'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                context.uiText('Tài liệu ${_totalPages} trang'),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.uiText(
              'Nhận dạng chữ trên trang scan (ảnh) — chạy trên máy, không cần mạng.',
            ),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
          const SizedBox(height: 14),

          _ScopeOption(
            icon: Icons.filter_1_outlined,
            label: context.uiText('Trang hiện tại'),
            detail:
                '${widget.controller.currentPage + 1}',
            selected: _scope == PdfOcrScope.currentPage,
            onTap: () => setState(() => _scope = PdfOcrScope.currentPage),
          ),
          _ScopeOption(
            icon: Icons.format_line_spacing_outlined,
            label: context.uiText('Khoảng trang'),
            selected: _scope == PdfOcrScope.range,
            onTap: () => setState(() => _scope = PdfOcrScope.range),
            trailing: _scope == PdfOcrScope.range
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PageNumberField(
                        controller: _fromController,
                        label: context.uiText('Từ trang'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(width: 8),
                      _PageNumberField(
                        controller: _toController,
                        label: context.uiText('Đến trang'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  )
                : null,
          ),
          _ScopeOption(
            icon: Icons.all_inclusive_outlined,
            label: context.uiText('Toàn bộ tài liệu'),
            selected: _scope == PdfOcrScope.all,
            onTap: () => setState(() => _scope = PdfOcrScope.all),
          ),

          const SizedBox(height: 10),
          // Bỏ qua trang đã có lớp chữ: mặc định BẬT — quét lại trang có chữ
          // chỉ tốn pin để nhận về đúng thứ đang có (cùng bài học F2 của
          // pdf_tts_bar).
          GestureDetector(
            onTap: () => setState(() => _skipTextLayer = !_skipTextLayer),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _skipTextLayer,
                    onChanged: (value) =>
                        setState(() => _skipTextLayer = value ?? true),
                    fillColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFF26C6DA)
                          : Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.uiText('Bỏ qua trang đã có lớp chữ'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _buildSummary(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _plannedCount > 0 ? _start : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF26C6DA),
                foregroundColor: const Color(0xFF06222A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: Text(
                context.uiText('Quét ${_plannedCount} trang'),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_plannedCount == 0) {
      return Text(
        context.uiText('Chọn phạm vi quét hợp lệ (trong 1..$_totalPages).'),
        style: TextStyle(color: Colors.orange[300], fontSize: 11.5),
      );
    }
    final estimatedSeconds = _plannedCount * 3;
    final children = <Widget>[
      Row(
        children: [
          const Icon(Icons.schedule, size: 13, color: Colors.white54),
          const SizedBox(width: 5),
          Text(
            context.uiText(
              'Sẽ quét ${_plannedCount} trang${_plannedCount >= 10 ? ' · ước ~${(estimatedSeconds / 60).ceil()} phút' : ''}',
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],
      ),
    ];
    if (_plannedCount > 40) {
      children.addAll([
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 13, color: Color(0xFFFFB74D)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                context.uiText(
                  'Tài liệu dài — nên quét thử một khoảng nhỏ trước khi quét toàn bộ.',
                ),
                style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11),
              ),
            ),
          ],
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void _start() {
    final pages = _plannedPages;
    if (pages.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      PdfOcrRequest(pages: pages, skipPagesWithTextLayer: _skipTextLayer),
    );
  }
}

/// Chạy batch OCR: progress dialog có Hủy → preview/SỬA → nạp vào TextProvider.
///
/// [context] phải là context của MÀN HÌNH reader (còn sống sau khi sheet pop).
/// Gate nền tảng đã làm ở nút mở sheet — hàm này vẫn tự bảo vệ một lần nữa
/// (defense in depth, cùng nguyên tắc OcrFlow.start).
Future<void> runPdfOcrBatchFlow({
  required BuildContext context,
  required PdfReaderController controller,
  required PdfOcrRequest request,
}) async {
  if (!OcrService.instance.isAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.uiText('OCR chỉ chạy trên Android/iOS')),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  final doc = controller.document;
  if (doc == null || request.pages.isEmpty) return;

  final messenger = ScaffoldMessenger.of(context);
  final token = OcrCancelToken();
  final progress = ValueNotifier<PdfBatchOcrProgress?>(null);
  final stopwatch = Stopwatch()..start();

  final progressRoute = _BatchProgressRoute.show(context, token, progress);
  final outcome = await runPdfBatchOcr(
    pages: request.pages,
    hasTextLayer: controller.pageHasExtractableText,
    skipPagesWithTextLayer: request.skipPagesWithTextLayer,
    cancelToken: token,
    onProgress: (p) => progress.value = p,
    recognize: (pageIndex) => _recognizePage(doc, token, pageIndex),
  );
  progressRoute.close();
  stopwatch.stop();
  if (!context.mounted) return;

  if (outcome.cancelled) {
    // Hủy giữa chừng nhưng ĐÃ có chữ ở các trang trước đó: vẫn đưa vào preview
    // để công sức không mất — user tự quyết giữ hay bỏ. Chỉ khi trống hoàn toàn
    // mới báo "đã hủy".
    if (!outcome.hasText) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.uiText('Đã hủy quét OCR')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
  }

  if (!outcome.hasText) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          outcome.failedCount > 0
              ? context.uiText(
                  'Không quét được chữ nào — ${outcome.failedCount} trang lỗi.',
                )
              : context.uiText(
                  'Không tìm thấy chữ trong các trang đã quét. Thử quét lại trang rõ hơn.',
                ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  await OcrFlow.presentResult(
    context,
    OcrResult(
      text: outcome.joinedText,
      elapsed: stopwatch.elapsed,
    ),
    suggestedTitle: '${controller.displayTitle} · OCR',
  );
}

Future<PdfPageOcrOutcome> _recognizePage(
  PdfDocument doc,
  OcrCancelToken token,
  int pageIndex,
) async {
  final raster = await rasterizePdfPage(doc, pageIndex);
  if (raster == null) {
    return PdfPageOcrOutcome.failure(pageIndex, 'render failed');
  }
  final result = await OcrService.instance.recognizeBitmap(
    pixels: raster.pixels,
    width: raster.width,
    height: raster.height,
    cancelToken: token,
  );
  if (!result.isSuccess) {
    return PdfPageOcrOutcome.failure(pageIndex, result.error ?? 'ocr failed');
  }
  final text = result.text.trim();
  if (text.isEmpty) return PdfPageOcrOutcome.empty(pageIndex);
  return PdfPageOcrOutcome.ok(pageIndex, text);
}

// ── Tiến trình quét ──────────────────────────────────────────────────────

/// Handle route tiến trình: MỘT chỗ mở, MỘT chỗ đóng — copy pattern
/// `_OcrProgressHandle` của ocr_flow.dart (đẩy route thủ công + chỉ gỡ đúng
/// route đó đúng một lần; pop nhầm sẽ đá user khỏi PDF Reader).
class _BatchProgressRoute {
  _BatchProgressRoute._(this._navigator, this._route);

  final NavigatorState _navigator;
  final DialogRoute<void> _route;
  bool _closed = false;

  static _BatchProgressRoute show(
    BuildContext context,
    OcrCancelToken token,
    ValueNotifier<PdfBatchOcrProgress?> progress,
  ) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final themes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      themes: themes,
      builder: (_) => ValueListenableBuilder<PdfBatchOcrProgress?>(
        valueListenable: progress,
        builder: (context, value, _) =>
            _BatchProgressDialog(progress: value, onCancel: token.cancel),
      ),
    );
    navigator.push(route);
    return _BatchProgressRoute._(navigator, route);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_route.isActive) {
      _navigator.removeRoute(_route);
    }
  }
}

class _BatchProgressDialog extends StatefulWidget {
  const _BatchProgressDialog({required this.progress, required this.onCancel});

  final PdfBatchOcrProgress? progress;
  final VoidCallback onCancel;

  @override
  State<_BatchProgressDialog> createState() => _BatchProgressDialogState();
}

class _BatchProgressDialogState extends State<_BatchProgressDialog> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final done = progress?.done ?? 0;
    final total = progress?.total ?? 0;
    return PopScope(
      // Back Android không pop dialog này — chỉ nút Hủy (qua cancel token)
      // được đóng, nếu không route và trạng thái UI lệch nhau.
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
                _cancelling
                    ? context.uiText('Đang hủy...')
                    : context.uiText(
                        'Đang quét trang ${total > 0 ? done : 0}/${total > 0 ? total : '…'}',
                      ),
                style: TextStyle(color: Colors.grey[300], fontSize: 13),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress?.fraction,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF26C6DA)),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _cancelling
                    ? null
                    : () {
                        setState(() => _cancelling = true);
                        widget.onCancel();
                      },
                child: Text(
                  context.uiText('Hủy'),
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

// ── Thành phần nhỏ ────────────────────────────────────────────────────────

class _ScopeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ScopeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF26C6DA).withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF26C6DA).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? const Color(0xFF26C6DA) : Colors.grey[500],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (detail != null) ...[
                Text(
                  detail!,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  const _PageNumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 10),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: Color(0xFF26C6DA)),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
