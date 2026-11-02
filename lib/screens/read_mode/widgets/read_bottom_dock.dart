// lib/screens/read_mode/widgets/read_bottom_dock.dart
//
// READ-UI-120 (audit v1.20.0) — MỘT dock duy nhất cho tab Đọc.
//
// Thay thế cụm cũ `SmartPlaybackBar + ReadBottomBar` (2 hàng, cuộn ngang im
// lặn, tùy biến nằm trong Setting) bằng:
//
//   * 1 hàng ~44px LUÔN HIỆN (kể cả khi cuộn chữ) — có pill «Đọc», A−/A+,
//     Dịch, IPA, Mark, Từ đã lưu và mũi tên bung/gộp cố định ở cuối;
//   * 1 panel inline khi bung, cao có giới hạn, đúng 1 panel/lần:
//       Đọc | Công cụ đọc | Hiển thị
//
// Hợp đồng kỹ thuật:
//   * KHÔNG AnimatedSize / AnimatedSlide / AnimatedOpacity / ClipRect trên
//     cụm đáy (READ-TOOLBAR-001 v2: khối đen trên GPU Mali/Adreno).
//     Bung/gộp = build điều kiện, đổi cây widget tức thời.
//   * Không tự gọi translateAll() — phát đi qua `startReadPlayback` (P0).
//   * Mọi nhãn đi qua `context.uiText` (quy tắc vàng #5).

import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/core/platform/safe_haptics.dart';
import 'package:provider/provider.dart';

import '../../../features/translation/translation_display_mode.dart';
import '../../../features/translation/translation_toolbar.dart';
import '../../../models/ipa_display_mode.dart';
import '../../../models/read_chrome_layout.dart';
import '../../../providers/text_provider.dart';
import '../controllers/read_mode_controller.dart';
import '../services/playback_controller.dart';
import '../services/read_text_action_runner.dart';
import '../sheets/read_settings_sheet.dart';
import '../sheets/segments_list_sheet.dart';
import 'read_text_action_hooks.dart';
import 'read_top_bar.dart';
import 'smart_playback_bar.dart';

class ReadBottomDock extends StatelessWidget {
  const ReadBottomDock({
    super.key,
    required this.layout,
    required this.onLayoutChanged,
    required this.textActionCallbacks,
    required this.showWordlistPanel,
    required this.onToggleWordlist,
    required this.onOpenSource,
  });

  final ReadChromeLayout layout;
  final ValueChanged<ReadChromeLayout> onLayoutChanged;
  final ReadTextActionCallbacks textActionCallbacks;
  final bool showWordlistPanel;
  final VoidCallback onToggleWordlist;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    if (layout.toolsHidden) return const SizedBox.shrink();

    final tp = context.watch<TextProvider>();
    final playback = context.watch<PlaybackController>();
    final controller = context.watch<ReadModeController>();
    final playing = playback.isRunning || tp.isTtsActive;

