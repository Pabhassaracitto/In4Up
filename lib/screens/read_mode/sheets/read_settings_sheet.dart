// lib/screens/read_mode/sheets/read_settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';

import '../../../features/grammar/grammar.dart';
import '../../../features/tts/widgets/auto_split_section.dart';
import '../../../features/tts/widgets/tts_settings_section.dart';
import '../../../models/color_mode.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';

class ReadSettingsSheet {
  ReadSettingsSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<TextProvider>(
          builder: (context, tp, _) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF2196F3)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Cài đặt Text Studio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ===== EXPERIENCE MODE =====
                  const _SectionTitle(
                      title: 'Chế độ trải nghiệm', icon: Icons.auto_awesome),
                  const SizedBox(height: 12),
                  _SubModeSelector(tp: tp),
                  const SizedBox(height: 24),

                  // ===== ALIGNMENT =====
                  const _SectionTitle(
                      title: 'Căn lề văn bản', icon: Icons.format_align_center),
                  const SizedBox(height: 12),
                  _AlignmentSelector(tp: tp),
                  const SizedBox(height: 24),

                  // ===== FONT SIZE =====
                  const _SectionTitle(title: 'Cỡ chữ', icon: Icons.text_fields),
                  const SizedBox(height: 12),
                  _FontSizeControl(tp: tp),
                  const SizedBox(height: 24),

                  // ===== TTS =====
                  const _SectionTitle(
                      title: 'Text-to-Speech', icon: Icons.record_voice_over),
                  const SizedBox(height: 12),
                  _TtsControls(tp: tp),
                  const SizedBox(height: 24),

                  // ===== COLOR MODE =====
                  const _SectionTitle(title: 'Chế độ màu', icon: Icons.palette),
                  const SizedBox(height: 12),
                  _ColorModeSelector(tp: tp),

                  if (tp.colorMode != ColorMode.none) ...[
                    const SizedBox(height: 16),
                    _LegendPanel(colorMode: tp.colorMode),
                  ],

                  if (tp.colorMode == ColorMode.wordType) ...[
                    const SizedBox(height: 16),
                    _GrammarHighlightSection(tp: tp),
                  ],

                  const SizedBox(height: 24),

