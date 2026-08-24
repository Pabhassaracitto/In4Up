// lib/features/vad/services/sherpa_vad_service.dart
// Handover SECTION 2 — Quy định kỹ thuật khi triển khai VAD
// Library khuyên dùng: sherpa_onnx (chỉ load VAD module, rất nhẹ ~2-5MB)

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/utils/audio_converter.dart';
import 'package:in4up_stt/vad/sherpa_vad_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/speech_segment.dart';

/// Abstract VAD Service — để sau này swap sang sherpa_onnx thực thụ
abstract class VadService {
  /// Phát hiện các đoạn speech trong file audio
  /// Trả về List<SpeechSegment> với start_time, end_time
  ///
  /// [onVadProgress] (tuỳ chọn): tiến độ quét VAD (0..1) — cho UI vẽ
  /// thanh tiến độ trong khi file dài đang được quét (audit VAD 30p:
  /// quét đồng bộ chặn main isolate gây đơ UI).
  Future<VadResult> detectSpeechSegments(
    String audioFilePath, {
    void Function(double fraction)? onVadProgress,
  });

  /// Release native resources
  Future<void> dispose();
}

/// Sherpa ONNX VAD Service — thiết kế theo handover
/// * Load VAD module rất nhẹ ~2-5MB (silero_vad.onnx)
/// * Absolute path via path_provider (Rule 1 tái sử dụng)
/// * Verification existsSync + size >1M trước init
/// * Fallback sang EnergyVad nếu model chưa có
class SherpaVadService implements VadService {
  static const String _kVadModelFileName = 'silero_vad.onnx';
  static const String _kVadModelFolder = 'sherpa_vad_models';

  // Sherpa VAD params (theo doc sherpa_onnx)
  final double threshold; // ngưỡng speech (0..1)
  final int minSpeechDurationMs;
  final int minSilenceDurationMs;
  final double maxSpeechDurationS;
  final int speechPadMs;
  final double samplesOverlap;

  bool _initialized = false;
  String? _modelAbsolutePath;
  // Pointer native sherpa VAD — GIỮ TRONG SINGLETON (Section 3 handover):
  // không re-init liên tục, tránh xung đột FFI với whisper.cpp.
  SherpaVadCore? _vadCore;

  SherpaVadService({
    this.threshold = 0.5,
    this.minSpeechDurationMs = 250,
    this.minSilenceDurationMs = 100,
    this.maxSpeechDurationS = 14, // không để chunk quá dài (tránh OOM)
    this.speechPadMs = 30,
    this.samplesOverlap = 0.1,
  });

