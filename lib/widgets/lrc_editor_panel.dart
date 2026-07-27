import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vipsound/providers/player_provider.dart';
import 'package:vipsound/providers/text_provider.dart';
import 'package:vipsound/screens/understand_mode/understand_provider.dart';
import 'package:vipsound_stt/stt_lrc_converter.dart';

class LrcEditorPanel extends StatefulWidget {
  final bool initiallyExpanded;
  final String title;
  final VoidCallback? onLrcApplied;
  final bool compact;
  final bool showAsLyrics;

  const LrcEditorPanel({
    super.key,
    this.initiallyExpanded = true,
    this.title = 'LRC Editor',
    this.onLrcApplied,
    this.compact = false,
    this.showAsLyrics = false,
  });

  @override
  State<LrcEditorPanel> createState() => _LrcEditorPanelState();
}

class _LrcEditorPanelState extends State<LrcEditorPanel> {
  List<LrcLine>? _lines;
  final Map<int, TextEditingController> _controllers = {};
  String? _lastLrcPath;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, _) {
        final lrcPath = provider.lastGeneratedLrcPath;
        final error = provider.lastSttError;

        // ★ DEBUG - xóa sau khi fix xong
        debugPrint('🔍 LrcEditorPanel rebuild: '
            'lrcPath=$lrcPath, '
            'error=$error, '
            'isGenerating=${provider.isGeneratingLrc}');

        // Hiển thị lỗi
        if (error != null && error.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          );
        }

        // ★ FIX: Chỉ cần lrcPath, không cần check segments
        if (lrcPath == null) {
          return const SizedBox.shrink();
        }

        // ★ FIX: Check file tồn tại trước khi load
        final file = File(lrcPath);
        if (!file.existsSync()) {
          debugPrint('⚠️ LRC file không tồn tại: $lrcPath');
          return const SizedBox.shrink();
        }

        // Load LRC nếu path thay đổi
        _ensureLoaded(lrcPath);

        // ★ FIX: Nếu load xong mà không có dòng nào thì ẩn
        if (_lines == null || _lines!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header có thể collapse
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.title} (${_lines!.length} dòng)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),

              if (_expanded) ...[
                const SizedBox(height: 10),
                // Danh sách dòng LRC
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: _lines!.length,
                    itemBuilder: (context, index) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '[${_formatDuration(_lines![index].timestamp)}] ',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controllers[index],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              maxLines: null,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saveEdits,
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Lưu chỉnh sửa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        _useThisLrc();
                        widget.onLrcApplied?.call();
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Sử dụng LRC này'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${_lines!.length} dòng · Nhấn để mở rộng',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _ensureLoaded(String lrcPath) async {
    if (lrcPath == _lastLrcPath && _lines != null) return;

    try {
      _lastLrcPath = lrcPath;
      final lrcContent = await File(lrcPath).readAsString();
      final parsed = await SttLrcConverter().parseLrcContent(lrcContent);

      // Filter dòng rỗng
      _lines = parsed.where((l) => l.text.trim().isNotEmpty).toList();

      // Dispose controllers cũ
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();

      // Tạo controllers mới
      for (int i = 0; i < _lines!.length; i++) {
        _controllers[i] = TextEditingController(text: _lines![i].text);
      }

      debugPrint('✅ LrcEditorPanel loaded: ${_lines!.length} lines');
      if (mounted) setState(() {}); // Trigger rebuild
    } catch (e) {
      debugPrint('❌ LrcEditorPanel load error: $e');
      _lines = null;
    }
  }

  Future<void> _saveEdits() async {
    if (_lines == null || _lastLrcPath == null) return;

    final updatedLines = _buildUpdatedLines();

    // Ghi lại file LRC
    final buffer = StringBuffer();
    for (final line in updatedLines) {
      buffer.writeln('[${_formatDuration(line.timestamp)}] ${line.text}');
    }

    await File(_lastLrcPath!).writeAsString(buffer.toString(), flush: true);

    if (!mounted) return;

    // Cập nhật UnderstandProvider
    context.read<UnderstandProvider>().loadLrcLines(updatedLines);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Đã lưu chỉnh sửa LRC'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _useThisLrc() {
    if (_lines == null || _lines!.isEmpty) return;

    final updatedLines = _buildUpdatedLines();

    // Clean text cho Tab Đọc
    final cleanText = updatedLines
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');

    // ★ Load vào TextProvider (Tab Đọc)
    context.read<TextProvider>().loadFromString(
          cleanText,
          title: 'Transcript',
        );

    // ★ Load vào UnderstandProvider (Tab Hiểu)
    context.read<UnderstandProvider>().loadLrcLines(updatedLines);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Đã tích hợp vào Tab Đọc và Tab Hiểu'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<LrcLine> _buildUpdatedLines() {
    return List<LrcLine>.generate(_lines!.length, (i) {
      final text = _controllers[i]?.text.trim() ?? _lines![i].text;
      return LrcLine(
        timestamp: _lines![i].timestamp,
        text: text,
      );
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = (d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }
}
