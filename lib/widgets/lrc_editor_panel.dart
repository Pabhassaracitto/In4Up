import 'dart:io';

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:in4up/providers/player_provider.dart';
import 'package:in4up/providers/text_provider.dart';
import 'package:in4up/screens/understand_mode/understand_provider.dart';
import 'package:in4up_stt/stt_lrc_converter.dart';

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
  String? _loadedLrcContent;
  String? _loadingLrcPath;
  int _loadGeneration = 0;
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
    // Chỉ rebuild khi lrcPath / error / isGenerating thay đổi, tránh rebuild liên tục do position
    return Selector<PlayerProvider,
        ({String? lrcPath, String? error, bool isGenerating})>(
      selector: (_, p) => (
        lrcPath: p.lastGeneratedLrcPath,
        error: p.lastSttError,
        isGenerating: p.isGeneratingLrc
      ),
      builder: (context, data, _) {
        final lrcPath = data.lrcPath;
        final error = data.error;
        final isGenerating = data.isGenerating;

        // Hiển thị lỗi - chỉ log khi error thay đổi
        if (error != null && error.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Lỗi tạo LRC',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 16, color: Colors.redAccent),
                      tooltip: context.uiText('Đóng lỗi'),
                      onPressed: () {
                        // Xóa lỗi để không hiện lại
                        context.read<PlayerProvider>().clearSttError();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  error,
                  maxLines: 12,
                  style:
                      const TextStyle(color: Colors.redAccent, height: 1.35, fontSize: 12),
                ),
                if (isGenerating) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Đang tạo lại...',
                          style: TextStyle(
                              color: Colors.redAccent, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          );
        }

        if (lrcPath == null) {
          return const SizedBox.shrink();
        }

        // Check file tồn tại trước khi load (không log spam)
        final file = File(lrcPath);
        if (!file.existsSync()) {
          // File chưa kịp tạo hoặc đã xóa, ẩn đi
          return const SizedBox.shrink();
        }

        // Load LRC nếu path thay đổi
        _ensureLoaded(lrcPath);

        if (_lines == null || _lines!.isEmpty) {
          // A null list means the current path is still being loaded.
          if (_lines == null) {
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Đang tải LRC...',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }
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
                        context.uiText('${widget.title} (${_lines!.length} dòng)'),
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
                              context.uiText('[${_formatDuration(_lines![index].timestamp)}] '),
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
                      onPressed: () async {
                        final applied = await _useThisLrc();
                        if (applied && mounted) widget.onLrcApplied?.call();
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Nạp vào Đọc & Hiểu'),
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
                    context.uiText('${_lines!.length} dòng · Nhấn để mở rộng'),
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
    if (lrcPath == _lastLrcPath &&
        (_lines != null || _loadingLrcPath == lrcPath)) return;

    final generation = ++_loadGeneration;
    try {
      // A file read can take time. Never expose the previous source's lines
      // under a newly selected path while the new file is loading.
      if (_lastLrcPath != lrcPath) _lines = null;
      _lastLrcPath = lrcPath;
      _loadingLrcPath = lrcPath;
      _loadedLrcContent = null;
      final lrcContent = await File(lrcPath).readAsString();
      if (!mounted || _lastLrcPath != lrcPath || generation != _loadGeneration) return;
      _loadedLrcContent = lrcContent;
      final parsed = SttLrcConverter().parseLrcContent(lrcContent);

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
      if (mounted && _lastLrcPath == lrcPath && generation == _loadGeneration) {
        setState(() => _lines = []);
      }
    } finally {
      if (generation == _loadGeneration) _loadingLrcPath = null;
    }
  }

  Future<void> _saveEdits() async {
    if (_lines == null || _lastLrcPath == null) return;

    final lrcPath = _lastLrcPath!;
    final audioPath = context.read<PlayerProvider>().currentSongPath;
    final updatedLines = await _validatedEdits();
    if (!mounted || updatedLines == null || _lastLrcPath != lrcPath ||
        context.read<PlayerProvider>().currentSongPath != audioPath) return;

    // Retain header, comments, unknown lines, ordering and newline style. Only
    // rows that were actually loaded into the editor are replaced.
    final original = _loadedLrcContent;
    if (original == null) return;
    var lyricIndex = 0;
    final converter = SttLrcConverter();
    final saved = original.split('\n').map((raw) {
      final parsed = converter.parseLrcContent(raw);
      final isLyric = parsed.any((line) => line.text.trim().isNotEmpty);
      if (!isLyric || lyricIndex >= updatedLines.length) return raw;
      final replacement = SttLrcConverter.serializeLine(updatedLines[lyricIndex++]);
      return raw.endsWith('\r') ? '$replacement\r' : replacement;
    }).join('\n');
    // Do not rewrite the file if the source changed externally while the
    // editor was open; a later reload can reconcile those edits safely.
    if (lyricIndex != updatedLines.length ||
        await File(lrcPath).readAsString() != original) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
          'LRC đã thay đổi ở nơi khác. Chưa lưu để tránh ghi đè; hãy sao chép chỉnh sửa rồi mở lại trình sửa.',
        )));
      }
      return;
    }
    if (!mounted || _lastLrcPath != lrcPath ||
        context.read<PlayerProvider>().currentSongPath != audioPath) return;
    await File(lrcPath).writeAsString(saved, flush: true);

    if (!mounted || _lastLrcPath != lrcPath ||
        context.read<PlayerProvider>().currentSongPath != audioPath) return;
    _loadedLrcContent = saved;
    _lines = updatedLines;
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

  Future<bool> _useThisLrc() async {
    if (_lines == null || _lines!.isEmpty) return false;

    final lrcPath = _lastLrcPath;
    final audioPath = context.read<PlayerProvider>().currentSongPath;
    final updatedLines = await _validatedEdits();
    if (!mounted || updatedLines == null || _lastLrcPath != lrcPath ||
        context.read<PlayerProvider>().currentSongPath != audioPath) return false;

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
    return true;
  }

  Future<List<LrcLine>?> _validatedEdits() async {
    final lines = _buildUpdatedLines();
    if (lines.every(SttLrcConverter.wordTimingsMatchText)) return lines;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mốc thời gian từng từ không còn khớp'),
        content: const Text(
          'Một số dòng đã đổi chữ. Nếu tiếp tục, các dòng đó chỉ giữ thời gian bắt đầu dòng và tô từng từ sẽ được ước lượng. Tệp gốc chỉ thay đổi khi bạn lưu.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Tiếp tục')),
        ],
      ),
    );
    if (!mounted || proceed != true) return null;
    return lines.map((line) => SttLrcConverter.wordTimingsMatchText(line)
        ? line
        : LrcLine(timestamp: line.timestamp, text: line.text)).toList();
  }

  List<LrcLine> _buildUpdatedLines() {
    return List<LrcLine>.generate(_lines!.length, (i) {
      final text = _controllers[i]?.text.trim() ?? _lines![i].text;
      return LrcLine(
        timestamp: _lines![i].timestamp,
        text: text,
        // Giữ word-timestamps cũ để karaoke vẫn hoạt động sau khi sửa
        words: _lines![i].words,
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
