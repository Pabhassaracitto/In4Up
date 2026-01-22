import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../providers/player_provider.dart';
import '../providers/text_provider.dart';
import '../models/text_item.dart';
import '../widgets/mini_player_controls.dart';
import '../widgets/synced_lyrics_view.dart';

class SyncHubScreen extends StatefulWidget {
  const SyncHubScreen({super.key});

  @override
  State<SyncHubScreen> createState() => _SyncHubScreenState();
}

class _SyncHubScreenState extends State<SyncHubScreen> {
  double _splitRatio = 0.35; // 35% music, 65% text
  bool _isLyricsMode = true;
  bool _autoScroll = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            _buildAppBar(context),

            // Main Content - Split View
            Expanded(
              child: _buildSplitView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sync,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Music + Text đồng bộ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Auto scroll toggle
          IconButton(
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
            },
            icon: Icon(
              _autoScroll ? Icons.vertical_align_center : Icons.vertical_align_top,
              color: _autoScroll ? const Color(0xFF6C63FF) : Colors.grey,
            ),
            tooltip: _autoScroll ? 'Tự động cuộn: BẬT' : 'Tự động cuộn: TẮT',
          ),
          // Import text
          IconButton(
            onPressed: () => _showImportOptions(context),
            icon: const Icon(Icons.add),
            tooltip: 'Thêm text/lyrics',
          ),
          // Settings
          IconButton(
            onPressed: () => _showSyncSettings(context),
            icon: const Icon(Icons.tune),
            tooltip: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  Widget _buildSplitView(BuildContext context) {
    return Consumer2<PlayerProvider, TextProvider>(
      builder: (context, player, textProvider, child) {
        // Nếu chưa có audio hoặc text
        if (player.currentSongPath == null && textProvider.lines.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            // Music Section (có thể kéo để resize)
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _splitRatio += details.delta.dy / MediaQuery.of(context).size.height;
                  _splitRatio = _splitRatio.clamp(0.2, 0.6);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: MediaQuery.of(context).size.height * _splitRatio,
                child: _buildMusicSection(context, player),
              ),
            ),

            // Divider có thể kéo
            _buildResizeDivider(),

            // Text/Lyrics Section
            Expanded(
              child: _buildTextSection(context, player, textProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.2),
                    const Color(0xFF4CAF50).withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sync,
                size: 64,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sync Hub',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kết nối Audio và Text để học hiệu quả hơn',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionCard(
                  icon: Icons.music_note,
                  title: 'Chọn Audio',
                  subtitle: 'MP3, WAV, M4A...',
                  color: const Color(0xFF6C63FF),
                  onTap: () => _pickAudioFile(context),
                ),
                const SizedBox(width: 16),
                _ActionCard(
                  icon: Icons.text_snippet,
                  title: 'Thêm Text',
                  subtitle: 'TXT, SRT, LRC...',
                  color: const Color(0xFF4CAF50),
                  onTap: () => _showImportOptions(context),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Features list
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  _FeatureItem(
                    icon: Icons.sync_alt,
                    text: 'Audio và Text đồng bộ theo thời gian',
                  ),
                  _FeatureItem(
                    icon: Icons.touch_app,
                    text: 'Bấm vào text để nhảy đến vị trí audio',
                  ),
                  _FeatureItem(
                    icon: Icons.record_voice_over,
                    text: 'TTS đọc text với nhiều tốc độ',
                  ),
                  _FeatureItem(
                    icon: Icons.bookmark,
                    text: 'Đánh dấu đoạn khó để ôn tập',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicSection(BuildContext context, PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Song info
          Row(
            children: [
              // Album art mini
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: player.isLooping
                        ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                        : [const Color(0xFF6C63FF), const Color(0xFF3F3D56)],
                  ),
                ),
                child: Icon(
                  player.isLooping ? Icons.loop : Icons.music_note,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.currentSongTitle ?? 'Chưa chọn audio',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      player.currentSongArtist ?? 'Bấm + để thêm audio',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    if (player.isLooping)
                      Text(
                        'Loop: ${player.loopCount}x',
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              // Add audio button
              if (player.currentSongPath == null)
                IconButton(
                  onPressed: () => _pickAudioFile(context),
                  icon: const Icon(Icons.add_circle, color: Color(0xFF6C63FF)),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          _buildProgressBar(context, player),

          const SizedBox(height: 8),

          // Mini controls
          const MiniPlayerControls(),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, PlayerProvider player) {
    final position = player.state.position;
    final duration = player.state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        // Progress slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            activeColor: player.isLooping
                ? const Color(0xFF4CAF50)
                : const Color(0xFF6C63FF),
            onChanged: (value) => player.seekToPercent(value),
          ),
        ),
        // Time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (player.isLooping && player.loopDuration != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Loop: ${_formatDuration(player.loopDuration!)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResizeDivider() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _splitRatio += details.delta.dy / MediaQuery.of(context).size.height;
          _splitRatio = _splitRatio.clamp(0.2, 0.6);
        });
      },
      child: Container(
        height: 20,
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextSection(
      BuildContext context,
      PlayerProvider player,
      TextProvider textProvider,
      ) {
    if (textProvider.lines.isEmpty) {
      return _buildNoTextState(context);
    }

    return SyncedLyricsView(
      autoScroll: _autoScroll,
      onLineTap: (index, line) {
        // Khi bấm vào dòng text
        textProvider.setCurrentLine(index);

        // Nếu có timestamp, nhảy đến vị trí audio
        if (line.startTime != null) {
          player.seek(line.startTime!);
        }
      },
      onLineDoubleTap: (index, line) {
        // Double tap để đọc TTS
        textProvider.setCurrentLine(index);
        textProvider.speakCurrentLine();
      },
      onLineLongPress: (index, line) {
        // Long press để hiện options
        _showLineOptions(context, textProvider, player, index, line);
      },
    );
  }

  Widget _buildNoTextState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.text_snippet_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có text/lyrics',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thêm text để hiển thị đồng bộ với audio',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showImportOptions(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DIALOGS & ACTIONS ====================

  void _showImportOptions(BuildContext context) {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thêm Text/Lyrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _ImportOption(
              icon: Icons.file_open,
              title: 'Mở file',
              subtitle: 'TXT, SRT, LRC',
              onTap: () {
                Navigator.pop(context);
                _importTextFile(context);
              },
            ),
            _ImportOption(
              icon: Icons.paste,
              title: 'Dán văn bản',
              subtitle: 'Từ clipboard',
              onTap: () {
                Navigator.pop(context);
                _showPasteDialog(context);
              },
            ),
            _ImportOption(
              icon: Icons.edit,
              title: 'Nhập thủ công',
              subtitle: 'Gõ từng dòng',
              onTap: () {
                Navigator.pop(context);
                _showManualInputDialog(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

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

  Future<void> _pickAudioFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null && context.mounted) {
          await context.read<PlayerProvider>().loadSong(
            path: file.path!,
            title: file.name,
            autoPlay: true,
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

  void _showPasteDialog(BuildContext context) {
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
          children: [
            const Text(
              'Dán văn bản',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Dán hoặc nhập text ở đây...\n\nMỗi dòng sẽ được hiển thị riêng.',
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
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        context.read<TextProvider>().loadText(controller.text);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
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

  void _showManualInputDialog(BuildContext context) {
    // Tương tự _showPasteDialog
    _showPasteDialog(context);
  }

  void _showSyncSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final textProvider = context.watch<TextProvider>();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cài đặt Sync Hub',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                // Auto scroll
                SwitchListTile(
                  secondary: const Icon(Icons.vertical_align_center, color: Colors.grey),
                  title: const Text('Tự động cuộn', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Cuộn theo vị trí audio', style: TextStyle(color: Colors.grey)),
                  value: _autoScroll,
                  onChanged: (value) {
                    setModalState(() => _autoScroll = value);
                    setState(() {});
                  },
                ),

                // Font size
                ListTile(
                  leading: const Icon(Icons.format_size, color: Colors.grey),
                  title: const Text('Cỡ chữ', style: TextStyle(color: Colors.white)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => textProvider.setFontSize(textProvider.fontSize - 2),
                        icon: const Icon(Icons.remove, color: Colors.white),
                      ),
                      Text(
                        '${textProvider.fontSize.toInt()}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => textProvider.setFontSize(textProvider.fontSize + 2),
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Show translation
                SwitchListTile(
                  secondary: const Icon(Icons.translate, color: Colors.grey),
                  title: const Text('Hiện bản dịch', style: TextStyle(color: Colors.white)),
                  value: textProvider.showTranslation,
                  onChanged: (_) => textProvider.toggleTranslation(),
                ),

                // TTS Speed
                ListTile(
                  leading: const Icon(Icons.speed, color: Colors.grey),
                  title: const Text('Tốc độ TTS', style: TextStyle(color: Colors.white)),
                  trailing: Text(
                    '${textProvider.ttsSpeed.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () => _showTtsSpeedPicker(context, textProvider),
                ),

                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTtsSpeedPicker(BuildContext context, TextProvider textProvider) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Tốc độ TTS', style: TextStyle(color: Colors.white)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: speeds.map((speed) {
            final isSelected = textProvider.ttsSpeed == speed;
            return ChoiceChip(
              label: Text('${speed}x'),
              selected: isSelected,
              selectedColor: const Color(0xFF6C63FF),
              onSelected: (_) {
                textProvider.setTtsSpeed(speed);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLineOptions(
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              line.content,
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Options
            ListTile(
              leading: const Icon(Icons.volume_up, color: Colors.blue),
              title: const Text('Đọc dòng này (TTS)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                textProvider.setCurrentLine(index);
                textProvider.speakCurrentLine();
              },
            ),
            ListTile(
              leading: const Icon(Icons.loop, color: Color(0xFF4CAF50)),
              title: const Text('Tạo A-B Loop tại đây', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Set loop từ vị trí hiện tại
                if (line.startTime != null && line.endTime != null) {
                  player.setLoop(line.startTime!, line.endTime!);
                } else {
                  // Nếu không có timestamp, set loop 10 giây
                  final current = player.state.position;
                  player.setLoop(current, current + const Duration(seconds: 10));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.red),
              title: const Text('Đánh dấu KHÓ', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                textProvider.markLineDifficulty(index, DifficultyMark.hard);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add, color: Colors.amber),
              title: const Text('Lưu Bookmark', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Lưu segment
                if (player.loopStart != null || line.startTime != null) {
                  player.saveLoopAsSegment(
                    title: line.content.length > 30
                        ? '${line.content.substring(0, 30)}...'
                        : line.content,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã lưu bookmark!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ==================== HELPER WIDGETS ====================

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF4CAF50)),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}