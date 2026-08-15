//
// FIX 1: Thêm tab YouTube (3 tabs: Thiết bị / Drive / YouTube)
// FIX 2: Chọn nhiều file → hiển thị playlist, phát được từng bài

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../features/youtube/youtube_sheet.dart';
import '../../../providers/player_provider.dart';
import 'google_drive_browser.dart';

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
    _tabCtrl = TabController(length: 3, vsync: this); // ← 3 tabs
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
                  _LocalAudioTab(onClose: () => Navigator.pop(context)),
                  const GoogleDriveBrowser(),
                  _YouTubeTab(onClose: () => Navigator.pop(context)),
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
            Color(0xFF6C63FF).withValues(alpha: 0.15),
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
              color: Color(0xFF6C63FF).withValues(alpha: 0.2),
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
                  'Thiết bị · Drive · YouTube',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: compact,
            tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
            indicator: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF6C63FF),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            labelPadding: EdgeInsets.symmetric(horizontal: compact ? 8 : 0),
            tabs: [
              _drawerTab(compact, const Icon(Icons.phone_android, size: 13), 'Thiết bị'),
              _drawerTab(compact, const Text('📂', style: TextStyle(fontSize: 13)), 'Drive'),
              _drawerTab(compact, const Text('▶️', style: TextStyle(fontSize: 13)), 'YouTube'),
            ],
          ),
        );
      },
    );
  }

  Tab _drawerTab(bool compact, Widget icon, String label) {
    return Tab(
      height: compact ? 34 : 38,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Tab 0: Thiết bị
// ─────────────────────────────────────────────────────────
class _LocalAudioTab extends StatefulWidget {
  final VoidCallback onClose;
  const _LocalAudioTab({required this.onClose});

  @override
  State<_LocalAudioTab> createState() => _LocalAudioTabState();
}

class _LocalAudioTabState extends State<_LocalAudioTab> {
  // FIX: Lưu playlist thay vì chỉ phát 1 file
  List<PlatformFile> _playlist = [];

  Future<void> _pickSingleFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    if (context.mounted) {
      await context.read<PlayerProvider>().loadSong(
            path: file.path!,
            title: file.name,
            autoPlay: true,
          );
      widget.onClose();
    }
  }

  Future<void> _pickMultipleFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    // Lọc file có path hợp lệ
    final valid = result.files.where((f) => f.path != null).toList();
    if (valid.isEmpty) return;

    // Lưu playlist để hiện danh sách
    setState(() => _playlist = valid);

    // Phát file đầu tiên
    if (context.mounted) {
      await context.read<PlayerProvider>().loadSong(
            path: valid.first.path!,
            title: valid.first.name,
            autoPlay: true,
          );
      // Không đóng drawer - user muốn xem playlist và chọn bài khác
    }
  }

  Future<void> _playFile(PlatformFile file) async {
    if (file.path == null || !context.mounted) return;
    await context.read<PlayerProvider>().loadSong(
          path: file.path!,
          title: file.name,
          autoPlay: true,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Buttons chọn file
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.audio_file_outlined,
                label: 'Chọn file âm thanh',
                subtitle: 'MP3, M4A, WAV, FLAC...',
                color: const Color(0xFF6C63FF),
                onTap: _pickSingleFile,
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.playlist_add,
                label: 'Chọn nhiều file',
                subtitle: 'Tạo playlist từ nhiều file',
                color: const Color(0xFF4CAF50),
                onTap: _pickMultipleFiles,
              ),
            ],
          ),
        ),

        Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),

        Expanded(
          child: Consumer<PlayerProvider>(
            builder: (context, player, _) {
              final hasContent =
                  player.currentSongPath != null || _playlist.isNotEmpty;

              if (!hasContent) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_off, size: 44, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text('Chưa có bài nào đang phát',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('Chọn file để bắt đầu',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 11)),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ── Đang phát ──
                  if (player.currentSongPath != null) ...[
                    Text('Đang phát',
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    _CurrentTrackCard(
                      title: player.currentSongTitle ??
                          player.currentSongPath!.split('/').last,
                      isPlaying: player.isPlaying,
                      onTap: widget.onClose,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Playlist (FIX: hiện đủ các file đã chọn) ──
                  if (_playlist.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('Playlist — ${_playlist.length} bài',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _playlist = []),
                          child: Text('Xóa',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._playlist.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final file = entry.value;
                      final isCurrent = player.currentSongPath == file.path;
                      return GestureDetector(
                        onTap: () => _playFile(file),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: isCurrent
                                    ? const Icon(Icons.graphic_eq,
                                        color: Color(0xFF6C63FF), size: 16)
                                    : Text('${idx + 1}',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: isCurrent
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (file.size > 0)
                                Text(
                                  _sizeLabel(file.size),
                                  style: TextStyle(
                                      color: Colors.grey[700], fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // ── Segments của bài hiện tại ──
                  if (player.currentSongPath != null &&
                      player.getSegmentsForCurrentSong().isNotEmpty) ...[
                    Row(
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
                            color: Color(0xFF6C63FF).withValues(alpha: 0.2),
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
                    const SizedBox(height: 8),
                    ...player.getSegmentsForCurrentSong().asMap().entries.map(
                          (e) => _SegmentTile(
                            segment: e.value,
                            onPlay: () {
                              player.playSegment(e.value, index: e.key);
                              widget.onClose();
                            },
                            onDelete: () => player.deleteSegment(e.value.id),
                          ),
                        ),
                  ],
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

  String _sizeLabel(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)}MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)}KB';
  }
}

// ─────────────────────────────────────────────────────────
// Tab 1: Google Drive — không thay đổi, dùng GoogleDriveBrowser
// ─────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────
// Tab 2: YouTube
// ─────────────────────────────────────────────────────────
class _YouTubeTab extends StatelessWidget {
  final VoidCallback onClose;
  const _YouTubeTab({required this.onClose});

  void _openYoutube(BuildContext context, {bool captionsFirst = false}) {
    // Đóng drawer trước, sau đó mở sheet
    Navigator.pop(context);
    Future.microtask(() {
      if (context.mounted) {
        YoutubeSheet.show(context, captionsFirst: captionsFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFFF0000).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Color(0xFFFF0000).withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Text('▶️', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YouTube',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      SizedBox(height: 2),
                      Text(
                        'Tải audio · Captions · Khám phá kênh',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Nút tải audio
          ElevatedButton.icon(
            onPressed: () => _openYoutube(context),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Tải Audio từ YouTube'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 10),

          // Nút tải captions
          OutlinedButton.icon(
            onPressed: () => _openYoutube(context, captionsFirst: true),
            icon: const Icon(Icons.subtitles_outlined, size: 18),
            label: const Text('Tải Lyrics / Captions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4CAF50),
              side: BorderSide(color: Color(0xFF4CAF50).withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),

          // Tips
          const _TipRow(
            icon: Icons.music_note,
            text: 'Dán URL YouTube → tải audio M4A chất lượng cao',
          ),
          const SizedBox(height: 8),
          const _TipRow(
            icon: Icons.subtitles,
            text: 'Tải captions → mở trong Understand Mode để học đồng bộ',
          ),
          const SizedBox(height: 8),
          const _TipRow(
            icon: Icons.link,
            text: 'Tải cả audio + captions → link lại để phát đồng bộ',
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 11, height: 1.4)),
        ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────

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
                          color: color.withValues(alpha: 0.7), fontSize: 11)),
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
  final bool isPlaying;
  final VoidCallback onTap;

  const _CurrentTrackCard({
    required this.title,
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
          color: Color(0xFF6C63FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFF6C63FF).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPlaying
                    ? const Color(0xFF6C63FF)
                    : Color(0xFF6C63FF).withValues(alpha: 0.3),
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
  final dynamic segment;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _SegmentTile({
    required this.segment,
    required this.onPlay,
    required this.onDelete,
  });

  String _fmt(Duration d) {
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(segment.title ?? 'Đoạn',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  '${_fmt(segment.startTime)} → ${_fmt(segment.endTime)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
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
                color: Color(0xFF4CAF50).withValues(alpha: 0.15),
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
