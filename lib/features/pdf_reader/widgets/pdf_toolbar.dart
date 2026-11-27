import 'package:in4up/features/tts/widgets/reader_voice_tile.dart';
import 'package:in4up/features/tts/reader_voice_preference.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../../../core/language/app_language.dart';
import '../../../models/color_mode.dart';
import '../../ocr/ocr_service.dart';
import '../../translation/translation_language_picker.dart';
import '../../translation/translation_service.dart';
import '../../tts/engines/tts_engine.dart' show TtsVoice;
import '../../tts/tts_service.dart';
import '../pdf_reader_controller.dart';
import '../../../services/storage_service.dart';
import '../services/pdf_reader_theme.dart';
import '../services/pdf_tts_language.dart';

class PdfToolbar extends StatelessWidget {
  final PdfReaderController controller;
  final String title;
  final VoidCallback? onUserInteraction;
  final VoidCallback? onShowAnnotations;
  final VoidCallback? onOpenGrammarSettings;
  final bool writingMode;
  final VoidCallback? onSendToWriting;

  /// READ-630-04: lưu hàng loạt từ trang hiện tại (chọn nhiều
  /// từ/cụm/câu → 1 chủ đề + ngôn ngữ).
  final VoidCallback? onBatchSavePage;

  /// Mở sheet chọn phạm vi quét OCR (trang hiện tại / khoảng / toàn bộ —
  /// PLAN-035 · PDF-OCR-002). Null = nền tảng không có OCR (ẩn mục menu).
  final VoidCallback? onOpenOcrSheet;

  /// Mở tìm kiếm trong file / mục lục / nhảy nhanh tới trang (Wave 1).
  final VoidCallback? onSearch;
  final VoidCallback? onShowToc;
  final VoidCallback? onJumpToPage;
  final VoidCallback? onShowShortcuts;
  /// Mở bảng chọn chủ đề đọc + độ sáng trang (Wave 1.5).
  final VoidCallback? onShowReaderTheme;
  /// Trạng thái theme hiện tại — chỉ để dòng menu hiển thị nhãn đang chọn.
  final PdfReaderThemeState? readerThemeState;

