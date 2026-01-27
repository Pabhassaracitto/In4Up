// lib/screens/read_mode_screen.dart
// VipSound - Chế độ ĐỌC với đầy đủ tính năng từ TextStudio
// Tích hợp: ColorMode, Word Analysis, TTS Controls, Segment Management

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

class ReadModeScreen extends StatefulWidget {
  const ReadModeScreen({super.key});

  @override
  State<ReadModeScreen> createState() => _ReadModeScreenState();
}

class _ReadModeScreenState extends State<ReadModeScreen>
    with TickerProviderStateMixin {

  final ScrollController _scrollController = ScrollController();
  bool _showLegend = false;
  bool _showTtsControls = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TextProvider, PlayerProvider>(
      builder: (context, textProvider, player, child) {
        if (!textProvider.hasLyrics) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            // Color Mode Bar
            _buildColorModeBar(context, textProvider),

            // TTS Controls (collapsible)
            if (_showTtsControls)
              _buildTtsControls(context, textProvider),

            // Selection Bar (if text selected)
            if (textProvider.selectedTextInfo != null)
              _buildSelectionBar(context, textProvider),

            // Main Text Content
            Expanded(
              child: _buildTextContent(context, textProvider, player),
            ),

            // Bottom Controls
            _buildBottomControls(context, textProvider, player),
          ],
        );
      },
    );
  }

  // ==================== EMPTY STATE ====================

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book,
                size: 64,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Chế độ Đọc',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Thêm văn bản để bắt đầu đọc',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),

            // Import buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ImportButton(
                  icon: Icons.upload_file,
                  label: 'Import TXT',
                  color: const Color(0xFF2196F3),
                  onTap: () => _importTextFile(context),
                ),
                const SizedBox(width: 12),
                _ImportButton(
                  icon: Icons.music_note,
                  label: 'Import LRC',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _importLrcFile(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _ImportButton(
              icon: Icons.edit_note,
              label: 'Nhập văn bản thủ công',
              color: const Color(0xFFFF9800),
              onTap: () => _showManualInputDialog(context),
            ),

            const SizedBox(height: 48),
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      (Icons.palette, 'Tô màu theo loại từ / CEFR / Độ khó'),
      (Icons.record_voice_over, 'Text-to-Speech (TTS)'),
      (Icons.touch_app, 'Tap từ để tra cứu & đánh dấu'),
      (Icons.bookmark, 'Lưu đoạn văn để luyện tập'),
      (Icons.sync, 'Đồng bộ với audio'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: features.map((f) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(f.$1, color: const Color(0xFF2196F3), size: 20),
                const SizedBox(width: 12),
                Text(
                  f.$2,
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== COLOR MODE BAR ====================

  Widget _buildColorModeBar(BuildContext context, TextProvider textProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.palette, size: 16, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              const Text(
                'Chế độ màu:',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2196F3),
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
                        child: GestureDetector(
                          onTap: () => textProvider.setColorMode(mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2196F3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2196F3)
                                    : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(mode.icon, size: 14,
                                    color: isSelected ? Colors.white : Colors.grey),
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
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showLegend = !_showLegend),
                icon: Icon(
                  _showLegend ? Icons.info : Icons.info_outline,
                  size: 20,
                ),
                color: _showLegend ? const Color(0xFF2196F3) : Colors.grey,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (_showLegend)
            _buildLegendPanel(textProvider.colorMode),
        ],
      ),
    );
  }

  Widget _buildLegendPanel(ColorMode colorMode) {
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2196F3),
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

  // ==================== TTS CONTROLS ====================

  Widget _buildTtsControls(BuildContext context, TextProvider textProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Speed slider
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              Text('TTS:', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              Expanded(
                child: Slider(
                  value: textProvider.ttsSpeed,
                  min: 0.25,
                  max: 2.0,
                  divisions: 7,
                  activeColor: const Color(0xFF2196F3),
                  inactiveColor: const Color(0xFF2196F3).withOpacity(0.2),
                  onChanged: (value) => textProvider.setTtsSpeed(value),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${textProvider.ttsSpeed.toStringAsFixed(2)}x',
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _TtsButton(
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
                child: _TtsButton(
                  icon: Icons.record_voice_over,
                  label: 'Dòng',
                  color: Colors.blue,
                  enabled: textProvider.currentLineIndex >= 0,
                  onTap: () => textProvider.speakCurrentLine(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TtsButton(
                  icon: Icons.select_all,
                  label: 'Chọn',
                  color: Colors.orange,
                  enabled: textProvider.selectedText != null,
                  onTap: () => textProvider.speakSelected(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TtsButton(
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

  // ==================== SELECTION BAR ====================

  Widget _buildSelectionBar(BuildContext context, TextProvider textProvider) {
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
            const Color(0xFF2196F3).withOpacity(0.2),
            const Color(0xFF2196F3).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.text_fields, size: 18, color: Color(0xFF2196F3)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã chọn ${info.text.split(' ').length} từ',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2196F3),
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
          IconButton(
            onPressed: () => textProvider.speakSelected(),
            icon: const Icon(Icons.volume_up, size: 20),
            color: Colors.blue,
            tooltip: 'Đọc TTS',
          ),
          IconButton(
            onPressed: () => _showCreateSegmentSheet(context, textProvider),
            icon: const Icon(Icons.bookmark_add, size: 20),
            color: Colors.amber,
            tooltip: 'Đánh dấu',
          ),
          IconButton(
            onPressed: () => textProvider.clearSelection(),
            icon: const Icon(Icons.close, size: 20),
            color: Colors.grey,
            tooltip: 'Bỏ chọn',
          ),
        ],
      ),
    );
  }

  // ==================== TEXT CONTENT ====================

  Widget _buildTextContent(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      ) {
    return Container(
      color: const Color(0xFF0D1520),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: textProvider.lines.length,
        itemBuilder: (context, index) {
          return _buildTextLine(context, textProvider, player, index);
        },
      ),
    );
  }

  Widget _buildTextLine(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      int index,
      ) {
    final line = textProvider.lines[index];
    final isCurrentLine = index == textProvider.currentLineIndex;
    final analyzedWords = index < textProvider.analyzedLines.length
        ? textProvider.analyzedLines[index]
        : <AnalyzedWord>[];

    // Check if synced with audio
    final isSynced = line.startTime != null;
    bool isPlaying = false;
    if (isSynced && player.isPlaying && line.startTime != null) {
      isPlaying = player.state.position >= line.startTime! &&
          (line.endTime == null || player.state.position <= line.endTime!);
    }

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
        _showLineOptionsSheet(context, textProvider, player, index, line);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrentLine
              ? const Color(0xFF2196F3).withOpacity(0.15)
              : isPlaying
              ? const Color(0xFF4CAF50).withOpacity(0.15)
              : const Color(0xFF1A1A2E).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentLine
                ? const Color(0xFF2196F3).withOpacity(0.5)
                : isPlaying
                ? const Color(0xFF4CAF50).withOpacity(0.5)
                : Colors.transparent,
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
                        ? const Color(0xFF2196F3)
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
                if (isSynced && line.startTime != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(line.startTime!),
                      style: TextStyle(
                        fontSize: 10,
                        color: isPlaying ? const Color(0xFF4CAF50) : Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (isCurrentLine && textProvider.isSpeaking)
                  _buildSpeakingIndicator(),
                if (isPlaying)
                  const Icon(Icons.volume_up, size: 16, color: Color(0xFF4CAF50)),
              ],
            ),
            const SizedBox(height: 8),

            // Text content with colors
            if (textProvider.colorMode == ColorMode.none)
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
              _buildColoredText(
                analyzedWords,
                textProvider,
                lineStartOffset,
                index,
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

  Widget _buildColoredText(
      List<AnalyzedWord> words,
      TextProvider textProvider,
      int lineStartOffset,
      int lineIndex,
      ) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: words.asMap().entries.map((entry) {
        final wordIndex = entry.key;
        final word = entry.value;

        return GestureDetector(
          onTap: () {
            textProvider.speak(word.word);
          },
          onLongPress: () {
            _showWordOptionsSheet(
              context,
              textProvider,
              word,
              lineIndex,
              wordIndex,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: word.getBackgroundColor(textProvider.colorMode),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              word.word,
              style: TextStyle(
                fontSize: textProvider.fontSize,
                color: word.getColor(textProvider.colorMode),
                fontWeight: word.userDifficulty != null
                    ? FontWeight.bold
                    : FontWeight.normal,
                height: 1.6,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpeakingIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(_pulseAnimation.value * 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up, size: 12, color: Color(0xFF2196F3)),
              SizedBox(width: 4),
              Text(
                'Đang đọc',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF2196F3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
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

  // ==================== BOTTOM CONTROLS ====================

  Widget _buildBottomControls(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
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
              color: textProvider.colorMode != ColorMode.none
                  ? const Color(0xFF2196F3)
                  : null,
              onTap: () => textProvider.cycleColorMode(),
            ),
            _BottomAction(
              icon: _showTtsControls ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              label: 'TTS',
              color: _showTtsControls ? const Color(0xFF2196F3) : null,
              onTap: () => setState(() => _showTtsControls = !_showTtsControls),
            ),
            _BottomAction(
              icon: Icons.bookmark,
              label: '${textProvider.segments.length}',
              color: textProvider.segments.isNotEmpty ? Colors.amber : null,
              onTap: () => _showSegmentsSheet(context, textProvider),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DIALOGS & SHEETS ====================

  void _showWordOptionsSheet(
      BuildContext context,
      TextProvider textProvider,
      AnalyzedWord word,
      int lineIndex,
      int wordIndex,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Word header
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
                          _Badge(label: word.wordType.labelVi, color: word.wordType.color),
                          const SizedBox(width: 6),
                          _Badge(label: word.cefrLevel.shortLabel, color: word.cefrLevel.color),
                        ],
                      ),
                      if (word.meaning != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            word.meaning!,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                      color: isSelected ? level.color : level.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: level.color, width: isSelected ? 2 : 1),
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
                      textProvider.selectText(word.word);
                      _showCreateSegmentSheet(context, textProvider);
                    },
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Lưu học'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLineOptionsSheet(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      int index,
      TextItem line,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dòng ${index + 1}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
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
            if (line.startTime != null && player.currentSongPath != null)
              ListTile(
                leading: const Icon(Icons.sync, color: Colors.green),
                title: const Text('Sync với Audio', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  player.seek(line.startTime!);
                  player.play();
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
                _showCreateSegmentSheet(context, textProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: const Text('Sao chép', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: line.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSegmentSheet(BuildContext context, TextProvider textProvider) {
    final info = textProvider.selectedTextInfo;
    if (info == null && textProvider.selectedText == null) return;

    TextSegmentDifficulty difficulty = TextSegmentDifficulty.medium;
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bookmark_add, color: Color(0xFF2196F3)),
                  SizedBox(width: 8),
                  Text(
                    'Tạo đoạn học',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
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
                    label: Text(
                      d == TextSegmentDifficulty.hard
                          ? 'Khó (5x)'
                          : d == TextSegmentDifficulty.medium
                          ? 'Vừa (3x)'
                          : 'Dễ (1x)',
                    ),
                    selected: difficulty == d,
                    selectedColor: d == TextSegmentDifficulty.hard
                        ? Colors.red
                        : d == TextSegmentDifficulty.medium
                        ? Colors.orange
                        : Colors.green,
                    onSelected: (_) => setModalState(() => difficulty = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Ghi chú (tùy chọn)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        textProvider.createSegmentFromSelection(
                          difficulty: difficulty,
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã lưu đoạn học!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Lưu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

  void _showSegmentsSheet(BuildContext context, TextProvider textProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          final segments = textProvider.segments;

          return Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Đoạn đã lưu (${segments.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: segments.isEmpty
                    ? const Center(
                  child: Text(
                    'Chưa có đoạn nào được lưu',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: segments.length,
                  itemBuilder: (context, index) {
                    final segment = segments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: segment.difficultyColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: segment.difficultyColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                segment.typeIcon,
                                size: 16,
                                color: segment.difficultyColor,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
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
                                '${segment.repeatCount}x',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            segment.content,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    textProvider.speakSegment(segment);
                                  },
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Phát'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: segment.difficultyColor,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  textProvider.deleteSegment(segment.id);
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showManualInputDialog(BuildContext context) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập văn bản',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập hoặc paste văn bản tại đây...\n\nMỗi dòng sẽ được tách riêng.',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        context.read<TextProvider>().loadFromString(controller.text);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                    ),
                    child: const Text('Xác nhận'),
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

  Future<void> _importTextFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      await context.read<TextProvider>().loadTextFile(result.files.single.path!);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _importLrcFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lrc', 'srt'],
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      await context.read<TextProvider>().loadTextFile(result.files.single.path!);
      HapticFeedback.mediumImpact();
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
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

class _TtsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final bool isActive;
  final VoidCallback onTap;

  const _TtsButton({
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
          color: isActive
              ? color.withOpacity(0.3)
              : enabled
              ? color.withOpacity(0.1)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? color : Colors.grey, size: 22),
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

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final effectiveColor = color ?? Colors.white;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          HapticFeedback.selectionClick();
          onTap!();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: color != null
                ? BoxDecoration(
              color: effectiveColor.withOpacity(0.2),
              shape: BoxShape.circle,
            )
                : null,
            child: Icon(
              icon,
              color: isEnabled ? effectiveColor : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isEnabled ? effectiveColor : Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}