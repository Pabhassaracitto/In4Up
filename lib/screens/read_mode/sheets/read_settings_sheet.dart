// lib/screens/read_mode/sheets/read_settings_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in2up_core/vocab_level_difficulty.dart';

import '../../../features/grammar/grammar.dart';
import '../../../features/translation/translation_display_mode.dart';
import '../../../features/translation/translation_language_picker.dart';
import '../../../features/tts/widgets/auto_split_section.dart';
import '../../../features/tts/widgets/tts_settings_section.dart';
import '../../../models/color_mode.dart';
import '../../../models/word_analysis.dart';
import '../../../providers/text_provider.dart';
import '../services/playback_controller.dart';

class ReadSettingsSheet {
  ReadSettingsSheet._();

  static void show(BuildContext context) {
    context.read<TextProvider>().refreshGrammarPresetLibrary();
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

                  // ===== TRANSLATION + BILINGUAL TTS =====
                  const _SectionTitle(
                    title: 'Dịch & đọc song ngữ',
                    icon: Icons.compare_arrows_rounded,
                  ),
                  const SizedBox(height: 12),
                  _TranslationLanguageSection(tp: tp),
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

class _TranslationLanguageSection extends StatelessWidget {
  final TextProvider tp;

  const _TranslationLanguageSection({required this.tp});

  @override
  Widget build(BuildContext context) {
    final source = tp.detectedSourceLanguage;
    final target = tp.translationTargetLanguage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslationLanguagePickerButton(
            sourceLanguage: source,
            targetLanguage: target,
            compact: false,
            accentColor: const Color(0xFF53D6BD),
            onSelected: (language) async {
              final playback = context.read<PlaybackController>();
              if (playback.isRunning) {
                playback.stop(fileId: tp.currentDocument?.id ?? 'unknown');
              }
              await tp.stopSpeaking();
              await tp.setTranslationTargetLanguage(
                language.translationCode,
                retranslateExisting: true,
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Nguồn được nhận diện tự động. Khi đọc song ngữ, In4Up sẽ '
            'chuyển giọng ${source.ttsLocale} ↔ ${target.ttsLocale} trước '
            'từng lượt đọc.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (tp.translationPairUsesSameLanguage) ...[
            const SizedBox(height: 8),
            const Text(
              'Hãy chọn ngôn ngữ đích khác ngôn ngữ nguồn.',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
    final presets = tp.availableGrammarPresets;
    final builtInPresets = presets.where((preset) => preset.isBuiltIn).toList();
    final customPresets = presets.where((preset) => !preset.isBuiltIn).toList();
    final palettes = GrammarPalettes.defaults();
    final previousPreset = presets.firstWhere(
      (preset) => preset.id == settings.lastNonCustomPresetId,
      orElse: () => GrammarHighlightPresets.byId(settings.lastNonCustomPresetId),
    );
    final hiddenCategories = GrammarCategory.values
        .where((category) => !settings.visibleCategories.contains(category))
        .toList()
      ..sort((a, b) => a.referenceStyleIndex.compareTo(b.referenceStyleIndex));
    final groupOrder = const [
      GrammarCategoryGroup.contentWord,
      GrammarCategoryGroup.functionWord,
      GrammarCategoryGroup.symbols,
      GrammarCategoryGroup.structural,
    ];

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
            'Panel này đã được làm lại theo hướng control panel: preset đẹp hơn, so sánh palette trực quan hơn, có mini/advanced và cho phép lưu preset cá nhân.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _GrammarControlSummary(
            settings: settings,
            activePresetName: tp.activeGrammarPreset.name,
            previousPresetName: previousPreset.name,
            visibleCount: settings.visibleCategories.length,
            hiddenCount: hiddenCategories.length,
            onRestorePreviousPreset: tp.restorePreviousGrammarPreset,
            onToggleAdvancedMode: tp.setGrammarAdvancedControls,
            onSaveCurrentPreset: () async {
              final draft = await _showReadSavePresetDialog(
                context,
                tp.activeGrammarPreset.name,
              );
              if (draft == null) return;
              await tp.saveCurrentGrammarPreset(
                name: draft.name,
                description: draft.description,
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Preset gợi ý',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: builtInPresets.map((preset) {
              final selected = settings.activePresetId == preset.id;
              return _PresetChoiceCard(
                preset: preset,
                selected: selected,
                onTap: () => tp.applyGrammarPreset(preset.id),
              );
            }).toList(),
          ),
          if (customPresets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Preset của bạn',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: customPresets.map((preset) {
                final selected = settings.activePresetId == preset.id;
                return _PresetChoiceCard(
                  preset: preset,
                  selected: selected,
                  onTap: () => tp.applyGrammarPreset(preset.id),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            settings.showAdvancedControls ? 'Preview & legend' : 'Preview nhanh',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
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
            _ReadSettingsHiddenGrammarCard(
              hiddenCategories: hiddenCategories,
              palette: palette,
              previousPresetName: previousPreset.name,
              onShowAllCategories: tp.showAllGrammarCategories,
              onToggleCategory: tp.toggleGrammarCategory,
            ),
          ],
          const SizedBox(height: 10),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Hiện legend mini trong vùng đọc',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              settings.showLegend
                  ? 'Đang bật để bạn lọc category trực tiếp trên màn đọc.'
                  : 'Tắt để vùng đọc sạch hơn; phần điều khiển vẫn nằm ở đây.',
              style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
            ),
            value: settings.showLegend,
            activeThumbColor: const Color(0xFF6C63FF),
            onChanged: (value) => tp.setGrammarLegendVisible(value),
          ),
          if (settings.showAdvancedControls) ...[
            const SizedBox(height: 14),
            Text(
              'So sánh palette trực quan',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: palettes.map((item) {
                final selected = settings.paletteId == item.id;
                return _PaletteChoiceCard(
                  palette: item,
                  selected: selected,
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
              'Nhóm từ loại',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...groupOrder.map((group) {
              final categories = grammarCategoriesForGroup(group);
              if (categories.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReadSettingsGrammarGroupCard(
                  group: group,
                  categories: categories,
                  settings: settings,
                  palette: palette,
                  onToggleCategory: tp.toggleGrammarCategory,
                ),
              );
            }),
          ] else ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.22),
                ),
              ),
              child: const Text(
                'Mini mode đang ưu tiên thao tác cốt lõi: chọn preset, xem preview, bật tắt legend, lưu preset riêng và khôi phục nhanh. Bật advanced để chia category theo content / function / symbols và so màu trực quan hơn.',
                style: TextStyle(
                  color: Color(0xFFB8B5FF),
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GrammarControlSummary extends StatelessWidget {
  final GrammarHighlightSettings settings;
  final String activePresetName;
  final String previousPresetName;
  final int visibleCount;
  final int hiddenCount;
  final Future<void> Function() onRestorePreviousPreset;
  final Future<void> Function(bool value) onToggleAdvancedMode;
  final Future<void> Function() onSaveCurrentPreset;

  const _GrammarControlSummary({
    required this.settings,
    required this.activePresetName,
    required this.previousPresetName,
    required this.visibleCount,
    required this.hiddenCount,
    required this.onRestorePreviousPreset,
    required this.onToggleAdvancedMode,
    required this.onSaveCurrentPreset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            settings.isCustomPreset
                ? 'Đang dùng preset: Tùy chỉnh'
                : 'Đang dùng preset: $activePresetName',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            settings.isCustomPreset
                ? 'Bạn đang chỉnh tay từ preset gần nhất: $previousPresetName'
                : 'Có thể chuyển sang tùy chỉnh nếu cần ẩn/hiện thủ công từng nhóm từ loại.',
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
              _TinyStatChip(label: '$visibleCount bật'),
              _TinyStatChip(label: '$hiddenCount ẩn'),
              _TinyStatChip(
                label: settings.showLegend ? 'Legend nổi' : 'Legend tắt',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Mini'),
                selected: !settings.showAdvancedControls,
                onSelected: (_) => onToggleAdvancedMode(false),
                selectedColor:
                    const Color(0xFF6C63FF).withValues(alpha: 0.20),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                labelStyle: TextStyle(
                  color: !settings.showAdvancedControls
                      ? const Color(0xFFB8B5FF)
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: !settings.showAdvancedControls
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              ChoiceChip(
                label: const Text('Advanced'),
                selected: settings.showAdvancedControls,
                onSelected: (_) => onToggleAdvancedMode(true),
                selectedColor:
                    const Color(0xFF6C63FF).withValues(alpha: 0.20),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                labelStyle: TextStyle(
                  color: settings.showAdvancedControls
                      ? const Color(0xFFB8B5FF)
                      : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: settings.showAdvancedControls
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSaveCurrentPreset,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('Lưu preset riêng'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8B5FF),
                  side: BorderSide(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                  ),
                ),
              ),
              if (settings.isCustomPreset)
                OutlinedButton.icon(
                  onPressed: onRestorePreviousPreset,
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: Text('Khôi phục $previousPresetName'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB8B5FF),
                    side: BorderSide(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadSettingsHiddenGrammarCard extends StatelessWidget {
  final List<GrammarCategory> hiddenCategories;
  final GrammarPalette palette;
  final String previousPresetName;
  final Future<void> Function() onShowAllCategories;
  final Future<void> Function(GrammarCategory category) onToggleCategory;

  const _ReadSettingsHiddenGrammarCard({
    required this.hiddenCategories,
    required this.palette,
    required this.previousPresetName,
    required this.onShowAllCategories,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đang ẩn ${hiddenCategories.length} nhóm từ loại. Chúng chưa bị xoá — bạn có thể bật lại từng nhóm, bật hết, hoặc quay về preset $previousPresetName.',
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
                onPressed: onShowAllCategories,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Bật lại tất cả'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8B5FF),
                  side: BorderSide(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                  ),
                ),
              ),
              for (final category in hiddenCategories.take(6))
                ActionChip(
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  side: BorderSide(
                    color: palette.styleFor(category).color.withValues(alpha: 0.28),
                  ),
                  label: Text(
                    '+ ${category.labelVi}',
                    style: TextStyle(
                      color: palette.styleFor(category).color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => onToggleCategory(category),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadSettingsGrammarGroupCard extends StatelessWidget {
  final GrammarCategoryGroup group;
  final List<GrammarCategory> categories;
  final GrammarHighlightSettings settings;
  final GrammarPalette palette;
  final Future<void> Function(GrammarCategory category) onToggleCategory;

  const _ReadSettingsGrammarGroupCard({
    required this.group,
    required this.categories,
    required this.settings,
    required this.palette,
    required this.onToggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 16, color: const Color(0xFFB8B5FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.labelVi,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            group.helperVi,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) {
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
                avatar: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected ? style.color : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  category.labelVi,
                  style: TextStyle(
                    color: selected ? style.color : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onSelected: (_) => onToggleCategory(category),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PresetChoiceCard extends StatelessWidget {
  final GrammarHighlightPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChoiceCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    preset.audienceLabel,
                    style: TextStyle(
                      color: selected ? const Color(0xFFD4D2FF) : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  preset.isBuiltIn ? Icons.auto_awesome : Icons.person_outline,
                  size: 15,
                  color: selected ? const Color(0xFFD4D2FF) : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preset.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preset.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              preset.focusSummary,
              style: TextStyle(
                color: selected ? const Color(0xFFB8B5FF) : Colors.grey[500],
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteChoiceCard extends StatelessWidget {
  final GrammarPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteChoiceCard({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sampleCategories = [
      GrammarCategory.verb,
      GrammarCategory.adjective,
      GrammarCategory.noun,
      GrammarCategory.preposition,
      GrammarCategory.pronoun,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    palette.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    palette.isDark ? 'Dark' : 'Light',
                    style: TextStyle(
                      color: selected ? const Color(0xFFD4D2FF) : Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: sampleCategories.map((category) {
                final color = palette.styleFor(category).color;
                return Expanded(
                  child: Container(
                    height: 12,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              _paletteHint(palette.id),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _paletteHint(String id) {
    switch (id) {
      case 'classic-dark':
        return 'Màu sâu, nổi rõ trên nền tối.';
      case 'classic-light':
        return 'Sáng, dễ so màu khi đọc nền trắng.';
      case 'noun-verb-focus':
        return 'Rất rõ noun/verb để luyện cấu trúc cốt lõi.';
      default:
        return 'So sánh trực quan các nhóm màu chính.';
    }
  }
}

class _TinyStatChip extends StatelessWidget {
  final String label;

  const _TinyStatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
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

class _ReadPresetDraft {
  final String name;
  final String description;

  const _ReadPresetDraft({required this.name, required this.description});
}

Future<_ReadPresetDraft?> _showReadSavePresetDialog(
  BuildContext context,
  String suggestedName,
) async {
  final nameCtrl = TextEditingController(
    text: suggestedName == 'Tùy chỉnh' ? 'Preset của tôi 1' : '$suggestedName riêng',
  );
  final descCtrl = TextEditingController();

  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF151B26),
        title: const Text('Lưu preset cá nhân'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _readDialogInputDecoration(
                  label: 'Tên preset',
                  hint: 'Ví dụ: Verb focus riêng',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: _readDialogInputDecoration(
                  label: 'Mô tả ngắn',
                  hint: 'Ghi chú cách dùng của preset này',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Lưu preset'),
          ),
        ],
      );
    },
  );

  if (shouldSave != true) return null;
  return _ReadPresetDraft(
    name: nameCtrl.text.trim(),
    description: descCtrl.text.trim(),
  );
}

InputDecoration _readDialogInputDecoration({
  required String label,
  required String hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: Colors.white70),
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
    ),
  );
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
            subtitle: Text(
                tp.translatedLineCount > 0
                    ? 'Đã có ${tp.translatedLineCount} dòng dịch • chạm để ${tp.showTranslation ? 'ẩn' : 'hiện'}'
                    : 'Hiển thị dịch nghĩa bên dưới mỗi dòng',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            value: tp.showTranslation,
            activeThumbColor: const Color(0xFF4CAF50),
            onChanged: (val) {
              // Rõ ràng hơn toggle: bật = stackedBelow, tắt = hidden
              if (val) {
                tp.setTranslationDisplayMode(
                    TranslationDisplayMode.stackedBelow);
              } else {
                tp.setTranslationDisplayMode(TranslationDisplayMode.hidden);
              }
            },
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
