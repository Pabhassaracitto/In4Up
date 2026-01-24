// lib/screens/text_studio_screen.dart
// VipSound - Text Studio Screen
// Version 3.0 - Enhanced for Buddhism & Language Learning
// Features: Read, Study, Edit modes with Segment-based Learning

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

/// Chế độ Text Studio
enum TextStudioMode {
  read,   // Đọc - Xem văn bản theo dòng
  study,  // Học - Luyện tập các segments đã đánh dấu
  edit,   // Sửa - Chỉnh sửa toàn văn bản tự do
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

  // === CONTROLLERS ===
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // === ANIMATION ===
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // === UI STATE ===
  bool _showSearch = false;
  String _searchQuery = '';

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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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
          name: 'Tịnh Tâm',
          segmentCategories: [
            TextSegmentCategory.sutra,
            TextSegmentCategory.dharma,
            TextSegmentCategory.mantra,
            TextSegmentCategory.verse,
          ],
        );

      case VipMode.english:
        return const _StudioTheme(
          primary: Color(0xFF64B5F6),
          secondary: Color(0xFF1976D2),
          accent: Color(0xFFBBDEFB),
          background: Color(0xFF0D1117),
          surface: Color(0xFF161B22),
          icon: Icons.school,
          name: 'Học Tập',
          segmentCategories: [
            TextSegmentCategory.vocabulary,
            TextSegmentCategory.phrase,
            TextSegmentCategory.idiom,
            TextSegmentCategory.sentence,
            TextSegmentCategory.grammar,
          ],
        );

      case VipMode.music:
        return const _StudioTheme(
          primary: Color(0xFF9C7CF4),
          secondary: Color(0xFF6C63FF),
          accent: Color(0xFFD1C4E9),
          background: Color(0xFF0F0F1A),
          surface: Color(0xFF1A1A2E),
          icon: Icons.music_note,
          name: 'Âm Nhạc',
          segmentCategories: [
            TextSegmentCategory.favorite,
            TextSegmentCategory.custom,
          ],
        );
    }
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerProvider, TextProvider>(
      builder: (context, player, textProvider, _) {
        final theme = _getTheme(player.currentMode);

        return Scaffold(
          backgroundColor: theme.background,
          body: SafeArea(
            child: Column(
              children: [
                // App Bar
                _buildAppBar(context, textProvider, player, theme),

                // Mode Switcher
                _buildModeSwitcher(theme),

                // TTS Controls (chỉ hiện khi Read/Study mode)
                if (_mode != TextStudioMode.edit)
                  _buildTtsControls(context, textProvider, player, theme),

                // Main Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildMainContent(context, textProvider, player, theme),
                  ),
                ),

                // Bottom Bar (chỉ hiện khi có text)
                if (textProvider.hasText && _mode != TextStudioMode.edit)
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
            onPressed: () => Navigator.pop(context),
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
            child: const Icon(Icons.text_fields, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Text Studio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  textProvider.currentDocument?.title ?? 'Chưa có văn bản',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Search toggle
          if (_mode == TextStudioMode.read)
            IconButton(
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              },
              icon: Icon(
                _showSearch ? Icons.search_off : Icons.search,
                size: 22,
              ),
              color: _showSearch ? theme.primary : Colors.white70,
            ),

          // Import file
          IconButton(
            onPressed: () => _importTextFile(context),
            icon: const Icon(Icons.file_open_outlined, size: 22),
            color: theme.primary,
            tooltip: 'Mở file',
          ),

          // Paste text
          IconButton(
            onPressed: () => _showPasteDialog(context, textProvider, theme),
            icon: const Icon(Icons.paste, size: 22),
            color: theme.primary,
            tooltip: 'Dán văn bản',
          ),

          // Settings
          IconButton(
            onPressed: () => _showSettingsSheet(context, textProvider, theme),
            icon: const Icon(Icons.tune, size: 22),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildModeChip(
            'Đọc',
            Icons.menu_book,
            TextStudioMode.read,
            theme,
          ),
          _buildModeChip(
            'Học',
            Icons.school,
            TextStudioMode.study,
            theme,
          ),
          _buildModeChip(
            'Sửa',
            Icons.edit_note,
            TextStudioMode.edit,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(
      String label,
      IconData icon,
      TextStudioMode mode,
      _StudioTheme theme,
      ) {
    final isSelected = _mode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _mode = mode);
          HapticFeedback.selectionClick();

          // Nếu chuyển sang edit mode, load text vào controller
          if (mode == TextStudioMode.edit) {
            final text = context.read<TextProvider>().fullText;
            _editController.text = text;
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: theme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
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
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TTS CONTROLS
  // ============================================================================

  Widget _buildTtsControls(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Speed slider
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
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: theme.primary,
                    inactiveTrackColor: theme.primary.withOpacity(0.2),
                    thumbColor: theme.primary,
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

          const SizedBox(height: 10),

          // TTS Action buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TtsButton(
                  icon: Icons.play_arrow,
                  label: 'Tất cả',
                  color: Colors.green,
                  isEnabled: textProvider.hasText && !textProvider.isSpeaking,
                  onPressed: () => textProvider.speakAllLines(),
                ),
                const SizedBox(width: 8),
                _TtsButton(
                  icon: Icons.record_voice_over,
                  label: 'Dòng này',
                  color: Colors.blue,
                  isEnabled: textProvider.currentLineIndex >= 0 && !textProvider.isSpeaking,
                  onPressed: () => textProvider.speakCurrentLine(),
                ),
                const SizedBox(width: 8),
                _TtsButton(
                  icon: Icons.select_all,
                  label: 'Đã chọn',
                  color: Colors.orange,
                  isEnabled: textProvider.hasSelection && !textProvider.isSpeaking,
                  onPressed: () => textProvider.speakSelected(),
                ),
                const SizedBox(width: 8),
                if (textProvider.isSpeaking || textProvider.isStudyingSegment)
                  _TtsButton(
                    icon: Icons.stop,
                    label: 'Dừng',
                    color: Colors.red,
                    isEnabled: true,
                    isActive: true,
                    onPressed: () => textProvider.stopSpeaking(),
                  ),
                if (_mode == TextStudioMode.study && textProvider.hasSegments) ...[
                  const SizedBox(width: 8),
                  _TtsButton(
                    icon: Icons.refresh,
                    label: 'Ôn tập',
                    color: Colors.purple,
                    isEnabled: textProvider.dueForReview.isNotEmpty,
                    onPressed: () => textProvider.speakAllDueSegments(),
                  ),
                ],
              ],
            ),
          ),

          // Study progress (nếu đang study segment)
          if (textProvider.isStudyingSegment && textProvider.currentSegment != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _buildStudyProgress(textProvider, theme),
            ),
        ],
      ),
    );
  }

  Widget _buildStudyProgress(TextProvider textProvider, _StudioTheme theme) {
    final segment = textProvider.currentSegment!;
    final progress = textProvider.currentRepeatCount / segment.repeatCount;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Icon(Icons.volume_up, size: 16, color: theme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  segment.content.length > 40
                      ? '${segment.content.substring(0, 40)}...'
                      : segment.content,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${textProvider.currentRepeatCount}/${segment.repeatCount}',
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: theme.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // MAIN CONTENT
  // ============================================================================

  Widget _buildMainContent(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
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
  // READ MODE
  // ============================================================================

  Widget _buildReadMode(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    if (!textProvider.hasText) {
      return _buildEmptyState(context, theme);
    }

    return Column(
      children: [
        // Search bar (nếu hiện)
        if (_showSearch)
          _buildSearchBar(theme),

        // Text content
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: textProvider.lines.length,
            itemBuilder: (context, index) {
              final line = textProvider.lines[index];

              // Filter by search
              if (_searchQuery.isNotEmpty &&
                  !line.content.toLowerCase().contains(_searchQuery.toLowerCase())) {
                return const SizedBox.shrink();
              }

              final isCurrentLine = index == textProvider.currentLineIndex;

              // Kiểm tra xem line này có segment nào không
              final lineSegments = _getSegmentsInLine(textProvider, index);

              return _buildTextLine(
                context,
                textProvider,
                index,
                line,
                isCurrentLine,
                lineSegments,
                theme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(_StudioTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm trong văn bản...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: theme.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            icon: const Icon(Icons.clear, size: 18),
            color: Colors.grey,
          )
              : null,
          filled: true,
          fillColor: theme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  List<TextSegment> _getSegmentsInLine(TextProvider textProvider, int lineIndex) {
    // Tính offset của line trong fullText
    int lineStartOffset = 0;
    for (int i = 0; i < lineIndex && i < textProvider.lines.length; i++) {
      lineStartOffset += textProvider.lines[i].content.length + 1;
    }
    final lineEndOffset = lineStartOffset + textProvider.lines[lineIndex].content.length;

    // Tìm segments nằm trong line này
    return textProvider.segments.where((s) {
      return (s.startOffset >= lineStartOffset && s.startOffset < lineEndOffset) ||
          (s.endOffset > lineStartOffset && s.endOffset <= lineEndOffset) ||
          (s.startOffset < lineStartOffset && s.endOffset > lineEndOffset);
    }).toList();
  }

  Widget _buildTextLine(
      BuildContext context,
      TextProvider textProvider,
      int index,
      TextItem line,
      bool isCurrentLine,
      List<TextSegment> lineSegments,
      _StudioTheme theme,
      ) {
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
        textProvider.setCurrentLine(index);
        _showLineOptionsSheet(context, textProvider, index, line, theme);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrentLine
              ? theme.primary.withOpacity(0.15)
              : lineSegments.isNotEmpty
              ? _getSegmentColor(lineSegments.first.difficulty).withOpacity(0.08)
              : theme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentLine
                ? theme.primary
                : lineSegments.isNotEmpty
                ? _getSegmentColor(lineSegments.first.difficulty).withOpacity(0.3)
                : Colors.transparent,
            width: isCurrentLine ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Line number
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCurrentLine
                        ? theme.primary.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrentLine ? theme.primary : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Segment badges
                if (lineSegments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...lineSegments.take(3).map((seg) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _SegmentBadge(
                      segment: seg,
                      onTap: () => _showSegmentDetails(context, textProvider, seg, theme),
                    ),
                  )),
                  if (lineSegments.length > 3)
                    Text(
                      '+${lineSegments.length - 3}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                ],

                const Spacer(),

                // Speaking indicator
                if (isCurrentLine && textProvider.isSpeaking)
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Icon(Icons.volume_up, size: 16, color: theme.primary),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Text content with selection support
            _buildSelectableText(context, textProvider, index, line, theme),

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
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectableText(
      BuildContext context,
      TextProvider textProvider,
      int lineIndex,
      TextItem line,
      _StudioTheme theme,
      ) {
    return SelectableText(
      line.content,
      style: TextStyle(
        fontSize: textProvider.fontSize,
        color: Colors.white,
        height: 1.6,
      ),
      onSelectionChanged: (selection, cause) {
        if (selection.baseOffset != selection.extentOffset) {
          final selectedText = line.content.substring(
            selection.baseOffset,
            selection.extentOffset,
          );

          // Tính global offset
          final globalStart = textProvider.calculateGlobalOffset(
            lineIndex,
            selection.baseOffset,
          );
          final globalEnd = textProvider.calculateGlobalOffset(
            lineIndex,
            selection.extentOffset,
          );

          textProvider.selectTextWithOffsets(
            text: selectedText,
            startOffset: globalStart,
            endOffset: globalEnd,
            lineIndex: lineIndex,
          );
        }
      },
    );
  }

  Color _getSegmentColor(TextSegmentDifficulty difficulty) {
    return Color(TextSegment.difficultyColorValue(difficulty));
  }

  // ============================================================================
  // STUDY MODE
  // ============================================================================

  Widget _buildStudyMode(
      BuildContext context,
      TextProvider textProvider,
      _StudioTheme theme,
      ) {
    if (!textProvider.hasSegments) {
      return _buildNoSegmentsState(context, theme);
    }

    final segments = textProvider.segments;
    final stats = textProvider.getStats();

    return Column(
      children: [
        // Stats summary
        _buildStudyStats(stats, theme),

        // Filter chips
        _buildSegmentFilters(textProvider, theme),

        // Segments list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: segments.length,
            itemBuilder: (context, index) {
              final segment = segments[index];
              return _buildSegmentCard(context, textProvider, segment, index, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStudyStats(TextLearningStats stats, _StudioTheme theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primary.withOpacity(0.15),
            theme.secondary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.bookmark,
            value: '${stats.totalSegments}',
            label: 'Đoạn',
            color: theme.primary,
          ),
          _StatItem(
            icon: Icons.flag,
            value: '${stats.hardCount}',
            label: 'Khó',
            color: Colors.red,
          ),
          _StatItem(
            icon: Icons.refresh,
            value: '${stats.totalReviews}',
            label: 'Ôn tập',
            color: Colors.orange,
          ),
          _StatItem(
            icon: Icons.check_circle,
            value: '${(stats.completionRate * 100).toInt()}%',
            label: 'Hoàn thành',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentFilters(TextProvider textProvider, _StudioTheme theme) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'Tất cả (${textProvider.segments.length})',
            isSelected: true,
            color: theme.primary,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Khó (${textProvider.hardSegments.length})',
            isSelected: false,
            color: Colors.red,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Cần ôn (${textProvider.dueForReview.length})',
            isSelected: false,
            color: Colors.orange,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(
      BuildContext context,
      TextProvider textProvider,
      TextSegment segment,
      int index,
      _StudioTheme theme,
      ) {
    final diffColor = _getSegmentColor(segment.difficulty);
    final isStudying = textProvider.isStudyingSegment &&
        textProvider.currentSegmentIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isStudying
            ? diffColor.withOpacity(0.15)
            : theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStudying ? diffColor : diffColor.withOpacity(0.3),
          width: isStudying ? 2 : 1,
        ),
        boxShadow: isStudying
            ? [
          BoxShadow(
            color: diffColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSegmentDetails(context, textProvider, segment, theme),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // Difficulty badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: diffColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getDifficultyLabel(segment.difficulty),
                        style: TextStyle(
                          color: diffColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Category badge
                    Icon(
                      IconData(
                        TextSegment.categoryIconCodePoint(segment.category),
                        fontFamily: 'MaterialIcons',
                      ),
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getCategoryLabel(segment.category),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    // Settings
                    Text(
                      '${segment.repeatCount}x • ${segment.ttsSpeed.toStringAsFixed(1)}x',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Content
                Text(
                  segment.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Note
                if (segment.note != null && segment.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notes, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            segment.note!,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Action buttons
                Row(
                  children: [
                    // Play button
                    _SegmentActionButton(
                      icon: isStudying ? Icons.stop : Icons.play_arrow,
                      color: isStudying ? Colors.red : Colors.green,
                      onTap: () {
                        if (isStudying) {
                          textProvider.skipCurrentSegment();
                        } else {
                          textProvider.speakSegment(segment);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    // Edit button
                    _SegmentActionButton(
                      icon: Icons.edit,
                      color: Colors.blue,
                      onTap: () => _showEditSegmentDialog(context, textProvider, segment, theme),
                    ),
                    const SizedBox(width: 8),
                    // Delete button
                    _SegmentActionButton(
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onTap: () => _confirmDeleteSegment(context, textProvider, segment),
                    ),
                    const Spacer(),
                    // Review count
                    if (segment.reviewCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Colors.green[400]),
                            const SizedBox(width: 4),
                            Text(
                              '${segment.reviewCount} lần',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Study progress (if studying this segment)
                if (isStudying)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: textProvider.currentRepeatCount / segment.repeatCount,
                        backgroundColor: diffColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(diffColor),
                        minHeight: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSegmentsState(BuildContext context, _StudioTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                Icons.bookmark_border,
                size: 48,
                color: theme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có đoạn học nào',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn văn bản trong chế độ Đọc,\nsau đó bấm "Đánh dấu" để tạo đoạn học.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _mode = TextStudioMode.read),
              icon: const Icon(Icons.menu_book, size: 18),
              label: const Text('Đến chế độ Đọc'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDifficultyLabel(TextSegmentDifficulty difficulty) {
    switch (difficulty) {
      case TextSegmentDifficulty.easy:
        return 'Dễ';
      case TextSegmentDifficulty.medium:
        return 'Vừa';
      case TextSegmentDifficulty.hard:
        return 'Khó';
      case TextSegmentDifficulty.master:
        return 'Thuộc lòng';
    }
  }

  String _getCategoryLabel(TextSegmentCategory category) {
    switch (category) {
      case TextSegmentCategory.sutra:
        return 'Kinh';
      case TextSegmentCategory.dharma:
        return 'Pháp';
      case TextSegmentCategory.mantra:
        return 'Chú';
      case TextSegmentCategory.verse:
        return 'Kệ';
      case TextSegmentCategory.vocabulary:
        return 'Từ vựng';
      case TextSegmentCategory.phrase:
        return 'Cụm từ';
      case TextSegmentCategory.idiom:
        return 'Thành ngữ';
      case TextSegmentCategory.sentence:
        return 'Câu';
      case TextSegmentCategory.grammar:
        return 'Ngữ pháp';
      case TextSegmentCategory.favorite:
        return 'Yêu thích';
      case TextSegmentCategory.difficult:
        return 'Điểm mù';
      case TextSegmentCategory.review:
        return 'Ôn tập';
      case TextSegmentCategory.custom:
        return 'Tùy chỉnh';
    }
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
          // Hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: theme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chỉnh sửa tự do. Các đoạn học đã đánh dấu có thể bị lệch offset.',
                    style: TextStyle(
                      color: theme.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Text editor
          Expanded(
            child: TextField(
              controller: _editController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                color: Colors.white,
                fontSize: textProvider.fontSize,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Nhập hoặc chỉnh sửa văn bản tự do...\n\nMỗi dòng sẽ được hiển thị riêng trong chế độ Đọc.',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  height: 1.6,
                ),
                filled: true,
                fillColor: theme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primary),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _editController.text = textProvider.fullText;
                    setState(() => _mode = TextStudioMode.read);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Hủy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    textProvider.updateFullText(_editController.text);
                    setState(() => _mode = TextStudioMode.read);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã cập nhật văn bản'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save, size: 18),
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
                Icons.text_snippet,
                size: 56,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 28),
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
              'Nhập hoặc mở file text để bắt đầu',
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _importTextFile(context),
                  icon: const Icon(Icons.file_open, size: 18),
                  label: const Text('Mở file'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _mode = TextStudioMode.edit),
                  icon: Icon(Icons.edit, color: theme.primary, size: 18),
                  label: Text('Nhập text', style: TextStyle(color: theme.primary)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Features
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(
                    'Tính năng vượt trội',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FeatureItem(
                    icon: Icons.bookmark,
                    text: 'Đánh dấu từ/cụm/câu với độ khó riêng',
                    color: theme.primary,
                  ),
                  _FeatureItem(
                    icon: Icons.speed,
                    text: 'Tốc độ TTS riêng cho từng đoạn',
                    color: Colors.orange,
                  ),
                  _FeatureItem(
                    icon: Icons.loop,
                    text: 'Số lần lặp tùy chỉnh (1-20 lần)',
                    color: Colors.green,
                  ),
                  _FeatureItem(
                    icon: Icons.school,
                    text: 'Study mode như Anki với TTS',
                    color: Colors.blue,
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
        border: Border(
          top: BorderSide(color: theme.primary.withOpacity(0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Font size decrease
          _BottomButton(
            icon: Icons.text_decrease,
            label: 'A-',
            color: theme.primary,
            onPressed: () => textProvider.setFontSize(textProvider.fontSize - 2),
          ),

          // Font size increase
          _BottomButton(
            icon: Icons.text_increase,
            label: 'A+',
            color: theme.primary,
            onPressed: () => textProvider.setFontSize(textProvider.fontSize + 2),
          ),

          // Mark segment (main action)
          _BottomButton(
            icon: Icons.bookmark_add,
            label: 'Đánh dấu',
            color: textProvider.hasSelection ? Colors.amber : Colors.grey,
            isHighlighted: textProvider.hasSelection,
            onPressed: textProvider.hasSelection
                ? () => _showCreateSegmentDialog(context, textProvider, player, theme)
                : null,
          ),

          // Sync with audio
          _BottomButton(
            icon: Icons.sync,
            label: 'Sync',
            color: player.currentSongPath != null ? Colors.green : Colors.grey,
            onPressed: player.currentSongPath != null
                ? () => _syncWithAudio(context)
                : null,
          ),

          // Clear all
          _BottomButton(
            icon: Icons.delete_sweep,
            label: 'Xóa',
            color: Colors.red,
            onPressed: () => _confirmClearAll(context, textProvider),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  void _showCreateSegmentDialog(
      BuildContext context,
      TextProvider textProvider,
      PlayerProvider player,
      _StudioTheme theme,
      ) {
    final info = textProvider.selectedTextInfo;
    if (info == null) return;

    TextSegmentDifficulty difficulty = TextSegmentDifficulty.medium;
    TextSegmentCategory category = theme.segmentCategories.first;
    final repeatController = TextEditingController(
      text: TextSegment.suggestedRepeatCount(difficulty).toString(),
    );
    final speedController = TextEditingController(
      text: TextSegment.suggestedTtsSpeed(difficulty).toStringAsFixed(2),
    );
    final gapController = TextEditingController(text: '1.0');
    final noteController = TextEditingController();
    final translationController = TextEditingController();

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
                // Handle
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
                const SizedBox(height: 16),

                // Title
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    info.text.length > 100
                        ? '${info.text.substring(0, 100)}...'
                        : info.text,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Difficulty selection
                const Text(
                  'Độ khó',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: TextSegmentDifficulty.values.map((d) {
                    final isSelected = difficulty == d;
                    final color = _getSegmentColor(d);
                    return ChoiceChip(
                      label: Text(_getDifficultyLabel(d)),
                      selected: isSelected,
                      selectedColor: color.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? color : Colors.grey,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? color : Colors.grey.withOpacity(0.3),
                      ),
                      onSelected: (_) {
                        setModalState(() {
                          difficulty = d;
                          repeatController.text =
                              TextSegment.suggestedRepeatCount(d).toString();
                          speedController.text =
                              TextSegment.suggestedTtsSpeed(d).toStringAsFixed(2);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Category selection
                const Text(
                  'Phân loại',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: theme.segmentCategories.map((c) {
                    final isSelected = category == c;
                    return ChoiceChip(
                      label: Text(_getCategoryLabel(c)),
                      selected: isSelected,
                      selectedColor: theme.primary.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? theme.primary : Colors.grey,
                      ),
                      side: BorderSide(
                        color: isSelected ? theme.primary : Colors.grey.withOpacity(0.3),
                      ),
                      onSelected: (_) => setModalState(() => category = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Repeat & Speed
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
                          prefixIcon: Icon(Icons.loop, color: theme.primary, size: 20),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
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
                          prefixIcon: Icon(Icons.speed, color: theme.primary, size: 20),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Gap duration
                TextField(
                  controller: gapController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Khoảng nghỉ giữa các lần (giây)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.timer, color: theme.primary, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Note
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (nghĩa, giải thích...)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.notes, color: theme.primary, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Translation
                TextField(
                  controller: translationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Bản dịch (tùy chọn)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.translate, color: theme.primary, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
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
                          final speed = double.tryParse(speedController.text) ?? 1.0;
                          final gap = double.tryParse(gapController.text) ?? 1.0;

                          textProvider.createSegmentFromSelection(
                            difficulty: difficulty,
                            category: category,
                            repeatCountOverride: repeat.clamp(1, 20),
                            ttsSpeedOverride: speed.clamp(0.25, 2.0),
                            gapDurationOverride: gap.clamp(0.5, 10.0),
                            note: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                            translation: translationController.text.trim().isEmpty
                                ? null
                                : translationController.text.trim(),
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Text('Đã tạo đoạn học!'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.bookmark_add, size: 18),
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Dòng ${index + 1}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 16),

            _LineOptionTile(
              icon: Icons.volume_up,
              title: 'Đọc dòng này',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                textProvider.setCurrentLine(index);
                textProvider.speakCurrentLine();
              },
            ),
            _LineOptionTile(
              icon: Icons.select_all,
              title: 'Chọn toàn bộ dòng',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                final globalStart = textProvider.calculateGlobalOffset(index, 0);
                final globalEnd = textProvider.calculateGlobalOffset(
                  index,
                  line.content.length,
                );
                textProvider.selectTextWithOffsets(
                  text: line.content,
                  startOffset: globalStart,
                  endOffset: globalEnd,
                  lineIndex: index,
                );
              },
            ),
            _LineOptionTile(
              icon: Icons.bookmark_add,
              title: 'Đánh dấu toàn dòng',
              subtitle: 'Tạo đoạn học từ dòng này',
              color: Colors.amber,
              onTap: () {
                Navigator.pop(context);
                final globalStart = textProvider.calculateGlobalOffset(index, 0);
                final globalEnd = textProvider.calculateGlobalOffset(
                  index,
                  line.content.length,
                );
                textProvider.selectTextWithOffsets(
                  text: line.content,
                  startOffset: globalStart,
                  endOffset: globalEnd,
                  lineIndex: index,
                );
                // Mở dialog tạo segment
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showCreateSegmentDialog(
                    context,
                    textProvider,
                    context.read<PlayerProvider>(),
                    theme,
                  );
                });
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showSegmentDetails(
      BuildContext context,
      TextProvider textProvider,
      TextSegment segment,
      _StudioTheme theme,
      ) {
    final diffColor = _getSegmentColor(segment.difficulty);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: diffColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getDifficultyLabel(segment.difficulty),
                    style: TextStyle(
                      color: diffColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Ôn: ${segment.reviewCount} lần',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: diffColor.withOpacity(0.3)),
              ),
              child: Text(
                segment.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ),

            // Translation
            if (segment.translation != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.translate, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'Bản dịch',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      segment.translation!,
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Note
            if (segment.note != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'Ghi chú',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      segment.note!,
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Settings info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DetailChip(
                  icon: Icons.loop,
                  label: '${segment.repeatCount} lần',
                  color: theme.primary,
                ),
                _DetailChip(
                  icon: Icons.speed,
                  label: '${segment.ttsSpeed.toStringAsFixed(1)}x',
                  color: Colors.orange,
                ),
                _DetailChip(
                  icon: Icons.timer,
                  label: '${segment.gapDuration.toStringAsFixed(1)}s',
                  color: Colors.cyan,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      textProvider.speakSegment(segment);
                    },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Học ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditSegmentDialog(context, textProvider, segment, theme);
                  },
                  icon: const Icon(Icons.edit),
                  color: Colors.blue,
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDeleteSegment(context, textProvider, segment);
                  },
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showEditSegmentDialog(
      BuildContext context,
      TextProvider textProvider,
      TextSegment segment,
      _StudioTheme theme,
      ) {
    TextSegmentDifficulty difficulty = segment.difficulty;
    final repeatController = TextEditingController(text: segment.repeatCount.toString());
    final speedController = TextEditingController(text: segment.ttsSpeed.toStringAsFixed(2));
    final gapController = TextEditingController(text: segment.gapDuration.toStringAsFixed(1));
    final noteController = TextEditingController(text: segment.note ?? '');
    final translationController = TextEditingController(text: segment.translation ?? '');

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
                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(Icons.edit, color: theme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Chỉnh sửa đoạn học',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Difficulty
                const Text('Độ khó', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: TextSegmentDifficulty.values.map((d) {
                    final isSelected = difficulty == d;
                    final color = _getSegmentColor(d);
                    return ChoiceChip(
                      label: Text(_getDifficultyLabel(d)),
                      selected: isSelected,
                      selectedColor: color.withOpacity(0.3),
                      labelStyle: TextStyle(
                        color: isSelected ? color : Colors.grey,
                      ),
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

                TextField(
                  controller: gapController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Khoảng nghỉ (giây)',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: translationController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Bản dịch',
                    labelStyle: TextStyle(color: Colors.grey),
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
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          textProvider.updateSegment(
                            segment.id,
                            difficulty: difficulty,
                            repeatCount: int.tryParse(repeatController.text) ?? segment.repeatCount,
                            ttsSpeed: double.tryParse(speedController.text) ?? segment.ttsSpeed,
                            gapDuration: double.tryParse(gapController.text) ?? segment.gapDuration,
                            note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                            translation: translationController.text.trim().isEmpty
                                ? null
                                : translationController.text.trim(),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primary,
                        ),
                        child: const Text('Lưu thay đổi'),
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

  void _confirmDeleteSegment(
      BuildContext context,
      TextProvider textProvider,
      TextSegment segment,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa tất cả?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn xóa toàn bộ văn bản và các đoạn học đã đánh dấu?',
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
              textProvider.clearAllSegments();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa tất cả'),
          ),
        ],
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
            const SizedBox(height: 16),
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
            ListTile(
                leading: 