// lib/screens/read_mode/read_mode_screen.dart
// Thêm tracking tiến độ đọc vào code hiện tại
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/translation/translation_toolbar.dart';
import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import 'controllers/read_mode_controller.dart';
import 'models/recent_file.dart';
import 'services/recent_files_service.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/read_bottom_bar.dart';
import 'widgets/read_top_bar.dart';
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
                child: GestureDetector(
                  onTap: () => _controller.removeFloatingMenu(),
                  child: _buildTextList(textProvider),
                ),
              ),
              const ReadBottomBar(),
            ],
          );
        },
      ),
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
