import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Màn hình phát video local với phụ đề overlay + học từ vựng
///
/// Cần thêm `video_player` vào pubspec.yaml trước khi chạy:
///   video_player: ^2.8.0
///
/// Approach: dùng video_player cho Android/iOS, WebView cho YouTube
class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String? subtitlePath;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    this.subtitlePath,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // VideoPlayerController? _controller;  // Uncomment khi có video_player
  bool _isPlaying = false;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;

  // Subtitle state
  final List<_SubtitleEntry> _subtitles = [];
  int _currentSubIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadSubtitles();
    // TODO: Init video_player controller
    // _controller = VideoPlayerController.file(File(widget.videoPath))
    //   ..initialize().then((_) {
    //     setState(() {});
    //     _controller!.addListener(_onVideoUpdate);
    //   });
  }

  @override
  void dispose() {
    // _controller?.removeListener(_onVideoUpdate);
    // _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadSubtitles() async {
    final subPath = widget.subtitlePath ?? _findSubtitleFile();
    if (subPath == null) return;

    try {
      final file = File(subPath);
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final entries = _parseSrt(content);
      if (mounted) {
        setState(() => _subtitles.addAll(entries));
      }
    } catch (_) {}
  }

  String? _findSubtitleFile() {
    final dir = Directory(
      widget.videoPath.substring(0, widget.videoPath.lastIndexOf('/')),
    );
    final baseName = widget.videoPath
        .split('/')
        .last
        .replaceAll(RegExp(r'\.[^.]+$'), '');

    for (final ext in ['srt', 'ass', 'vtt']) {
      final subFile = File('${dir.path}/$baseName.$ext');
      if (subFile.existsSync()) return subFile.path;
    }
    return null;
  }

  List<_SubtitleEntry> _parseSrt(String content) {
    final entries = <_SubtitleEntry>[];
    final blocks = content.split(RegExp(r'\r?\n\r?\n'));

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue;

      // Line 0: index, Line 1: timestamp, Line 2+: text
      final timeMatch = RegExp(
        r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
      ).firstMatch(lines[1]);
      if (timeMatch == null) continue;

      final start = Duration(
        hours: int.parse(timeMatch.group(1)!),
        minutes: int.parse(timeMatch.group(2)!),
        seconds: int.parse(timeMatch.group(3)!),
        milliseconds: int.parse(timeMatch.group(4)!),
      );
      final end = Duration(
        hours: int.parse(timeMatch.group(5)!),
        minutes: int.parse(timeMatch.group(6)!),
        seconds: int.parse(timeMatch.group(7)!),
        milliseconds: int.parse(timeMatch.group(8)!),
      );
      final text = lines.sublist(2).join('\n').trim();

      if (text.isNotEmpty) {
        entries.add(_SubtitleEntry(start: start, end: end, text: text));
      }
    }
    return entries;
  }

  void _onVideoUpdate() {
    // TODO: Sync position + subtitle index
    // final pos = _controller?.value.position ?? Duration.zero;
    // setState(() => _position = pos);
    // _updateSubtitleIndex(pos);
  }

  void _updateSubtitleIndex(Duration position) {
    for (var i = 0; i < _subtitles.length; i++) {
      if (position >= _subtitles[i].start && position <= _subtitles[i].end) {
        if (_currentSubIndex != i) {
          setState(() => _currentSubIndex = i);
        }
        return;
      }
    }
    if (_currentSubIndex >= 0) {
      setState(() => _currentSubIndex = -1);
    }
  }

  void _togglePlay() {
    // TODO: _controller?.value.isPlaying == true ? _controller?.pause() : _controller?.play();
    setState(() => _isPlaying = !_isPlaying);
  }

  void _seek(Duration position) {
    // TODO: _controller?.seekTo(position);
    _updateSubtitleIndex(position);
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    _seek(target.isNegative ? Duration.zero : target);
  }

  void _setSpeed(double speed) {
    // TODO: _controller?.setPlaybackSpeed(speed);
    setState(() => _playbackSpeed = speed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape =
                orientation == Orientation.landscape;
            return isLandscape
                ? _buildLandscape()
                : _buildPortrait();
          },
        ),
      ),
    );
  }

  Widget _buildPortrait() {
    return Column(
      children: [
        // Title bar
        _buildTitleBar(),
        // Video area
        Expanded(child: _buildVideoArea()),
        // Subtitle overlay
        if (_currentSubIndex >= 0 && _currentSubIndex < _subtitles.length)
          _buildSubtitleOverlay(_subtitles[_currentSubIndex]),
        // Controls
        _buildControls(),
        // Subtitle timeline
        if (_subtitles.isNotEmpty) _buildSubtitleTimeline(),
      ],
    );
  }

  Widget _buildLandscape() {
    return Stack(
      children: [
        // Video fills screen
        GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: _buildVideoArea(),
        ),
        // Subtitle overlay (bottom)
        if (_currentSubIndex >= 0 && _currentSubIndex < _subtitles.length)
          Positioned(
            bottom: 60,
            left: 16,
            right: 16,
            child: _buildSubtitleOverlay(_subtitles[_currentSubIndex]),
          ),
        // Controls overlay
        if (_showControls)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(),
          ),
        // Back button
        Positioned(
          top: 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleBar() {
    final fileName = widget.videoPath.split('/').last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Speed chip
          GestureDetector(
            onTap: _showSpeedDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _playbackSpeed != 1.0
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _playbackSpeed != 1.0
                      ? Colors.orange.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                '${_playbackSpeed}×',
                style: TextStyle(
                  color: _playbackSpeed != 1.0
                      ? Colors.orange
                      : Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    // TODO: Replace with VideoPlayer(_controller!) when video_player is added
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, size: 64, color: Colors.grey[800]),
            const SizedBox(height: 16),
            Text(
              'Video Player',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.videoPath.split('/').last,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Cần thêm video_player vào pubspec.yaml',
              style: TextStyle(color: Colors.orange[300], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleOverlay(_SubtitleEntry entry) {
    return GestureDetector(
      onTap: () => _showSubtitleWordSheet(entry),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFFFB300).withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Text(
          entry.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF161B22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          Row(
            children: [
              Text(
                _fmtDuration(_position),
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 4,
                    ),
                    thumbColor: const Color(0xFFFFB300),
                    activeTrackColor: const Color(0xFFFFB300),
                    inactiveTrackColor: Colors.white12,
                  ),
                  child: Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds /
                                _duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    onChanged: (v) {
                      final pos = Duration(
                        milliseconds: (v * _duration.inMilliseconds).round(),
                      );
                      _seek(pos);
                    },
                  ),
                ),
              ),
              Text(
                _fmtDuration(_duration),
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
          // Play controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white70),
                onPressed: () => _seekRelative(-10),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF9800)],
                    ),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white70),
                onPressed: () => _seekRelative(10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleTimeline() {
    return Container(
      height: 80,
      color: const Color(0xFF0D1117),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _subtitles.length,
        itemBuilder: (_, i) {
          final sub = _subtitles[i];
          final isActive = i == _currentSubIndex;
          return GestureDetector(
            onTap: () => _seek(sub.start),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFFFB300).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: isActive
                    ? Border.all(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.4))
                    : null,
              ),
              constraints: const BoxConstraints(maxWidth: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmtDuration(sub.start),
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFFFFB300)
                          : Colors.grey[600],
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub.text,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[400],
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSubtitleWordSheet(_SubtitleEntry entry) {
    // TODO: Tích hợp WordAnalysisSheet từ từ điển
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nhấn giữ từ trong phụ đề để tra từ điển',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '${_fmtDuration(entry.start)} → ${_fmtDuration(entry.end)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Tốc độ phát'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                final isSelected = _playbackSpeed == speed;
                return ChoiceChip(
                  label: Text('${speed}×'),
                  selected: isSelected,
                  onSelected: (_) {
                    _setSpeed(speed);
                    Navigator.pop(context);
                  },
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  selectedColor:
                      const Color(0xFFFFB300).withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFFFFB300)
                        : Colors.white70,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

/// Subtitle entry model
class _SubtitleEntry {
  final Duration start;
  final Duration end;
  final String text;

  const _SubtitleEntry({
    required this.start,
    required this.end,
    required this.text,
  });
}
