import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/video_info.dart';

/// Màn hình phát video
class VideoPlayerScreen extends StatefulWidget {
  final VideoInfo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isPlaying = false;
  bool _showControls = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // TODO: Initialize video_player controller
    // For now, just show placeholder
    setState(() {
      _duration = widget.video.duration;
    });
  }

  @override
  void dispose() {
    // TODO: Dispose controller
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
  }

  void _seekTo(Duration position) {
    setState(() => _position = position);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: Column(
        children: [
          // Video area
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Container(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Video placeholder
                    Center(
                      child: Icon(
                        Icons.videocam,
                        size: 80,
                        color: Colors.grey[800],
                      ),
                    ),

                    // Play button overlay
                    if (!_isPlaying)
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Controls bar
          if (_showControls)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: const Color(0xFF111827),
              child: Column(
                children: [
                  // Progress bar
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: const Color(0xFF9C27B0),
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.1),
                            thumbColor: const Color(0xFF9C27B0),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds /
                                    _duration.inMilliseconds
                                : 0.0,
                            onChanged: (v) {
                              _seekTo(Duration(
                                  milliseconds:
                                      (v * _duration.inMilliseconds).toInt()));
                            },
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  // Control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10,
                            color: Colors.white, size: 28),
                        onPressed: () {
                          final newPos = _position -
                              const Duration(seconds: 10);
                          _seekTo(newPos.isNegative ? Duration.zero : newPos);
                        },
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9C27B0)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.forward_10,
                            color: Colors.white, size: 28),
                        onPressed: () {
                          final newPos = _position +
                              const Duration(seconds: 10);
                          _seekTo(newPos > _duration ? _duration : newPos);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
