// lib/features/tts/widgets/voice_clone_section.dart
//
// TTS-CLONE-001 — Giao diện clone giọng VieNeu-TTS từ mẫu âm thanh.
// Cho phép người dùng thu âm mẫu giọng, tạo speaker embedding, và chọn
// giọng đã clone để đọc TTS.
//
// Quy trình:
//   1. Nhập tên giọng mới (ví dụ: "Giọng tôi").
//   2. Thu âm 3–5 câu mẫu (tổng cộng 30–60 giây).
//   3. Bấm "Tạo giọng" → sinh speaker.emb.txt qua native encoder.
//   4. Giọng mới xuất hiện trong dropdown giọng VieNeu-TTS.
//
// Lưu ý: VieNeu-TTS v3 Turbo dùng x-vector 256 chiều. Nếu chưa có encoder
// native (libspeaker_encoder.so), embedding sẽ là placeholder — giọng sẽ
// nghe giống giọng mặc định embed trong GGUF.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:in4up_stt/tts/vieneu_tts_core.dart';

/// Thời lượng tối đa thu âm mỗi mẫu (giây).
const int _maxSampleSeconds = 60;

/// Số mẫu tối đa cho một giọng.
const int _maxSamplesPerVoice = 5;

/// Widget clone giọng VieNeu-TTS.
class VoiceCloneSection extends StatefulWidget {
  final Color primaryColor;

  const VoiceCloneSection({super.key, this.primaryColor = const Color(0xFF6C63FF)});

  @override
  State<VoiceCloneSection> createState() => _VoiceCloneSectionState();
}

class _VoiceCloneSectionState extends State<VoiceCloneSection> {
  final _ttsCore = VieneuTtsCore.instance;

  // Thư mục lưu các mẫu giọng đã clone (khởi tạo trong _init vì cần path_provider async).
  late String _clonedVoicesDir;

  // Trạng thái thu âm.
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _recordingError;
  int _recordingSeconds = 0;

  // Danh sách giọng đã clone.
  List<_ClonedVoice> _clonedVoices = [];
  bool _loadingVoices = true;
  String? _loadError;

