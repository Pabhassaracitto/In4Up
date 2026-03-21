//
// ★ THÊM TAB GOOGLE DRIVE
// Tab 0: Máy (local files) - giữ nguyên
// Tab 1: Drive (Google Drive audio browser) - MỚI
//
// NOTE: Giữ nguyên toàn bộ logic tab "Máy", chỉ thêm tab Drive

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/player_provider.dart';
import 'google_drive_browser.dart';   // ← THÊM

class AudioLibraryDrawer extends StatefulWidget {
  const AudioLibraryDrawer({super.key});

  @override
  State<AudioLibraryDrawer> createState() => _AudioLibraryDrawerState();
}

class _AudioLibraryDrawerState extends State<AudioLibraryDrawer>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1520),
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 0: Local files ──
                  _LocalAudioTab(onClose: () => Navigator.pop(context)),

                  // ── Tab 1: Google Drive ── MỚI
                  const GoogleDriveBrowser(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.15),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.library_music,
                color: Color(0xFF6C63FF), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thư viện âm thanh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Thiết bị · Google Drive',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF6C63FF),
        unselectedLabelColor: Colors.grey,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_android, size: 14),
                SizedBox(width: 5),
                Text('Thiết bị'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google Drive icon (simplified)
                Text('📂', style: TextStyle(fontSize: 14)),
                SizedBox(width: 5),
                Text('Drive'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Tab local (giữ nguyên logic hiện tại của bạn)
// ──────────────────────────────────────────────────────────
class _LocalAudioTab extends StatefulWidget {
  final VoidCallback onClose;
  const _LocalAudioTab({required this.onClose});

  @override
  State<_LocalAudioTab> createState() => _LocalAudioTabState();
}

class _LocalAudioTabState extends State<_LocalAudioTab> {
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    if (context.mounted) {
      await context.read<PlayerProvider>().loadSong(
        path: path,
        title: result.files.single.name,
        autoPlay: true,
      );
      widget.onClose();
    }
  }

  Future<void> _pickAudioFolder() async {
    // FilePicker không hỗ trợ folder scan trực tiếp
    // Dùng pickFiles multiple
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    // Phát file đầu tiên
    final first = result.files.first;
    if (first.path != null && context.mounted) {
      await context.read<PlayerProvider>().loadSong(
        path: first.path!,
        title: first.name,
        autoPlay: true,
      );
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.audio_file_outlined,
                label: 'Chọn file âm thanh',
                subtitle: 'MP3, M4A, WAV, FLAC...',
                color: const Color(0xFF6C63FF),
                onTap: _pickAudioFile,
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.folder_open_outlined,
                label: 'Chọn nhiều file',
                subtitle: 'Chọn nhiều file cùng lúc',
                color: const Color(0xFF4CAF50),
                onTap: _pickAudioFolder,
              ),
            ],
          ),
        ),

        Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

        // Current playing
        Expanded(
          child: Consumer<PlayerProvider>(
            builder: (context, player, _) {
              if (player.currentSongPath == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_off,
                          size: 44, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text('Chưa có bài nào đang phát',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('Chọn file để bắt đầu',
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 11)),
                    ],
                  ),
                );
              }

              final fileName = player.currentSongTitle ?? 
                  player.currentSongPath!.split('/').last;

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Đang phát',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _CurrentTrackCard(
                      title: fileName,
                      path: player.currentSongPath!,
                      isPlaying: player.isPlaying,
                      onTap: widget.onClose,
                    ),
                  ),

                  // Segments của bài hiện tại
                  if (player.getSegmentsForCurrentSong().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Text('Đoạn đã lưu',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${player.getSegmentsForCurrentSong().length}',
                              style: const TextStyle(
                                  color: Color(0xFF9C8FFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount:
                            player.getSegmentsForCurrentSong().length,
                        itemBuilder: (ctx, i) {
                          final seg =
                              player.getSegmentsForCurrentSong()[i];
                          return _SegmentTile(
                            segment: seg,
                            onPlay: () {
                              player.playSegment(seg, index: i);
                              widget.onClose();
                            },
                            onDelete: () =>
                                player.deleteSegment(seg.id),
                          );
                        },
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                'Vuốt từ cạnh phải để mở',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 13),
          ],
        ),
      ),
    );
  }
}

class _CurrentTrackCard extends StatelessWidget {
  final String title;
  final String path;
  final bool isPlaying;
  final VoidCallback onTap;

  const _CurrentTrackCard({
    required this.title,
    required this.path,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPlaying
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF6C63FF).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPlaying ? '▶ Đang phát' : 'Đã tải',
                    style: TextStyle(
                        color: isPlaying
                            ? const Color(0xFF6C63FF)
                            : Colors.grey[600],
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final dynamic segment; // Segment model
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _SegmentTile({
    required this.segment,
    required this.onPlay,
    required this.onDelete,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(segment.title ?? 'Đoạn',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
                Text(
                  '${_formatDuration(segment.startTime)} → ${_formatDuration(segment.endTime)}',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_arrow,
                  color: Color(0xFF4CAF50), size: 16),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}
