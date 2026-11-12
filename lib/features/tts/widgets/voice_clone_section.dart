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

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:in4up_stt/tts/vieneu_tts_core.dart';
import 'package:in4up_stt/tts/vieneu_tts_paths.dart';
import '../tts_service.dart';

/// Thời lượng tối đa thu âm mỗi mẫu (giây).
const int _maxSampleSeconds = 60;

/// Số mẫu tối đa cho một giọng.
const int _maxSamplesPerVoice = 5;

// Keep message kinds instead of translated strings so a locale change also
// updates any error or status that is already visible.
enum _RecordingIssue { permissionRequired, permissionDenied, failed }
enum _CloneNotice { needName, needSample, importedSamples, success, failed }

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
  _RecordingIssue? _recordingIssue;
  int _recordingSeconds = 0;

  // Danh sách giọng đã clone.
  List<_ClonedVoice> _clonedVoices = [];
  bool _loadingVoices = true;
  String? _loadError;

  // Trạng thái tạo giọng.
  String _newVoiceId = '';
  bool _isCloning = false;
  _CloneNotice? _cloneNotice;
  String? _cloneNoticeDetail;
  int _sampleCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // PSRC-184: bản cũ dùng `Directory.current` trên desktop trong khi
    // TtsService/engine dùng documents ⇒ UI liệt kê giọng ở nơi KHÁC với
    // nơi native ghi embedding. Dùng chung một thư mục documents.
    _clonedVoicesDir =
        p.join(Directory.current.path, 'vieneu_tts', 'cloned_voices');
    // Hỏi quyền micro TRƯỚC khi chờ path_provider: hai lời gọi platform
    // channel liên tiếp làm thông báo quyền xuất hiện muộn hơn khung pump đầu
    // tiên của widget test. Gốc documents được cập nhật ngay sau đó, trước
    // khi đọc danh sách giọng / số mẫu tạm.
    await _requestPermissions();
    if (!mounted) return;
    try {
      final root = (await getApplicationDocumentsDirectory()).path;
      if (!mounted) return;
      _clonedVoicesDir = p.join(root, 'vieneu_tts', 'cloned_voices');
    } catch (_) {
      // path_provider chưa sẵn sàng trong test thuần: giữ gốc fallback.
    }
    await _loadClonedVoices();
    await _refreshSampleCount();
  }

  /// PSRC-184/185 — đếm / dọn mẫu tạm TRỰC TIẾP trên đĩa. Không gọi
  /// `TtsService()` ở đây: singleton đó kéo theo platform channel của
  /// just_audio và làm test widget thuần (voice_clone_localization_test)
  /// văng MissingPluginException ngay trong `initState`.
  String get _tempSamplesDir =>
      p.join(_clonedVoicesDir, vieneuTempSamplesDirName);

  Future<int> _countTempSamples() async {
    final dir = Directory(_tempSamplesDir);
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final entity in dir.list()) {
      if (entity is File && isVieneuVoiceSampleFile(entity.path)) count++;
    }
    return count;
  }

  Future<void> _clearTempSamples() async {
    final dir = Directory(_tempSamplesDir);
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _refreshSampleCount() async {
    int count = 0;
    try {
      count = await _countTempSamples();
    } catch (_) {
      // path_provider chưa sẵn sàng trong test: giữ 0.
    }
    if (!mounted) return;
    setState(() => _sampleCount = count);
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() => _recordingIssue = _RecordingIssue.permissionRequired);
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
      // `_temp_samples` là vùng chứa mẫu CHƯA tạo giọng — không phải giọng.
      if (voiceId.startsWith('_') || voiceId == vieneuTempSamplesDirName) continue;
      final embFile = File(p.join(entity.path, 'speaker.emb.txt'));
      final samplesDir = Directory(p.join(entity.path, 'samples'));
      final sampleCount =
          await samplesDir.exists()
              ? await samplesDir.list().toList().then((list) => list.length)
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
      if (!mounted) return;
      // Lúc MỞ màn đã báo `permissionRequired` ("cần quyền micro").
      // Khi user CHỦ ĐỘNG bấm ghi mà quyền vẫn bị từ chối thì phải nói khác:
      // "quyền chưa được cấp" — nếu lặp lại câu đầu, user bấm mà không thấy
      // phản hồi gì (đúng lỗi voice_clone_localization_test bắt được).
      setState(() => _recordingIssue = _RecordingIssue.permissionDenied);
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
        _recordingIssue = null;
        _recordingSeconds = 0;
      });

      _startRecordingTimer();
    } catch (e, stack) {
      // Plugin diagnostics are not localized and can contain Vietnamese.
      // Keep them in logs while presenting an actionable localized message.
      debugPrint('Voice sample recording failed: $e\n$stack');
      if (!mounted) return;
      setState(() => _recordingIssue = _RecordingIssue.failed);
    }
  }

  Timer? _recordingTimer;

  void _startRecordingTimer() {
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

  /// PSRC-185 — import mẫu từ thư mục có sẵn (người dùng đã có bộ sưu tập
  /// WAV). Ưu tiên chọn thư mục; platform không hỗ trợ (Android/SAF) thì
  /// chọn nhiều file. Chỉ nhận `.wav` — đúng định dạng native đọc được.
  Future<void> _importSamplesFromFolder() async {
    String? dirPath;
    try {
      dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: context.uiText('Chọn thư mục chứa mẫu giọng'),
      );
    } catch (_) {}
    try {
      int count;
      if (dirPath != null) {
        count = await TtsService().importVieneuSamplesFromDirectory(dirPath);
      } else {
        final result = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const ['wav'],
          dialogTitle: context.uiText('Chọn file mẫu giọng WAV'),
        );
        if (result == null || result.files.isEmpty) return;
        count = await TtsService().importVieneuSampleFiles(
          result.files.map((f) => f.path).whereType<String>().toList(),
        );
      }
      await _refreshSampleCount();
      if (!mounted) return;
      setState(() {
        _cloneNotice = _CloneNotice.importedSamples;
        _cloneNoticeDetail = '$count';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.uiText('Đã import $count mẫu WAV'))),
      );
    } catch (e) {
      debugPrint('Import samples error: $e');
      if (!mounted) return;
      setState(() {
        _cloneNotice = _CloneNotice.failed;
        _cloneNoticeDetail = null;
      });
    }
  }

  /// Copy TẤT CẢ mẫu WAV từ vùng tạm vào `<voiceId>/samples/` TRƯỚC khi gọi
  /// native clone. PSRC-184: bản cũ chỉ copy file cuối và XOÁ vùng tạm ngay
  /// lập tức — một lần clone lỗi là mất hết mẫu đã thu. Vùng tạm chỉ được
  /// dọn sau khi clone thành công (trong `_createClonedVoice`).
  Future<void> _prepareSamplesForVoice(String voiceId) async {
    final docDir = await getApplicationDocumentsDirectory();
    final tempDir = Directory(p.join(docDir.path, 'vieneu_tts',
        'cloned_voices', vieneuTempSamplesDirName));
    final voiceSamplesDir = Directory(
        p.join(docDir.path, 'vieneu_tts', 'cloned_voices', voiceId, 'samples'));
    if (!await voiceSamplesDir.exists()) {
      await voiceSamplesDir.create(recursive: true);
    }

    var copied = 0;
    if (await tempDir.exists()) {
      await for (final entity in tempDir.list()) {
        if (entity is! File || !isVieneuVoiceSampleFile(entity.path)) continue;
        final dest = File(p.join(voiceSamplesDir.path, p.basename(entity.path)));
        if (await dest.exists()) {
          copied++;
          continue;
        }
        try {
          await entity.copy(dest.path);
          copied++;
        } catch (_) {}
      }
    }
    // File recording vừa dừng có thể chưa flush vào temp dir.
    final current = _currentRecordingPath;
    if (current != null && isVieneuVoiceSampleFile(current)) {
      final cur = File(current);
      final dest = File(p.join(voiceSamplesDir.path, p.basename(current)));
      if (await cur.exists() && !await dest.exists()) {
        try {
          await cur.copy(dest.path);
          copied++;
        } catch (_) {}
      }
    }
    if (copied == 0) {
      throw StateError('Không có mẫu WAV hợp lệ để tạo giọng');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // TẠO GIỌNG
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> _createClonedVoice() async {
    // PSRC-184: tên giọng là TÊN THƯ MỤC — phải chuẩn hoá trước khi đưa
    // xuống native (`../`, `/`, ký tự điều khiển tạo sai đường dẫn).
    final voiceId = sanitizeVieneuVoiceId(_newVoiceId);
    if (voiceId.isEmpty) {
      setState(() {
        _cloneNotice = _CloneNotice.needName;
        _cloneNoticeDetail = null;
      });
      return;
    }
    if (_isCloning) return;

    // Đếm đúng số file WAV (bản cũ đếm mọi entity, kể cả thư mục rác).
    int sampleCount = 0;
    try {
      sampleCount = await _countTempSamples();
    } catch (_) {}
    if (!mounted) return;
    if (sampleCount == 0) {
      setState(() {
        _cloneNotice = _CloneNotice.needSample;
        _cloneNoticeDetail = null;
      });
      return;
    }

    setState(() {
      _isCloning = true;
      _cloneNotice = null;
      _cloneNoticeDetail = null;
    });

    try {
      await _prepareSamplesForVoice(voiceId);
      final samplesDir = p.join(_clonedVoicesDir, voiceId, 'samples');

      // PSRC-184: đi qua TtsService ⇒ engine.init có lock, chờ native init
      // XONG rồi mới clone. Bản cũ kiểm tra `_ttsCore.isInitialized` (true
      // ngay sau handshake) rồi gửi `clone_voice` trong lúc worker còn đang
      // nạp 170 MB ⇒ trả "Chưa init" ⇒ "Không thể tạo giọng".
      await TtsService().ensureVieneuWorkerReady();
      await _ttsCore.cloneVoice(
        voiceId: voiceId,
        samplesDir: samplesDir,
      );

      // Chỉ dọn vùng tạm SAU KHI đã có embedding; thất bại ở trên giữ nguyên
      // mẫu để người dùng bấm lại mà không phải thu âm lại.
      await _clearTempSamples();
      TtsService().notifyVoicesChanged();
      await _refreshSampleCount();
      if (!mounted) return;
      setState(() {
        _isCloning = false;
        _cloneNotice = _CloneNotice.success;
        _cloneNoticeDetail = voiceId;
        _newVoiceId = '';
      });
      await _loadClonedVoices();
    } catch (e, stack) {
      // Native errors may be Vietnamese even when the app locale is not.
      debugPrint('Voice creation failed: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _isCloning = false;
        _cloneNotice = _CloneNotice.failed;
        _cloneNoticeDetail = null;
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
    TtsService().notifyVoicesChanged();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recordingError = switch (_recordingIssue) {
      null => null,
      _RecordingIssue.permissionRequired => l10n.ttsCloneVoicePermissionRequired,
      _RecordingIssue.permissionDenied => l10n.ttsCloneVoicePermissionDenied,
      _RecordingIssue.failed => l10n.ttsCloneVoiceRecordingError,
    };
    final cloneStatus = switch (_cloneNotice) {
      null => null,
      _CloneNotice.needName => l10n.ttsCloneVoiceNeedName,
      _CloneNotice.needSample => l10n.ttsCloneVoiceNeedSample,
      _CloneNotice.importedSamples => context.uiText(
          'Đã import ${_cloneNoticeDetail ?? '0'} mẫu WAV'),
      _CloneNotice.success => l10n.ttsCloneVoiceSuccess(_cloneNoticeDetail ?? ''),
      _CloneNotice.failed => l10n.ttsCloneVoiceCreateError,
    };
    final cloneIsError = _cloneNotice != _CloneNotice.success &&
        _cloneNotice != _CloneNotice.importedSamples;
    final sampleStatus = _isRecording
        ? l10n.ttsCloneVoiceRecording
        : _currentRecordingPath != null
            ? l10n.ttsCloneVoiceSampleReady
            : l10n.ttsCloneVoiceNoSample;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADER ──
        Row(
          children: [
            Icon(Icons.record_voice_over, size: 18, color: widget.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.ttsCloneVoiceTitle,
                style: TextStyle(
                  fontSize: 16,
                  color: widget.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── MÔ TẢ ──
        Text(
          l10n.ttsCloneVoiceDesc,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),

        // ── NHẬP TÊN GIỌNG ──
        TextField(
          decoration: InputDecoration(
            labelText: l10n.ttsCloneVoiceNewName,
            hintText: l10n.ttsCloneVoiceNewHint,
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
          '${l10n.ttsCloneVoiceSamples} ($sampleStatus)',
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
                  label: Text(l10n.ttsCloneVoiceRecord, style: const TextStyle(fontSize: 11)),
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
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
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
                    tooltip: l10n.ttsCloneVoiceStopRecording,
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.ttsCloneVoiceStop, style: TextStyle(fontSize: 9, color: Colors.red[300])),
                ],
              ),
          ],
        ),
        if (recordingError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              recordingError,
              style: TextStyle(fontSize: 10, color: Colors.red[300]),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          l10n.ttsCloneVoiceSamplesCount(_sampleCount),
          style: TextStyle(fontSize: 9.5, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),

        // ── IMPORT MẪU TỪ THƯ MỤC (PSRC-185) ──
        OutlinedButton.icon(
          onPressed: _importSamplesFromFolder,
          icon: const Icon(Icons.folder_open, size: 16),
          label: Text(
            context.uiText('Thêm mẫu từ thư mục'),
            style: const TextStyle(fontSize: 11),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.grey[600]!),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.uiText(
              'Chọn thư mục chứa file WAV (hoặc nhiều file) để thêm vào danh sách mẫu.'),
          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
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
                  _isCloning ? l10n.ttsCloneVoiceCreating : l10n.ttsCloneVoiceCreate,
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
                label: Text(l10n.commonCancel, style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red[700]!),
                ),
              ),
          ],
        ),
        if (cloneStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (cloneIsError ? Colors.red : Colors.green).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (cloneIsError ? Colors.red : Colors.green).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cloneIsError ? Icons.error : Icons.check_circle,
                    size: 14,
                    color: cloneIsError ? Colors.red[300] : Colors.green[300],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    // The success notice contains a user-provided voice name.
                    child: material.Text(
                      cloneStatus,
                      style: TextStyle(
                        fontSize: 10,
                        color: cloneIsError ? Colors.red[200] : Colors.green[200],
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
          l10n.ttsCloneVoiceVoices,
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
            l10n.ttsCloneVoiceNoVoices,
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
    final l10n = AppLocalizations.of(context);
    final embeddingStatus = voice.embeddingPath != null
        ? l10n.ttsCloneVoiceHasEmbedding
        : l10n.ttsCloneVoiceNoEmbedding;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        dense: true,
        // Voice IDs are user content, not presentation strings.
        title: material.Text(
          voice.id,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        subtitle: Text(
          '${l10n.ttsCloneVoiceSamplesCount(voice.sampleCount)} · $embeddingStatus',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[300], size: 18),
              onPressed: () => onDelete(voice),
              tooltip: l10n.ttsCloneVoiceDelete,
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
