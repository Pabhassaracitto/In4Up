// lib/screens/read_mode/widgets/read_top_bar.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/core/platform/safe_haptics.dart';

import '../../../models/color_mode.dart';
import '../../../models/ipa_display_mode.dart';
import '../../../providers/text_provider.dart';
import '../../../services/ipa_styling.dart';
import '../../../widgets/collapsible_action_bar.dart';
import '../controllers/read_mode_controller.dart';
import '../sheets/read_settings_sheet.dart';
import 'read_line_hint.dart';
import 'quick_library_sheet.dart'; // ← THÊM

class ReadTopBar extends StatelessWidget {
  const ReadTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    final controller = context.watch<ReadModeController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallHeight = MediaQuery.of(context).size.height < 700;
        final compact = constraints.maxWidth < 620 || isSmallHeight;
        final screenWidth = MediaQuery.sizeOf(context).width;

        // AUDIT-2026-10-20 (mục 2): thanh chức năng TRÊN chuyển sang
        // dạng 2 TẦNG (gộp ⇄ bung bằng mũi tên) — giống thanh phát trong
        // vùng đọc. Trên điện thoại nhỏ, các nút gộp lại chỉ còn ICON ⇒
        // phần chữ của vùng đọc không bị giới hạn nữa; bấm mũi tên để bung
        // ra nhãn khi thật sự cần.
        final showGrammarBadge = screenWidth >= 520 &&
            tp.colorMode == ColorMode.wordType &&
            tp.grammarSettings.enabled;

        final actions = <CollapsibleAction>[
          // 1) Chế độ tô màu (chạm để đổi chế độ)
          CollapsibleAction(
            label: context.uiText(tp.colorMode.label),
            icon: tp.colorMode.icon,
            active: tp.colorMode != ColorMode.none,
            activeColor: const Color(0xFF2196F3),
            badge: showGrammarBadge
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tp.activeGrammarPreset.name,
                      style: const TextStyle(
                        color: Color(0xFFB8B5FF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
            onPressed: () {
              SafeHaptics.selectionClick();
              tp.cycleColorMode();
            },
          ),
          // Hiện/ẩn nhãn A1, N/V hoặc độ khó dưới từng từ để cân bằng
          // độ chi tiết và không gian đọc.
          CollapsibleAction(
            label: context.uiText('Thông tin màu'),
            icon: tp.showColorModeDetails
                ? Icons.label_rounded
                : Icons.label_off_rounded,
            active: tp.showColorModeDetails,
            activeColor: const Color(0xFF64B5F6),
            onPressed: () =>
                tp.setShowColorModeDetails(!tp.showColorModeDetails),
          ),
          // 2) Box từng từ ⇄ bôi nhiều chữ
          CollapsibleAction(
            label: context.uiText('Box từng từ'),
            tooltip: context.uiText(
              tp.wordTapBoxes
                  ? 'Box từng từ — chạm để về bôi nhiều chữ'
                  : 'Bôi nhiều chữ — chạm để box từng từ',
            ),
            icon: tp.wordTapBoxes
                ? Icons.grid_view_rounded
                : Icons.grid_view_outlined,
            active: tp.wordTapBoxes,
            activeColor: const Color(0xFFFF9800),
            onPressed: () {
              SafeHaptics.selectionClick();
              tp.setWordTapBoxes(!tp.wordTapBoxes);
            },
          ),
          // 3) Màu IPA (chỉ khi IPA không ẩn hoàn toàn)
          if (tp.ipaDisplayMode != IpaDisplayMode.hidden)
            CollapsibleAction(
              label: context.uiText('Màu IPA'),
              icon: Icons.palette_outlined,
              active: tp.ipaLegendVisible,
              activeColor: IpaStyling.baseIpaColor,
              onPressed: () => tp.setIpaLegendVisible(!tp.ipaLegendVisible),
            ),
          // 4) Đồng bộ tự động
          CollapsibleAction(
            label: context.uiText('Đồng bộ tự động'),
            icon: controller.autoSyncEnabled
                ? Icons.sync
                : Icons.sync_disabled,
            active: controller.autoSyncEnabled,
            activeColor: const Color(0xFF4CAF50),
            onPressed: () => controller.toggleAutoSync(),
          ),
          // 5) Hướng dẫn đọc theo dòng
          CollapsibleAction(
            label: context.uiText('Hướng dẫn đọc theo dòng'),
            icon: Icons.help_outline,
            onPressed: () => ReadLineHint.showSheet(context),
          ),
          // 6) Cài đặt đọc
          CollapsibleAction(
            label: context.uiText('Cài đặt'),
            icon: Icons.tune,
            onPressed: () => ReadSettingsSheet.show(context),
          ),
          // 7) Chế độ Focus (ẩn thanh trên, giao diện tối giản)
          CollapsibleAction(
            label: context.uiText('Chế độ Focus'),
            icon: controller.isFocusMode
                ? Icons.fullscreen_exit
                : Icons.fullscreen,
            active: controller.isFocusMode,
            onPressed: () => controller.toggleFocusMode(),
          ),
        ];

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isSmallHeight ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleButton(tp: tp, controller: controller),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: CollapsibleActionBar(actions: actions),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _TitleButton(tp: tp, controller: controller),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CollapsibleActionBar(actions: actions),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ── Title Button ──────────────────────────────────────────────
// Bấm → mở QuickLibrarySheet để đổi tài liệu nhanh
class _TitleButton extends StatelessWidget {
  final TextProvider tp;
  final ReadModeController controller;

  const _TitleButton({
    required this.tp,
    required this.controller,
  });

  /// Tên tài liệu hiện tại — cắt ngắn nếu quá dài
  String get _displayTitle {
    // 1. Từ document title
    final docTitle = tp.currentDocument?.title;
    if (docTitle != null && docTitle.isNotEmpty && docTitle != 'Untitled') {
      return docTitle.length > 20 ? '${docTitle.substring(0, 20)}…' : docTitle;
    }

    // 2. Từ file path
    final path = tp.currentTextPath;
    if (path != null) {
      final name = path.split('/').last.split("\\").last;
      final nameNoExt =
          name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
      return nameNoExt.length > 20
          ? '${nameNoExt.substring(0, 20)}…'
          : nameNoExt;
    }

    // 3. Fallback
    return 'Text Studio';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        return Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: GestureDetector(
                onTap: () {
                  SafeHaptics.selectionClick();
                  QuickLibrarySheet.show(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 13,
                        color: Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: Color(0xFF2196F3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  controller.readingProgressText,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Focus title bar (READ-FOCUS-002 / IN4-30) ────────────────────────────
// Chế độ Focus mặc định ẩn TRỌN thanh trên. Người dùng có thể chọn
// chỉ giữ lại PHẦN TIÊU ĐỀ (tên tài liệu) — đặt TRÊN hoặc DƯỚI vùng
// đọc — để vẫn biết đang đọc tài liệu nào mà không mất không gian đọc.
//
// Widget này CHỈ hiện tiêu đề (không kéo theo icon chức năng) — đúng nghĩa
// "chỉ giữ phần tiêu đề".
class ReadFocusTitleBar extends StatelessWidget {
  final TextProvider tp;
  final ReadModeController controller;

  const ReadFocusTitleBar({
    super.key,
    required this.tp,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      color: const Color(0xFF0D1520),
      child: Row(
        children: [
          const Icon(Icons.article_outlined, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(child: _TitleButton(tp: tp, controller: controller)),
        ],
      ),
    );
  }
}
