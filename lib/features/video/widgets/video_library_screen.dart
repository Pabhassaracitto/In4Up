// I4U18-VIDEO-LIB-001 — Thư viện video trực quan:
//  - Quét thư mục (SAF, đệ quy) — không chỉ thêm từng file lẻ.
//  - Tìm kiếm + lọc (Tất cả / Yêu thích / Gần đây / Có phụ đề) + sắp xếp.
//  - Ghép phụ đề tự động; giữ vị trí phát gần nhất (badge tiến độ).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:flutter/material.dart' show Text;
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
import '../services/video_device_channel.dart';
import '../services/video_library_logic.dart';
import '../services/video_library_service.dart';
import 'video_player_screen.dart';

/// Màn hình thư viện video
class VideoLibraryScreen extends StatefulWidget {
  /// False khi nhúng trong IndexedStack của shell (tab phụ "Xem"): khi đó
  /// không có route để pop — nút back sẽ pop nhầm route gốc gây đen màn hình
  /// (LISTEN-VIEW-001). True khi push như một route độc lập (quick actions).
  final bool showBackButton;

  const VideoLibraryScreen({super.key, this.showBackButton = true});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  static const _accent = Color(0xFF9C27B0);

  bool _isLoading = true;
  bool _loadError = false;
  bool _scanning = false;
  String? _scanError;
  List<VideoInfo> _videos = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  VideoFilter _filter = VideoFilter.all;
  VideoSort _sort = VideoSort.dateNewest;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    try {
      await VideoLibraryService.instance.ensureInitialized();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _videos = VideoLibraryService.instance.videos;
      _isLoading = false;
      _loadError = false;
    });
    // Nếu đã có thư mục → tự quét lại nền (cập nhật file mới, không trùng).
    if (VideoLibraryService.instance.hasFolder) {
      unawaitedScan();
    }
  }

  void unawaitedScan() {
    _scanFolder(silent: true);
  }

  Future<void> _retryLoad() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });
    await _loadVideos();
  }

  Future<void> _pickFolder() async {
    if (!VideoLibraryService.instance.folderScanSupported) {
      _snack(context.uiText(
          'Nền tảng này chưa hỗ trợ quét thư mục — hãy dùng "Thêm video".'));
      return;
    }
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      final picked = await VideoLibraryService.instance.pickAndScanFolder();
      if (!mounted) return;
      setState(() {
        _videos = VideoLibraryService.instance.videos;
        _scanning = false;
      });
      if (picked) {
        _snack(context.uiText('Đã quét thư mục: ${VideoLibraryService.instance.folderLabel}'));
      }
    } on VideoScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError = e.toString();
      });
    }
  }

  Future<void> _scanFolder({bool silent = false}) async {
    if (!VideoLibraryService.instance.hasFolder) {
      await _pickFolder();
      return;
    }
    setState(() {
      _scanning = true;
      _scanError = null;
    });
    try {
      await VideoLibraryService.instance.scanFolder();
      if (!mounted) return;
      setState(() {
        _videos = VideoLibraryService.instance.videos;
        _scanning = false;
      });
    } on VideoScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _scanError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      if (!silent) _snack(e.toString());
    }
  }

  Future<void> _addVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kVideoExtensions.toList(),
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    final path = result.files.single.path!;
    try {
      final file = File(path);
      final stat = await file.stat();
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      final title =
          result.files.single.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final id = md5
          .convert(utf8.encode(
              '$path:${stat.modified.millisecondsSinceEpoch}'))
          .toString();
      await VideoLibraryService.instance.addVideo(VideoInfo(
        id: id,
        title: title.isEmpty ? result.files.single.name : title,
        filePath: VideoLibraryLogic.normalizeUri(path),
        duration: duration,
        addedAt: DateTime.now(),
        sizeBytes: stat.size,
        folder: VideoLibraryLogic.folderLabel(path),
        source: VideoSource.picked,
      ));
      if (!mounted) return;
      setState(() => _videos = VideoLibraryService.instance.videos);
      _snack(context.uiText('Đã thêm video: $title'));
    } catch (e) {
      if (!mounted) return;
      _snack(context.uiText('Không thể mở video: $e'));
    }
  }

  Future<void> _toggleFavorite(VideoInfo v) async {
    await VideoLibraryService.instance.toggleFavorite(v.id);
    if (!mounted) return;
    setState(() => _videos = VideoLibraryService.instance.videos);
  }

  void _openVideo(VideoInfo v) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v)),
    ).then((_) {
      if (mounted) {
        setState(() => _videos = VideoLibraryService.instance.videos);
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<VideoInfo> get _visible => _videos.query(
        search: _query,
        filter: _filter,
        sort: _sort,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Video', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: _accent),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          PopupMenuButton<VideoSort>(
            icon: const Icon(Icons.sort, color: Colors.white70),
            color: const Color(0xFF1A1A2E),
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              _sortItem(VideoSort.dateNewest, context.uiText('Mới nhất')),
              _sortItem(VideoSort.titleAsc, context.uiText('Tên A→Z')),
              _sortItem(VideoSort.durationLongest, context.uiText('Dài nhất')),
              _sortItem(VideoSort.folder, context.uiText('Theo thư mục')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _loadError
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildSearchBar(),
                    _buildFilterChips(),
                    if (_scanError != null) _buildScanError(),
                    Expanded(
                      child: _videos.isEmpty
                          ? _buildEmptyState()
                          : _buildVideoList(),
                    ),
                  ],
                ),
      floatingActionButton: _isLoading || _loadError
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'video_add_file',
                  onPressed: _addVideo,
                  backgroundColor: const Color(0xFF2A2A40),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'video_scan_folder',
                  onPressed: _scanning ? null : _scanFolder,
                  backgroundColor: _accent,
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.create_new_folder_outlined),
                  label: Text(VideoLibraryService.instance.hasFolder
                      ? context.uiText('Quét thư mục')
                      : context.uiText('Chọn thư mục')),
                ),
              ],
            ),
    );
  }

  PopupMenuItem<VideoSort> _sortItem(VideoSort s, String label) {
    return PopupMenuItem(
      value: s,
      child: Row(
        children: [
          Icon(_sort == s ? Icons.check : Icons.sort,
              size: 16, color: _sort == s ? _accent : Colors.white38),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: context.uiText('🔍  Tìm video…'),
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12.5),
          filled: true,
          fillColor: const Color(0xFF111827),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    Widget chip(VideoFilter f, String label, IconData icon) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _filter = f),
          backgroundColor: const Color(0xFF111827),
          selectedColor: _accent.withValues(alpha: 0.3),
          side: BorderSide(
              color: selected ? _accent : Colors.white12, width: 1),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? _accent : Colors.white54),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.white54,
                      fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          chip(VideoFilter.all, context.uiText('Tất cả'), Icons.grid_view),
          chip(VideoFilter.favorites, context.uiText('Yêu thích'),
              Icons.favorite),
          chip(VideoFilter.recent, context.uiText('Gần đây'), Icons.history),
          chip(VideoFilter.hasSubtitle, context.uiText('Có phụ đề'),
              Icons.subtitles),
        ],
      ),
    );
  }

  Widget _buildScanError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFEF5350), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_scanError!,
                style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12)),
          ),
          TextButton(
            onPressed: _pickFolder,
            child: Text(context.uiText('Chọn thư mục khác'),
                style: const TextStyle(color: _accent, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            context.uiText('Không tải được thư viện video'),
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _retryLoad,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(context.uiText('Thử lại')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined, size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text(
            'Chưa có video nào',
            style: TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            context.uiText('Chọn một thư mục để quét video, hoặc thêm từng file'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _scanning ? null : _pickFolder,
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            icon: const Icon(Icons.create_new_folder_outlined,
                color: Colors.white, size: 18),
            label: Text(context.uiText('Chọn thư mục video'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    final list = _visible;
    if (list.isEmpty) {
      return Center(
        child: Text(
          context.uiText('Không có video khớp bộ lọc'),
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _scanFolder(silent: true),
      color: _accent,
      backgroundColor: const Color(0xFF1A2235),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 140),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final video = list[index];
          return _VideoCard(
            video: video,
            onTap: () => _openVideo(video),
            onFavorite: () => _toggleFavorite(video),
          );
        },
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final VideoInfo video;
  final Color accent;

  const _VideoThumbnail({required this.video, required this.accent});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = widget.video.filePath;
      final controller = value.startsWith('content://')
          ? VideoPlayerController.contentUri(Uri.parse(value))
          : VideoPlayerController.file(File(value));
      await controller.initialize();
      await controller.seekTo(Duration.zero);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      // Unsupported/corrupt files keep the useful extension placeholder.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Icon(Icons.play_circle_outline,
                color: Colors.white.withValues(alpha: .9), size: 28),
          ),
        ],
      );
    }
    final extension = VideoLibraryLogic.extensionOf(widget.video.title).toUpperCase();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.movie_outlined, color: widget.accent, size: 25),
        Text(extension.isEmpty ? 'VIDEO' : extension,
            style: TextStyle(color: widget.accent, fontSize: 9, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _VideoCard({
    required this.video,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF9C27B0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _VideoThumbnail(video: video, accent: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (video.hasSubtitle)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.subtitles,
                              size: 13, color: accent),
                        ),
                      Flexible(
                        child: Text(
                          [
                            if (video.folder.isNotEmpty) video.folder,
                            if (video.sizeLabel.isNotEmpty) video.sizeLabel,
                            if (video.durationText.isNotEmpty)
                              video.durationText,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (video.isInProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: video.progress,
                          minHeight: 3,
                          backgroundColor: Colors.white10,
                          valueColor:
                              const AlwaysStoppedAnimation(accent),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                video.favorite ? Icons.favorite : Icons.favorite_border,
                color: video.favorite ? accent : Colors.grey[600],
                size: 20,
              ),
              onPressed: onFavorite,
            ),
          ],
        ),
      ),
    );
  }
}
