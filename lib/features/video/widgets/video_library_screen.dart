import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
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
  bool _isLoading = true;
  bool _loadError = false;
  List<VideoInfo> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      await VideoLibraryService.instance.ensureInitialized();
    } catch (_) {
      // LISTEN-VIEW-001: lỗi init hiện thành UI lỗi + thử lại, không đen.
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
  }

  Future<void> _retryLoad() async {
    setState(() {
      _isLoading = true;
      _loadError = false;
    });
    await _loadVideos();
  }

  Future<void> _addVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v'],
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
      final title = result.files.single.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final id = md5.convert(utf8.encode('$path:${stat.modified.millisecondsSinceEpoch}')).toString();
      await VideoLibraryService.instance.addVideo(VideoInfo(
        id: id,
        title: title.isEmpty ? result.files.single.name : title,
        filePath: path,
        duration: duration,
        addedAt: DateTime.now(),
      ));
      if (!mounted) return;
      setState(() => _videos = VideoLibraryService.instance.videos);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm video: $title')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Video',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: widget.showBackButton
            ? IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Color(0xFF9C27B0)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError
              ? _buildErrorState()
              : _videos.isEmpty
                  ? _buildEmptyState()
                  : _buildVideoList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVideo,
        backgroundColor: const Color(0xFF9C27B0),
        icon: const Icon(Icons.video_library_outlined),
        label: const Text('Thêm video'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 64, color: Colors.grey[800]),
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
          Icon(Icons.video_library_outlined,
              size: 64, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
            'Chưa có video nào',
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Thêm video để bắt đầu học',
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return _VideoCard(
          video: video,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(video: video),
              ),
            );
          },
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_circle_outline,
                  color: Color(0xFF9C27B0), size: 32),
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
                  Text(
                    video.durationText,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }
}
