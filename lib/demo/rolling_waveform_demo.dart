// lib/demo/rolling_waveform_demo.dart
import 'package:flutter/material.dart';
import 'package:ultra_music_player/models/waveform_data.dart';
import 'package:ultra_music_player/models/waveform_data.dart';
import '../widgets/rolling_waveform_view.dart';
import '../widgets/rolling_waveform_controller.dart';
import '../utils/waveform_utils.dart';
import 'dart:async';

class RollingWaveformDemo extends StatefulWidget {
  const RollingWaveformDemo({super.key});

  @override
  State<RollingWaveformDemo> createState() => _RollingWaveformDemoState();
}

class _RollingWaveformDemoState extends State<RollingWaveformDemo> {
  late RollingWaveformController _controller;
  late Timer _timer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = RollingWaveformController();

    // Generate dummy waveform
    final dummyData = WaveformUtils.generateDummy(const Duration(minutes: 3));
    _controller.setWaveformData(dummyData);

    // Add sample loop region
    _controller.addLoopRegion(
      LoopRegion(
        start: const Duration(seconds: 30),
        end: const Duration(seconds: 60),
      ),
    );

    // Simulate playback
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isPlaying) {
        final newPosition = Duration(
          milliseconds: _controller.position.inMilliseconds + 100,
        );
        if (newPosition <= _controller.duration) {
          _controller.updatePosition(newPosition);
        } else {
          _isPlaying = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: const Text('Rolling Waveform Demo'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),

          // Waveform
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RollingWaveformView(
                controller: _controller,
                onSeek: (position) {
                  _controller.updatePosition(position);
                },
                onTap: () {
                  setState(() => _isPlaying = !_isPlaying);
                },
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 48,
                  color: const Color(0xFF6C63FF),
                  onPressed: () {
                    setState(() => _isPlaying = !_isPlaying);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
