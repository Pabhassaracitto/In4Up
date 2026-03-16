import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/youtube_audio_download_dialog.dart';

class AudioLibraryDrawer extends StatefulWidget {
  const AudioLibraryDrawer({super.key});

  @override
  State<AudioLibraryDrawer> createState() => _AudioLibraryDrawerState();
}

class _AudioLibraryDrawerState extends State<AudioLibraryDrawer> {
  // Map<path, positionMs>
  Map<String, int> _recentFiles = {};

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  void _loadRecentFiles() {
    final storage = StorageService();
    if (!storage.isInitialized) return;

    final positions = storage.getAllSavedPositions();

    // Lọc bỏ file không còn tồn tại trên disk
    final valid = <String, int>{};
    for (final entry in positions.entries) {
      if (File(entry.key).existsSync()) {
        valid[entry.key] = entry.value;
      }
    }

    setState(() => _recentFiles = valid);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF15102A),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.library_music,
                      color: Color(0xFF6C63FF),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thư viện Audio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Pháp thoại, podcast, nhạc',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Import button ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _importAudioFile(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Thêm Audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final savedPath =
                            await YoutubeAudioDownloadDialog.show(context);
                        if (savedPath != null) {
                          _loadRecentFiles(); // Reload list để hiện file mới
                        }
                      },
                      icon: const Icon(
                        Icons.play_circle_fill,
                        color: Color(0xFFFF0000),
                        size: 18,
                      ),
                      label: const Text(
                        'Tải từ YouTube',
                        style: TextStyle(color: Colors.white70),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: const Color(0xFFFF0000).withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: Colors.white.withValues(alpha: 0.1)),

            // ── Currently playing ────────────────────────────────
            Consumer<PlayerProvider>(
              builder: (context, player, _) {
                if (player.currentSongPath == null)
                  return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6C63FF).withValues(alpha: 0.2),
                        const Color(0xFF6C63FF).withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          player.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Đang phát',
                              style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              player.currentSongTitle ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Recent files label ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gần đây (${_recentFiles.length})',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_recentFiles.isNotEmpty)
                    GestureDetector(
                      onTap: _loadRecentFiles,
                      child: Icon(Icons.refresh,
                          size: 16, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),

            // ── List ─────────────────────────────────────────────
            Expanded(
              child: _recentFiles.isEmpty
                  ? _buildEmptyState()
                  : Consumer<PlayerProvider>(
                      builder: (context, player, _) {
                        final entries = _recentFiles.entries.toList()
                          ..sort((a, b) => b.value
                              .compareTo(a.value)); // sort by position desc

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final path = entries[index].key;
                            final posMs = entries[index].value;
                            final isPlaying = player.currentSongPath == path;
                            final fileName = path.split('/').last;
                            final name = fileName.contains('.')
                                ? fileName.substring(
                                    0, fileName.lastIndexOf('.'))
                                : fileName;

                            return _AudioFileItem(
                              name: name,
                              path: path,
                              positionMs: posMs,
                              isPlaying: isPlaying,
                              onTap: () => _playFile(context, path, name),
                              onDelete: () => _deleteFromRecent(path),
                            );
                          },
                        );
                      },
                    ),
            ),

            // ── Footer ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.swipe, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Vuốt từ cạnh phải để mở',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.audio_file, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Chưa có audio',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhấn "Thêm Audio" để bắt đầu',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _playFile(BuildContext context, String path, String name) async {
    await context.read<PlayerProvider>().loadSong(
          path: path,
          title: name,
          autoPlay: true,
        );
    HapticFeedback.mediumImpact();
    if (context.mounted) Navigator.pop(context);
  }

  void _deleteFromRecent(String path) {
    StorageService().clearPosition(path);
    setState(() => _recentFiles.remove(path));
  }

  Future<void> _importAudioFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        await context.read<PlayerProvider>().loadSong(
              path: path,
              title: name,
              autoPlay: true,
            );
        HapticFeedback.mediumImpact();
        // Reload list sau khi thêm
        _loadRecentFiles();
        if (context.mounted) Navigator.pop(context);
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// AUDIO FILE ITEM
// ═══════════════════════════════════════════════════════════════

class _AudioFileItem extends StatelessWidget {
  final String name;
  final String path;
  final int positionMs;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AudioFileItem({
    required this.name,
    required this.path,
    required this.positionMs,
    required this.isPlaying,
    required this.onTap,
    required this.onDelete,
  });

  String _formatPosition(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPlaying
                ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: isPlaying
                ? Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPlaying ? Icons.equalizer : Icons.audio_file,
                  color: isPlaying ? const Color(0xFF6C63FF) : Colors.grey,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // Name + position
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isPlaying ? Colors.white : Colors.grey[300],
                        fontSize: 13,
                        fontWeight:
                            isPlaying ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (positionMs > 5000) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Đã nghe đến ${_formatPosition(positionMs)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Playing indicator
              if (isPlaying)
                const Icon(Icons.volume_up, size: 16, color: Color(0xFF6C63FF)),
            ],
          ),
        ),
      ),
    );
  }
}
