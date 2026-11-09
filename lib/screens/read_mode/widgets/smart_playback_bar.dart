// lib/screens/read_mode/widgets/smart_playback_bar.dart

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/core/platform/safe_haptics.dart';

import '../../../core/language/app_language.dart';
import '../../../models/read_chrome_layout.dart';
import '../../../providers/text_provider.dart';
import '../../../widgets/pulsing_icon.dart';
import '../models/playback_anchor.dart';
import '../models/playback_recipe.dart';
import '../models/playback_snapshot.dart';
import '../services/playback_controller.dart';

// ══════════════════════════════════════════════════════════════
// READ-UI-120 — API công khai cho dock đáy tab Đọc (audit v1.20.0)
// ══════════════════════════════════════════════════════════════
//
// Trước đây `_MainRow` tự giữ `_startPlayback` + `_showPresetSheet` ⇒ dock
// mới không gọi được, và tốc độ có HAI nguồn (`tts_speed` của TextProvider
// và `playback_recipe.speed` của PlaybackController). Từ nay mọi lối vào
// (thanh cũ lẫn dock) đi qua 4 hàm dưới đây.

double clampReadSpeed(double value) => value.clamp(0.5, 2.0).toDouble();

/// Một nguồn sự thật duy nhất về tốc độ: `TextProvider.ttsSpeed`
/// (Hive key `tts_speed`). Controller chỉ giữ bản phản chiếu trong phiên phát.
Future<void> setReadSpeed(BuildContext context, double value) async {
  final tp = context.read<TextProvider>();
  final controller = context.read<PlaybackController>();
  final next = clampReadSpeed(value);
  await tp.setTtsSpeed(next);
  await controller.syncSpeed(next);
}

Future<void> adjustReadSpeed(BuildContext context, double delta) async {
  final tp = context.read<TextProvider>();
  await setReadSpeed(context, tp.ttsSpeed + delta);
}

void _readSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Text(context.uiText(message)),
    ),
  );
}

/// Bấm nút «Đọc» duy nhất: đang phát ⇒ dừng MỌI phiên TTS; chưa phát ⇒ phát
/// ngay (không chờ bản dịch).
Future<void> toggleReadPlayback(
  BuildContext context, {
  required ReadChromeLayout layout,
}) async {
  SafeHaptics.mediumImpact();
  final controller = context.read<PlaybackController>();
  final tp = context.read<TextProvider>();
  if (controller.isRunning || tp.isTtsActive) {
    if (controller.isRunning) {
      controller.stop(fileId: tp.currentDocument?.id ?? 'unknown');
    }
    await tp.stopSpeaking();
    return;
  }
  await startReadPlayback(context, layout: layout);
}

/// Phát cả bài. READ-UI-120 P0: **KHÔNG chặn Play vì chưa dịch xong**.
///
/// `PlaybackEngine` đã có sẵn cờ `hasCurrentTarget` — khi dòng chưa có bản
/// dịch nó tự bỏ qua lượt đích và chỉ đọc nguồn. Vì `tp.lines` là danh sách
/// trực tiếp, bản dịch hoàn tất trong lúc phát sẽ được đọc ở những dòng sau.
Future<void> startReadPlayback(
  BuildContext context, {
  required ReadChromeLayout layout,
}) async {
  final controller = context.read<PlaybackController>();
  final tp = context.read<TextProvider>();
  final recipe = controller.recipe;
  final sourceLanguage = tp.detectedSourceLanguage;
  final targetLanguage = tp.translationTargetLanguage;
  final fileId = tp.currentDocument?.id ?? 'unknown';

  final needsTarget = recipe.mode != PlaybackMode.enOnly;
  final hasTranslations = tp.translatedLineCount > 0;
  PlaybackRecipe? recipeOverride;

  if (needsTarget && !hasTranslations) {
    // `translateAll()` đã có guard `if (_isTranslating) return;` ⇒ không
    // chạy chéo với nút Dịch của TranslationToolbar. KHÔNG await: đây là bản
    // dịch nền, không phải điều kiện tiên quyết của nút Play.
    final autoTranslate = layout.autoTranslateOnBilingual;
    if (recipe.mode == PlaybackMode.viOnly) {
      // `viOnly` mà chưa có bản dịch ⇒ engine im lặng hoàn toàn. Đọc nguồn
      // cho riêng phiên này, KHÔNG ghi đè recipe bền vững của người dùng.
      recipeOverride = recipe.copyWith(
        mode: PlaybackMode.enOnly,
        enRepeats: recipe.enRepeats > 0 ? recipe.enRepeats : 1,
      );
      if (autoTranslate) unawaited(tp.translateAll());
      _readSnack(context, 'Chưa có bản dịch, đang đọc nguồn');
    } else if (autoTranslate) {
      unawaited(tp.translateAll());
      _readSnack(context, 'Đang dịch, sẽ đọc bản dịch khi có');
    }
  }

  void startFrom({PlaybackAnchor? anchor}) {
    unawaited(controller.start(
      tp.lines,
      fileId: fileId,
      sourceLanguageCode: sourceLanguage.translationCode,
      targetLanguageCode: targetLanguage.translationCode,
      anchor: anchor,
      // Nguồn tốc độ duy nhất — không còn đọc từ recipe.speed.
      speed: tp.ttsSpeed,
      recipeOverride: recipeOverride,
    ));
  }

  final anchor = controller.loadAnchor(fileId);
  if (anchor != null) {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => _ResumeDialog(
        anchor: anchor,
        onFromStart: () {
          controller.clearAnchor(fileId);
          startFrom();
        },
        onResume: () => startFrom(anchor: anchor),
      ),
    );
    return;
  }
  startFrom();
}

