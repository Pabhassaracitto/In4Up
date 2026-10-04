// Khối "Xuất / nhập chú thích" trong bảng quản lý ghi chú (Wave 2, B1+B2).
//
// StatefulWidget riêng vì nó cần trạng thái `_busy` của riêng nó: chuyển
// `_PdfAnnotationManager` (StatelessWidget, ~200 dòng) sang stateful chỉ để có
// một boolean là cái giá không đáng.
import 'package:in4up/core/language/localized_material.dart';

import '../pdf_reader_controller.dart';
import '../services/pdf_annotation_sidecar.dart' show PdfAnnotationSidecar;
import '../services/pdf_export_service.dart';

class PdfReaderExportRow extends StatefulWidget {
  const PdfReaderExportRow({super.key, required this.controller});

  final PdfReaderController controller;

  @override
  State<PdfReaderExportRow> createState() => _PdfReaderExportRowState();
}

class _PdfReaderExportRowState extends State<PdfReaderExportRow> {
  bool _busy = false;

  /// Kết quả mới nhất, hiện NGAY DƯỚI các nút (không dùng SnackBar: sheet chiếm
  /// 0.88 chiều cao nên snackbar rất dễ bị che).
  String? _message;
  bool _messageIsError = false;

  Future<void> _runExport(PdfExportKind kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    final controller = widget.controller;
    final outcome = await exportPdfReaderData(
      kind: kind,
      pdfPath: controller.pdfPath,
      annotations: controller.annotations,
      lastPageIndex: controller.currentPage,
      document: controller.document,
    );
    if (!mounted) return;
    final count = outcome.count;
    var message = context.uiText(outcome.messageKey) +
        (count > 0 ? ' · $count' : '');
    if (outcome.isTruncated) {
      message = '$message · ${context.uiText('Đã giới hạn số trang xuất')}';
    }
    setState(() {
      _busy = false;
      _message = message;
      _messageIsError = !outcome.isSuccess;
    });
  }

  Future<void> _runImport() async {
    if (_busy) return;
    final controller = widget.controller;
    final identity = controller.identity;
    final result = await pickAndReadSidecar(
      fileSize: identity?.fileSize ?? -1,
      fileModifiedMs: identity?.fileModifiedMs ?? -1,
      pageCount: controller.totalPages,
      dialogTitle: context.uiText('Nhập chú thích'),
    );
    if (!mounted) return;
    if (result.isCancelled) return;
    if (!result.canImport) {
      setState(() => _message = context.uiText(result.problemKey!));
      setState(() => _messageIsError = true);
      return;
    }
    final sidecar = result.sidecar!;
    final confirmed = await _confirmImport(sidecar, result.matchLabelKey);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final added = await controller.importAnnotations(sidecar.annotations);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = '${context.uiText('Đã nhập chú thích')} · +$added';
      _messageIsError = added == 0;
    });
  }

  Future<bool?> _confirmImport(PdfAnnotationSidecar sidecar, String matchKey) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(
            dialogContext.uiText('Nhập chú thích'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      dialogContext.uiText('Số annotation trong tệp'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${sidecar.annotationCount}',
                    style: const TextStyle(
                      color: Color(0xFF9CCC65),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dialogContext.uiText(matchKey),
                style: TextStyle(
                  color: const Color(0xFFFFB74D),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dialogContext.uiText('Highlight đang có sẽ được giữ nguyên.'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                dialogContext.uiText('Huỷ'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.uiText('Nhập')),
            ),
          ],
        );
      },
    );
  }

  Widget _button(String label, VoidCallback? onTap) {
    return OutlinedButton(
      onPressed: _busy ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF64B5F6),
        side: BorderSide(
          color: const Color(0xFF64B5F6).withValues(alpha: 0.35),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        context.uiText(label),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.uiText('Xuất / nhập chú thích'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _button('JSON', () => _runExport(PdfExportKind.sidecarJson)),
            _button('XFDF', () => _runExport(PdfExportKind.xfdf)),
            _button('PDF ảnh', () => _runExport(PdfExportKind.snapshotPdf)),
            _button('Nhập JSON', _runImport),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(
            minHeight: 2,
            color: Color(0xFF64B5F6),
            backgroundColor: Colors.transparent,
          ),
        ] else if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: TextStyle(
              color: _messageIsError
                  ? const Color(0xFFEF9A9A)
                  : const Color(0xFF9CCC65),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
