// lib/screens/text_studio_screen.dart
// VipSound - Text Studio Screen
// Version 3.0 - Enhanced for Buddhism & Language Learning
// Features: Read/Study/Edit modes, Text Segments with SRS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../providers/text_provider.dart';
import '../providers/player_provider.dart';
import '../models/text_item.dart';
import '../models/text_segment.dart';

// ============================================================================
// ENUMS & CONSTANTS
// ============================================================================

/// Chế độ hoạt động của Text Studio
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

  // === FILTER STATE ===
  TextSegmentDifficulty? _difficultyFilter;
  TextSegmentType? _typeFilter;

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
                if (_mode == TextStudioMode.read)
                  _buildTtsControls(context, textProvider, theme),
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
          // Back button
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

          // Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primary, theme.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.text_fields, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Text Studio',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  textProvider.currentDocument?.title ?? 'Chưa có văn bản',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Stats badge
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

          // Import button
          IconButton(
            onPressed: () => _importTextFile(context),
            icon: Icon(Icons.file_open_outlined, size: 22),
            color: theme.primary,
            tooltip: 'Mở file',
          ),

          // Paste button
          IconButton(
            onPressed: () => _showPasteDialog(context, theme),
            icon: Icon(Icons.paste, size: 22),
            color: theme.primary,
            tooltip: 'Dán văn bản',
          ),

          // Settings
          IconButton(
            onPressed: () => _showSettingsSheet(context, textProvider, theme),
            icon: Icon(Icons.tune, size: 22),
            color: theme.primary,
            tooltip: 'Cài đặt',
          ),
        ],
      ),
    );
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
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey,
              ),
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
  // READ MODE - Đọc và đánh dấu đoạn
  // ============================================================================

  Widget _buildReadMode(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    return Column(
      children: [
        // Selection hint
        if (textProvider.selectedTextInfo != null)
          _buildSelectionBar(context, textProvider, theme),

        // Text content
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: textProvider.lines.length,
            itemBuilder: (context, index) {
              return _buildTextLine(
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Quick action buttons
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
            onTap: () {
              textProvider.clearSelection();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextLine(
      BuildContext context,
      TextProvider textProvider,
      int index,
      _StudioTheme theme,
      ) {
    final line = textProvider.lines[index];
    final isCurrentLine = index == textProvider.currentLineIndex;

    // Tính offset của dòng này trong fullText
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

            // Selectable content
            SelectableText(
              line.content,
              style: TextStyle(
                fontSize: textProvider.fontSize,
                color: Colors.white,
                height: 1.6,
              ),
              onSelectionChanged: (selection, cause) {
                if (selection.baseOffset != selection.extentOffset) {
                  final start = selection.baseOffset < selection.extentOffset
                      ? selection.baseOffset
                      : selection.extentOffset;
                  final end = selection.baseOffset < selection.extentOffset
                      ? selection.extentOffset
                      : selection.baseOffset;

                  final selectedText = line.content.substring(start, end);

                  textProvider.selectTextWithOffsets(
                    text: selectedText,
                    startOffset: lineStartOffset + start,
                    endOffset: lineStartOffset + end,
                    lineIndex: index,
                  );
                }
              },
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
  // STUDY MODE - Luyện các đoạn đã đánh dấu (SRS)
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
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StudyStat(
                label: 'Tổng',
                value: '${stats['total']}',
                color: theme.primary,
              ),
              _StudyStat(
                label: 'Dễ',
                value: '${stats['easy']}',
                color: Colors.green,
              ),
              _StudyStat(
                label: 'Vừa',
                value: '${stats['medium']}',
                color: Colors.orange,
              ),
              _StudyStat(
                label: 'Khó',
                value: '${stats['hard']}',
                color: Colors.red,
              ),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: textProvider.isPlayingSegment
                    ? textProvider.stopSegmentPlayback
                    : () => _startReviewSession(context, textProvider, theme),
                icon: Icon(
                  textProvider.isPlayingSegment ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(
                  textProvider.isPlayingSegment
                      ? 'Dừng ôn tập'
                      : 'Bắt đầu ôn tập ($needsReview đoạn)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  textProvider.isPlayingSegment ? Colors.red : Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          // Filter chips
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  isSelected: _difficultyFilter == null,
                  onTap: () => setState(() => _difficultyFilter = null),
                  theme: theme,
                ),
                _FilterChip(
                  label: 'Dễ',
                  isSelected: _difficultyFilter == TextSegmentDifficulty.easy,
                  color: Colors.green,
                  onTap: () => setState(
                          () => _difficultyFilter = TextSegmentDifficulty.easy),
                  theme: theme,
                ),
                _FilterChip(
                  label: 'Vừa',
                  isSelected: _difficultyFilter == TextSegmentDifficulty.medium,
                  color: Colors.orange,
                  onTap: () => setState(
                          () => _difficultyFilter = TextSegmentDifficulty.medium),
                  theme: theme,
                ),
                _FilterChip(
                  label: 'Khó',
                  isSelected: _difficultyFilter == TextSegmentDifficulty.hard,
                  color: Colors.red,
                  onTap: () => setState(
                          () => _difficultyFilter = TextSegmentDifficulty.hard),
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyMode(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    var segments = textProvider.segments;

    // Apply filter
    if (_difficultyFilter != null) {
      segments = segments
          .where((s) => s.difficulty == _difficultyFilter)
          .toList();
    }

    if (segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: theme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _difficultyFilter != null
                  ? 'Không có đoạn nào với độ khó này'
                  : 'Chưa có đoạn học nào',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chuyển sang chế độ Đọc và chọn đoạn văn bản để đánh dấu',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => setState(() => _mode = TextStudioMode.read),
              icon: Icon(Icons.chrome_reader_mode, color: theme.primary),
              label: Text('Chuyển sang Đọc', style: TextStyle(color: theme.primary)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
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

        return _buildSegmentCard(
          context,
          textProvider,
          segment,
          isPlaying,
          theme,
        );
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
        boxShadow: isPlaying
            ? [
          BoxShadow(
            color: segment.difficultyColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: segment.difficultyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    segment.typeIcon,
                    size: 16,
                    color: segment.difficultyColor,
                  ),
                ),
                const SizedBox(width: 8),

                // Difficulty badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: segment.difficultyColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    segment.difficulty == TextSegmentDifficulty.hard
                        ? 'Khó'
                        : segment.difficulty == TextSegmentDifficulty.medium
                        ? 'Vừa'
                        : 'Dễ',
                    style: TextStyle(
                      fontSize: 11,
                      color: segment.difficultyColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const Spacer(),

                // Settings
                Text(
                  '${segment.repeatCount}x • ${segment.ttsSpeed.toStringAsFixed(1)}x',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),

                // Mastery indicator
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

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              segment.content,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),

          // Note
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

          // Playing progress
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

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Play button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPlaying
                        ? textProvider.stopSegmentPlayback
                        : () => textProvider.speakSegment(segment),
                    icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow, size: 18),
                    label: Text(isPlaying ? 'Dừng' : 'Phát'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPlaying
                          ? Colors.red
                          : segment.difficultyColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Edit button
                IconButton(
                  onPressed: () => _showEditSegmentSheet(
                      context, textProvider, segment, theme),
                  icon: Icon(Icons.edit_outlined, color: Colors.grey[400]),
                  tooltip: 'Chỉnh sửa',
                ),

                // Delete button
                IconButton(
                  onPressed: () => _confirmDeleteSegment(
                      context, textProvider, segment),
                  icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                  tooltip: 'Xóa',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // EDIT MODE - Chỉnh sửa toàn bộ văn bản
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
          // Info bar
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber,
                    ),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Text editor
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
                  hintText: 'Nhập hoặc dán văn bản ở đây...\n\n'
                      '• Mỗi dòng sẽ được tách riêng\n'
                      '• Dòng trống sẽ bị bỏ qua\n'
                      '• Sau khi lưu, chuyển sang chế độ Đọc để đánh dấu đoạn',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    height: 1.6,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _hasUnsavedChanges = true);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Speed control
          Row(
            children: [
              Icon(Icons.speed, size: 18, color: theme.primary),
              const SizedBox(width: 8),
              Text(
                'TTS:',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
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

          // TTS buttons
          Row(
            children: [
              Expanded(
                child: _TtsActionButton(
                  icon: Icons.play_arrow,
                  label: 'Tất cả',
                  color: Colors.green,
                  enabled: textProvider.lines.isNotEmpty,
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
          _BottomAction(
            icon: Icons.delete_sweep,
            label: 'Xóa',
            color: Colors.red,
            onTap: () => _confirmClearAll(context, textProvider),
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
              child: Icon(
                Icons.text_snippet_outlined,
                size: 64,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có văn bản',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập văn bản để bắt đầu học',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),

            // Action buttons
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _mode = TextStudioMode.edit);
                  },
                  icon: Icon(Icons.edit, color: theme.primary),
                  label: Text('Nhập text', style: TextStyle(color: theme.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _TipItem(
                    icon: Icons.touch_app,
                    text: 'Chạm vào dòng để chọn, chạm đúp để đọc TTS',
                    color: theme.primary,
                  ),
                  _TipItem(
                    icon: Icons.text_fields,
                    text: 'Bôi đen văn bản để đánh dấu đoạn học',
                    color: Colors.amber,
                  ),
                  _TipItem(
                    icon: Icons.school,
                    text: 'Chuyển sang Luyện để ôn tập theo SRS',
                    color: Colors.purple,
                  ),
                ],
              ),
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
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dán văn bản',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.primary,
              ),
            ),
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
                      if (controller.text.trim().isNotEmpty) {
                        context.read<TextProvider>().loadText(
                          controller.text,
                          title: 'Văn bản mới',
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                    ),
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

  void _showCreateSegmentSheet(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    final info = textProvider.selectedTextInfo;
    if (info == null) return;

    TextSegmentDifficulty difficulty = TextSegmentDifficulty.medium;
    TextSegmentType type = theme.defaultSegmentType;
    final repeatController = TextEditingController(text: '3');
    final speedController = TextEditingController(
      text: textProvider.ttsSpeed.toStringAsFixed(2),
    );
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.bookmark_add, color: theme.primary),
                    const SizedBox(width: 8),
                    const Text(
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

                // Selected text preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    info.text.length > 100
                        ? '${info.text.substring(0, 100)}...'
                        : info.text,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),

                // Difficulty selector
                const Text(
                  'Độ khó:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _DifficultyChip(
                      label: 'Dễ (1x)',
                      value: TextSegmentDifficulty.easy,
                      current: difficulty,
                      onSelected: (d) => setModalState(() {
                        difficulty = d;
                        repeatController.text = '1';
                        speedController.text = '1.0';
                      }),
                    ),
                    _DifficultyChip(
                      label: 'Vừa (3x)',
                      value: TextSegmentDifficulty.medium,
                      current: difficulty,
                      onSelected: (d) => setModalState(() {
                        difficulty = d;
                        repeatController.text = '3';
                        speedController.text = '0.85';
                      }),
                    ),
                    _DifficultyChip(
                      label: 'Khó (5x)',
                      value: TextSegmentDifficulty.hard,
                      current: difficulty,
                      onSelected: (d) => setModalState(() {
                        difficulty = d;
                        repeatController.text = '5';
                        speedController.text = '0.7';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Type selector
                const Text(
                  'Loại:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TextSegmentType.values.map((t) {
                    final isSelected = type == t;
                    return ChoiceChip(
                      label: Text(_getTypeLabel(t)),
                      selected: isSelected,
                      selectedColor: theme.primary,
                      onSelected: (_) => setModalState(() => type = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Custom settings
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: repeatController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Số lần lặp',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.repeat, color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
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
                          labelText: 'Tốc độ TTS',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.speed, color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Note
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (VD: Tứ Diệu Đế, Phrasal verb...)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.notes, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
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
                          final repeat = int.tryParse(repeatController.text) ?? 3;
                          final speed = double.tryParse(speedController.text) ??
                              textProvider.ttsSpeed;

                          textProvider.createSegmentFromSelection(
                            difficulty: difficulty,
                            type: type,
                            repeatCountOverride: repeat,
                            ttsSpeedOverride: speed,
                            note: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Đã lưu đoạn học!'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'Xem',
                                textColor: Colors.white,
                                onPressed: () =>
                                    setState(() => _mode = TextStudioMode.study),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Lưu đoạn học'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLineOptionsSheet(
      BuildContext context,
      TextProvider textProvider,
      int index,
      TextItem line,
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
            Text(
              'Dòng ${index + 1}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                line.content,
                style: const TextStyle(color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            _LineOption(
              icon: Icons.volume_up,
              title: 'Đọc TTS',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                textProvider.setCurrentLine(index);
                textProvider.speakCurrentLine();
              },
            ),
            _LineOption(
              icon: Icons.bookmark_add,
              title: 'Đánh dấu toàn bộ dòng',
              color: Colors.amber,
              onTap: () {
                Navigator.pop(context);
                // Select entire line
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
            _LineOption(
              icon: Icons.copy,
              title: 'Sao chép',
              color: Colors.grey,
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
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showEditSegmentSheet(
      BuildContext context,
      TextProvider textProvider,
      TextSegment segment,
      _StudioTheme theme,
      ) {
    TextSegmentDifficulty difficulty = segment.difficulty;
    final repeatController = TextEditingController(
      text: segment.repeatCount.toString(),
    );
    final speedController = TextEditingController(
      text: segment.ttsSpeed.toStringAsFixed(2),
    );
    final noteController = TextEditingController(text: segment.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
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
              const Text(
                'Chỉnh sửa đoạn học',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Difficulty
              const Text('Độ khó:', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: TextSegmentDifficulty.values.map((d) {
                  return ChoiceChip(
                    label: Text(d == TextSegmentDifficulty.hard
                        ? 'Khó'
                        : d == TextSegmentDifficulty.medium
                        ? 'Vừa'
                        : 'Dễ'),
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
              const SizedBox(height: 16),

              // Settings
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: repeatController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Số lần lặp',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: speedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Tốc độ TTS',
                        labelStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Note
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final updated = segment.copyWith(
                          difficulty: difficulty,
                          repeatCount: int.tryParse(repeatController.text) ??
                              segment.repeatCount,
                          ttsSpeed: double.tryParse(speedController.text) ??
                              segment.ttsSpeed,
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        );
                        textProvider.updateSegment(updated);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primary,
                      ),
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

  void _showSettingsSheet(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cài đặt Text Studio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.primary,
                ),
              ),
              const SizedBox(height: 20),

              // Font size
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
                  Text(
                    '${textProvider.fontSize.toInt()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),

              // TTS Language
              ListTile(
                leading: const Icon(Icons.language, color: Colors.grey),
                title: const Text('Ngôn ngữ TTS',
                    style: TextStyle(color: Colors.white)),
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

              // Show translation
              SwitchListTile(
                secondary: const Icon(Icons.translate, color: Colors.grey),
                title: const Text('Hiện bản dịch',
                    style: TextStyle(color: Colors.white)),
                value: textProvider.showTranslation,
                activeColor: theme.primary,
                onChanged: (_) {
                  textProvider.toggleTranslation();
                  setModalState(() {});
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSegment(
      BuildContext context,
      TextProvider textProvider,
      TextSegment segment,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Xóa đoạn học?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bạn có chắc muốn xóa:\n"${segment.content.length > 50 ? '${segment.content.substring(0, 50)}...' : segment.content}"',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
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

  void _confirmClearAll(BuildContext context, TextProvider textProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Xóa tất cả?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Xóa toàn bộ văn bản và các đoạn đã đánh dấu?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              textProvider.clearText();
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
        title: const Text('Chưa lưu thay đổi',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có thay đổi chưa lưu. Bạn muốn làm gì?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tiếp tục sửa'),
          ),
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

  void _startReviewSession(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    textProvider.startReviewSession();
  }

  String _getTypeLabel(TextSegmentType type) {
    switch (type) {
      case TextSegmentType.vocabulary:
        return 'Từ vựng';
      case TextSegmentType.phrase:
        return 'Cụm từ';
      case TextSegmentType.sentence:
        return 'Câu';
      case TextSegmentType.paragraph:
        return 'Đoạn';
      case TextSegmentType.dharma:
        return 'Phật Pháp';
      case TextSegmentType.grammar:
        return 'Ngữ pháp';
    }
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
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;
  final _StudioTheme theme;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? theme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
            Icon(
              icon,
              color: enabled ? color : Colors.grey,
              size: 22,
            ),
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

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TipItem({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String label;
  final TextSegmentDifficulty value;
  final TextSegmentDifficulty current;
  final void Function(TextSegmentDifficulty) onSelected;

  const _DifficultyChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    final color = value == TextSegmentDifficulty.hard
        ? Colors.red
        : value == TextSegmentDifficulty.medium
        ? Colors.orange
        : Colors.green;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey,
      ),
      onSelected: (_) => onSelected(value),
    );
  }
}

class _LineOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _LineOption({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}