/// Mở sheet chọn preset — dùng chung cho thanh cũ (long-press ▶) và dock.
void showPlaybackPresetSheet(BuildContext context) {
  SafeHaptics.mediumImpact();
  final controller = context.read<PlaybackController>();
  final tp = context.read<TextProvider>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF0D1520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ChangeNotifierProvider.value(
      value: controller,
      child: _PresetSheet(
        currentRecipe: controller.recipe,
        sourceLanguage: tp.detectedSourceLanguage,
        targetLanguage: tp.translationTargetLanguage,
        onApplySpeed: (speed) => unawaited(setReadSpeed(context, speed)),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// SMART PLAYBACK BAR — Entry point
// ══════════════════════════════════════════════════════════════

class SmartPlaybackBar extends StatelessWidget {
  const SmartPlaybackBar({
    super.key,
    this.showMainRow = true,
    this.forceExpanded = false,
    this.layout = ReadChromeLayout.defaults,
  });

  /// `false` khi nhúng vào panel «Đọc» của dock: dock sở hữu hàng nút chính,
  /// widget này chỉ vẽ LiveStatus + thanh tốc độ + pattern builder.
  final bool showMainRow;

  /// Bung sẵn pattern builder (dùng khi panel audio đang mở).
  final bool forceExpanded;

  final ReadChromeLayout layout;

  @override
  Widget build(BuildContext context) {
    // ★ FIX 1: watch trực tiếp ở đây để trigger rebuild đúng
    final tp = context.watch<TextProvider>();
    if (!tp.hasLyrics) return const SizedBox.shrink();

    return _SmartPlaybackBarContent(
      showMainRow: showMainRow,
      forceExpanded: forceExpanded,
      layout: layout,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CONTENT — StatefulWidget riêng để tránh rebuild conflict
// ══════════════════════════════════════════════════════════════

class _SmartPlaybackBarContent extends StatefulWidget {
  const _SmartPlaybackBarContent({
    required this.showMainRow,
    required this.forceExpanded,
    required this.layout,
  });

  final bool showMainRow;
  final bool forceExpanded;
  final ReadChromeLayout layout;

  @override
  State<_SmartPlaybackBarContent> createState() =>
      _SmartPlaybackBarContentState();
}

class _SmartPlaybackBarContentState extends State<_SmartPlaybackBarContent> {
  late bool _expanded = widget.forceExpanded;
  late bool _showSpeedSlider = !widget.showMainRow;

  // ★ FIX 1: Dùng helper để gọi controller + setState cùng lúc
  void _setExpanded(bool v) => setState(() => _expanded = v);
  void _setShowSlider(bool v) => setState(() => _showSpeedSlider = v);

  @override
  Widget build(BuildContext context) {
    // ★ FIX 1: watch controller TRONG StatefulWidget này
    final controller = context.watch<PlaybackController>();
    final tp = context.watch<TextProvider>();
    final recipe = controller.recipe;
    // READ-UI-120 P0: tốc độ lấy từ MỘT nguồn (TextProvider / `tts_speed`).
    final speed = tp.ttsSpeed;
    final sourceLanguage = tp.detectedSourceLanguage;
    final targetLanguage = tp.translationTargetLanguage;
    final expanded = widget.forceExpanded || _expanded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Live Status (khi đang phát) ──────────────────────
        if (controller.isRunning && controller.snapshot != null)
          _LiveStatusBar(
            snapshot: controller.snapshot!,
            speed: speed,
            controller: controller,
          ),
        if (controller.lastError != null)
          Container(
            width: double.infinity,
            color: Colors.red.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 15),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    context.uiText(controller.lastError!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.clearError,
                  icon: const Icon(Icons.close,
                      color: Colors.white38, size: 15),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

        Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),

        // ── Main bar / panel nhúng trong dock ─────────────────
        Container(
          color: const Color(0xFF0D1520),
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showMainRow)
                _MainRow(
                  controller: controller,
                  tp: tp,
                  recipe: recipe,
                  sourceLanguage: sourceLanguage,
                  targetLanguage: targetLanguage,
                  expanded: expanded,
                  showSpeedSlider: _showSpeedSlider,
                  onToggleExpand: () => _setExpanded(!_expanded),
                  onToggleSlider: () => _setShowSlider(!_showSpeedSlider),
                  layout: widget.layout,
                ),
              if (!widget.showMainRow)
                _DockHeader(
                  speed: speed,
                  sliderVisible: _showSpeedSlider,
                  onToggleSlider: () => _setShowSlider(!_showSpeedSlider),
                ),

              // Speed slider
              if (_showSpeedSlider)
                _SpeedSliderRow(
                  speed: speed,
                  onChanged: (v) => unawaited(setReadSpeed(context, v)),
                  onClose: () => _setShowSlider(false),
                ),

              // Expanded: pattern builder
              if (expanded)
                _PatternBuilder(
                  controller: controller,
                  recipe: recipe,
                  sourceLanguage: sourceLanguage,
                  targetLanguage: targetLanguage,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hàng điều khiển khi [SmartPlaybackBar] được nhúng vào panel «Đọc» của
/// dock: dock đã có nút Play nên ở đây chỉ còn tốc độ + lối vào preset.
/// Không dùng AnimatedSize/AnimatedOpacity (READ-TOOLBAR-001 v2).
class _DockHeader extends StatelessWidget {
  const _DockHeader({
    required this.speed,
    required this.sliderVisible,
    required this.onToggleSlider,
  });

  final double speed;
  final bool sliderVisible;
  final VoidCallback onToggleSlider;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.uiText('Tốc độ'),
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onToggleSlider,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sliderVisible
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${speed.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: Color(0xFFB8B5FF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => showPlaybackPresetSheet(context),
          icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFB8B5FF)),
          label: Text(
            context.uiText('Chọn chế độ học'),
            style: const TextStyle(color: Color(0xFFB8B5FF), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MAIN ROW
// ══════════════════════════════════════════════════════════════

class _MainRow extends StatelessWidget {
  final PlaybackController controller;
  final TextProvider tp;
  final PlaybackRecipe recipe;
  final AppLanguage sourceLanguage;
  final AppLanguage targetLanguage;
  final bool expanded;
  final bool showSpeedSlider;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleSlider;
  final ReadChromeLayout layout;

  const _MainRow({
    required this.controller,
    required this.tp,
    required this.recipe,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.expanded,
    required this.showSpeedSlider,
    required this.onToggleExpand,
    required this.onToggleSlider,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerySmall = constraints.maxWidth < 360;
        final isSmall = constraints.maxWidth < 400;

        // On very small screens, stack vertically to avoid 19px overflow
        if (isVerySmall) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Mode chips
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ModeBtn(
                        label: sourceLanguage.flag,
                        tooltip: context.uiText('Chỉ ${sourceLanguage.nativeName}'),
                        active: recipe.mode == PlaybackMode.enOnly,
                        onTap: () {
                          SafeHaptics.selectionClick();
                          controller.updateRecipe(
                            recipe.copyWith(mode: PlaybackMode.enOnly),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      _ModeBtn(
                        label: '🔄',
                        tooltip: context.uiText('Song ngữ / Xen kẽ'),
                        active: recipe.mode == PlaybackMode.interleaved ||
                            recipe.mode == PlaybackMode.custom,
                        onTap: () {
                          SafeHaptics.selectionClick();
                          if (!tp.translationPairUsesSameLanguage &&
                              tp.translatedLineCount == 0) {
                            unawaited(tp.translateAll());
                          }
                          if (recipe.mode == PlaybackMode.custom) {
                            controller.updateRecipe(
                              recipe.copyWith(mode: PlaybackMode.interleaved),
                            );
                          } else {
                            controller.updateRecipe(
                              recipe.copyWith(mode: PlaybackMode.interleaved),
                            );
                          }
                        },
                        onLongPress: () {
                          SafeHaptics.mediumImpact();
                          controller.updateRecipe(
                            recipe.copyWith(mode: PlaybackMode.custom),
                          );
                          if (!expanded) onToggleExpand();
                        },
                      ),
                      const SizedBox(width: 4),
                      _ModeBtn(
                        label: targetLanguage.flag,
                        tooltip: context.uiText('Chỉ ${targetLanguage.nativeName}'),
                        active: recipe.mode == PlaybackMode.viOnly,
                        onTap: () {
                          SafeHaptics.selectionClick();
                          if (tp.translationPairUsesSameLanguage) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Hãy chọn ngôn ngữ đích khác nguồn.'),
                              ),
                            );
                            return;
                          }
                          if (tp.translatedLineCount == 0) {
                            unawaited(tp.translateAll());
                          }
                          controller.updateRecipe(
                            recipe.copyWith(mode: PlaybackMode.viOnly),
                          );
                        },
                      ),
                    ],
                  ),
                  // Play controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SmallIconBtn(
                        icon: Icons.skip_previous_rounded,
                        color: controller.isRunning ? Colors.white60 : Colors.grey[700]!,
                        onTap: controller.isRunning ? () => controller.skip(-1) : null,
                      ),
                      _PlayBtn(
                        isRunning: controller.isRunning,
                        onTap: () => unawaited(
                          toggleReadPlayback(context, layout: layout),
                        ),
                        onLongPress: () => showPlaybackPresetSheet(context),
                      ),
                      _SmallIconBtn(
                        icon: Icons.skip_next_rounded,
                        color: controller.isRunning ? Colors.white60 : Colors.grey[700]!,
                        onTap: controller.isRunning ? () => controller.skip(1) : null,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SpeedChip(
                    speed: tp.ttsSpeed,
                    onTap: onToggleSlider,
                    onSwipe: (delta) =>
                        unawaited(adjustReadSpeed(context, delta)),
                  ),
                  _SmallIconBtn(
                    icon: expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: expanded ? const Color(0xFF6C63FF) : Colors.grey,
                    onTap: onToggleExpand,
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Mode chips (3 nút trái) ──────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeBtn(
                  label: sourceLanguage.flag,
                  tooltip: context.uiText('Chỉ ${sourceLanguage.nativeName}'),
                  active: recipe.mode == PlaybackMode.enOnly,
                  onTap: () {
                    SafeHaptics.selectionClick();
                    controller.updateRecipe(
                      recipe.copyWith(mode: PlaybackMode.enOnly),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _ModeBtn(
                  label: '🔄',
                  tooltip: context.uiText('Song ngữ / Xen kẽ'),
                  active: recipe.mode == PlaybackMode.interleaved ||
                      recipe.mode == PlaybackMode.custom,
                  onTap: () {
                    SafeHaptics.selectionClick();
                    if (!tp.translationPairUsesSameLanguage &&
                        tp.translatedLineCount == 0) {
                      unawaited(tp.translateAll());
                    }
                    // Toggle: nếu đang ở interleaved → custom, custom → interleaved
                    if (recipe.mode == PlaybackMode.custom) {
                      controller.updateRecipe(
                        recipe.copyWith(mode: PlaybackMode.interleaved),
                      );
                    } else {
                      controller.updateRecipe(
                        recipe.copyWith(mode: PlaybackMode.interleaved),
                      );
                    }
                  },
                  onLongPress: () {
                    // Long press → custom mode + mở expand
                    SafeHaptics.mediumImpact();
                    controller.updateRecipe(
                      recipe.copyWith(mode: PlaybackMode.custom),
                    );
                    if (!expanded) onToggleExpand();
                  },
                ),
                const SizedBox(width: 4),
                _ModeBtn(
                  label: targetLanguage.flag,
                  tooltip: context.uiText('Chỉ ${targetLanguage.nativeName}'),
                  active: recipe.mode == PlaybackMode.viOnly,
                  onTap: () {
                    SafeHaptics.selectionClick();
                    if (tp.translationPairUsesSameLanguage) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hãy chọn ngôn ngữ đích khác nguồn.'),
                        ),
                      );
                      return;
                    }
                    if (tp.translatedLineCount == 0) {
                      unawaited(tp.translateAll());
                    }
                    controller.updateRecipe(
                      recipe.copyWith(mode: PlaybackMode.viOnly),
                    );
                  },
                ),
              ],
            ),

            // ── Navigation + Play ────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prev
                _SmallIconBtn(
                  icon: Icons.skip_previous_rounded,
                  color: controller.isRunning ? Colors.white60 : Colors.grey[700]!,
                  onTap: controller.isRunning ? () => controller.skip(-1) : null,
                ),
                SizedBox(width: isSmall ? 2 : 6),

                // PLAY BUTTON
                _PlayBtn(
                  isRunning: controller.isRunning,
                  onTap: () => unawaited(
                    toggleReadPlayback(context, layout: layout),
                  ),
                  onLongPress: () => showPlaybackPresetSheet(context),
                ),

                SizedBox(width: isSmall ? 2 : 6),

                // Next
                _SmallIconBtn(
                  icon: Icons.skip_next_rounded,
                  color: controller.isRunning ? Colors.white60 : Colors.grey[700]!,
                  onTap: controller.isRunning ? () => controller.skip(1) : null,
                ),
              ],
            ),

            // ── Right controls ───────────────────────────────────
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Speed chip (tap = slider, swipe = ±0.25x)
                _SpeedChip(
                  speed: tp.ttsSpeed,
                  onTap: onToggleSlider,
                  onSwipe: (delta) =>
                      unawaited(adjustReadSpeed(context, delta)),
                ),
                const SizedBox(width: 6),

                // Expand toggle
                _SmallIconBtn(
                  icon: expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  color: expanded ? const Color(0xFF6C63FF) : Colors.grey,
                  onTap: onToggleExpand,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

}

// ══════════════════════════════════════════════════════════════
// PATTERN BUILDER — Tầng 2 (hiện khi expand)
// ══════════════════════════════════════════════════════════════

class _PatternBuilder extends StatelessWidget {
  final PlaybackController controller;
  final PlaybackRecipe recipe;
  final AppLanguage sourceLanguage;
  final AppLanguage targetLanguage;

  const _PatternBuilder({
    required this.controller,
    required this.recipe,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Hàng 1: Lặp câu + Vòng bài ─────────────────────
          // Fix overflow 35px trên màn hình nhỏ: dùng Wrap
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Label('Lặp câu'),
              _Stepper(
                value: recipe.lineRepeats,
                min: 1,
                max: 5,
                suffix: 'lần',
                onChanged: (v) => controller.updateRecipe(
                  recipe.copyWith(lineRepeats: v),
                ),
              ),
              _Label('Vòng bài'),
              _Stepper(
                value: recipe.totalPasses == 0 ? 1 : recipe.totalPasses,
                min: 1,
                max: 10,
                suffix: recipe.totalPasses == 0 ? '∞' : 'lần',
                onChanged: (v) => controller.updateRecipe(
                  recipe.copyWith(totalPasses: v),
                ),
              ),
              _ToggleChip(
                label: '∞',
                active: recipe.totalPasses == 0,
                onTap: () => controller.updateRecipe(
                  recipe.copyWith(
                    totalPasses: recipe.totalPasses == 0 ? 1 : 0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Hàng 2: Pattern nguồn → đích (LUÔN HIỆN) ────────────
          // ★ FIX 2: Luôn hiện stepper nguồn/đích bất kể mode
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual pattern display
              _PatternVisual(
                recipe: recipe,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
              ),
              const SizedBox(height: 8),

              // Fix overflow 19px: Nguồn/đích dùng Wrap
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Label(
                    '${sourceLanguage.flag} ${sourceLanguage.translationCode}',
                  ),
                  _Stepper(
                    value: recipe.enRepeats.clamp(0, 5),
                    min: 0,
                    max: 5,
                    suffix: '×',
                    onChanged: (v) {
                      final newMode = _resolveMode(v, recipe.viRepeats);
                      controller.updateRecipe(
                        recipe.copyWith(enRepeats: v, mode: newMode),
                      );
                    },
                  ),
                  const Text('→',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  _Label(
                    '${targetLanguage.flag} ${targetLanguage.translationCode}',
                  ),
                  _Stepper(
                    value: recipe.viRepeats.clamp(0, 3),
                    min: 0,
                    max: 3,
                    suffix: '×',
                    onChanged: (v) {
                      final newMode = _resolveMode(recipe.enRepeats, v);
                      controller.updateRecipe(
                        recipe.copyWith(viRepeats: v, mode: newMode),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Hàng 3: Khoảng lặng (chỉ khi có bản dịch) ────────────
          // Fix overflow: dùng Wrap
          if (recipe.viRepeats > 0) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Label('Khoảng lặng'),
                ...SilenceGap.values.map((gap) => _ToggleChip(
                      label: gap.label,
                      active: recipe.silenceGap == gap,
                      onTap: () => controller.updateRecipe(
                        recipe.copyWith(silenceGap: gap),
                      ),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ★ FIX 2: Auto-resolve mode dựa trên số lượt nguồn/đích
  PlaybackMode _resolveMode(int enRep, int viRep) {
    if (enRep > 0 && viRep == 0) return PlaybackMode.enOnly;
    if (enRep == 0 && viRep > 0) return PlaybackMode.viOnly;
    if (enRep == 1 && viRep == 1) return PlaybackMode.interleaved;
    return PlaybackMode.custom; // nguồn×2→đích×1, v.v., etc.
  }
}

// ══════════════════════════════════════════════════════════════
// PATTERN VISUAL — Hiển thị công thức trực quan
// ══════════════════════════════════════════════════════════════

class _PatternVisual extends StatelessWidget {
  final PlaybackRecipe recipe;
  final AppLanguage sourceLanguage;
  final AppLanguage targetLanguage;

  const _PatternVisual({
    required this.recipe,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  Widget build(BuildContext context) {
    // Tạo sequence dots: 🔵🔵🔵 → 🟠
    final List<Widget> dots = [];

    // Source dots
    for (int i = 0; i < recipe.enRepeats.clamp(0, 5); i++) {
      dots.add(_Dot(color: const Color(0xFF3B82F6)));
      dots.add(const SizedBox(width: 3));
    }

    // Arrow + target dots
    if (recipe.viRepeats > 0 && recipe.enRepeats > 0) {
      dots.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('→', style: TextStyle(color: Colors.grey, fontSize: 11)),
      ));
    }

    for (int i = 0; i < recipe.viRepeats.clamp(0, 3); i++) {
      dots.add(_Dot(color: const Color(0xFFEF4444)));
      dots.add(const SizedBox(width: 3));
    }

    // Label
    String label;
    switch (recipe.mode) {
      case PlaybackMode.enOnly:
        label = 'Chỉ ${sourceLanguage.nativeName}';
        break;
      case PlaybackMode.viOnly:
        label = 'Chỉ ${targetLanguage.nativeName}';
        break;
      case PlaybackMode.interleaved:
        label = 'Song ngữ ${sourceLanguage.translationCode} → '
            '${targetLanguage.translationCode}';
        break;
      case PlaybackMode.custom:
        label = '${sourceLanguage.translationCode}×${recipe.enRepeats} → '
            '${targetLanguage.translationCode}×${recipe.viRepeats}';
        break;
    }

    return Row(
      children: [
        ...dots,
        const SizedBox(width: 8),
        Text(
          context.uiText(label),
          style: const TextStyle(
            color: Color(0xFFA5B4FC),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LIVE STATUS BAR
// ══════════════════════════════════════════════════════════════

class _LiveStatusBar extends StatelessWidget {
  final PlaybackSnapshot snapshot;
  final double speed;
  final PlaybackController controller;

  const _LiveStatusBar({
    required this.snapshot,
    required this.speed,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -300) unawaited(adjustReadSpeed(context, 0.25));
        if (v > 300) unawaited(adjustReadSpeed(context, -0.25));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        color: const Color(0xFF080B1A),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Lang badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: snapshot.isSource
                        ? Color(0xFF3B82F6).withValues(alpha: 0.2)
                        : Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    snapshot.activeLanguage.compactLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: snapshot.isSource
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.uiText(snapshot.statusText),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Speed tap to reset
                GestureDetector(
                  onTap: () {
                    if ((speed - 1.0).abs() > 0.01) {
                      unawaited(adjustReadSpeed(context, 1.0 - speed));
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (speed - 1.0).abs() > 0.01
                          ? Color(0xFF6C63FF).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      context.uiText('${speed.toStringAsFixed(2)}x'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: (speed - 1.0).abs() > 0.01
                            ? const Color(0xFFA5B4FC)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            LinearProgressIndicator(
              value: snapshot.lineProgress,
              minHeight: 2,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(
                snapshot.isSource
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PRESET SHEET (long-press Play)
// ══════════════════════════════════════════════════════════════

class _PresetSheet extends StatelessWidget {
  final PlaybackRecipe currentRecipe;
  final AppLanguage sourceLanguage;
  final AppLanguage targetLanguage;

  /// READ-UI-120 P0: preset có tốc độ riêng (quiz/shadowing 0.75x) ⇒ áp
  /// luôn vào nguồn tốc độ duy nhất, không để `recipe.speed` tách ra lần nữa.
  final ValueChanged<double>? onApplySpeed;

  const _PresetSheet({
    required this.currentRecipe,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.onApplySpeed,
  });

  List<({String icon, String label, String sub, PlaybackRecipe recipe})>
      get _presets => [
            (
              icon: sourceLanguage.flag,
              label: 'Chỉ ${sourceLanguage.translationCode}',
              sub: 'Luyện nghe thuần ${sourceLanguage.nativeName}',
              recipe: PlaybackRecipe.enOnly,
            ),
            (
              icon: '🔄',
              label: 'Song ngữ',
              sub: '${sourceLanguage.translationCode} → nghĩ → '
                  '${targetLanguage.translationCode} (1:1)',
              recipe: PlaybackRecipe.bilingual,
            ),
            (
              icon: '⚡',
              label: '${sourceLanguage.translationCode}×2 → '
                  '${targetLanguage.translationCode}×1',
              sub: 'Nghe kỹ nguồn rồi xác nhận bản dịch',
              recipe: PlaybackRecipe.intensive,
            ),
            (
              icon: '🎯',
              label: 'Tự kiểm tra',
              sub: '${sourceLanguage.translationCode} → 3 giây → '
                  '${targetLanguage.translationCode}',
              recipe: PlaybackRecipe.quiz,
            ),
            (
              icon: '🔊',
              label: 'Shadowing',
              sub: '${sourceLanguage.translationCode}×3 chậm 0.75x',
              recipe: PlaybackRecipe.shadowing,
            ),
            (
              icon: targetLanguage.flag,
              label: 'Chỉ ${targetLanguage.translationCode}',
              sub: 'Nghe bản dịch ${targetLanguage.nativeName}',
              recipe: PlaybackRecipe.viOnly,
            ),
          ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlaybackController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Chọn chế độ học',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Hint: long-press ↔ để custom
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0xFF6C63FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Giữ 🔄 để tuỳ chỉnh',
                  style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._presets.map((p) {
            final isActive = controller.recipe == p.recipe;
            return GestureDetector(
              onTap: () {
                SafeHaptics.selectionClick();
                onApplySpeed?.call(p.recipe.speed);
                unawaited(controller.updateRecipe(
                  p.recipe.copyWith(speed: p.recipe.speed),
                ));
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? Color(0xFF6C63FF).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isActive ? const Color(0xFF6C63FF) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(p.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.uiText(p.label),
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            context.uiText(p.sub),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      const Icon(Icons.check_circle,
                          color: Color(0xFF6C63FF), size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RESUME DIALOG
// ══════════════════════════════════════════════════════════════

class _ResumeDialog extends StatelessWidget {
  final PlaybackAnchor anchor;
  final VoidCallback onFromStart;
  final VoidCallback onResume;

  const _ResumeDialog({
    required this.anchor,
    required this.onFromStart,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('▶ Tiếp tục phát?',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Text(
        context.uiText(
          'Câu ${anchor.lineIndex + 1}  •  ${context.uiText(anchor.ageText)}',
        ),
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onFromStart();
          },
          child: const Text('Từ đầu', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onResume();
          },
          child: const Text('Tiếp tục',
              style: TextStyle(color: Color(0xFF6C63FF))),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ATOMIC WIDGETS
// ══════════════════════════════════════════════════════════════

class _PlayBtn extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PlayBtn({
    required this.isRunning,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // AUDIT-2026-10-20 (mục 6): icon loa "đang phát" phải **sống** — nhấp
    // nháy + đổi màu đỏ (đổi sang nút DỪNG) ⇒ user thấy ngay app đang phát
    // thay vì bấm xong không biết có chạy không. Chạm lần 2 ⇒ dừng (đã có).
    final button = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isRunning ? const Color(0xFFEF4444) : const Color(0xFF6C63FF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isRunning
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF6C63FF))
                  .withValues(alpha: isRunning ? 0.55 : 0.4),
              blurRadius: isRunning ? 14 : 10,
              spreadRadius: isRunning ? 2 : 1,
            ),
          ],
        ),
        child: PulsingIcon(
          icon: isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 28,
          active: isRunning,
          maxScale: 1.12,
        ),
      ),
    );
    return Tooltip(
      message: isRunning
          ? context.uiText('Đang phát — chạm để dừng')
          : context.uiText('Phát âm thanh'),
      child: button,
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ModeBtn({
    required this.label,
    required this.active,
    required this.tooltip,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.uiText(tooltip),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? Color(0xFF6C63FF).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? const Color(0xFF6C63FF) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final VoidCallback onTap;
  final ValueChanged<double> onSwipe;

  const _SpeedChip({
    required this.speed,
    required this.onTap,
    required this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final modified = (speed - 1.0).abs() > 0.01;
    return GestureDetector(
      onTap: onTap,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -300) onSwipe(0.25);
        if (v > 300) onSwipe(-0.25);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: modified
              ? Color(0xFF6C63FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: modified ? const Color(0xFF6C63FF) : Colors.transparent,
          ),
        ),
        child: Text(
          context.uiText('${speed.toStringAsFixed(2)}x'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: modified ? const Color(0xFFA5B4FC) : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _SpeedSliderRow extends StatelessWidget {
  final double speed;
  final ValueChanged<double> onChanged;
  final VoidCallback onClose;

  const _SpeedSliderRow({
    required this.speed,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Text('0.5x',
              style: TextStyle(color: Colors.grey, fontSize: 9)),
          const SizedBox(width: 4),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: speed,
                min: 0.5,
                max: 2.0,
                divisions: 6,
                label: '${speed.toStringAsFixed(2)}x',
                activeColor: const Color(0xFF6C63FF),
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text('2.0x',
              style: TextStyle(color: Colors.grey, fontSize: 9)),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onClose,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6C63FF)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? const Color(0xFF6C63FF)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.grey, fontSize: 11),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ★ FIX 1: InkWell thay vì GestureDetector để có ripple + phản ứng ngay
        _StepBtn(
          icon: Icons.remove,
          enabled: value > min,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            context.uiText('$value'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StepBtn(
          icon: Icons.add,
          enabled: value < max,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
        if (suffix.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Text(
              suffix,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _StepBtn({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ★ FIX 1: Dùng Material + InkWell để có phản ứng visual ngay lập tức
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Color(0xFF6C63FF).withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? Colors.white70 : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const _SmallIconBtn({
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
