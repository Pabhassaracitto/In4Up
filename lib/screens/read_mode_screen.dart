import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/text_provider.dart';
import '../providers/player_provider.dart';

/// Chế độ ĐỌC - Text-first experience
/// Focus: Văn bản lớn, dễ đọc, TTS, highlight từ
class ReadModeScreen extends StatefulWidget {
  const ReadModeScreen({super.key});

  @override
  State<ReadModeScreen> createState() => _ReadModeScreenState();
}

class _ReadModeScreenState extends State<ReadModeScreen> {
  // Font settings
  double _fontSize = 18.0;
  bool _darkBackground = true;

  // Reading progress
  int _currentLineIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TextProvider, PlayerProvider>(
      builder: (context, textProvider, player, child) {
        // Nếu chưa có text
        if (!textProvider.hasLyrics) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            // Reading toolbar
            _buildToolbar(textProvider),

            // Main text content
            Expanded(
              child: _buildTextContent(textProvider, player),
            ),

            // Bottom controls
            _buildBottomControls(textProvider, player),
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
            // Icon
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

            // Title
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

            // Features list
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      (Icons.text_fields, 'Điều chỉnh cỡ chữ'),
      (Icons.record_voice_over, 'Text-to-Speech (TTS)'),
      (Icons.touch_app, 'Tap từ để tra cứu'),
      (Icons.bookmark, 'Đánh dấu câu quan trọng'),
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

  Widget _buildToolbar(TextProvider textProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Line counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentLineIndex + 1}/${textProvider.lines.length}',
              style: const TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Spacer(),

          // Font size controls
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            color: Colors.grey,
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize - 2).clamp(12.0, 32.0);
              });
            },
          ),
          Text(
            '${_fontSize.round()}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            color: Colors.grey,
            onPressed: () {
              setState(() {
                _fontSize = (_fontSize + 2).clamp(12.0, 32.0);
              });
            },
          ),

          const SizedBox(width: 8),

          // Theme toggle
          IconButton(
            icon: Icon(
              _darkBackground ? Icons.light_mode : Icons.dark_mode,
              size: 20,
            ),
            color: Colors.grey,
            onPressed: () {
              setState(() {
                _darkBackground = !_darkBackground;
              });
            },
          ),

          // TTS button
          IconButton(
            icon: const Icon(Icons.record_voice_over, size: 20),
            color: const Color(0xFF4CAF50),
            onPressed: () {
              // TODO: Implement TTS
              _showTtsOptions(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(TextProvider textProvider, PlayerProvider player) {
    return Container(
      color: _darkBackground
          ? const Color(0xFF0D1520)
          : const Color(0xFFFAFAFA),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: textProvider.lines.length,
        itemBuilder: (context, index) {
          final line = textProvider.lines[index];
          final isCurrentLine = index == _currentLineIndex;
          final isSynced = line.startTime != Duration.zero;

          // Check if this line is currently playing
          bool isPlaying = false;
          if (isSynced && player.isPlaying) {
            isPlaying = line.startTime != null &&
                player.state.position >= line.startTime! &&
                (line.endTime == null || player.state.position <= line.endTime!);
          }

          return GestureDetector(
            onTap: () {
              setState(() => _currentLineIndex = index);
              HapticFeedback.selectionClick();

              // Nếu đã sync, seek đến vị trí audio
              if (isSynced && line.startTime != null) {
                player.seek(line.startTime!); // Thêm ! để unwrap Duration?
              }
            },
            onLongPress: () {
              _showLineOptions(context, line, index, textProvider);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrentLine
                    ? const Color(0xFF2196F3).withOpacity(_darkBackground ? 0.15 : 0.1)
                    : isPlaying
                    ? const Color(0xFF4CAF50).withOpacity(_darkBackground ? 0.15 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isCurrentLine
                    ? Border.all(color: const Color(0xFF2196F3).withOpacity(0.5))
                    : isPlaying
                    ? Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5))
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line number
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isCurrentLine
                            ? const Color(0xFF2196F3)
                            : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.content,
                          style: TextStyle(
                            color: _darkBackground ? Colors.white : Colors.black87,
                            fontSize: _fontSize,
                            height: 1.6,
                            fontWeight: isCurrentLine ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),

                        // Translation (if available)
                        if (line.translation != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            line.translation!,
                            style: TextStyle(
                              color: _darkBackground
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: _fontSize - 2,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Sync indicator
                  if (isSynced)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        isPlaying ? Icons.volume_up : Icons.access_time,
                        size: 16,
                        color: isPlaying
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls(TextProvider textProvider, PlayerProvider player) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous line
            _NavButton(
              icon: Icons.arrow_upward,
              onTap: () {
                if (_currentLineIndex > 0) {
                  setState(() => _currentLineIndex--);
                  _scrollToCurrentLine();
                }
              },
            ),

            const SizedBox(width: 8),

            // Next line
            _NavButton(
              icon: Icons.arrow_downward,
              onTap: () {
                if (_currentLineIndex < textProvider.lines.length - 1) {
                  setState(() => _currentLineIndex++);
                  _scrollToCurrentLine();
                }
              },
            ),

            const Spacer(),

            // TTS speak current line
            ElevatedButton.icon(
              onPressed: () {
                // TODO: TTS speak current line
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Đọc'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Sync to audio button
            if (player.currentSongPath != null)
              ElevatedButton.icon(
                onPressed: () {
                  // Sync current line to audio position
                  final currentLine = textProvider.lines[_currentLineIndex];
                  if (currentLine.startTime != null) {
                    player.seek(currentLine.startTime!);
                    player.play();
                  }
                },
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _scrollToCurrentLine() {
    // Scroll to current line
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final targetOffset = _currentLineIndex * 100.0; // Approximate
        _scrollController.animateTo(
          targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
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

  void _showTtsOptions(BuildContext context) {
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
            const Text(
              'Text-to-Speech',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Language selection
            ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF2196F3)),
              title: const Text('Ngôn ngữ', style: TextStyle(color: Colors.white)),
              subtitle: Text('Tiếng Việt', style: TextStyle(color: Colors.grey[500])),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                // TODO: Language picker
              },
            ),

            // Speed
            ListTile(
              leading: const Icon(Icons.speed, color: Color(0xFF4CAF50)),
              title: const Text('Tốc độ đọc', style: TextStyle(color: Colors.white)),
              subtitle: Text('1.0x', style: TextStyle(color: Colors.grey[500])),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                // TODO: Speed picker
              },
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Read current line
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Đọc dòng hiện tại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Read all
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.playlist_play),
                    label: const Text('Đọc tất cả'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
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

  void _showLineOptions(BuildContext context, dynamic line, int index, TextProvider textProvider) {
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
            // Preview text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                line.content,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),

            // Options
            _OptionTile(
              icon: Icons.record_voice_over,
              label: 'Đọc dòng này (TTS)',
              color: const Color(0xFF4CAF50),
              onTap: () {
                // TODO: TTS
                Navigator.pop(context);
              },
            ),
            _OptionTile(
              icon: Icons.bookmark_add,
              label: 'Đánh dấu quan trọng',
              color: const Color(0xFFFFB300),
              onTap: () {
                // TODO: Bookmark
                Navigator.pop(context);
              },
            ),
            _OptionTile(
              icon: Icons.copy,
              label: 'Sao chép văn bản',
              color: const Color(0xFF2196F3),
              onTap: () {
                Clipboard.setData(ClipboardData(text: line.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép')),
                );
              },
            ),
            _OptionTile(
              icon: Icons.translate,
              label: 'Dịch',
              color: const Color(0xFF9C27B0),
              onTap: () {
                // TODO: Translate
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// Helper widgets
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
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
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
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
      onTap: onTap,
    );
  }
}