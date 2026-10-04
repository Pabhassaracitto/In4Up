// ignore_for_file: unnecessary_brace_in_string_interps
// I4U18-VIDEO-LIB-001 — Màn hình phát video THẬT (video_player) với:
//  - Phụ đề overlay (SRT/VTT/ASS/LRC) đồng bộ theo vị trí phát.
//  - Reopen đúng vị trí: seek tới lastPositionMs khi mở, lưu vị trí khi
//    tạm dừng / thoát.
//  - Điều khiển: play/pause, tua ±10s, thanh tiến độ, tốc độ 0.5×–2×.
import 'dart:async';
import 'dart:io';

import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:flutter/material.dart' show Text;
import 'package:video_player/video_player.dart';

import '../models/video_info.dart';
import '../services/subtitle_parser.dart';
import '../services/video_device_channel.dart';
import '../services/video_library_logic.dart';
import '../services/video_library_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoInfo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _initFailed = false;
  bool _showControls = true;
  double _speed = 1.0;
  List<SubtitleCue> _cues = const [];
  SubtitleCue? _currentCue;
  bool _resumed = false;
  Timer? _saveTimer;

  static const _accent = Color(0xFF9C27B0);

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadSubtitle();
  }

  Future<void> _initPlayer() async {
    try {
      final path = widget.video.filePath;
      final controller = path.startsWith('content://')
          ? VideoPlayerController.contentUri(Uri.parse(path))
          : VideoPlayerController.file(File(path));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      setState(() => _controller = controller);

      // Reopen đúng vị trí: seek tới vị trí phát gần nhất (nếu đáng kể).
      final resumeMs = widget.video.lastPositionMs;
      if (resumeMs > 5000 &&
          resumeMs < controller.value.duration.inMilliseconds - 3000) {
        await controller.seekTo(Duration(milliseconds: resumeMs));
      }
      _resumed = true;
      await controller.play();
      // Lưu vị trí định kỳ để không mất khi app bị kill.
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _persistPosition());
    } catch (e) {
      if (!mounted) return;
      setState(() => _initFailed = true);
    }
  }

  Future<void> _loadSubtitle() async {
    final sub = widget.video.subtitlePath;
    if (sub == null || sub.isEmpty) return;
    try {
      String? readable = sub;
      if (sub.startsWith('content://')) {
        readable = await VideoDeviceChannel.copyContentToCache(sub);
      }
      if (readable == null) return;
      final content = await File(readable).readAsString();
      final ext = VideoLibraryLogic.extensionOf(sub);
      final cues = SubtitleParser.parse(content, ext: ext);
      if (!mounted) return;
      setState(() => _cues = cues);
    } catch (_) {
      // Phụ đề lỗi → bỏ qua, video vẫn phát.
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_cues.isNotEmpty) {
      final cue = SubtitleParser.cueAt(_cues, c.value.position);
      if (cue != _currentCue) {
        setState(() => _currentCue = cue);
      }
    } else {
      setState(() {});
    }
  }

  Future<void> _persistPosition() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !_resumed) return;
    await VideoLibraryService.instance.updatePlayback(
      widget.video.id,
      position: c.value.position,
      duration: c.value.duration,
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_persistPosition());
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _persistPosition();
      } else {
        c.play();
      }
    });
  }

  void _seekBy(Duration delta) {
    final c = _controller;
    if (c == null) return;
    var target = c.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > c.value.duration) target = c.value.duration;
    c.seekTo(target);
  }

  Future<void> _setSpeed(double s) async {
    final c = _controller;
    if (c == null) return;
    await c.setPlaybackSpeed(s);
    setState(() => _speed = s);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.video.title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (ready)
            PopupMenuButton<double>(
              icon: const Icon(Icons.speed, color: Colors.white),
              color: const Color(0xFF1A1A2E),
              onSelected: _setSpeed,
              itemBuilder: (_) => [
                for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  PopupMenuItem(
                    value: s,
                    child: Text(
                      '${s}×${s == _speed ? '  ✓' : ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Container(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (ready)
                      Center(
                        child: AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
                      )
                    else if (_initFailed)
                      _buildError()
                    else
                      const CircularProgressIndicator(color: _accent),

                    // Phụ đề overlay.
                    if (_currentCue != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _SubtitleText(text: _currentCue!.text),
                      ),

                    // Nút play lớn khi đang tạm dừng.
                    if (ready && !c.value.isPlaying)
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 40),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showControls && ready) _buildControls(c),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            context.uiText('Không phát được video này'),
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(VideoPlayerController c) {
    final pos = c.value.position;
    final dur = c.value.duration;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: const Color(0xFF111827),
      child: Column(
        children: [
          Row(
            children: [
              Text(_fmt(pos),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _accent,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    thumbColor: _accent,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (v) => c.seekTo(
                        Duration(milliseconds: (v * dur.inMilliseconds).toInt())),
                  ),
                ),
              ),
              Text(_fmt(dur),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10,
                    color: Colors.white, size: 28),
                onPressed: () => _seekBy(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10,
                    color: Colors.white, size: 28),
                onPressed: () => _seekBy(const Duration(seconds: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  final String text;
  const _SubtitleText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}
