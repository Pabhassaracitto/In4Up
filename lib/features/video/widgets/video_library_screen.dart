import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../services/video_library_service.dart';
import 'video_player_screen.dart';

/// Màn hình thư viện video
class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  bool _isLoading = true;
  List<VideoInfo> _videos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    await VideoLibraryService.instance.ensureInitialized();
    setState(() {
      _videos = VideoLibraryService.instance.videos;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Video',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF9C27B0)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? _buildEmptyState()
              : _buildVideoList(),
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
