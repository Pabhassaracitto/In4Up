// lib/screens/read_mode/read_mode_screen.dart
// Orchestrator: gọn ~120 dòng, chỉ ghép các widget lại

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import 'controllers/read_mode_controller.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/read_bottom_bar.dart';
import 'widgets/read_top_bar.dart';
import 'widgets/text_line_widget.dart';

class ReadModeScreen extends StatefulWidget {
  const ReadModeScreen({super.key});

  @override
  State<ReadModeScreen> createState() => _ReadModeScreenState();
}

class _ReadModeScreenState extends State<ReadModeScreen> {
  final ScrollController _scrollController = ScrollController();
  late ReadModeController _controller;
  bool _controllerInitialized = false;

  VoidCallback? _playerListener;
  Duration _lastPos = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerInitialized) {
      final tp = context.read<TextProvider>();
      final pp = context.read<PlayerProvider>();

      _controller = ReadModeController(textProvider: tp, playerProvider: pp);

      _playerListener = () {
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

  @override
  void deactivate() {
    _controller.removeFloatingMenu();
    super.deactivate();
  }

  @override
  void dispose() {
    final pp = context.read<PlayerProvider>();
    if (_playerListener != null) {
      pp.removeListener(_playerListener!);
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
              // Top Bar
              const ReadTopBar(),

              // Main Text Content
              Expanded(
                child: GestureDetector(
                  onTap: () => _controller.removeFloatingMenu(),
                  child: _buildTextList(textProvider),
                ),
              ),

              // Bottom Bar
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
        }
        return false;
      },
      child: Container(
        color: const Color(0xFF0D1520),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: textProvider.lines.length,
          // Tối ưu: chỉ build dòng visible
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
