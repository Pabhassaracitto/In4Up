// lib/screens/listen_mode/services/listen_live_offline_stt.dart
//
// M4U-IMPORT-003 — phiên live STT OFFLINE (sherpa-onnx) cho tab Nghe.
//
// Dùng model ASR offline đã cài trên máy:
//   * Parakeet TDT 0.6B v3 (NVIDIA, int8) — 25 ngôn ngữ châu Âu, ~670MB;
//   * Zipformer VI 30M int8 — tiếng Việt offline.
//
// Parakeet là transducer OFFLINE (không có bản streaming của sherpa-onnx)
// ⇒ live đi đường "simulated streaming": `OfflineRecognizer` + Silero VAD,
// giống hệt đường live STT của Cabin (CABIN-ASR-002 / PARAKEET-002).
//
// KHÔNG tạo engine/singleton mới: dùng `SherpaSttEngine` (packages/in4up_stt)
// + `AudioRecorder` PCM 16 kHz — cùng pattern với `SherpaQuickCaptureSource`
// (HOME-QUICK-001) và `SttsCabinService`.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/models/stt_result.dart';
import 'package:in4up_stt/sherpa_model_manager.dart';
import 'package:in4up_stt/stt_engine_sherpa.dart';
import 'package:record/record.dart';

/// Phiên ghi âm + nhận diện offline bằng sherpa-onnx cho tab Nghe.
class ListenLiveOfflineStt {
  ListenLiveOfflineStt({
    SherpaModelManager? manager,
    SherpaSttEngine? engine,
  })  : _manager = manager ?? SherpaModelManager(),
        _engine = engine ?? SherpaSttEngine();

  /// Phiên đang chạy — chỉ một mic offline tại một thời điểm (tab Nghe có
  /// nhiều chỗ render phần "tạo LRC": trong trang + trong bottom sheet).
  static ListenLiveOfflineStt? _active;

  final SherpaModelManager _manager;
  final SherpaSttEngine _engine;

  AudioRecorder? _recorder;
  bool _listening = false;
  String? _lastError;

  /// Đang ghi + nhận diện.
  bool get isListening => _listening;

  /// Lỗi gần nhất (null = chưa có lỗi) — UI hiện dạng snackbar.
  String? get lastError => _lastError ?? _engine.lastError;

  /// Kết quả live (partial + final).
  Stream<SttResult> get results => _engine.liveResultStream;

  /// Bắt đầu phiên live cho [language] (mã ngôn ngữ, vd `vi`, `de`).
  ///
  /// Trả false + [lastError] khi không có model offline cho ngôn ngữ đó hoặc
  /// engine không khởi tạo được (thiếu VAD, thiếu RAM…).
  Future<bool> start(String language) async {
    await stop();
    // Chỉ một phiên mic offline tại một thời điểm — dừng phiên cũ (nếu có)
    // trước khi chiếm mic.
    final active = _active;
    if (active != null && !identical(active, this)) {
      await active.stop();
    }
    _active = this;
    _lastError = null;

    // Model có thể vừa được import/tải ⇒ quét lại state trước khi kết luận
    // "chưa có model" (CABIN-ASR-002).
    try {
      await _manager.ensureFresh();
    } catch (e) {
      debugPrint('⚠️ ListenLiveOfflineStt ensureFresh lỗi: $e');
    }

    final paths = _manager.getAsrModelPaths(language);
    if (paths == null) {
      _lastError =
          'Chưa có model nhận diện offline cho ngôn ngữ này. Mở Quản lý '
          'Model AI để tải/import model (Parakeet hoặc Zipformer VI).';
      debugPrint('⚠️ ListenLiveOfflineStt: $_lastError');
      return false;
    }

    final recorder = AudioRecorder();
    _recorder = recorder;
    try {
      final pcmStream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      final ok = await _engine.startLive(
        language: language,
        pcmStream: pcmStream,
        // Truyền đúng model đã tra (Parakeet khi profile chuyên ngôn ngữ
        // chưa cài) — không để engine tự tra lại theo ngôn ngữ.
        modelPaths: paths,
      );
      if (!ok) {
        _lastError = _engine.lastError ?? 'Không khởi động được model offline.';
        await _releaseRecorder();
        return false;
      }

      _listening = true;
      debugPrint('🎙️ ListenLiveOfflineStt started ($language, '
          'profile=${paths.family.name})');
      return true;
    } catch (e) {
      _lastError = 'Lỗi khởi động ghi âm/nhận diện offline: $e';
      debugPrint('❌ ListenLiveOfflineStt start lỗi: $e');
      await _releaseRecorder();
      return false;
    }
  }

  /// Dừng phiên (nhả mic, giải phóng recognizer).
  Future<void> stop() async {
    if (_listening) {
      try {
        await _engine.stopListening();
      } catch (e) {
        debugPrint('⚠️ ListenLiveOfflineStt stop engine lỗi: $e');
      }
    }
    _listening = false;
    if (identical(_active, this)) _active = null;
    await _releaseRecorder();
  }

  /// Giải phóng tài nguyên (gọi khi rời màn).
  Future<void> dispose() async {
    await stop();
    try {
      await _engine.dispose();
    } catch (e) {
      debugPrint('⚠️ ListenLiveOfflineStt dispose lỗi: $e');
    }
  }

  Future<void> _releaseRecorder() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder == null) return;
    try {
      if (await recorder.isRecording()) {
        await recorder.stop();
      }
    } catch (_) {}
    try {
      await recorder.dispose();
    } catch (_) {}
  }
}
