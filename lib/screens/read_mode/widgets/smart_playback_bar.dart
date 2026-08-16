// lib/screens/read_mode/widgets/smart_playback_bar.dart

import 'dart:async';

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/language/app_language.dart';
import '../../../providers/text_provider.dart';
import '../models/playback_anchor.dart';
import '../models/playback_recipe.dart';
import '../models/playback_snapshot.dart';
import '../services/playback_controller.dart';

// ══════════════════════════════════════════════════════════════
// SMART PLAYBACK BAR — Entry point
// ══════════════════════════════════════════════════════════════

class SmartPlaybackBar extends StatelessWidget {
  const SmartPlaybackBar({super.key});

  @override
  Widget build(BuildContext context) {
    // ★ FIX 1: watch trực tiếp ở đây để trigger rebuild đúng
    final tp = context.watch<TextProvider>();
    if (!tp.hasLyrics) return const SizedBox.shrink();

    return const _SmartPlaybackBarContent();
  }
}

// ══════════════════════════════════════════════════════════════
// CONTENT — StatefulWidget riêng để tránh rebuild conflict
// ══════════════════════════════════════════════════════════════

class _SmartPlaybackBarContent extends StatefulWidget {
  const _SmartPlaybackBarContent();

  @override
  State<_SmartPlaybackBarContent> createState() =>
      _SmartPlaybackBarContentState();
}

class _SmartPlaybackBarContentState extends State<_SmartPlaybackBarContent> {
  bool _expanded = false;
  bool _showSpeedSlider = false;

  // ★ FIX 1: Dùng helper để gọi controller + setState cùng lúc
  void _setExpanded(bool v) => setState(() => _expanded = v);
  void _setShowSlider(bool v) => setState(() => _showSpeedSlider = v);

  @override
  Widget build(BuildContext context) {
    // ★ FIX 1: watch controller TRONG StatefulWidget này
    final controller = context.watch<PlaybackController>();
    final tp = context.watch<TextProvider>();
    final recipe = controller.recipe;
    final sourceLanguage = tp.detectedSourceLanguage;
    final targetLanguage = tp.translationTargetLanguage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Live Status (khi đang phát) ──────────────────────
        if (controller.isRunning && controller.snapshot != null)
          _LiveStatusBar(
            snapshot: controller.snapshot!,
            speed: recipe.speed,
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

        // ── Main bar ─────────────────────────────────────────
        Container(
          color: const Color(0xFF0D1520),
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row chính
              _MainRow(
                controller: controller,
                tp: tp,
                recipe: recipe,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                expanded: _expanded,
                showSpeedSlider: _showSpeedSlider,
                onToggleExpand: () => _setExpanded(!_expanded),
                onToggleSlider: () => _setShowSlider(!_showSpeedSlider),
              ),

              // Speed slider
              if (_showSpeedSlider)
                _SpeedSliderRow(
                  speed: recipe.speed,
                  onChanged: (v) {
                    final delta = v - recipe.speed;
                    controller.adjustSpeed(delta);
                  },
                  onClose: () => _setShowSlider(false),
                ),

              // Expanded: pattern builder
              if (_expanded)
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
  });

  @override
  Widget build(BuildContext context) {
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
                HapticFeedback.selectionClick();
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
                HapticFeedback.selectionClick();
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
                HapticFeedback.mediumImpact();
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
                HapticFeedback.selectionClick();
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
            const SizedBox(width: 6),

            // PLAY BUTTON
            _PlayBtn(
              isRunning: controller.isRunning,
              onTap: () => _onPlayTap(context),
              onLongPress: () => _showPresetSheet(context),
            ),

            const SizedBox(width: 6),

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
              speed: recipe.speed,
              onTap: onToggleSlider,
              onSwipe: (delta) => controller.adjustSpeed(delta),
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
  }

  // ── Handlers ────────────────────────────────────────────────

  void _onPlayTap(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (controller.isRunning) {
      controller.stop(fileId: tp.currentDocument?.id ?? 'unknown');
    } else {
      unawaited(_startPlayback(context));
    }
  }

  Future<void> _startPlayback(BuildContext context) async {
    final needsTranslation = recipe.mode != PlaybackMode.enOnly;
    if (needsTranslation && tp.translationPairUsesSameLanguage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy chọn ngôn ngữ đích khác nguồn trước khi phát.'),
        ),
      );
      return;
    }
    if (needsTranslation && tp.isTranslating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang dịch, vui lòng chờ hoàn tất…')),
      );
      return;
    }
    if (needsTranslation && tp.translatedLineCount == 0) {
      await tp.translateAll();
      if (tp.translatedLineCount == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.uiText(
                  tp.translationError ?? 'Chưa có bản dịch để đọc song ngữ.',
                ),
              ),
            ),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;

    final fileId = tp.currentDocument?.id ?? 'unknown';
    final anchor = controller.loadAnchor(fileId);

    if (anchor != null) {
      showDialog(
        context: context,
        builder: (_) => _ResumeDialog(
          anchor: anchor,
          onFromStart: () {
            controller.clearAnchor(fileId);
            controller.start(
              tp.lines,
              fileId: fileId,
              sourceLanguageCode: sourceLanguage.translationCode,
              targetLanguageCode: targetLanguage.translationCode,
            );
          },
          onResume: () {
            controller.start(
              tp.lines,
              fileId: fileId,
              sourceLanguageCode: sourceLanguage.translationCode,
              targetLanguageCode: targetLanguage.translationCode,
              anchor: anchor,
            );
          },
        ),
      );
    } else {
      controller.start(
        tp.lines,
        fileId: fileId,
        sourceLanguageCode: sourceLanguage.translationCode,
        targetLanguageCode: targetLanguage.translationCode,
      );
    }
  }

  void _showPresetSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: _PresetSheet(
          currentRecipe: recipe,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        ),
      ),
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
        if (v < -300) controller.adjustSpeed(0.25);
        if (v > 300) controller.adjustSpeed(-0.25);
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
                      controller.adjustSpeed(1.0 - speed);
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
                      '${speed.toStringAsFixed(2)}x',
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

  const _PresetSheet({
    required this.currentRecipe,
    required this.sourceLanguage,
    required this.targetLanguage,
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
                HapticFeedback.selectionClick();
                controller.updateRecipe(p.recipe);
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
    return GestureDetector(
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
                  .withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
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
          '${speed.toStringAsFixed(2)}x',
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
            '$value',
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
