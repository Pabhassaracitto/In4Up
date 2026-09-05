import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;

import '../models/video_info.dart';
import '../services/video_library_service.dart';
import 'video_player_screen.dart';

/// Màn hình thư viện video — quét thiết bị hoặc chọn file
class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  final _service = VideoLibraryService.instance;
  bool _scanning = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (!_service.isScanned) _scanDevice();
  }

  Future<void> _scanDevice() async {
    setState(() => _scanning = true);
    await _service.scanVideos();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _pickFile() async {
    final result = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: VideoInfo.supportedExtensions,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoPath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _searchQuery.isEmpty
        ? _service.videos
        : _service.search(_searchQuery);

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          context.uiText('Video'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFFFB300)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: context.uiText('Chọn file'),
            onPressed: _pickFile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.uiText('Quét lại'),
            onPressed: _scanning ? null : _scanDevice,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: context.uiText('Tìm video...'),
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Content
          Expanded(
            child: _scanning
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 12),
                        Text('Đang quét video...',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : videos.isEmpty
                    ? _buildEmptyState()
                    : _buildVideoList(videos),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        backgroundColor: const Color(0xFFFFB300),
        child: const Icon(Icons.video_file),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Chưa tìm thấy video',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhấn nút bên dưới để chọn file video\nhoặc đặt video vào thư mục Movies/Download',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: Text(context.uiText('Chọn file video')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoList(List<VideoInfo> videos) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: videos.length,
      itemBuilder: (_, i) => _VideoCard(
        video: videos[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(videoPath: videos[i].filePath),
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_circle_outline,
            color: Color(0xFFFFB300), size: 28),
      ),
      title: Text(
        video.fileName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            video.fileSizeFormatted,
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
          const SizedBox(width: 8),
          Text(
            '.${video.extension}',
            style: TextStyle(color: Colors.grey[700], fontSize: 10),
          ),
          if (video.hasSubtitle) ...[
            const SizedBox(width: 8),
            Icon(Icons.subtitles, size: 12, color: Colors.green[400]),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