  const PdfToolbar({
    super.key,
    required this.controller,
    required this.title,
    this.onUserInteraction,
    this.onShowAnnotations,
    this.onOpenGrammarSettings,
    this.writingMode = false,
    this.onSendToWriting,
    this.onBatchSavePage,
    this.onOpenOcrSheet,
    this.onSearch,
    this.onShowToc,
    this.onJumpToPage,
    this.onShowShortcuts,
    this.onShowReaderTheme,
    this.readerThemeState,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  onUserInteraction?.call();
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: context.uiText('Tìm trong file'),
                onPressed: () {
                  onUserInteraction?.call();
                  onSearch?.call();
                },
                icon: const Icon(Icons.search, size: 20, color: Colors.white70),
              ),
              IconButton(
                tooltip: context.uiText('Mục lục'),
                onPressed: () {
                  onUserInteraction?.call();
                  onShowToc?.call();
                },
                icon: const Icon(
                  Icons.list_alt,
                  size: 20,
                  color: Colors.white70,
                ),
              ),
              // Nhãn trang là NÚT: đọc sách dài thì "tới trang 187" nhanh hơn
              // vuốt 187 lần, và đây là lối vào duy nhất khi không có mục lục.
              InkWell(
                onTap: onJumpToPage == null
                    ? null
                    : () {
                        onUserInteraction?.call();
                        onJumpToPage!();
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.uiText('${controller.currentPage + 1} / ${controller.totalPages}'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _ColorModeButton(
                controller: controller,
                onUserInteraction: onUserInteraction,
              ),
              const SizedBox(width: 4),
              _RecallMarkersButton(
                controller: controller,
                onUserInteraction: onUserInteraction,
              ),
              const SizedBox(width: 4),
              // Dịch màn hình (PLAN-035 · XLAT-SCR-001): chỉ có nghĩa ở chế độ
              // xem trang — Text Mode đã có đường "Mở trong Read Mode" với
              // translateAll đầy đủ.
              if (controller.viewMode == PdfViewMode.pdfView) ...[
                _TranslatePageButton(
                  controller: controller,
                  onUserInteraction: onUserInteraction,
                ),
                const SizedBox(width: 4),
              ],
              _ViewModeButton(
                controller: controller,
                onUserInteraction: onUserInteraction,
              ),
              const SizedBox(width: 4),
              _MoreButton(
                controller: controller,
                onUserInteraction: onUserInteraction,
                onShowAnnotations: onShowAnnotations,
                onOpenGrammarSettings: onOpenGrammarSettings,
                onShowShortcuts: onShowShortcuts,
                onShowReaderTheme: onShowReaderTheme,
                readerThemeState: readerThemeState,
                onBatchSavePage: onBatchSavePage,
                onOpenOcrSheet: onOpenOcrSheet,
              ),
            ],
          ),
          if (writingMode) ...[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
              decoration: BoxDecoration(
                color: const Color(0xFF26C6DA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF26C6DA).withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF80DEEA),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Nguồn cho Viết · chọn một đoạn để viết lại hoặc dùng toàn bộ PDF để tóm tắt.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: controller.isDocumentLoaded
                        ? () {
                            onUserInteraction?.call();
                            onSendToWriting?.call();
                          }
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF80DEEA),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text(
                      'Dùng PDF',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Color Mode Button ─────────────────────────────────────

class _ColorModeButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;

  const _ColorModeButton({
    required this.controller,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = controller.colorMode != ColorMode.none;
    final showGrammarBadge =
        controller.colorMode == ColorMode.wordType && controller.grammarSettings.enabled;
    return GestureDetector(
      onTap: () {
        onUserInteraction?.call();
        HapticFeedback.selectionClick();
        controller.cycleColorMode();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Color(0xFF2196F3).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: Color(0xFF2196F3).withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              controller.colorMode.icon,
              size: 13,
              color: isActive ? const Color(0xFF2196F3) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              context.uiText(controller.colorMode.label),
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF2196F3) : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (showGrammarBadge && MediaQuery.of(context).size.width >= 700) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  controller.activeGrammarPreset.name,
                  style: const TextStyle(
                    color: Color(0xFFB8B5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Recall Markers Button (READ-630-03) ───────────────────
/// Bật/tắt marker bao quanh từ đã lưu. Mặc định TẮT (đọc sạch);
/// bật khi cần xem nhanh từ nào đã lưu / có ghi chú / đến kỳ ôn.
class _RecallMarkersButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;

  const _RecallMarkersButton({
    required this.controller,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = controller.showRecallMarkers;
    return Tooltip(
      message: context.uiText(
        isActive
            ? 'Đang hiện vòng tròn quanh từ đã lưu / có ghi chú / đến kỳ ôn'
            : 'Hiện vòng tròn quanh từ đã lưu / có ghi chú / đến kỳ ôn',
      ),
      child: GestureDetector(
        onTap: () {
          onUserInteraction?.call();
          HapticFeedback.selectionClick();
          controller.toggleRecallMarkers();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(9),
            border: isActive
                ? Border.all(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.45))
                : null,
          ),
          child: Icon(
            isActive ? Icons.bookmark_added : Icons.bookmark_add_outlined,
            size: 15,
            color: isActive ? const Color(0xFF66BB6A) : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ── Translate Page Button (Dịch màn hình) ─────────────────

/// Nút "Dịch trang hiện tại" trên toolbar (PLAN-035 · XLAT-SCR-001) — theo
/// đề xuất tư vấn Gemini của owner: một nút trên thanh công cụ, quét segment
/// văn bản đang hiển thị rồi dịch batch qua TranslationService đã có.
class _TranslatePageButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;

  const _TranslatePageButton({
    required this.controller,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final active = controller.pageTranslatePanelVisible;
    final target = TranslationService().targetLanguage;
    final busy = controller.isTranslatingPage;

    // AUDIT v1.30.1 (mục 2) — «nút dịch chưa chọn được ngôn ngữ đích».
    //
    // Trước đây chỉ có một ô vuông: chạm = bật/tắt panel, và ngôn ngữ đích
    // luôn là `TranslationService.targetLang` (mặc định VI, không có lối đổi
    // ngay tại chỗ đọc). Nay nút là MỘT CỤM: [cờ + mã đích] [mũi tên đổi].
    //   • Chạm ô mã  → bật/tắt panel như cũ (không phá thói quen).
    //   • Chạm mũi tên → `showTranslationLanguagePicker` (bảng chọn đích dùng
    //     chung của tab Đọc, có tìm kiếm); đổi xong thì dịch lại trang hiện tại
    //     ngay để bản dịch khớp ngôn ngữ vừa chọn.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            onUserInteraction?.call();
            HapticFeedback.selectionClick();
            controller.togglePageTranslatePanel();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF66BB6A).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
              border: active
                  ? Border.all(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.4))
                  : null,
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate,
                        size: 16,
                        color: active
                            ? const Color(0xFF81C784)
                            : Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        target.flag,
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        target.translationCode,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? const Color(0xFF81C784)
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        GestureDetector(
          onTap: () => _pickTargetLanguage(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF66BB6A).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(8),
              ),
              border: active
                  ? Border.all(
                      color: const Color(0xFF66BB6A).withValues(alpha: 0.4))
                  : null,
            ),
            // Chạm vùng nhỏ 3px vẫn khó ⇒ đệm trong suốt 8px để tổng bề rộng
            // chạm ≥ 24px, vẫn giữ cụm nút gọn trên máy 320px.
            child: const SizedBox(
              width: 14,
              height: 16,
              child: Center(
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mở bảng chọn ngôn ngữ ĐÍCH dùng chung của tab Đọc.
  ///
  /// Nguồn: `TranslationService` đang nhận diện gì trên trang hiện tại —
  /// nhưng đây chỉ là NHÃN hiển thị trong bảng; engine vẫn tự nhận diện từng
  /// câu (`sourceLang: 'AUTO'`), nên đoán sai cũng không làm hỏng bản dịch.
  Future<void> _pickTargetLanguage(BuildContext context) async {
    onUserInteraction?.call();
    HapticFeedback.selectionClick();
    final service = TranslationService();
    final sourceText = controller.selectedText?.trim() ?? '';
    final source = sourceText.isEmpty
        ? AppLanguageCatalog.english
        : service.detectSourceLanguage(sourceText);
    final picked = await showTranslationLanguagePicker(
      context,
      sourceLanguage: source,
      currentTarget: service.targetLanguage,
      accentColor: const Color(0xFF66BB6A),
    );
    if (picked == null) return;
    service.configure(targetLang: picked.translationCode);
    // Lưu bền: `configure()` chỉ đổi RAM (trước đây tab Đọc lưu riêng ở
    // `saveTranslationTargetLanguage`). Không lưu ⇒ mở lại app là quay về VI
    // dù người dùng vừa chọn Nhật cho cả tài liệu.
    final storage = StorageService();
    if (storage.isInitialized) {
      await storage.saveTranslationTargetLanguage(picked.translationCode);
    }
    // Đổi đích ⇒ bản dịch cũ của trang không còn đúng: xoá + dịch lại ngay
    // (nếu panel đang mở) để người dùng thấy kết quả mới, không phải bấm lại.
    await controller.retranslateCurrentPage();
  }
}

// ── View Mode Button ──────────────────────────────────────

class _ViewModeButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;

  const _ViewModeButton({
    required this.controller,
    this.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = controller.viewMode == PdfViewMode.pdfView;
    return GestureDetector(
      onTap: () {
        onUserInteraction?.call();
        HapticFeedback.selectionClick();
        if (isPdf) {
          controller.switchToTextMode();
        } else {
          controller.switchToPdfMode();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isPdf ? Icons.text_fields : Icons.picture_as_pdf,
          size: 16,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// ── More Options ─────────────────────────────────────────

class _MoreButton extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onUserInteraction;
  final VoidCallback? onShowAnnotations;
  final VoidCallback? onOpenGrammarSettings;
  final VoidCallback? onBatchSavePage;
  final VoidCallback? onOpenOcrSheet;
  final VoidCallback? onShowShortcuts;
  final VoidCallback? onShowReaderTheme;
  final PdfReaderThemeState? readerThemeState;

  const _MoreButton({
    required this.controller,
    this.onUserInteraction,
    this.onShowAnnotations,
    this.onOpenGrammarSettings,
    this.onBatchSavePage,
    this.onOpenOcrSheet,
    this.onShowShortcuts,
    this.onShowReaderTheme,
    this.readerThemeState,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onUserInteraction?.call();
        _showOptionsSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_vert, size: 16, color: Colors.white70),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SingleChildScrollView(child: _PdfOptionsSheet(
        controller: controller,
        onShowAnnotations: onShowAnnotations,
        onOpenGrammarSettings: onOpenGrammarSettings,
        onBatchSavePage: onBatchSavePage,
        onOpenOcrSheet: onOpenOcrSheet,
        onShowShortcuts: onShowShortcuts,
        onShowReaderTheme: onShowReaderTheme,
        readerThemeState: readerThemeState,
      )),
    );
  }
}

class _PdfOptionsSheet extends StatelessWidget {
  final PdfReaderController controller;
  final VoidCallback? onShowAnnotations;
  final VoidCallback? onOpenGrammarSettings;
  final VoidCallback? onBatchSavePage;
  final VoidCallback? onOpenOcrSheet;
  final VoidCallback? onShowReaderTheme;
  final PdfReaderThemeState? readerThemeState;
  final VoidCallback? onShowShortcuts;

  const _PdfOptionsSheet({
    required this.controller,
    this.onShowAnnotations,
    this.onOpenGrammarSettings,
    this.onBatchSavePage,
    this.onOpenOcrSheet,
    this.onShowShortcuts,
    this.onShowReaderTheme,
    this.readerThemeState,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          const SizedBox(height: 16),

          const Text('Tùy chọn',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),

          // TTS Language
          const Text('Giọng đọc',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          ListenableBuilder(listenable: controller, builder: (_, __) =>
              _TtsLanguageSelector(controller: controller)),
          const ReaderVoiceTile(TtsReader.pdf),

          const SizedBox(height: 16),

          // TTS Speed
          const Text('Tốc độ đọc',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          _TtsSpeedSlider(controller: controller),

          const SizedBox(height: 8),

          if (controller.colorMode == ColorMode.wordType) ...[
            ListTile(
              leading: const Icon(Icons.auto_awesome_motion, color: Color(0xFF6C63FF)),
              title: const Text(
                'Từ loại chuyên sâu',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                controller.activeGrammarPreset.name,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () {
                Navigator.pop(context);
                onOpenGrammarSettings?.call();
              },
            ),
            const SizedBox(height: 8),
          ],

          // READ-630-04: lưu hàng loạt từ trang hiện tại
          if (onBatchSavePage != null)
            ListTile(
              leading: const Icon(
                Icons.auto_fix_high_outlined,
                color: Color(0xFF4CAF50),
              ),
              title: const Text(
                'Lưu hàng loạt từ trang này',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Chọn nhiều từ/cụm/câu → 1 chủ đề + ngôn ngữ',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                onBatchSavePage?.call();
              },
            ),

          // PLAN-035 · PDF-OCR-002: batch OCR — chọn trang hiện tại / khoảng /
          // toàn bộ tài liệu. Menu này là lối vào KỂ CẢ khi trang hiện tại có
          // lớp chữ (nút trên thanh TTS chỉ hiện khi trang không có chữ).
          if (onOpenOcrSheet != null && OcrService.instance.isAvailable)
            ListTile(
              leading: const Icon(
                Icons.document_scanner_outlined,
                color: Color(0xFF26C6DA),
              ),
              title: Text(
                context.uiText('Quét OCR (trang / toàn bộ)…'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                context.uiText(
                  'Nhận dạng chữ trang scan → nạp vào Text Studio',
                ),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                onOpenOcrSheet?.call();
              },
            ),

          // Wave 1.5: đổi chủ đề đọc là lý do số 1 người ta rời app đọc PDF vệ
          // sinh mắt (ReadEra có menu riêng cho việc này). Ở đây chỉ phủ màu
          // trang + đổi nền quanh trang, KHÔNG đổi chrome ⇒ không lây sang nơi khác.
          if (onShowReaderTheme != null)
            ListTile(
              leading: const Icon(
                Icons.palette_outlined,
                color: Color(0xFFFFB74D),
              ),
              title: Text(
                context.uiText('Chủ đề đọc'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: readerThemeState == null
                  ? null
                  : Text(
                      _readerThemeSubtitle(context, readerThemeState!),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () {
                Navigator.pop(context);
                onShowReaderTheme?.call();
              },
            ),

          // Wave 1.9: phím tắt desktop là tính năng "reader thật" mà người dùng
          // Windows không tự đoán được — phải tra tại chỗ.
          if (onShowShortcuts != null)
            ListTile(
              leading: const Icon(
                Icons.keyboard,
                color: Color(0xFF9CCC65),
              ),
              title: Text(
                context.uiText('Phím tắt'),
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '→ ← Space F T B + − Esc',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.white54),
              onTap: () {
                Navigator.pop(context);
                onShowShortcuts?.call();
              },
            ),

          ListTile(
            leading: Icon(
              controller.hasBookmarkOnPage(controller.currentPage)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: const Color(0xFF64B5F6),
            ),
            title: Text(
              context.uiText(controller.hasBookmarkOnPage(controller.currentPage)
                  ? 'Bỏ đánh dấu trang này'
                  : 'Đánh dấu trang này'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              context.uiText('Tìm lại nhanh trong danh sách Ghi chú & đánh dấu'),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () async {
              final added = !controller.hasBookmarkOnPage(controller.currentPage);
              await controller.toggleBookmark();
              Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(added
                        ? context.uiText('Đã đánh dấu trang này')
                        : context.uiText('Đã bỏ đánh dấu')),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

          // Annotations count
          ListTile(
            leading: const Icon(Icons.note_alt_outlined, color: Colors.amber),
            title: Text(
              context.uiText('${controller.annotations.length} ghi chú'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Mở danh sách để xem, sửa hoặc xoá ghi chú đã lưu',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            trailing: controller.annotations.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.list, color: Colors.grey),
                    onPressed: () {
                      Navigator.pop(context);
                      onShowAnnotations?.call();
                    },
                  ),
            onTap: controller.annotations.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    onShowAnnotations?.call();
                  },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

/// AUDIT v1.30.1 (mục 1) — chọn NGÔN NGỮ ĐỌC trong bảng cài đặt PDF Reader.
///
/// Trước đây khai báo cứng 3 dòng ('auto' + English + Tiếng Việt), cộng thêm
/// một tuỳ chọn «Song ngữ» bị khoá sau `isBilingualTtsAvailable == false` ⇒
/// người đọc tiếng Nhật/Hàn/Trung/Pháp… không có giọng nào để chọn dù
/// `EdgeTtsEngine` đã có sẵn 35 giọng / 17 ngôn ngữ.
///
/// Nay: chip «Tự động» + chip cho NGÔN NGỮ ĐANG DÙNG (nếu khác mặc định) + nút
/// mở bảng chọn đầy đủ theo `AppLanguageCatalog` (26 ngôn ngữ, có tìm kiếm).
/// Bảng chỉ liệt kê ngôn ngữ mà engine hiện có GIỌNG thật — không mời chọn
/// thứ sẽ im lặng.
class _TtsLanguageSelector extends StatelessWidget {
  final PdfReaderController controller;
  const _TtsLanguageSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final currentLabel = pdfTtsLanguageLabel(controller.ttsLanguage);
    final isAuto = currentLabel == null;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TtsLanguageChip(
          label: context.uiText('Tự động'),
          selected: isAuto,
          onTap: () => controller.setTtsLanguage(kPdfTtsAutoCode),
        ),
        if (currentLabel != null)
          _TtsLanguageChip(
            label: currentLabel,
            selected: true,
            onTap: () => _openLanguageSheet(context),
          ),
        _TtsLanguageChip(
          label: context.uiText('Ngôn ngữ khác…'),
          selected: false,
          trailingIcon: Icons.expand_more_rounded,
          onTap: () => _openLanguageSheet(context),
        ),
      ],
    );
  }

  Future<void> _openLanguageSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TtsLanguageSheet(controller: controller),
    );
    if (picked == null) return;
    await controller.setTtsLanguage(picked);
  }
}

class _TtsLanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const _TtsLanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2196F3)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontSize: 12,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 2),
              Icon(
                trailingIcon,
                size: 15,
                color: selected ? Colors.white : Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bảng chọn ngôn ngữ đọc đầy đủ (26 ngôn ngữ, có tìm kiếm).
///
/// Chỉ hiện ngôn ngữ có ít nhất một giọng trong engine đang chọn, để mỗi dòng
/// bấm vào là NGHE ĐƯỢC. Danh sách giọng lấy từ `readerVoiceCatalog` (đã hợp
/// nhất preset + danh sách live của Edge) nên không cần mạng để vẽ bảng.
class _TtsLanguageSheet extends StatefulWidget {
  final PdfReaderController controller;
  const _TtsLanguageSheet({required this.controller});

  @override
  State<_TtsLanguageSheet> createState() => _TtsLanguageSheetState();
}

class _TtsLanguageSheetState extends State<_TtsLanguageSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  Map<String, int>? _voiceCounts;

  @override
  void initState() {
    super.initState();
    _loadVoiceCounts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Đếm số giọng theo `ttsLocale`. Lỗi/không có engine ⇒ `{}` và bảng hiện
  /// đủ 26 ngôn ngữ (chọn vẫn hợp lệ: engine có thể tự tải giọng sau).
  Future<void> _loadVoiceCounts() async {
    Map<String, int> counts = const {};
    try {
      final prefs = TtsService().preferenceFor(TtsReader.pdf);
      final engineId = prefs?.engine ?? '';
      final voices = engineId.isEmpty
          ? const <TtsVoice>[]
          : await TtsService().readerVoiceCatalog(engineId);
      final local = <String, int>{};
      for (final voice in voices) {
        final key = normalizePdfTtsLanguage(voice.language);
        local[key] = (local[key] ?? 0) + 1;
      }
      counts = local;
    } catch (_) {
      counts = const {};
    }
    if (!mounted) return;
    setState(() => _voiceCounts = counts);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final counts = _voiceCounts;
    final options = pdfTtsLanguageOptions().where((language) {
      if (query.isEmpty) return true;
      return language.nativeName.toLowerCase().contains(query) ||
          language.englishName.toLowerCase().contains(query) ||
          language.vietnameseName.toLowerCase().contains(query) ||
          language.translationCode.toLowerCase().contains(query) ||
          language.ttsLocale.toLowerCase().contains(query);
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              context.uiText('Ngôn ngữ đọc'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.uiText('Tìm ngôn ngữ…'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18,
                    color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                _TtsLanguageRow(
                  label: context.uiText('Tự động'),
                  subtitle: context.uiText('Theo ngôn ngữ của tài liệu'),
                  selected: normalizePdfTtsLanguage(widget.controller.ttsLanguage) ==
                      kPdfTtsAutoCode,
                  onTap: () => Navigator.of(context).pop(kPdfTtsAutoCode),
                ),
                for (final language in options)
                  _TtsLanguageRow(
                    label: '${language.flag} ${language.nativeName}',
                    subtitle: counts == null
                        ? language.ttsLocale
                        : '${language.ttsLocale} · '
                            '${counts[language.ttsLocale] ?? 0} '
                            '${context.uiText('giọng')}',
                    selected: normalizePdfTtsLanguage(widget.controller.ttsLanguage) ==
                        language.ttsLocale,
                    onTap: () =>
                        Navigator.of(context).pop(language.ttsLocale),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TtsLanguageRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TtsLanguageRow({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      selected: selected,
      selectedTileColor: const Color(0xFF2196F3).withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF90CAF9) : Colors.white,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF2196F3))
          : null,
    );
  }
}

class _TtsSpeedSlider extends StatelessWidget {
  final PdfReaderController controller;
  const _TtsSpeedSlider({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('0.5x', style: TextStyle(color: Colors.grey, fontSize: 11)),
        Expanded(
          child: Slider(
            value: controller.ttsSpeed,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            activeColor: const Color(0xFF2196F3),
            inactiveColor: Colors.white12,
            onChanged: controller.setTtsSpeed,
          ),
        ),
        Text(
          context.uiText('${controller.ttsSpeed.toStringAsFixed(1)}x'),
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

/// Nhãn chủ đề đọc cho dòng menu: tên theme đã dịch + `%` độ sáng (số, không
/// cần dịch). Ghép ở đây thay vì `uiText('...$x...')` vì chỉ key CHÍNH XÁC mới
/// được duyệt trong catalog (rule #5).
String _readerThemeSubtitle(BuildContext context, PdfReaderThemeState state) {
  final summary = pdfReaderThemeSummary(state);
  final label = context.uiText(summary.labelKey);
  final suffix = summary.suffix;
  return suffix == null ? label : '$label$suffix';
}