    return Container(
      key: const Key('read-bottom-dock'),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1520),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh tiến độ đọc (thay _ReadingProgressBar của ReadBottomBar).
            LinearProgressIndicator(
              value: controller.readingProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(
                  const Color(0xFF2196F3),
                  const Color(0xFF4CAF50),
                  controller.readingProgress,
                )!,
              ),
              minHeight: 3,
            ),
            // ── Hàng chính: LUÔN có, kể cả khi chrome phía trên smart-hide ──
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PlayPill(
                          playing: playing,
                          layout: layout,
                        ),
                        const SizedBox(width: 4),
                        _DockIcon(
                          icon: Icons.text_decrease,
                          tooltip: context.uiText('Cỡ chữ'),
                          onTap: () => tp.setFontSize(tp.fontSize - 2),
                        ),
                        _DockIcon(
                          icon: Icons.text_increase,
                          tooltip: context.uiText('Cỡ chữ'),
                          onTap: () => tp.setFontSize(tp.fontSize + 2),
                        ),
                        _DockIcon(
                          icon: Icons.translate,
                          tooltip: context.uiText('Dịch'),
                          active: tp.showTranslation,
                          onTap: () => tp.setTranslationDisplayMode(
                            tp.showTranslation
                                ? TranslationDisplayMode.hidden
                                : TranslationDisplayMode.stackedBelow,
                          ),
                        ),
                        _DockIcon(
                          icon: Icons.abc,
                          tooltip: context.uiText('Phiên âm / IPA'),
                          active: tp.ipaDisplayMode != IpaDisplayMode.hidden,
                          onTap: () => tp.cycleIpaDisplayMode(),
                        ),
                        _DockIcon(
                          icon: Icons.bookmark_border,
                          tooltip: context.uiText('Đánh dấu'),
                          badge: tp.segments.isEmpty
                              ? null
                              : '${tp.segments.length}',
                          onTap: () => SegmentsListSheet.show(context),
                        ),
                        _DockIcon(
                          icon: showWordlistPanel
                              ? Icons.view_sidebar
                              : Icons.view_sidebar_outlined,
                          tooltip: context.uiText('Từ đã lưu'),
                          active: showWordlistPanel,
                          onTap: onToggleWordlist,
                        ),
                      ],
                    ),
                  ),
                ),
                // Mũi tên cố định: KHÔNG nằm trong vùng cuộn ⇒ trên máy nhỏ
                // vẫn thấy rõ lối vào phần tùy biến (fix cảm nhận "chỉ phát
                // 1 dòng rồi tùy chỉnh biến mất").
                _DockIcon(
                  widgetKey: const Key('read-bottom-dock-expand'),
                  icon: layout.toolsExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  tooltip: context.uiText(
                    layout.toolsExpanded ? 'Thu gọn' : 'Mở rộng',
                  ),
                  active: layout.toolsExpanded,
                  onTap: () {
                    SafeHaptics.selectionClick();
                    var panel = layout.lastPanel;
                    if (layout.displayExpanded) {
                      panel = ReadDockPanel.display;
                    }
                    if (layout.displayHidden &&
                        panel == ReadDockPanel.display) {
                      panel = ReadDockPanel.audio;
                    }
                    onLayoutChanged(layout.collapsedTools(
                      panel: panel,
                      open: !layout.toolsExpanded,
                    ));
                  },
                ),
              ],
            ),
            // ── Panel inline: build ĐIỀU KIỆN, không animation ──
            if (layout.toolsExpanded)
              _DockPanel(
                layout: layout,
                onLayoutChanged: onLayoutChanged,
                textActionCallbacks: textActionCallbacks,
                onOpenSource: onOpenSource,
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PLAY PILL — một cửa vào duy nhất cho cả 2 phạm vi TTS
// ══════════════════════════════════════════════════════════════

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.playing, required this.layout});

  final bool playing;
  final ReadChromeLayout layout;

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TextProvider>();
    final label = context.uiText(playing ? 'Dừng' : 'Đọc');
    return Tooltip(
      message: context.uiText(
        playing
            ? 'Đang đọc — chạm để dừng'
            : (layout.readsWholeDocument
                ? 'Cả bài'
                : 'Đọc dòng hiện tại'),
      ),
      child: Material(
        color: playing
            ? const Color(0xFF6C63FF).withValues(alpha: 0.24)
            : const Color(0xFF6C63FF).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('read-bottom-dock-play'),
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            SafeHaptics.mediumImpact();
            if (playing) {
              // Dừng MỌI phiên TTS (cả preview lẫn cả bài).
              await toggleReadPlayback(context, layout: layout);
              return;
            }
            if (layout.readsWholeDocument) {
              await startReadPlayback(context, layout: layout);
            } else {
              await tp.speakCurrentLine();
            }
          },
          onLongPress: () => showPlaybackPresetSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  playing
                      ? Icons.stop_circle_outlined
                      : Icons.record_voice_over,
                  size: 16,
                  color: const Color(0xFFB8B5FF),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFB8B5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PANEL — 1 panel/lần, cao có trần, cuộn dọc được
// ══════════════════════════════════════════════════════════════

class _DockPanel extends StatelessWidget {
  const _DockPanel({
    required this.layout,
    required this.onLayoutChanged,
    required this.textActionCallbacks,
    required this.onOpenSource,
  });

  final ReadChromeLayout layout;
  final ValueChanged<ReadChromeLayout> onLayoutChanged;
  final ReadTextActionCallbacks textActionCallbacks;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        (MediaQuery.sizeOf(context).height * 0.42).clamp(160.0, 320.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight.toDouble()),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF121827),
          border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelTabs(
              layout: layout,
              onLayoutChanged: onLayoutChanged,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: _panelContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelContent(BuildContext context) {
    switch (layout.lastPanel) {
      case ReadDockPanel.audio:
        return _AudioPanel(
          layout: layout,
          onLayoutChanged: onLayoutChanged,
        );
      case ReadDockPanel.tools:
        return _ToolsPanel(
          textActionCallbacks: textActionCallbacks,
          onOpenSource: onOpenSource,
        );
      case ReadDockPanel.display:
        if (layout.displayHidden) return const SizedBox.shrink();
        return _DisplayPanel(
          layout: layout,
          onLayoutChanged: onLayoutChanged,
        );
    }
    // Phòng thủ: nếu sau này thêm panel mới mà quên case, không crash màn Đọc.
    return const SizedBox.shrink();
  }
}

class _PanelTabs extends StatelessWidget {
  const _PanelTabs({required this.layout, required this.onLayoutChanged});

  final ReadChromeLayout layout;
  final ValueChanged<ReadChromeLayout> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    const entries = <ReadDockPanel, String>{
      ReadDockPanel.audio: 'Đọc',
      ReadDockPanel.tools: 'Công cụ đọc',
      ReadDockPanel.display: 'Hiển thị',
    };
    // Nhóm «Thông tin & Hiển thị» bị Ẩn ⇒ tab của nó cũng biến mất, nhưng
    // 2 tab kia vẫn hoạt động (3 nhóm độc lập, không ẩn cả dock).
    final tabs = entries.entries
        .where((entry) =>
            entry.key != ReadDockPanel.display || !layout.displayHidden)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          for (final entry in tabs) ...[
            if (entry.key != ReadDockPanel.audio) const SizedBox(width: 6),
            Expanded(
              child: _PanelTab(
                label: context.uiText(entry.value),
                selected: layout.lastPanel == entry.key,
                onTap: () => onLayoutChanged(
                  layout.copyWith(lastPanel: entry.key),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelTab extends StatelessWidget {
  const _PanelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Panel Đọc: phạm vi + một bộ thông số TTS ────────────────────

class _AudioPanel extends StatelessWidget {
  const _AudioPanel({required this.layout, required this.onLayoutChanged});

  final ReadChromeLayout layout;
  final ValueChanged<ReadChromeLayout> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: Text(context.uiText('Đọc dòng hiện tại')),
              selected: !layout.readsWholeDocument,
              onSelected: (_) => onLayoutChanged(
                layout.copyWith(
                  playbackScope: ReadPlaybackScope.currentLine,
                ),
              ),
            ),
            ChoiceChip(
              label: Text(context.uiText('Cả bài')),
              selected: layout.readsWholeDocument,
              onSelected: (_) => onLayoutChanged(
                layout.copyWith(
                  playbackScope: ReadPlaybackScope.wholeDocument,
                ),
              ),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.uiText('Tự động dịch khi phát song ngữ'),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          value: layout.autoTranslateOnBilingual,
          onChanged: (v) => onLayoutChanged(
            layout.copyWith(autoTranslateOnBilingual: v),
          ),
        ),
        // Thanh cũ, nhưng KHÔNG vẽ hàng nút chính (dock đã có pill «Đọc»)
        // và bung sẵn pattern builder. Tốc độ/ preset/ chế độ đều ở đây.
        SmartPlaybackBar(
          showMainRow: false,
          forceExpanded: true,
          layout: layout,
        ),
      ],
    );
  }
}

// ── Panel Công cụ: 5 nút context + dòng «Áp dụng cho» + thanh dịch ──

class _ToolsPanel extends StatelessWidget {
  const _ToolsPanel({
    required this.textActionCallbacks,
    required this.onOpenSource,
  });

  final ReadTextActionCallbacks textActionCallbacks;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TextProvider>();
    final target = ReadTextActionRunner.targetFor(tp);
    final scope = target == null
        ? ''
        : context.uiText(
            target.fromSelection ? 'đoạn đang chọn' : 'dòng đang đọc',
          );
    final preview = target == null
        ? ''
        : (target.text.length > 42
            ? '${target.text.substring(0, 42)}…'
            : target.text);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // READ-ACT-001: feedback bắt buộc — dời xuống dock thì phải dời
        // theo, nếu không người dùng không biết đang dịch đoạn nào.
        Text(
          '${context.uiText('Áp dụng cho')}: $scope — $preview',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (onOpenSource != null)
              ActionChip(
                avatar: const Icon(Icons.open_in_new_rounded,
                    size: 13, color: Colors.white70),
                label: Text(context.uiText('Mở nguồn')),
                onPressed: onOpenSource,
              ),
          ],
        ),
        if (target != null)
          ReadTextActionBar(
            selectedText: target.text,
            callbacks: textActionCallbacks,
          ),
        const SizedBox(height: 8),
        // TranslationToolbar chuyển từ tầng chrome TRÊN xuống panel.
        const TranslationToolbar(),
      ],
    );
  }
}

