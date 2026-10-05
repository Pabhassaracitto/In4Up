// lib/features/pdf_reader/widgets/pdf_page_translate_panel.dart
//
// Panel song ngữ "Dịch màn hình" của PDF Reader (PLAN-035 · KANBAN XLAT-SCR-001).
//
// Ghép phía TRÊN thanh TTS trong Stack của màn hình reader: mỗi câu gốc kèm
// bản dịch ngay dưới (kiểu stacked của TranslationDisplayMode). Đây là "render
// song song" an toàn: không vẽ đè lên trang PDF (overlay theo rect là bước
// nâng cấp ADR-0010 — cần nghiệm thu trên máy thật trước khi tin).
//
// Nguồn dữ liệu: `PdfReaderController.pageTranslations` (cache ~6 trang) +
// trạng thái isTranslatingPage/progress/error — panel thuần hiển thị, không
// tự gọi engine dịch.

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../models/pdf_page_translation.dart';
import '../pdf_reader_controller.dart';

class PdfPageTranslatePanel extends StatelessWidget {
  final PdfReaderController controller;

  /// Load text trang hiện tại vào TextProvider rồi pop reader — dịch TOÀN BỘ
  /// bằng translateAll đã có của Read Mode. Callback của màn hình, không nằm
  /// trong panel để tránh import TextProvider vào đây.
  final VoidCallback? onOpenInReadMode;

  const PdfPageTranslatePanel({
    super.key,
    required this.controller,
    this.onOpenInReadMode,
  });

  @override
  Widget build(BuildContext context) {
    final translations = controller.pageTranslations;
    final translating = controller.isTranslatingPage;

    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF66BB6A).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, translating),
          if (translating && translations.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.uiText('Đang dịch...'),
                    style: TextStyle(color: Colors.grey[400], fontSize: 11.5),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: controller.pageTranslateProgress > 0
                          ? controller.pageTranslateProgress
                          : null,
                      minHeight: 3,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF66BB6A)),
                    ),
                  ),
                ],
              ),
            )
          else if (translations.isEmpty)
            _buildMessage(context)
          else
            Flexible(child: _buildList(translations, translating)),
          if (onOpenInReadMode != null && translations.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0x11FFFFFF)),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onOpenInReadMode!();
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9C8FFF),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: Text(
                  context.uiText('Mở trong Read Mode'),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool translating) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.translate_rounded,
              size: 15, color: Color(0xFF66BB6A)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              context.uiText(
                'Bản dịch · trang ${controller.currentPage + 1}/${controller.totalPages}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (translating)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  value: controller.pageTranslateProgress > 0
                      ? controller.pageTranslateProgress
                      : null,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                ),
              ),
            )
          else if (controller.pageTranslatedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                context.uiText('${controller.pageTranslatedCount} câu'),
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ),
          _HeaderBtn(
            icon: Icons.refresh_rounded,
            tooltip: context.uiText('Dịch lại'),
            onTap: translating
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    controller.translateCurrentPage(force: true);
                  },
          ),
          _HeaderBtn(
            icon: Icons.close_rounded,
            tooltip: context.uiText('Đóng'),
            onTap: () {
              HapticFeedback.selectionClick();
              controller.hidePageTranslatePanel();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context) {
    final error = controller.pageTranslateError;
    if (error == 'page_no_text') {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 26, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'Trang này không có chữ để dịch. Trang scan cần quét OCR trước.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 11.5),
            ),
          ],
        ),
      );
    }
    if (error == 'translate_failed') {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 26, color: Colors.grey[700]),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                'Dịch không thành công — kiểm tra kết nối hoặc cài đặt engine dịch.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 11.5),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Text(
        context.uiText('Chưa có bản dịch cho trang này'),
        style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
      ),
    );
  }

  Widget _buildList(List<PdfPageSentenceTranslation> translations,
      bool translating) {
    // Spinner nhỏ chỉ trên câu ĐANG dịch (câu đầu tiên chưa có bản dịch —
    // kết quả trả về theo thứ tự); các câu sau giữ placeholder trống.
    final firstPending =
        translations.indexWhere((t) => !t.hasTranslation);
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: translations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = translations[index];
        final isTranslatingThis =
            translating && !item.hasTranslation && index == firstPending;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.original,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            if (item.hasTranslation)
              Text(
                item.translation!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              )
            else if (isTranslatingThis)
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.4,
                  valueColor: AlwaysStoppedAnimation(
                      Colors.white.withValues(alpha: 0.35)),
                ),
              )
            else
              Text(
                '—',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _HeaderBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 17,
            color: onTap == null ? Colors.grey[700] : Colors.white70,
          ),
        ),
      ),
    );
  }
}
