//
// Dialog tích hợp vào AudioLibraryDrawer:
//  - Dán URL → fetch info (title, thumbnail, duration)
//  - Download audio (progress bar realtime)
//  - Auto-play sau khi tải xong
//  - Cancel download

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../lib/providers/player_provider.dart';
import 'youtube_download_service.dart';

class YoutubeAudioDownloadDialog extends StatefulWidget {
  const YoutubeAudioDownloadDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<PlayerProvider>(),
        child: const YoutubeAudioDownloadDialog(),
      ),
    );
  }

  @override
  State<YoutubeAudioDownloadDialog> createState() =>
      _YoutubeAudioDownloadDialogState();
}

class _YoutubeAudioDownloadDialogState
    extends State<YoutubeAudioDownloadDialog> {
  final _urlCtrl = TextEditingController();
  final _svc = YoutubeDownloadService();

  // Phases: 'input' | 'info' | 'downloading' | 'done' | 'error'
  String _phase = 'input';

  YtVideoInfo? _videoInfo;
  DownloadProgress? _progress;
  String? _errorMessage;
  StreamSubscription<DownloadProgress>? _sub;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _sub?.cancel();
    super.dispose();
  }

  // ── Step 1: Fetch video info ──────────────────────────────

  Future<void> _fetchInfo() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;

    final videoId = YoutubeDownloadService.extractVideoId(url);
    if (videoId == null) {
      setState(() {
        _errorMessage = 'URL không hợp lệ.\nVí dụ: https://youtu.be/xxxxx';
        _phase = 'error';
      });
      return;
    }

    setState(() {
      _phase = 'info';
      _errorMessage = null;
    });

    final info = await _svc.fetchVideoInfo(url);
    if (!mounted) return;

    if (info == null) {
      setState(() {
        _errorMessage =
            'Không tải được thông tin video.\nKiểm tra URL và kết nối mạng.';
        _phase = 'error';
      });
      return;
    }

    setState(() {
      _videoInfo = info;
      _phase = 'info';
    });
  }

  // ── Step 2: Start download ────────────────────────────────

  Future<void> _startDownload() async {
    if (_videoInfo == null) return;

    setState(() {
      _phase = 'downloading';
      _progress = DownloadProgress(
        videoId: _videoInfo!.id,
        title: _videoInfo!.title,
        status: DownloadStatus.fetchingInfo,
      );
    });

    final stream = _svc.downloadAudio(_videoInfo!.id);
    _sub = stream.listen(
      (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);

        if (progress.status == DownloadStatus.completed) {
          setState(() => _phase = 'done');
          // Auto-play
          if (progress.savedPath != null && mounted) {
            _autoPlay(progress.savedPath!, progress.title);
          }
        } else if (progress.status == DownloadStatus.failed) {
          setState(() {
            _phase = 'error';
            _errorMessage = progress.errorMessage ?? 'Download thất bại';
          });
        } else if (progress.status == DownloadStatus.cancelled) {
          setState(() => _phase = 'input');
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _phase = 'error';
          _errorMessage = e.toString();
        });
      },
    );
  }

  Future<void> _autoPlay(String path, String title) async {
    final player = context.read<PlayerProvider>();
    await player.loadSong(path: path, title: title, autoPlay: true);
  }

  void _cancel() {
    if (_videoInfo != null) {
      _svc.cancelDownload(_videoInfo!.id);
    }
    setState(() => _phase = 'input');
  }

  void _reset() {
    _sub?.cancel();
    setState(() {
      _phase = 'input';
      _videoInfo = null;
      _progress = null;
      _errorMessage = null;
      _urlCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF0000).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.play_circle_fill,
              color: Color(0xFFFF0000), size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tải audio YouTube',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('Dán link → tải về máy',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case 'input':
        return _buildInputPhase();
      case 'info':
        return _videoInfo == null ? _buildLoadingInfo() : _buildInfoPhase();
      case 'downloading':
        return _buildDownloadingPhase();
      case 'done':
        return _buildDonePhase();
      case 'error':
        return _buildErrorPhase();
      default:
        return _buildInputPhase();
    }
  }

  // ── Phase: Input ─────────────────────────────────────────

  Widget _buildInputPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // URL field
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.link, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Dán URL YouTube vào đây...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (_) => _fetchInfo(),
                  textInputAction: TextInputAction.go,
                ),
              ),
              // Paste button
              IconButton(
                icon: const Icon(Icons.content_paste,
                    color: Colors.grey, size: 18),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    _urlCtrl.text = data!.text!.trim();
                  }
                },
                tooltip: 'Paste',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Supported formats hint
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hỗ trợ:',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              SizedBox(height: 4),
              Text('• youtube.com/watch?v=...',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('• youtu.be/...',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              Text('• youtube.com/shorts/...',
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Buttons
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _fetchInfo,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Tìm kiếm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Phase: Loading info ──────────────────────────────────

  Widget _buildLoadingInfo() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFFFF0000)),
          ),
          SizedBox(height: 16),
          Text('Đang lấy thông tin video...',
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  // ── Phase: Show info + confirm ────────────────────────────

  Widget _buildInfoPhase() {
    final info = _videoInfo!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Video card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: info.thumbnailUrl != null
                    ? Image.network(
                        info.thumbnailUrl!,
                        width: 80,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title.length > 60
                          ? '${info.title.substring(0, 58)}...'
                          : info.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${info.author} · ${info.formattedDuration}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Format info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2137),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.audio_file, size: 14, color: Color(0xFF2196F3)),
              SizedBox(width: 6),
              Text(
                'Định dạng: M4A/WebM · Chất lượng cao nhất',
                style: TextStyle(color: Colors.blue, fontSize: 11),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('← Quay lại',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Tải xuống'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Phase: Downloading ────────────────────────────────────

  Widget _buildDownloadingPhase() {
    final p = _progress;
    final isReady = p != null && p.status == DownloadStatus.downloading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          p?.title ?? 'Đang tải...',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: isReady ? p.progress : null,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),

        // Progress text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              p?.progressText ?? 'Đang chuẩn bị...',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              '${((p?.progress ?? 0) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Cancel button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _cancel,
            icon:
                const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
            label: const Text('Hủy tải', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Phase: Done ───────────────────────────────────────────

  Widget _buildDonePhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tải thành công!',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Audio đã được tải về và đang phát',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tải video khác',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _progress?.savedPath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Phase: Error ──────────────────────────────────────────

  Widget _buildErrorPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Đã xảy ra lỗi',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbPlaceholder() => Container(
        width: 80,
        height: 56,
        color: Colors.grey[900],
        child:
            const Icon(Icons.play_circle_outline, color: Colors.grey, size: 28),
      );
}