// ── Panel Hiển thị: cấu hình khung đọc (không tác động lên chữ) ──

class _DisplayPanel extends StatelessWidget {
  const _DisplayPanel({required this.layout, required this.onLayoutChanged});

  final ReadChromeLayout layout;
  final ValueChanged<ReadChromeLayout> onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReadModeController>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ActionChip(
              avatar: const Icon(Icons.view_quilt_outlined,
                  size: 13, color: Colors.white70),
              label: Text(context.uiText('Hiển thị')),
              onPressed: () => showReadDisplaySheet(
                context,
                controller: controller,
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.tune, size: 13, color: Colors.white70),
              label: Text(context.uiText('Cài đặt')),
              onPressed: () => ReadSettingsSheet.show(context),
            ),
            ActionChip(
              avatar: Icon(
                controller.isFocusMode
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                size: 13,
                color: Colors.white70,
              ),
              label: Text(context.uiText('Chế độ Focus')),
              onPressed: () => controller.toggleFocusMode(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.uiText('Vị trí công cụ'),
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: [
            ChoiceChip(
              label: Text(context.uiText('Dưới')),
              selected: layout.useBottomDock,
              onSelected: (_) => onLayoutChanged(
                layout.copyWith(
                  toolsPlacement: ReadToolsPlacement.bottom,
                ),
              ),
            ),
            ChoiceChip(
              label: Text(context.uiText('Trên')),
              selected: !layout.useBottomDock,
              onSelected: (_) => onLayoutChanged(
                layout.copyWith(
                  toolsPlacement: ReadToolsPlacement.top,
                ),
              ),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.uiText('Nhớ trạng thái bung'),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          value: layout.rememberExpanded,
          onChanged: (v) =>
              onLayoutChanged(layout.copyWith(rememberExpanded: v)),
        ),
      ],
    );
  }
}

// ── Nút icon gọn ────────────────────────────────────────────────

class _DockIcon extends StatelessWidget {
  const _DockIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.badge,
    this.widgetKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final String? badge;
  final Key? widgetKey;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: widgetKey,
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          SafeHaptics.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? const Color(0xFFB8B5FF) : Colors.white54,
              ),
              if (badge != null)
                Positioned(
                  top: -5,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
