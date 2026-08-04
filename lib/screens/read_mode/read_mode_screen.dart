// lib/screens/read_mode/read_mode_screen.dart
// Thêm tracking tiến độ đọc vào code hiện tại
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:in2up/models/word_entry.dart';

import '../../features/translation/translation_toolbar.dart';
import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import '../../providers/vocabulary_provider.dart';
import 'controllers/read_mode_controller.dart';
import 'models/recent_file.dart';
import 'services/recent_files_service.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/read_bottom_bar.dart';
import 'widgets/read_top_bar.dart';
import 'widgets/smart_playback_bar.dart'; // ← THÊM
import 'widgets/text_line_widget.dart';

class ReadModeScreen extends StatefulWidget {
  // ★ THÊM: Nhận RecentFile để biết đang đọc file nào
  final RecentFile? currentFile;

  const ReadModeScreen({super.key, this.currentFile});

  @override
  State<ReadModeScreen> createState() => _ReadModeScreenState();
}

class _ReadModeScreenState extends State<ReadModeScreen> {
  final ScrollController _scrollController = ScrollController();
  late ReadModeController _controller;
  bool _controllerInitialized = false;
  VoidCallback? _playerListener;
  Duration _lastPos = Duration.zero;
  bool _showWordlistPanel = false; // wordlist

  // ★ FIX: Lưu reference PlayerProvider để dùng trong dispose()
  PlayerProvider? _playerProviderRef;

  // ★ THÊM: Track progress
  final _recentService = RecentFilesService();
  int _lastSavedLine = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      final tp = context.read<TextProvider>();
      final pp = context.read<PlayerProvider>();

      // ★ FIX: Lưu reference
      _playerProviderRef = pp;

      _controller = ReadModeController(textProvider: tp, playerProvider: pp);
      _playerListener = () {
        if (!mounted) return; // ★ FIX: Guard check
        final pos = pp.state.position;
        if (pos == _lastPos) return;
        _lastPos = pos;
        final targetLine = _controller.checkAudioSync(pos);
        if (targetLine >= 0) {
          _controller.scrollToLine(_scrollController, targetLine);
        }
      };
      pp.addListener(_playerListener!);
      _controllerInitialized = true;
    }
  }

  // ★ THÊM: Lưu tiến độ khi scroll
  void _onScrollEnd(TextProvider tp) {
    if (widget.currentFile == null) return;
    if (tp.lines.isEmpty) return;

    // Ước tính dòng hiện tại dựa trên scroll position
    final offset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final approxLine =
        maxOffset > 0 ? ((offset / maxOffset) * tp.lines.length).round() : 0;

    // Chỉ lưu nếu thay đổi đáng kể (tránh write quá nhiều)
    if ((approxLine - _lastSavedLine).abs() >= 3) {
      _lastSavedLine = approxLine;
      _recentService.updateProgress(
        widget.currentFile!.id,
        currentLine: approxLine,
        totalLines: tp.lines.length,
      );
    }
  }

  @override
  void deactivate() {
    _controller.removeFloatingMenu();
    super.deactivate();
  }

  @override
  void dispose() {
    // ★ FIX: Dùng _playerProviderRef thay vì context.read()
    if (_playerListener != null && _playerProviderRef != null) {
      _playerProviderRef!.removeListener(_playerListener!);
    }
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<TextProvider>(
        builder: (context, textProvider, _) {
          if (!textProvider.hasLyrics) {
            return const ReadEmptyState();
          }
          return Column(
            children: [
              const ReadTopBar(),
              if (textProvider.showTranslation) const TranslationToolbar(),
              Expanded(
                child: _showWordlistPanel
                    ? _buildSplitView(textProvider)
                    : GestureDetector(
                        onTap: () => _controller.removeFloatingMenu(),
                        child: _buildTextList(textProvider),
                      ),
              ),
              const SmartPlaybackBar(), // ← THÊM Smart Playback Bar
              ReadBottomBar(
                showWordlistPanel: _showWordlistPanel,
                onToggleWordlist: () {
                  setState(() => _showWordlistPanel = !_showWordlistPanel);
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSplitView(TextProvider tp) {
    final title = tp.currentDocument?.title ?? 'Text Studio';
    return Row(
      children: [
        // Text 65%
        Expanded(
          flex: 65,
          child: GestureDetector(
            onTap: () => _controller.removeFloatingMenu(),
            child: _buildTextList(tp),
          ),
        ),
        // Wordlist mini panel 35%
        Expanded(
          flex: 35,
          child: _StoryWordlistPanel(storyTitle: title),
        ),
      ],
    );
  }

  Widget _buildTextList(TextProvider textProvider) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _controller.setScrolling(true);
        } else if (notification is ScrollEndNotification) {
          _controller.setScrolling(false);
          // ★ THÊM: Lưu tiến độ khi dừng scroll
          _onScrollEnd(textProvider);
        }
        return false;
      },
      child: Container(
        color: const Color(0xFF0D1520),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: textProvider.lines.length,
          cacheExtent: 300,
          itemBuilder: (context, index) {
            return TextLineWidget(
              index: index,
              scrollController: _scrollController,
            );
          },
        ),
      ),
    );
  }
}

class _StoryWordlistPanel extends StatelessWidget {
  final String storyTitle;

  const _StoryWordlistPanel({required this.storyTitle});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (_, provider, __) {
        // Lấy từ đã lưu từ story này
        final words = provider.allWords
            .where((w) => w.contexts.any(
                  (c) => c.sourceName == storyTitle,
                ))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF080B1A),
            border: Border(
              left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                color: const Color(0xFF0D1520),
                child: Row(
                  children: [
                    const Icon(Icons.library_books,
                        size: 13, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Từ đã lưu (${words.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: words.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border,
                                size: 28, color: Colors.grey[800]),
                            const SizedBox(height: 6),
                            Text(
                              'Chưa lưu từ nào\ntừ story này',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 10),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: words.length,
                        itemBuilder: (_, i) {
                          final w = words[i];
                          return Container(
                            margin: const EdgeInsets.fromLTRB(6, 2, 6, 2),
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.025),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: w.vocabType.color
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        w.vocabType.badge,
                                        style: TextStyle(
                                          color: w.vocabType.color,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        w.word,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => provider.removeWord(w.id),
                                      child: Icon(Icons.close,
                                          size: 11, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                                if (w.meaning.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    w.meaning,
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(1),
                                  child: LinearProgressIndicator(
                                    value: w.mastery,
                                    minHeight: 2,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.06),
                                    valueColor: AlwaysStoppedAnimation(
                                      w.zone.color.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