  // Trạng thái tạo giọng.
  String _newVoiceId = '';
  bool _isCloning = false;
  String? _cloneStatus;
  bool _cloneIsError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _clonedVoicesDir = (Platform.isAndroid || Platform.isIOS)
        ? (await getApplicationDocumentsDirectory()).path
        : Directory.current.path;
    _clonedVoicesDir = '$_clonedVoicesDir/vieneu_tts/cloned_voices';
    await _requestPermissions();
    await _loadClonedVoices();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() => _recordingError = 'Cần quyền microphone để thu âm mẫu giọng');
    }
  }

  Future<void> _loadClonedVoices() async {
    final dir = Directory(_clonedVoicesDir);
    if (!await dir.exists()) {
      if (!mounted) return;
      setState(() {
        _clonedVoices = [];
        _loadingVoices = false;
      });
      return;
    }

    final voices = <_ClonedVoice>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final voiceId = p.basename(entity.path);
      final embFile = File(p.join(entity.path, 'speaker.emb.txt'));
      final samplesDir = Directory(p.join(entity.path, 'samples'));
      final sampleCount =
          await samplesDir.exists()
              ? await samplesDir.list().then((list) => list.length)
              : 0;
      voices.add(_ClonedVoice(
        id: voiceId,
        embeddingPath: await embFile.exists() ? embFile.path : null,
        sampleCount: sampleCount,
        createdAt: await entity.stat().then((s) => s.modified),
      ));
    }
    voices.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (!mounted) return;
    setState(() {
      _clonedVoices = voices;
      _loadingVoices = false;
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // THU ÂM MẪU
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _startRecording() async {
    if (_isRecording) return;
    if (!await Permission.microphone.isGranted) {
      setState(() => _recordingError = 'Chưa được cấp quyền microphone');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final samplesDir = Directory(p.join(dir.path, 'vieneu_tts', 'cloned_voices', '_temp_samples'));
    if (!await samplesDir.exists()) {
      await samplesDir.create(recursive: true);
    }
    final path = p.join(samplesDir.path, 'sample_${DateTime.now().millisecondsSinceEpoch}.wav');

    final config = const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      bitRate: 128000,
    );

    try {
      await _audioRecorder.start(config, path: path);
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _currentRecordingPath = path;
        _recordingError = null;
        _recordingSeconds = 0;
      });

      _recordingTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _recordingError = 'Lỗi thu âm: $e');
    }
  }

  Timer? _recordingTimer;

  void _recordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecording) {
        _recordingTimer?.cancel();
        return;
      }
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= _maxSampleSeconds) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    await _audioRecorder.stop();
    _recordingTimer?.cancel();
    if (!mounted) return;
    setState(() => _isRecording = false);
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    _recordingTimer?.cancel();
    if (_currentRecordingPath != null) {
      await File(_currentRecordingPath!).delete().catchError((_) {});
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingSeconds = 0;
    });
  }

  // Lưu mẫu thu âm vào thư mục giọng mới (chưa tạo embedding).
  Future<void> _saveSampleToVoiceDir(String voiceId) async {
    if (_currentRecordingPath == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory(p.join(dir.path, 'vieneu_tts', 'cloned_voices', voiceId, 'samples'));
    if (!await voiceDir.exists()) {
      await voiceDir.create(recursive: true);
    }

    final dest = p.join(voiceDir.path, p.basename(_currentRecordingPath!));
    await File(_currentRecordingPath!).copy(dest.path);
    await File(_currentRecordingPath!).delete();

    if (!mounted) return;
    setState(() {
      _currentRecordingPath = null;
      _recordingSeconds = 0;
    });
    await _loadClonedVoices();
  }

  // ════════════════════════════════════════════════════════════════════════
  // TẠO GIỌNG
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _createClonedVoice() async {
    if (_newVoiceId.trim().isEmpty) {
      setState(() => _cloneStatus = 'Vui lòng nhập tên giọng');
      return;
    }
    if (_isCloning) return;

    // Kiểm tra có mẫu thu âm nào không.
    final tempDir = Directory(p.join(
      (await getApplicationDocumentsDirectory()).path,
      'vieneu_tts',
      'cloned_voices',
      '_temp_samples',
    ));
    int sampleCount = 0;
    if (await tempDir.exists()) {
      sampleCount = await tempDir.list().then((list) => list.length);
    }
    if (sampleCount == 0) {
      setState(() => _cloneStatus = 'Chưa có mẫu thu âm. Hãy ghi âm ít nhất 1 mẫu.');
      return;
    }

    setState(() {
      _isCloning = true;
      _cloneStatus = null;
      _cloneIsError = false;
    });

    try {
      await _ttsCore.cloneVoice(
        voiceId: _newVoiceId.trim(),
        samplesDir: tempDir.path,
      );
      if (!mounted) return;
      setState(() {
        _isCloning = false;
        _cloneStatus = 'Đã tạo giọng "$_newVoiceId" thành công!';
        _cloneIsError = false;
        _newVoiceId = '';
      });
      await _loadClonedVoices();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCloning = false;
        _cloneStatus = 'Lỗi tạo giọng: $e';
        _cloneIsError = true;
      });
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // XÓA GIỌNG
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _deleteClonedVoice(_ClonedVoice voice) async {
    final dir = Directory(p.join(_clonedVoicesDir, voice.id));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _loadClonedVoices();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADER ──
        Row(
          children: [
            Icon(Icons.record_voice_over, size: 18, color: widget.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Clone giọng VieNeu-TTS',
              style: TextStyle(
                fontSize: 16,
                color: widget.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── MÔ TẢ ──
        Text(
          'Thu âm mẫu giọng và tạo giọng đọc cá nhân hóa. '
          'Giọng mới sẽ xuất hiện trong dropdown giọng VieNeu-TTS.',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),

        // ── NHẬP TÊN GIỌNG ──
        TextField(
          decoration: InputDecoration(
            labelText: 'Tên giọng mới',
            hintText: 'Ví dụ: Giọng tôi, Giọng bà,…',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          onChanged: (v) => setState(() => _newVoiceId = v),
        ),
        const SizedBox(height: 8),

        // ── THU ÂM MẪU ──
        Text(
          'Mẫu âm thanh (${
            _currentRecordingPath != null ? 'Đang thu âm…' : 'Chưa có mẫu'
          })',
          style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (!_isRecording)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic, size: 16),
                  label: const Text('Thu âm mẫu', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.primaryColor,
                    side: BorderSide(color: widget.primaryColor),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _recordingSeconds / _maxSampleSeconds,
                      color: widget.primaryColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_recordingSeconds}s / ${_maxSampleSeconds}s',
                      style: const TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            if (_isRecording)
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.red),
                    onPressed: _stopRecording,
                    tooltip: 'Dừng thu âm',
                  ),
                  const SizedBox(height: 4),
                  Text('Dừng', style: TextStyle(fontSize: 9, color: Colors.red[300])),
                ],
              ),
          ],
        ),
        if (_recordingError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _recordingError!,
              style: TextStyle(fontSize: 10, color: Colors.red[300]),
            ),
          ),
        const SizedBox(height: 8),

        // ── NÚT TẠO GIỌNG ──
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isCloning ? null : _createClonedVoice,
                icon: _isCloning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                  _isCloning ? 'Đang tạo giọng…' : 'Tạo giọng từ mẫu',
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.primaryColor,
                  side: BorderSide(color: widget.primaryColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_currentRecordingPath != null)
              OutlinedButton.icon(
                onPressed: _cancelRecording,
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Hủy', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red[700]!),
                ),
              ),
          ],
        ),
        if (_cloneStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (_cloneIsError ? Colors.red : Colors.green).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (_cloneIsError ? Colors.red : Colors.green).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _cloneIsError ? Icons.error : Icons.check_circle,
                    size: 14,
                    color: _cloneIsError ? Colors.red[300] : Colors.green[300],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _cloneStatus!,
                      style: TextStyle(
                        fontSize: 10,
                        color: _cloneIsError ? Colors.red[200] : Colors.green[200],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),

        // ── DANH SÁCH GIỌNG ĐÃ CLONE ──
        Text(
          'Giọng đã clone',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (_loadingVoices)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_clonedVoices.isEmpty)
          Text(
            'Chưa có giọng clone. Thu âm mẫu và bấm "Tạo giọng từ mẫu".',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          )
        else
          Column(
            children: [
              for (final voice in _clonedVoices)
                _ClonedVoiceTile(
                  voice: voice,
                  primaryColor: widget.primaryColor,
                  onDelete: _deleteClonedVoice,
                ),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

/// Thông tin một giọng đã clone.
class _ClonedVoice {
  final String id;
  final String? embeddingPath;
  final int sampleCount;
  final DateTime createdAt;

  _ClonedVoice({
    required this.id,
    required this.embeddingPath,
    required this.sampleCount,
    required this.createdAt,
  });
}

/// Một dòng trong danh sách giọng đã clone.
class _ClonedVoiceTile extends StatelessWidget {
  final _ClonedVoice voice;
  final Color primaryColor;
  final Future<void> Function(_ClonedVoice) onDelete;

  const _ClonedVoiceTile({
    required this.voice,
    required this.primaryColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        dense: true,
        title: Text(
          voice.id,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        subtitle: Text(
          '${voice.sampleCount} mẫu · '
          '${voice.embeddingPath != null ? 'Đã có embedding' : 'Chưa có embedding'}',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[300], size: 18),
              onPressed: () => onDelete(voice),
              tooltip: 'Xoá giọng',
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ClonedVoiceTile &&
          runtimeType == other.runtimeType &&
          voice == other.voice;

  @override
  int get hashCode => voice.hashCode;
}
