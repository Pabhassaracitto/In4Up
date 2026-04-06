// test_just_audio_windows.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:typed_data';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('just_audio Windows Test')),
        body: AudioTest(),
      ),
    );
  }
}

class AudioTest extends StatefulWidget {
  @override
  _AudioTestState createState() => _AudioTestState();
}

class _AudioTestState extends State<AudioTest> {
  final AudioPlayer _player = AudioPlayer();
  String _log = '';

  void _addLog(String message) {
    print(message);
    setState(() {
      _log += '$message\n';
    });
  }

  Future<void> _testJustAudio() async {
    _addLog('=== Testing just_audio on Windows ===');
    _addLog('just_audio: 0.10.5');
    _addLog('Platform interface: 4.6.0');
    _addLog('just_audio_web: 0.4.16');
    _addLog('Platform: ${Platform.operatingSystem}');

    try {
      // Test 1: Kiểm tra player
      _addLog('\n1. Creating AudioPlayer...');
      _addLog('Player created: ${_player.runtimeType}');

      // Test 2: Kiểm tra nếu có file test
      final testFile = File('test.wav');
      if (!await testFile.exists()) {
        _addLog('\n2. Creating test WAV file...');
        await _createTestWav();
      }

      // Test 3: Thử play
      _addLog('\n3. Playing audio...');
      await _player.setAudioSource(
        AudioSource.uri(Uri.file('test.wav')),
      );
      await _player.play();
      _addLog('Playback started!');

      // Listen for events
      _player.playbackEventStream.listen((event) {
        _addLog('Event: ${event.processingState}');
      });
    } catch (e, stack) {
      _addLog('\n❌ ERROR: $e');
      _addLog('Stack: $stack');
    }
  }

  Future<void> _createTestWav() async {
    // Tạo file WAV đơn giản
    final wavBytes = Uint8List.fromList([
      // WAV header (44 bytes)
      0x52, 0x49, 0x46, 0x46, 0x24, 0x08, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45,
      0x66, 0x6D, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00,
      0x44, 0xAC, 0x00, 0x00, 0x10, 0xB1, 0x02, 0x00, 0x04, 0x00, 0x10, 0x00,
      0x64, 0x61, 0x74, 0x61, 0x00, 0x08, 0x00, 0x00,
      // Audio data (silence)
      ...List.filled(2048, 0)
    ]);

    await File('test.wav').writeAsBytes(wavBytes);
    _addLog('Created test.wav (2KB)');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _testJustAudio,
            child: const Text('Test just_audio'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _log,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
