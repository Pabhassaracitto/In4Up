// lib/features/ocr/ocr_result_dialog.dart
//
// Màn preview + SỬA ĐƯỢC kết quả OCR trước khi nạp (ADR-0009 · OCR-001).
//
// BẮT BUỘC có bước này: OCR là best-effort — phông lạ, ảnh mờ, trang nghiêng
// đều sinh nhiễu. Nạp thẳng kết quả thô vào TextProvider sẽ đưa rác vào
// pipeline CEFR/POS và vào SRS của người học.
//
// i18n (rule vàng #5): literal tiếng Việt ở đây đều là giá trị `vi` của ARB
// hoặc đã có trong tool/legacy_ui_english_overrides.json ('Nạp vào Đọc',
// 'Hủy', '{value0} từ · {value1} dòng').

import 'dart:io' show File;

import 'package:in4up/core/language/localized_material.dart';

/// Kết quả người dùng đã xác nhận từ [OcrResultDialog].
class OcrDraft {
  /// Văn bản (user có thể đã sửa tay trước khi xác nhận).
  final String content;

  /// Tiêu đề đề xuất (lấy từ tên file ảnh, không phải chuỗi hard-code).
  final String title;

  /// Đường dẫn ẢNH NGUỒN — giữ làm evidence để reopen đúng nguồn
  /// (rule vàng #3).
  final String? imagePath;

  const OcrDraft({
    required this.content,
    required this.title,
    this.imagePath,
  });
}

class OcrResultDialog extends StatefulWidget {
  final String initialText;
  final String? imagePath;
  final String suggestedTitle;

  const OcrResultDialog({
    super.key,
    required this.initialText,
    required this.suggestedTitle,
    this.imagePath,
  });

  /// Mở dialog. Trả về null nếu user hủy.
  static Future<OcrDraft?> show(
    BuildContext context, {
    required String text,
    required String suggestedTitle,
    String? imagePath,
  }) {
    return showDialog<OcrDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OcrResultDialog(
        initialText: text,
        suggestedTitle: suggestedTitle,
        imagePath: imagePath,
      ),
    );
  }

  @override
  State<OcrResultDialog> createState() => _OcrResultDialogState();
}

class _OcrResultDialogState extends State<OcrResultDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final content = _ctrl.text.trim();
    if (content.isEmpty) return;
    Navigator.of(context).pop(
      OcrDraft(
        content: content,
        title: widget.suggestedTitle,
        imagePath: widget.imagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `previewPath` chỉ non-null khi ảnh thật sự đọc được → nhánh render dưới
    // dùng `if (previewPath != null)` là ĐỦ để flow-analysis promote, không cần
    // toán tử `!` (bản cũ viết `File(imagePath!)` bị analyzer bắt
    // unnecessary_non_null_assertion).
    final imagePath = widget.imagePath;
    final String? previewPath =
        imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()
            ? imagePath
            : null;

    return Dialog(
      backgroundColor: const Color(0xFF0D1520),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Header ----
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.text_snippet_outlined,
                      color: Color(0xFF26C6DA),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kết quả quét',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ---- Body ----
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (previewPath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(previewPath),
                          height: 132,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(height: 0),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'Kiểm tra và sửa chữ trước khi nạp',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ctrl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.6,
                      ),
                      maxLines: 14,
                      minLines: 6,
                      decoration: _inputDecoration(),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _ctrl,
                      builder: (_, value, __) {
                        final words = value.text
                            .split(RegExp(r'\s+'))
                            .where((w) => w.isNotEmpty)
                            .length;
                        final lines = value.text
                            .split('\n')
                            .where((l) => l.trim().isNotEmpty)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            // Chuỗi mẫu đã có trong overrides ('{value0} từ ·
                            // {value1} dòng') — dùng uiText để template bắt được.
                            context.uiText('$words từ · $lines dòng'),
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ---- Footer ----
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _ctrl,
                      builder: (_, value, __) {
                        final canSave = value.text.trim().isNotEmpty;
                        return ElevatedButton.icon(
                          onPressed: canSave ? _submit : null,
                          icon: const Icon(Icons.save_alt),
                          label: Text('Nạp vào Đọc'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF26C6DA)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