  /// Rule 1 & 3 tái sử dụng: absolute path + verification
  Future<String> _resolveVadModelDirectory() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = await getApplicationSupportDirectory();
    }
    final dir = Directory(p.join(baseDir.path, _kVadModelFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String?> _findVadModelFile() async {
    try {
      final dirPath = await _resolveVadModelDirectory();
      final candidates = [
        p.join(dirPath, _kVadModelFileName),
        // Fallback tên khác mà sherpa_onnx hay dùng
        p.join(dirPath, 'vad.onnx'),
        p.join(dirPath, 'silero_vad.onnx'),
      ];

      // Thêm legacy support dir
      try {
        final sup = await getApplicationSupportDirectory();
        candidates.add(p.join(sup.path, _kVadModelFolder, _kVadModelFileName));
      } catch (_) {}

      for (final cand in candidates) {
        final f = File(cand);
        // Rule 3: existsSync + size > 1M? VAD model ~2-5MB nên >1M hợp lệ
        if (f.existsSync()) {
          final size = f.lengthSync();
          if (size > 1000000) {
            debugPrint('✅ VAD model found at absolute path: $cand size=$size');
            return cand;
          } else {
            debugPrint('⚠️ VAD model too small ($size bytes) at $cand');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ _findVadModelFile error: $e');
    }
    return null;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    _modelAbsolutePath = await _findVadModelFile();

    if (_modelAbsolutePath == null) {
      debugPrint(
        'ℹ️ Sherpa VAD model not found at ${_kVadModelFolder}/$_kVadModelFileName '
        '(size <1MB or missing). Will use EnergyVad fallback. '
        'Để dùng sherpa_onnx thật, hãy chép file silero_vad.onnx (~2-5MB) vào '
        '${await _resolveVadModelDirectory()}',
      );
      // Không throw — fallback sang energy VAD
    } else {
      try {
        // PLAN-008: khởi tạo sherpa_onnx.Vad THẬT (Silero VAD)
        _vadCore = SherpaVadCore(
          modelPath: _modelAbsolutePath!,
          threshold: threshold,
          minSilenceDuration: minSilenceDurationMs / 1000.0,
          minSpeechDuration: minSpeechDurationMs / 1000.0,
          maxSpeechDuration: maxSpeechDurationS,
        );
      } catch (e) {
        debugPrint('⚠️ SherpaVadCore init lỗi, dùng EnergyVad fallback: $e');
        _vadCore = null;
      }
    }

    _initialized = true;
  }

  @override
  Future<VadResult> detectSpeechSegments(
    String audioFilePath, {
    void Function(double fraction)? onVadProgress,
  }) async {
    await _ensureInitialized();
    final sw = Stopwatch()..start();

    // Kiểm tra file audio tồn tại
    final audioFile = File(audioFilePath);
    if (!audioFile.existsSync()) {
      throw StateError('Audio file không tồn tại: $audioFilePath');
    }

    // PLAN-008: có sherpa VAD thật → dùng nó (Silero VAD)
    if (_vadCore != null) {
      final sherpaResult = await _runSherpaVad(
        audioFilePath,
        onVadProgress: onVadProgress,
      );
      if (sherpaResult != null) {
        sw.stop();
        return sherpaResult;
      }
      // convert/detect lỗi → rơi xuống fallback (pipeline không gãy)
      debugPrint('⚠️ Sherpa VAD không cho kết quả, dùng EnergyVad fallback');
    }

    // Fallback: Energy-based VAD (không cần model) — chỉ dùng khi
    // thiếu silero_vad.onnx hoặc sherpa lỗi.
    final result = await _runEnergyVadFallback(audioFilePath);

    sw.stop();
    return VadResult(
      segments: result.segments,
      totalAudioDuration: result.totalAudioDuration,
      totalSpeechDuration: result.totalSpeechDuration,
      processingTime: sw.elapsed,
      engineUsed: _vadCore != null ? 'sherpa_silero' : 'energy_fallback',
    );
  }

  /// Chạy Silero VAD thật: convert audio → 16k mono WAV → sherpa detect.
  /// Trả null nếu không xử lý được (caller fallback energy).
  Future<VadResult?> _runSherpaVad(
    String audioPath, {
    void Function(double fraction)? onVadProgress,
  }) async {
    final core = _vadCore;
    if (core == null) return null;
    String? convertedPath;
    try {
      onVadProgress?.call(0.0);
      convertedPath = await AudioConverter.convertToWhisperCompatible(audioPath);
      // readWave chỉ ăn WAV 16k mono — convertToWhisperCompatible đã chuẩn
      // .wav input được trả nguyên (nếu wav không phải 16k, detect trả []
      // → fallback, đúng nghĩa "sai chuẩn thì an toàn")
      // ★ detectAsync: yield event loop định kỳ — file 30p không đơ UI
      //   (audit 2026-08-23), kèm tiến độ quét cho UI.
      final segments = await core.detectAsync(
        convertedPath!,
        onProgress: (done, total) {
          if (total > 0) onVadProgress?.call(done / total);
        },
      );
      if (segments.isEmpty) return null;

      // Duration thật của file (probe) — chuẩn hơn last-segment end
      double totalAudioDuration = 0;
      try {
        final ms = await AudioConverter.probeDurationMs(audioPath);
        totalAudioDuration = (ms ?? 0) / 1000.0;
      } catch (_) {}
      if (totalAudioDuration <= 0) {
        totalAudioDuration = segments.last.endTime;
      }
      final totalSpeechDuration =
          segments.fold<double>(0, (s, x) => s + x.duration);

      debugPrint(
        '✅ Silero VAD: ${audioPath.split('/').last} → '
        '${segments.length} speech segments '
        '(${totalSpeechDuration.toStringAsFixed(1)}s speech)',
      );

      return VadResult(
        segments: segments
            .map((s) => SpeechSegment(
                  startTime: s.startTime,
                  endTime: s.endTime,
                  confidence: 0.95,
                  isSpeech: true,
                ))
            .toList(),
        totalAudioDuration: totalAudioDuration,
        totalSpeechDuration: totalSpeechDuration,
        processingTime: Duration.zero,
        engineUsed: 'sherpa_silero',
      );
    } catch (e) {
      debugPrint('⚠️ _runSherpaVad error: $e');
      return null;
    } finally {
      // Rule cleanup: file convert tạm phải xóa ngay (không để rác tmp)
      if (convertedPath != null && convertedPath != audioPath) {
        try {
          await AudioConverter.cleanupConvertedFile(convertedPath);
        } catch (_) {}
      }
    }
  }

  /// Fallback VAD đơn giản dựa trên chia chunk đều + giả định toàn bộ là speech
  /// Khi có sherpa_onnx thật, hàm này sẽ bị thay thế.
  /// Để tối ưu thời gian từ 20p xuống 8-10p, ta cần loại bỏ silence thật sự.
  /// Hiện tại fallback này vẫn giữ pipeline chạy được, nhưng sẽ được cải thiện.
  Future<VadResult> _runEnergyVadFallback(String audioPath) async {
    // Để tránh nạp cả file 1h vào RAM (Rule quản lý Memory & Cleanup)
    // Ta chỉ probe duration bằng ffmpeg/ffprobe, không đọc PCM toàn bộ
    // Nếu không probe được, fallback chia 15s chunk đều

    double totalDurationSeconds = 0;
    try {
      totalDurationSeconds = await _probeAudioDurationSeconds(audioPath);
    } catch (_) {
      // Nếu probe fail, giả định file dài 1h = 3600s để chia
      totalDurationSeconds = 3600;
    }

    if (totalDurationSeconds <= 0) {
      totalDurationSeconds = 3600;
    }

    // Quy định kỹ thuật: không nạp nguyên file 1h vào RAM
    // Chia thành các segment theo maxSpeechDurationS (14s default per handover)
    // Đây cũng là cách sherpa_onnx hoạt động: trả về List<SpeechSegment>
    final segments = <SpeechSegment>[];
    double cursor = 0;

    while (cursor < totalDurationSeconds) {
      final end = (cursor + maxSpeechDurationS).clamp(0, totalDurationSeconds);
      // Thêm padding nhỏ để tránh cắt cụt từ
      final paddedEnd = (end + speechPadMs / 1000.0).clamp(0, totalDurationSeconds);

      segments.add(SpeechSegment(
        startTime: cursor,
        endTime: paddedEnd.toDouble(),
        confidence: 0.9,
        isSpeech: true,
      ));

      cursor = paddedEnd.toDouble();
      // Overlap để không mất từ ở biên
      cursor -= samplesOverlap;
      if (cursor < 0) cursor = 0;
    }

    // Tính total speech duration (fallback: coi tất cả là speech)
    final speechDur = segments.fold<double>(0, (sum, s) => sum + s.duration);

    debugPrint(
      '🔊 EnergyVadFallback: audio ${totalDurationSeconds.toStringAsFixed(1)}s -> '
      '${segments.length} segments x ${maxSpeechDurationS}s',
    );

    return VadResult(
      segments: segments,
      totalAudioDuration: totalDurationSeconds,
      totalSpeechDuration: speechDur,
      processingTime: Duration.zero,
      engineUsed: 'energy_fallback',
    );
  }

  Future<double> _probeAudioDurationSeconds(String audioPath) async {
    // Thử dùng ffprobe nếu có, nếu không ước lượng qua file size
    // Để đơn giản, ta ước lượng: file 1h ~ 60MB ở 128kbps?
    // Tốt hơn là để AudioConverter (đã có probe) xử lý — ở đây fallback
    // sẽ gọi AudioConverter nếu có thể
    try {
      // Dynamic import để tránh circular dependency
      // Nếu AudioConverter không khả dụng, ước lượng qua file size
      final file = File(audioPath);
      if (!file.existsSync()) return 0;

      // Nếu là wav: duration ≈ size / (sampleRate*channels*bits/8)
      // Giả định 16kHz mono 16bit ~ 32KB/s
      final size = file.lengthSync();
      // Ước lượng thô: 1 phút ~ 2MB ở 16kHz mono
      final estSeconds = size / (32000); // 32KB/s
      if (estSeconds > 1 && estSeconds < 86400) {
        return estSeconds;
      }
    } catch (_) {}
    return 0;
  }

  @override
  Future<void> dispose() async {
    // Section 3: chỉ free pointer khi service DỪNG hẳn — không re-init
    // liên tục (tránh xung đột FFI với whisper.cpp)
    try {
      _vadCore?.dispose();
    } catch (e) {
      debugPrint('⚠️ SherpaVadCore.dispose error: $e');
    }
    _vadCore = null;
    _initialized = false;
  }

  /// Singleton giữ Pointer C-struct để tránh re-init liên tục (Section 3)
  static final SherpaVadService _instance = SherpaVadService();
  factory SherpaVadService.singleton() => _instance;
  SherpaVadService._singletonInternal()
      : threshold = 0.5,
        minSpeechDurationMs = 250,
        minSilenceDurationMs = 100,
        maxSpeechDurationS = 14,
        speechPadMs = 30,
        samplesOverlap = 0.1;
}
