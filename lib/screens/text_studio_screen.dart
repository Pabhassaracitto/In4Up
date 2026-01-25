// lib/screens/text_studio_screen.dart
// VipSound - Text Studio Screen
// Version 4.0 - Enhanced with Color Modes (WordType, CEFR, Difficulty)
// Tham khảo: edward.io, Language Reactor

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../providers/text_provider.dart';
import '../providers/player_provider.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';
import '../models/word_analysis.dart';

// ============================================================================
// ENUMS & CONSTANTS
// ============================================================================

enum TextStudioMode {
  read,   // Đọc văn bản, chọn đoạn
  study,  // Luyện các đoạn đã đánh dấu (SRS)
  edit,   // Chỉnh sửa toàn bộ văn bản
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class TextStudioScreen extends StatefulWidget {
  const TextStudioScreen({super.key});

  @override
  State<TextStudioScreen> createState() => _TextStudioScreenState();
}

class _TextStudioScreenState extends State<TextStudioScreen>
    with TickerProviderStateMixin {
  // === MODE STATE ===
  TextStudioMode _mode = TextStudioMode.read;

  // === EDIT STATE ===
  final TextEditingController _editController = TextEditingController();
  bool _hasUnsavedChanges = false;

  // === ANIMATION ===
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // === LEGEND ===
  bool _showLegend = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================================
  // THEME
  // ============================================================================

  _StudioTheme _getTheme(VipMode mode) {
    switch (mode) {
      case VipMode.buddhism:
        return const _StudioTheme(
          primary: Color(0xFFD4A574),
          secondary: Color(0xFF8B7355),
          accent: Color(0xFFF5E6D3),
          background: Color(0xFF1A1612),
          surface: Color(0xFF2D2520),
          icon: Icons.spa,
          name: 'Pháp Học',
          defaultSegmentType: TextSegmentType.dharma,
        );
      case VipMode.english:
        return const _StudioTheme(
          primary: Color(0xFF64B5F6),
          secondary: Color(0xFF1976D2),
          accent: Color(0xFFBBDEFB),
          background: Color(0xFF0D1117),
          surface: Color(0xFF161B22),
          icon: Icons.school,
          name: 'Ngữ Học',
          defaultSegmentType: TextSegmentType.vocabulary,
        );
      case VipMode.music:
        return const _StudioTheme(
          primary: Color(0xFF9C7CF4),
          secondary: Color(0xFF6C63FF),
          accent: Color(0xFFD1C4E9),
          background: Color(0xFF0F0F1A),
          surface: Color(0xFF1A1A2E),
          icon: Icons.lyrics,
          name: 'Lời Nhạc',
          defaultSegmentType: TextSegmentType.sentence,
        );
    }
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, TextProvider>(
      builder: (context, player, textProvider, child) {
        final theme = _getTheme(player.currentMode);

        return Scaffold(
          backgroundColor: theme.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, textProvider, player, theme),
                _buildModeSwitcher(theme),
                if (_mode == TextStudioMode.read) ...[
                  _buildColorModeBar(context, textProvider, theme),
                  _buildTtsControls(context, textProvider, theme),
                ],
                if (_mode == TextStudioMode.study)
                  _buildStudyHeader(context, textProvider, theme),
                Expanded(
                  child: _buildContent(context, textProvider, player, theme),
                ),
                if (_mode != TextStudioMode.edit && textProvider.lines.isNotEmpty)
                  _buildBottomBar(context, textProvider, player, theme),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // APP BAR
  // ============================================================================

  Widget _buildAppBar(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.primary.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_hasUnsavedChanges) {
                _showUnsavedChangesDialog(context);
              } else {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: Colors.white70,
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primary, theme.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.text_fields, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Text Studio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  textProvider.currentDocument?.title ?? 'Chưa có văn bản',
                  style: TextStyle(fontSize: 11, color: theme.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (textProvider.segments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark, size: 12, color: theme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${textProvider.segments.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: () => _importTextFile(context),
            icon: Icon(Icons.file_open_outlined, size: 22),
            color: theme.primary,
          ),
          IconButton(
            onPressed: () => _showPasteDialog(context, theme),
            icon: Icon(Icons.paste, size: 22),
            color: theme.primary,
          ),
          IconButton(
            onPressed: () => _showSettingsSheet(context, textProvider, theme),
            icon: Icon(Icons.tune, size: 22),
            color: theme.primary,
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // COLOR MODE BAR - Thanh chuyển đổi chế độ màu
  // ============================================================================

  Widget _buildColorModeBar(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.palette, size: 16, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'Chế độ màu:',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ColorMode.values.map((mode) {
                      final isSelected = textProvider.colorMode == mode;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ColorModeChip(
                          mode: mode,
                          isSelected: isSelected,
                          onTap: () => textProvider.setColorMode(mode),
                          theme: theme,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Legend toggle
              IconButton(
                onPressed: () => setState(() => _showLegend = !_showLegend),
                icon: Icon(
                  _showLegend ? Icons.info : Icons.info_outline,
                  size: 20,
                ),
                color: _showLegend ? theme.primary : Colors.grey,
                tooltip: 'Hiển thị chú thích màu',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          // Legend panel
          if (_showLegend)
            _buildLegendPanel(textProvider.colorMode, theme),
        ],
      ),
    );
  }

  Widget _buildLegendPanel(ColorMode colorMode, _StudioTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getLegendTitle(colorMode),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _buildLegendItems(colorMode),
          ),
        ],
      ),
    );
  }

  String _getLegendTitle(ColorMode mode) {
    switch (mode) {
      case ColorMode.none:
        return 'Không tô màu';
      case ColorMode.wordType:
        return 'Màu theo loại từ (Tham khảo: edward.io)';
      case ColorMode.cefrLevel:
        return 'Màu theo cấp độ CEFR (Tham khảo: Language Reactor)';
      case ColorMode.difficulty:
        return 'Màu theo độ khó (Bạn tự đánh dấu)';
    }
  }

  List<Widget> _buildLegendItems(ColorMode mode) {
    switch (mode) {
      case ColorMode.none:
        return [
          const Text('Văn bản hiển thị màu trắng bình thường',
              style: TextStyle(color: Colors.grey, fontSize: 11))
        ];
      case ColorMode.wordType:
        return WordType.values.where((t) => t != WordType.unknown).map((type) {
          return _LegendItem(
            color: type.color,
            label: type.labelVi,
            abbreviation: type.abbreviation,
          );
        }).toList();
      case ColorMode.cefrLevel:
        return CEFRLevel.values.where((l) => l != CEFRLevel.unknown).map((level) {
          return _LegendItem(
            color: level.color,
            label: level.shortLabel,
            abbreviation: level.descriptionVi,
          );
        }).toList();
      case ColorMode.difficulty:
        return DifficultyLevel.values.map((level) {
          return _LegendItem(
            color: level.color,
            label: level.label,
            abbreviation: '${level.repeatCount}x',
          );
        }).toList();
    }
  }

  // ============================================================================
  // MODE SWITCHER
  // ============================================================================

  Widget _buildModeSwitcher(_StudioTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildModeTab(
            icon: Icons.chrome_reader_mode,
            label: 'Đọc',
            mode: TextStudioMode.read,
            theme: theme,
          ),
          _buildModeTab(
            icon: Icons.school,
            label: 'Luyện',
            mode: TextStudioMode.study,
            theme: theme,
            badge: context.watch<TextProvider>().getSegmentsForReview().length,
          ),
          _buildModeTab(
            icon: Icons.edit_note,
            label: 'Sửa',
            mode: TextStudioMode.edit,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required IconData icon,
    required String label,
    required TextStudioMode mode,
    required _StudioTheme theme,
    int badge = 0,
  }) {
    final isSelected = _mode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_mode == TextStudioMode.edit && _hasUnsavedChanges) {
            _showUnsavedChangesDialog(context, onDiscard: () {
              setState(() => _mode = mode);
            });
          } else {
            setState(() => _mode = mode);
            if (mode == TextStudioMode.edit) {
              _editController.text = context.read<TextProvider>().fullText;
            }
          }
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // CONTENT ROUTER
  // ============================================================================

  Widget _buildContent(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    if (textProvider.lines.isEmpty && _mode != TextStudioMode.edit) {
      return _buildEmptyState(context, theme);
    }

    switch (_mode) {
      case TextStudioMode.read:
        return _buildReadMode(context, textProvider, player, theme);
      case TextStudioMode.study:
        return _buildStudyMode(context, textProvider, theme);
      case TextStudioMode.edit:
        return _buildEditMode(context, textProvider, theme);
    }
  }

  // ============================================================================
  // READ MODE - Với hiển thị màu sắc
  // ============================================================================

  Widget _buildReadMode(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    return Column(
      children: [
        if (textProvider.selectedTextInfo != null)
          _buildSelectionBar(context, textProvider, theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: textProvider.lines.length,
            itemBuilder: (context, index) {
              return _buildColoredTextLine(
                context,
                textProvider,
                index,
                theme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBar(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    final info = textProvider.selectedTextInfo!;
    final previewText = info.text.length > 50
        ? '${info.text.substring(0, 50)}...'
        : info.text;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.2),
            theme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.text_fields, size: 18, color: theme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã chọn ${info.text.split(' ').length} từ',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  previewText,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _SelectionActionButton(
            icon: Icons.volume_up,
            color: Colors.blue,
            tooltip: 'Đọc TTS',
            onTap: () => textProvider.speakSelected(),
          ),
          _SelectionActionButton(
            icon: Icons.bookmark_add,
            color: Colors.amber,
            tooltip: 'Đánh dấu',
            onTap: () => _showCreateSegmentSheet(context, textProvider, theme),
          ),
          _SelectionActionButton(
            icon: Icons.close,
            color: Colors.grey,
            tooltip: 'Bỏ chọn',
            onTap: () => textProvider.clearSelection(),
          ),
        ],
      ),
    );
  }

  /// Build dòng text với màu sắc theo ColorMode
  Widget _buildColoredTextLine(
      BuildContext context,
      TextProvider textProvider,
      int index,
      _StudioTheme theme,
      ) {
    final line = textProvider.lines[index];
    final isCurrentLine = index == textProvider.currentLineIndex;
    final analyzedWords = index < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[index]
        : <AnalyzedWord>[];

    int lineStartOffset = 0;
    for (int i = 0; i < index; i++) {
      lineStartOffset += textProvider.lines[i].content.length + 1;
    }

    return GestureDetector(
      onTap: () {
        textProvider.setCurrentLine(index);
        HapticFeedback.selectionClick();
      },
      onDoubleTap: () {
        textProvider.setCurrentLine(index);
        textProvider.speakCurrentLine();
      },
      onLongPress: () {
        _showLineOptionsSheet(context, textProvider, index, line, theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentLine
              ? theme.primary.withOpacity(0.15)
              : theme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentLine ? theme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrentLine
                        ? theme.primary
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrentLine ? Colors.white : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (isCurrentLine && textProvider.isSpeaking)
                  _buildSpeakingIndicator(theme),
              ],
            ),
            const SizedBox(height: 8),

            // Colored text content
            if (textProvider.colorMode == ColorMode.none)
            // Plain text mode với selection
              SelectableText(
                line.content,
                style: TextStyle(
                  fontSize: textProvider.fontSize,
                  color: Colors.white,
                  height: 1.6,
                ),
                onSelectionChanged: (selection, cause) {
                  _handleTextSelection(
                    selection,
                    line.content,
                    textProvider,
                    lineStartOffset,
                    index,
                  );
                },
              )
            else
            // Colored text mode
              _buildColoredText(
                analyzedWords,
                textProvider,
                lineStartOffset,
                index,
                theme,
              ),

            // Translation
            if (textProvider.showTranslation && line.translation != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  line.translation!,
                  style: TextStyle(
                    fontSize: textProvider.fontSize - 2,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleTextSelection(
      TextSelection selection,
      String content,
      TextProvider textProvider,
      int lineStartOffset,
      int lineIndex,
      ) {
    if (selection.baseOffset != selection.extentOffset) {
      final start = selection.baseOffset < selection.extentOffset
          ? selection.baseOffset
          : selection.extentOffset;
      final end = selection.baseOffset < selection.extentOffset
          ? selection.extentOffset
          : selection.baseOffset;

      final selectedText = content.substring(start, end);

      textProvider.selectTextWithOffsets(
        text: selectedText,
        startOffset: lineStartOffset + start,
        endOffset: lineStartOffset + end,
        lineIndex: lineIndex,
      );
    }
  }

  /// Build văn bản với màu sắc
  Widget _buildColoredText(
      List<AnalyzedWord> words,
      TextProvider textProvider,
      int lineStartOffset,
      int lineIndex,
      _StudioTheme theme,
      ) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: words.asMap().entries.map((entry) {
        final wordIndex = entry.key;
        final word = entry.value;

        return _ColoredWordWidget(
          word: word,
          colorMode: textProvider.colorMode,
          fontSize: textProvider.fontSize,
          onTap: () {
            // Tap vào từ để đọc TTS
            textProvider.speak(word.word);
          },
          onLongPress: () {
            // Long press để đánh dấu độ khó
            _showWordOptionsSheet(
              context,
              textProvider,
              word,
              lineIndex,
              wordIndex,
              theme,
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildSpeakingIndicator(_StudioTheme theme) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.primary.withOpacity(_pulseAnimation.value * 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up, size: 12, color: theme.primary),
              const SizedBox(width: 4),
              Text(
                'Đang đọc',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // WORD OPTIONS SHEET - Đánh dấu độ khó cho từ
  // ============================================================================

  void _showWordOptionsSheet(
      BuildContext context,
      TextProvider textProvider,
      AnalyzedWord word,
      int lineIndex,
      int wordIndex,
      _StudioTheme theme,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: word.wordType.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    word.word,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: word.wordType.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _WordBadge(
                            label: word.wordType.labelVi,
                            color: word.wordType.color,
                          ),
                          const SizedBox(width: 6),
                          _WordBadge(
                            label: word.cefrLevel.shortLabel,
                            color: word.cefrLevel.color,
                          ),
                        ],
                      ),
                      if (word.meaning != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            word.meaning!,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Difficulty buttons
            const Text(
              'Đánh dấu độ khó của bạn:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DifficultyLevel.values.map((level) {
                final isSelected = word.userDifficulty == level;
                return GestureDetector(
                  onTap: () {
                    textProvider.markWordDifficulty(lineIndex, wordIndex, level);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã đánh dấu "${word.word}" là ${level.label}'),
                        backgroundColor: level.color,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? level.color
                          : level.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: level.color,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: isSelected ? Colors.white : level.color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${level.label} (${level.repeatCount}x)',
                          style: TextStyle(
                            color: isSelected ? Colors.white : level.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      textProvider.speak(word.word);
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Đọc TTS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Tạo segment từ từ này
                      textProvider.selectText(word.word);
                      _showCreateSegmentSheet(context, textProvider, theme);
                    },
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Lưu học'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // STUDY MODE
  // ============================================================================

  Widget _buildStudyHeader(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    final stats = textProvider.getSegmentStats();
    final needsReview = stats['needsReview'] as int;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.1),
            theme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StudyStat(label: 'Tổng', value: '${stats['total']}', color: theme.primary),
              _StudyStat(label: 'Dễ', value: '${stats['easy']}', color: Colors.green),
              _StudyStat(label: 'Vừa', value: '${stats['medium']}', color: Colors.orange),
              _StudyStat(label: 'Khó', value: '${stats['hard']}', color: Colors.red),
              _StudyStat(
                label: 'Cần ôn',
                value: '$needsReview',
                color: Colors.purple,
                highlight: needsReview > 0,
              ),
            ],
          ),
          if (needsReview > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: textProvider.isPlayingSegment
                        ? textProvider.stopSegmentPlayback
                        : () => textProvider.startReviewSession(),
                    icon: Icon(textProvider.isPlayingSegment ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      textProvider.isPlayingSegment
                          ? 'Dừng ôn tập'
                          : 'Ôn tập ($needsReview)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textProvider.isPlayingSegment ? Colors.red : Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Đọc từ khó trước
                ElevatedButton.icon(
                  onPressed: textProvider.isPlayingSegment
                      ? null
                      : () => textProvider.speakDifficultWordsFirst(),
                  icon: const Icon(Icons.fitness_center, size: 18),
                  label: const Text('Từ khó'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyMode(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    final segments = textProvider.segments;

    if (segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: theme.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'Chưa có đoạn học nào',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Chuyển sang chế độ Đọc và chọn đoạn văn bản để đánh dấu',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => setState(() => _mode = TextStudioMode.read),
              icon: Icon(Icons.chrome_reader_mode, color: theme.primary),
              label: Text('Chuyển sang Đọc', style: TextStyle(color: theme.primary)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: theme.primary)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final segment = segments[index];
        final isPlaying = textProvider.currentPlayingSegment?.id == segment.id;
        return _buildSegmentCard(context, textProvider, segment, isPlaying, theme);
      },
    );
  }

  Widget _buildSegmentCard(
      BuildContext context,
      TextProvider textProvider,
      TextSegment segment,
      bool isPlaying,
      _StudioTheme theme,
      ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPlaying
            ? segment.difficultyColor.withOpacity(0.15)
            : theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying
              ? segment.difficultyColor
              : segment.difficultyColor.withOpacity(0.3),
          width: isPlaying ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: segment.difficultyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(segment.typeIcon, size: 16, color: segment.difficultyColor),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: segment.difficultyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    segment.difficultyLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: segment.difficultyColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${segment.repeatCount}x • ${segment.ttsSpeed.toStringAsFixed(1)}x',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: segment.masteryLevel,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    color: segment.difficultyColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              segment.content,
              style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.5),
            ),
          ),
          if (segment.note != null && segment.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notes, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        segment.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isPlaying) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: textProvider.currentRepeatIndex / segment.repeatCount,
                      backgroundColor: Colors.white12,
                      color: segment.difficultyColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${textProvider.currentRepeatIndex}/${segment.repeatCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: segment.difficultyColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPlaying
                        ? textProvider.stopSegmentPlayback
                        : () => textProvider.speakSegment(segment),
                    icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow, size: 18),
                    label: Text(isPlaying ? 'Dừng' : 'Phát'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPlaying ? Colors.red : segment.difficultyColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showEditSegmentSheet(context, textProvider, segment, theme),
                  icon: Icon(Icons.edit_outlined, color: Colors.grey[400]),
                ),
                IconButton(
                  onPressed: () => _confirmDeleteSegment(context, textProvider, segment),
                  icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // EDIT MODE
  // ============================================================================

  Widget _buildEditMode(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chỉnh sửa văn bản sẽ xóa tất cả đoạn đã đánh dấu',
                    style: TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ),
                if (_hasUnsavedChanges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Chưa lưu',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.primary.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _editController,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: textProvider.fontSize,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: 'Nhập hoặc dán văn bản ở đây...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  contentPadding: const EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _hasUnsavedChanges = true),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _editController.text = textProvider.fullText;
                    setState(() {
                      _hasUnsavedChanges = false;
                      _mode = TextStudioMode.read;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _hasUnsavedChanges
                      ? () {
                    textProvider.updateFullText(_editController.text);
                    setState(() {
                      _hasUnsavedChanges = false;
                      _mode = TextStudioMode.read;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã lưu văn bản!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                      : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu & Cập nhật'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TTS CONTROLS
  // ============================================================================

  Widget _buildTtsControls(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.speed, size: 18, color: theme.primary),
              const SizedBox(width: 8),
              Text('TTS:', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.primary,
                    inactiveTrackColor: theme.primary.withOpacity(0.2),
                    thumbColor: theme.primary,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: textProvider.ttsSpeed,
                    min: 0.25,
                    max: 2.0,
                    divisions: 7,
                    onChanged: (value) => textProvider.setTtsSpeed(value),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${textProvider.ttsSpeed.toStringAsFixed(2)}x',
                  style: TextStyle(
                    color: theme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TtsActionButton(
                  icon: Icons.play_arrow,
                  label: 'Tất cả',
                  color: Colors.green,
                  enabled: textProvider.lines.isNotEmpty && !textProvider.isSpeaking,
                  isActive: textProvider.isSpeaking,
                  onTap: () => textProvider.speakAllLines(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TtsActionButton(
                  icon: Icons.record_voice_over,
                  label: 'Dòng',
                  color: Colors.blue,
                  enabled: textProvider.currentLineIndex >= 0,
                  onTap: () => textProvider.speakCurrentLine(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TtsActionButton(
                  icon: Icons.select_all,
                  label: 'Chọn',
                  color: Colors.orange,
                  enabled: textProvider.selectedText != null,
                  onTap: () => textProvider.speakSelected(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TtsActionButton(
                  icon: Icons.stop,
                  label: 'Dừng',
                  color: Colors.red,
                  enabled: textProvider.isSpeaking,
                  isActive: textProvider.isSpeaking,
                  onTap: () => textProvider.stopSpeaking(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BOTTOM BAR
  // ============================================================================

  Widget _buildBottomBar(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomAction(
            icon: Icons.text_decrease,
            label: 'A-',
            onTap: () => textProvider.setFontSize(textProvider.fontSize - 2),
          ),
          _BottomAction(
            icon: Icons.text_increase,
            label: 'A+',
            onTap: () => textProvider.setFontSize(textProvider.fontSize + 2),
          ),
          _BottomAction(
            icon: Icons.palette,
            label: 'Màu',
            color: textProvider.colorMode != ColorMode.none ? theme.primary : null,
            onTap: () => textProvider.cycleColorMode(),
          ),
          _BottomAction(
            icon: Icons.translate,
            label: 'Dịch',
            isActive: textProvider.showTranslation,
            color: textProvider.showTranslation ? theme.primary : null,
            onTap: () => textProvider.toggleTranslation(),
          ),
          _BottomAction(
            icon: Icons.sync,
            label: 'Sync',
            color: player.currentSongPath != null ? Colors.green : null,
            onTap: player.currentSongPath != null
                ? () => Navigator.pushNamed(context, '/sync-hub')
                : null,
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // EMPTY STATE
  // ============================================================================

  Widget _buildEmptyState(BuildContext context, _StudioTheme theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.primary.withOpacity(0.2),
                    theme.secondary.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(Icons.text_snippet_outlined, size: 64, color: theme.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có văn bản',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text('Nhập văn bản để bắt đầu học', style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _importTextFile(context),
                  icon: const Icon(Icons.file_open),
                  label: const Text('Mở file'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _mode = TextStudioMode.edit),
                  icon: Icon(Icons.edit, color: theme.primary),
                  label: Text('Nhập text', style: TextStyle(color: theme.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS & SHEETS
  // ============================================================================

  Future<void> _importTextFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'srt', 'lrc'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final content = await file.readAsString();
        final title = result.files.first.name;

        if (context.mounted) {
          context.read<TextProvider>().loadText(content, title: title);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tải: $title'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPasteDialog(BuildContext context, _StudioTheme theme) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dán văn bản', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Dán văn bản ở đây...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy'))),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context.read<TextProvider>().loadText(controller.text, title: 'Văn bản mới');
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
                    child: const Text('Thêm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showCreateSegmentSheet(BuildContext context, TextProvider textProvider, _StudioTheme theme) {
    final info = textProvider.selectedTextInfo;
    if (info == null && textProvider.selectedText == null) return;

    TextSegmentDifficulty difficulty = TextSegmentDifficulty.medium;
    TextSegmentType type = theme.defaultSegmentType;
    final repeatController = TextEditingController(text: '3');
    final speedController = TextEditingController(text: textProvider.ttsSpeed.toStringAsFixed(2));
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark_add, color: theme.primary),
                    const SizedBox(width: 8),
                    const Text('Tạo đoạn học', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    (info?.text ?? textProvider.selectedText ?? '').length > 100
                        ? '${(info?.text ?? textProvider.selectedText ?? '').substring(0, 100)}...'
                        : (info?.text ?? textProvider.selectedText ?? ''),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Độ khó:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: TextSegmentDifficulty.values.map((d) {
                    return ChoiceChip(
                      label: Text(d == TextSegmentDifficulty.hard ? 'Khó (5x)' : d == TextSegmentDifficulty.medium ? 'Vừa (3x)' : 'Dễ (1x)'),
                      selected: difficulty == d,
                      selectedColor: d == TextSegmentDifficulty.hard ? Colors.red : d == TextSegmentDifficulty.medium ? Colors.orange : Colors.green,
                      onSelected: (_) => setModalState(() {
                        difficulty = d;
                        repeatController.text = d == TextSegmentDifficulty.hard ? '5' : d == TextSegmentDifficulty.medium ? '3' : '1';
                        speedController.text = d == TextSegmentDifficulty.hard ? '0.70' : d == TextSegmentDifficulty.medium ? '0.85' : '1.00';
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: repeatController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Lặp',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: speedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tốc độ',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ghi chú',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy'))),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          textProvider.createSegmentFromSelection(
                            difficulty: difficulty,
                            type: type,
                            repeatCountOverride: int.tryParse(repeatController.text),
                            ttsSpeedOverride: double.tryParse(speedController.text),
                            note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('Đã lưu!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Lưu'),
                        style: ElevatedButton.styleFrom(backgroundColor: theme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLineOptionsSheet(BuildContext context, TextProvider textProvider, int index, TextItem line, _StudioTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dòng ${index + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primary)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.volume_up, color: Colors.blue),
              title: const Text('Đọc TTS', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                textProvider.setCurrentLine(index);
                textProvider.speakCurrentLine();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add, color: Colors.amber),
              title: const Text('Đánh dấu toàn bộ dòng', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                int offset = 0;
                for (int i = 0; i < index; i++) {
                  offset += textProvider.lines[i].content.length + 1;
                }
                textProvider.selectTextWithOffsets(
                  text: line.content,
                  startOffset: offset,
                  endOffset: offset + line.content.length,
                  lineIndex: index,
                );
                _showCreateSegmentSheet(context, textProvider, theme);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: const Text('Sao chép', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: line.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép!'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSegmentSheet(BuildContext context, TextProvider textProvider, TextSegment segment, _StudioTheme theme) {
    TextSegmentDifficulty difficulty = segment.difficulty;
    final repeatController = TextEditingController(text: segment.repeatCount.toString());
    final speedController = TextEditingController(text: segment.ttsSpeed.toStringAsFixed(2));
    final noteController = TextEditingController(text: segment.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chỉnh sửa đoạn học', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              const Text('Độ khó:', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TextSegmentDifficulty.values.map((d) {
                  return ChoiceChip(
                    label: Text(d == TextSegmentDifficulty.hard ? 'Khó' : d == TextSegmentDifficulty.medium ? 'Vừa' : 'Dễ'),
                    selected: difficulty == d,
                    selectedColor: d == TextSegmentDifficulty.hard ? Colors.red : d == TextSegmentDifficulty.medium ? Colors.orange : Colors.green,
                    onSelected: (_) => setModalState(() => difficulty = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: repeatController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Số lần lặp', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: speedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Tốc độ TTS', labelStyle: TextStyle(color: Colors.grey)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Ghi chú', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy'))),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final updated = segment.copyWith(
                          difficulty: difficulty,
                          repeatCount: int.tryParse(repeatController.text) ?? segment.repeatCount,
                          ttsSpeed: double.tryParse(speedController.text) ?? segment.ttsSpeed,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                        );
                        textProvider.updateSegment(updated);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: theme.primary),
                      child: const Text('Cập nhật'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, TextProvider textProvider, _StudioTheme theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cài đặt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.primary)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.format_size, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Text('Cỡ chữ:', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: textProvider.fontSize,
                      min: 12,
                      max: 32,
                      activeColor: theme.primary,
                      onChanged: (value) {
                        textProvider.setFontSize(value);
                        setModalState(() {});
                      },
                    ),
                  ),
                  Text('${textProvider.fontSize.toInt()}', style: const TextStyle(color: Colors.white)),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.language, color: Colors.grey),
                title: const Text('Ngôn ngữ TTS', style: TextStyle(color: Colors.white)),
                trailing: DropdownButton<String>(
                  value: textProvider.ttsLanguage,
                  dropdownColor: theme.surface,
                  items: const [
                    DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                    DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
                    DropdownMenuItem(value: 'vi-VN', child: Text('Tiếng Việt')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      textProvider.setTtsLanguage(value);
                      setModalState(() {});
                    }
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.translate, color: Colors.grey),
                title: const Text('Hiện bản dịch', style: TextStyle(color: Colors.white)),
                value: textProvider.showTranslation,
                activeColor: theme.primary,
                onChanged: (_) {
                  textProvider.toggleTranslation();
                  setModalState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSegment(BuildContext context, TextProvider textProvider, TextSegment segment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Xóa đoạn học?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Xóa: "${segment.content.length > 50 ? '${segment.content.substring(0, 50)}...' : segment.content}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              textProvider.deleteSegment(segment.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showUnsavedChangesDialog(BuildContext context, {VoidCallback? onDiscard}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Chưa lưu thay đổi', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có thay đổi chưa lưu.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tiếp tục sửa')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editController.text = context.read<TextProvider>().fullText;
              setState(() => _hasUnsavedChanges = false);
              onDiscard?.call();
            },
            child: const Text('Bỏ thay đổi', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TextProvider>().updateFullText(_editController.text);
              Navigator.pop(context);
              setState(() => _hasUnsavedChanges = false);
              onDiscard?.call();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _StudioTheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final IconData icon;
  final String name;
  final TextSegmentType defaultSegmentType;

  const _StudioTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.icon,
    required this.name,
    required this.defaultSegmentType,
  });
}

class _ColorModeChip extends StatelessWidget {
  final ColorMode mode;
  final bool isSelected;
  final VoidCallback onTap;
  final _StudioTheme theme;

  const _ColorModeChip({
    required this.mode,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primary : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mode.icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 4),
            Text(
              mode.label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String abbreviation;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.abbreviation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label ($abbreviation)',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ColoredWordWidget extends StatelessWidget {
  final AnalyzedWord word;
  final ColorMode colorMode;
  final double fontSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ColoredWordWidget({
    required this.word,
    required this.colorMode,
    required this.fontSize,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = word.getColor(colorMode);
    final bgColor = word.getBackgroundColor(colorMode);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          word.word,
          style: TextStyle(
            fontSize: fontSize,
            color: textColor,
            fontWeight: word.userDifficulty != null ? FontWeight.bold : FontWeight.normal,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _WordBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _WordBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _SelectionActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SelectionActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: color,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }
}

class _StudyStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _StudyStat({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(highlight ? 0.3 : 0.1),
            shape: BoxShape.circle,
            border: highlight ? Border.all(color: color, width: 2) : null,
          ),
          child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }
}

class _TtsActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final bool isActive;
  final VoidCallback onTap;

  const _TtsActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.3) : enabled ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? color : Colors.transparent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? color : Colors.grey, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: enabled ? color : Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isActive;
  final VoidCallback? onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    this.color,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final effectiveColor = color ?? Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: isActive
                ? BoxDecoration(color: effectiveColor.withOpacity(0.2), shape: BoxShape.circle)
                : null,
            child: Icon(icon, color: isEnabled ? effectiveColor : Colors.grey, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isEnabled ? effectiveColor : Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}