                  // ===== DISPLAY OPTIONS =====
                  const _SectionTitle(
                      title: 'Hiển thị', icon: Icons.visibility),
                  const SizedBox(height: 12),
                  _DisplayOptions(tp: tp),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),

                  // ★ TTS Settings (Cấu hình nâng cao)
                  const TtsSettingsSection(
                    primaryColor: Color(0xFF6C63FF),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),

                  // ★ Auto Split (Tách dòng tự động)
                  AutoSplitSection(
                    currentText: tp.fullText,
                    primaryColor: const Color(0xFF6C63FF),
                    onApply: (lines) {
                      tp.loadFromLines(lines);
                      Navigator.pop(context); // Đóng settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Đã tách thành ${lines.length} dòng')),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AlignmentSelector extends StatelessWidget {
  final TextProvider tp;
  const _AlignmentSelector({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildAlignBtn(Icons.format_align_left, 'Trái', TextAlign.left),
          const SizedBox(width: 8),
          _buildAlignBtn(Icons.format_align_center, 'Giữa', TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildAlignBtn(IconData icon, String label, TextAlign align) {
    final isSelected = tp.textAlign == align;
    return Expanded(
      child: GestureDetector(
        onTap: () => tp.setTextAlign(align),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2196F3)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  final TextProvider tp;
  const _FontSizeControl({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => tp.setFontSize(tp.fontSize - 2),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.remove, color: Colors.white, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${tp.fontSize.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: tp.fontSize,
                  min: 12,
                  max: 36,
                  divisions: 12,
                  activeColor: const Color(0xFF2196F3),
                  onChanged: (v) => tp.setFontSize(v),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => tp.setFontSize(tp.fontSize + 2),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TtsControls extends StatelessWidget {
  final TextProvider tp;
  const _TtsControls({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Speed slider
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              const Text('Tốc độ:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Expanded(
                child: Slider(
                  value: tp.ttsSpeed,
                  min: 0.25,
                  max: 2.0,
                  divisions: 7,
                  activeColor: const Color(0xFF2196F3),
                  onChanged: (v) => tp.setTtsSpeed(v),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF2196F3).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tp.ttsSpeed.toStringAsFixed(2)}x',
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _TtsButton(
                  icon: Icons.play_arrow,
                  label: 'Đọc dòng',
                  color: const Color(0xFF4CAF50),
                  enabled: tp.lines.isNotEmpty && !tp.isSpeaking,
                  onTap: () {
                    Navigator.pop(context);
                    tp.speakCurrentLine();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TtsButton(
                  icon: Icons.playlist_play,
                  label: 'Đọc tất cả',
                  color: const Color(0xFF2196F3),
                  enabled: tp.lines.isNotEmpty && !tp.isSpeaking,
                  onTap: () {
                    Navigator.pop(context);
                    tp.speakAllLines();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TtsButton(
                  icon: Icons.stop,
                  label: 'Dừng',
                  color: Colors.red,
                  enabled: tp.isSpeaking,
                  onTap: () => tp.stopSpeaking(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TtsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _TtsButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: enabled ? color : Colors.grey, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorModeSelector extends StatelessWidget {
  final TextProvider tp;
  const _ColorModeSelector({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ColorMode.values.map((mode) {
        final isSelected = tp.colorMode == mode;
        return GestureDetector(
          onTap: () => tp.setColorMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2196F3)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2196F3)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode.icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LegendPanel extends StatelessWidget {
  final ColorMode colorMode;
  const _LegendPanel({required this.colorMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _items),
        ],
      ),
    );
  }

  String get _title {
    switch (colorMode) {
      case ColorMode.none:
        return '';
      case ColorMode.wordType:
        return 'Loại từ (Syntax Highlighting):';
      case ColorMode.cefrLevel:
        return 'Cấp độ CEFR:';
      case ColorMode.difficulty:
        return 'Độ khó (bạn đánh dấu):';
    }
  }

  List<Widget> get _items {
    switch (colorMode) {
      case ColorMode.none:
        return [];
      case ColorMode.wordType:
        return WordType.values
            .where((t) => t != WordType.unknown)
            .map((type) => _Chip(color: type.color, label: type.labelVi))
            .toList();
      case ColorMode.cefrLevel:
        return CEFRLevel.values
            .where((l) => l != CEFRLevel.unknown)
            .map((level) => _Chip(color: level.color, label: level.shortLabel))
            .toList();
      case ColorMode.difficulty:
        return DifficultyLevel.values
            .map((level) => _Chip(color: level.color, label: level.label))
            .toList();
    }
  }
}

class _Chip extends StatelessWidget {
  final Color color;
  final String label;
  const _Chip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrammarHighlightSection extends StatelessWidget {
  final TextProvider tp;

  const _GrammarHighlightSection({required this.tp});

  @override
  Widget build(BuildContext context) {
    final settings = tp.grammarSettings;
    final palette = tp.activeGrammarPalette;
    final presets = GrammarHighlightPresets.defaults();
    final palettes = GrammarPalettes.defaults();
    final hiddenCategories = GrammarCategory.values
        .where((category) => !settings.visibleCategories.contains(category))
        .toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: 'Phase A · Từ loại chuyên sâu',
                  icon: Icons.auto_awesome_motion,
                ),
              ),
              Switch(
                value: settings.enabled,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (value) => tp.setGrammarHighlightEnabled(value),
              ),
            ],
          ),
          Text(
            'Dùng palette/preset mới lấy cảm hứng từ English Syntax Highlighter để làm rõ loại từ và cho phép bật tắt từng nhóm.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GrammarStylePreview(
            settings: settings,
            palette: palette,
          ),
          const SizedBox(height: 12),
          GrammarLegendBar(
            settings: settings,
            palette: palette,
            onToggleCategory: (category) => tp.toggleGrammarCategory(category),
          ),
          if (hiddenCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị xoá — bạn có thể bật lại từng nhóm ở danh sách bên dưới hoặc khôi phục nhanh tất cả.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: tp.showAllGrammarCategories,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Bật lại tất cả'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB8B5FF),
                          side: BorderSide(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      for (final category in hiddenCategories.take(5))
                        ActionChip(
                          backgroundColor: Colors.white.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: palette
                                .styleFor(category)
                                .color
                                .withValues(alpha: 0.28),
                          ),
                          label: Text(
                            '+ ${category.labelVi}',
                            style: TextStyle(
                              color: palette.styleFor(category).color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () => tp.toggleGrammarCategory(category),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Preset học tập',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              final selected = settings.activePresetId == preset.id;
              return _ChoiceChipButton(
                label: preset.name,
                subtitle: preset.description,
                selected: selected,
                onTap: () => tp.applyGrammarPreset(preset.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'Palette màu',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: palettes.map((item) {
              final selected = settings.paletteId == item.id;
              return _ChoiceChipButton(
                label: item.name,
                selected: selected,
                compact: true,
                onTap: () => tp.setGrammarPalette(item.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'Kiểu tô màu',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GrammarHighlightStyle.values.map((style) {
              final selected = settings.highlightStyle == style;
              return _ChoiceChipButton(
                label: style.labelVi,
                selected: selected,
                compact: true,
                onTap: () => tp.setGrammarHighlightStyle(style),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'Bật/tắt từng nhóm từ loại',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GrammarCategory.values.map((category) {
              final selected = settings.visibleCategories.contains(category);
              final style = palette.styleFor(category);
              return FilterChip(
                selected: selected,
                selectedColor: style.color.withValues(alpha: 0.18),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                side: BorderSide(
                  color: selected
                      ? style.color.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                label: Text(
                  category.labelVi,
                  style: TextStyle(
                    color: selected ? style.color : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onSelected: (_) => tp.toggleGrammarCategory(category),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Hiện legend mini trong phần cài đặt',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            value: settings.showLegend,
            activeThumbColor: const Color(0xFF6C63FF),
            onChanged: (value) => tp.setGrammarLegendVisible(value),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    this.subtitle,
    required this.selected,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 10,
          vertical: compact ? 9 : 10,
        ),
        constraints: BoxConstraints(minWidth: compact ? 0 : 120),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFFB8B5FF) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (!compact && subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DisplayOptions extends StatelessWidget {
  final TextProvider tp;
  const _DisplayOptions({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Hiện bản dịch',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Hiển thị dịch nghĩa bên dưới mỗi dòng',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            value: tp.showTranslation,
            activeThumbColor: const Color(0xFF4CAF50),
            onChanged: (_) => tp.toggleTranslation(),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          SwitchListTile(
            title: const Text('Hiện số dòng',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Hiện số thứ tự và timestamp',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            value: tp.showLineNumbers,
            activeThumbColor: const Color(0xFF2196F3),
            onChanged: (_) => tp.toggleLineNumbers(),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          SwitchListTile(
            title: const Text('Tách dòng thông minh',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text('Tự động tối ưu độ dài câu để dễ đọc',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            value: tp.useAutoSplit,
            activeThumbColor: const Color(0xFF9C27B0),
            onChanged: (v) => tp.toggleAutoSplit(v),
          ),
        ],
      ),
    );
  }
}

class _SubModeSelector extends StatelessWidget {
  final TextProvider tp;
  const _SubModeSelector({required this.tp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _SubModeItem(
            icon: Icons.menu_book,
            label: 'Chế độ Đọc',
            isSelected: tp.subMode == ReadSubMode.reading,
            onTap: () => tp.setSubMode(ReadSubMode.reading),
          ),
          _SubModeItem(
            icon: Icons.record_voice_over,
            label: 'Chế độ Nghe (TTS)',
            isSelected: tp.subMode == ReadSubMode.listening,
            onTap: () => tp.setSubMode(ReadSubMode.listening),
          ),
          _SubModeItem(
            icon: Icons.translate,
            label: 'Chế độ Dịch',
            isSelected: tp.subMode == ReadSubMode.translation,
            onTap: () => tp.setSubMode(ReadSubMode.translation),
          ),
          _SubModeItem(
            icon: Icons.directions_car,
            label: 'Chế độ Lái xe',
            isSelected: tp.subMode == ReadSubMode.driving,
            onTap: () => tp.setSubMode(ReadSubMode.driving),
          ),
        ],
      ),
    );
  }
}

class _SubModeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubModeItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading:
          Icon(icon, color: isSelected ? const Color(0xFF2196F3) : Colors.grey),
      title: Text(label,
          style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontSize: 14)),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF2196F3), size: 18)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
      dense: true,
    );
  }
}
