// packages/in4up_stt/lib/tts/sherpa_piper_tts_core.dart
//
// SherpaPiperTtsCore — Piper TTS (FastSpeech2 + HiFiGAN, CPU-friendly)
// qua sherpa_onnx. PLAN-009 step "TTS VITS/Piper — offline hoàn toàn".
//
// API v1.13.4 VERIFY từ source k2-fsa/sherpa-onnx (tag v1.13.4) + ví dụ
// chính thức dart-api-examples/tts/bin/piper.dart:
//
//   OfflineTtsVitsModelConfig(model, tokens, dataDir)   // Piper = VITS config
//   OfflineTtsModelConfig(vits: ..., numThreads: N)
//   OfflineTtsConfig(model: ..., maxNumSenetences: N)
//   tts.generateWithConfig(text:, config:, [onProgress:]) -> Audio{samples, sampleRate}
//
// Convention file (khớp bộ model Piper trên local user):
//   <modelsFolder>/
//     espeak-ng-data/            ← thư mục phonemizer (DÙNG CHUNG)
//     calmwoman3688.onnx         ← model giọng
//     calmwoman3688.onnx.json    ← config (chứa audio.sample_rate)
//     calmwoman3688_tokens.txt   ← tokens
//
//   Một "giọng" = 1 bộ (name.onnx + name_tokens.txt).
//   <name>.onnx.json đọc để lấy sample_rate (fallback 22050 — chuẩn Piper).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../sherpa_bindings.dart';

/// Một giọng Piper phát hiện được trong thư mục model.
class PiperTtsVoice {
  final String name;
  final String modelPath;
  final String tokensPath;
  final String dataDir;
  final int sampleRate;

  const PiperTtsVoice({
    required this.name,
    required this.modelPath,
    required this.tokensPath,
    required this.dataDir,
    required this.sampleRate,
  });
}

/// Kết quả generate (PCM float32 mono [-1,1] + sample rate).
class PiperTtsAudio {
  final Float32List samples;
  final int sampleRate;

  const PiperTtsAudio({required this.samples, required this.sampleRate});
}

class SherpaPiperTtsCore {
  /// Thư mục model — đặt CÙNG quy ước với VAD (documents/...).
  /// Android: /sdcard/Android/data/<pkg>/documents/sherpa_piper_models/
  /// Windows: %LOCALAPPDATA%\<org>\<app>_documents/sherpa_piper_models/
  static const String modelsFolderName = 'sherpa_piper_models';
  static const String espeakDataFolder = 'espeak-ng-data';

  static const int defaultPiperSampleRate = 22050;

  sherpa.OfflineTts? _tts;
  PiperTtsVoice? _activeVoice;

  PiperTtsVoice? get activeVoice => _activeVoice;

  static Future<Directory> _modelsDir() async {
    Directory base;
    try {
      base = await getApplicationDocumentsDirectory();
    } catch (_) {
      base = await getApplicationSupportDirectory();
    }
    final dir = Directory(p.join(base.path, modelsFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Quét thư mục model → danh sách giọng (mỗi <name>.onnx có
  /// <name>_tokens.txt là một giọng; espeak-ng-data dùng chung).
  static Future<List<PiperTtsVoice>> discoverVoices() async {
    try {
      final dir = await _modelsDir();
      final dataDir = p.join(dir.path, espeakDataFolder);
      final dataOk = Directory(dataDir).existsSync();

      final voices = <PiperTtsVoice>[];
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        final fileName = p.basename(entity.path);
        if (!fileName.endsWith('.onnx')) continue;
        final name = fileName.substring(0, fileName.length - '.onnx'.length);

        final tokensPath = p.join(dir.path, '${name}_tokens.txt');
        if (!File(tokensPath).existsSync()) continue;

        final sampleRate = _readSampleRate(p.join(dir.path, '$name.onnx.json')) ??
            defaultPiperSampleRate;

        voices.add(PiperTtsVoice(
          name: name,
          modelPath: entity.path,
          tokensPath: tokensPath,
          dataDir: dataDir,
          sampleRate: sampleRate,
        ));
      }
      voices.sort((a, b) => a.name.compareTo(b.name));
      if (!dataOk) {
        debugPrint(
          '⚠️ SherpaPiperTtsCore: thiếu thư mục $espeakDataFolder trong '
          '${dir.path} — Piper cần phonemizer data',
        );
      }
      return voices;
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore.discoverVoices error: $e');
      return const [];
    }
  }

  /// sample_rate từ config Piper (<name>.onnx.json → audio.sample_rate)
  static int? _readSampleRate(String jsonPath) {
    try {
      final raw = File(jsonPath).readAsStringSync();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final audio = map['audio'];
      if (audio is Map<String, dynamic>) {
        final sr = audio['sample_rate'];
        if (sr is int && sr > 0) return sr;
      }
    } catch (_) {}
    return null;
  }

  /// Chọn giọng (tạo OfflineTts — pointer singleton, không re-init
  /// liên tục; đổi giọng mới mới tạo lại).
  Future<bool> selectVoice(String voiceName) async {
    final voices = await discoverVoices();
    PiperTtsVoice? voice;
    for (final v in voices) {
      if (v.name == voiceName) {
        voice = v;
        break;
      }
    }
    if (voice == null) {
      debugPrint('⚠️ SherpaPiperTtsCore: giọng không tồn tại: $voiceName');
      return false;
    }
    if (_activeVoice?.name == voiceName && _tts != null) return true;

    // Đổi giọng → free bản cũ (pointer cũ không dùng nữa)
    try {
      _tts?.free();
    } catch (_) {}
    _tts = null;

    try {
      ensureSherpaBindings();
      final modelConfig = sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: voice.modelPath,
          tokens: voice.tokensPath,
          dataDir: voice.dataDir,
        ),
        numThreads: 2,
        debug: kDebugMode,
      );
      _tts = sherpa.OfflineTts(
        sherpa.OfflineTtsConfig(
          model: modelConfig,
          maxNumSenetences: 100,
        ),
      );
      _activeVoice = voice;
      debugPrint('🎙️ SherpaPiperTtsCore: giọng "$voiceName" sẵn sàng '
          '(${voice.sampleRate}Hz)');
      return true;
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore.selectVoice lỗi: $e');
      _tts = null;
      _activeVoice = null;
      return false;
    }
  }

  /// Generate audio cho text (giọng hiện tại). Trả null nếu lỗi/
  /// chưa chọn giọng.
  Future<PiperTtsAudio?> generate({
    required String text,
    double speed = 1.0,
    int sid = 0,
  }) async {
    final tts = _tts;
    final voice = _activeVoice;
    if (tts == null || voice == null) return null;
    if (text.trim().isEmpty) return null;

    try {
      final genConfig = sherpa.OfflineTtsGenerationConfig(
        sid: sid,
        speed: speed <= 0 ? 1.0 : speed,
        silenceScale: 0.2,
      );
      final audio =
          tts.generateWithConfig(text: text, config: genConfig);
      if (audio.samples.isEmpty) return null;
      return PiperTtsAudio(
        samples: audio.samples,
        sampleRate: audio.sampleRate > 0
            ? audio.sampleRate
            : voice.sampleRate,
      );
    } catch (e) {
      debugPrint('⚠️ SherpaPiperTtsCore.generate lỗi: $e');
      return null;
    }
  }

  /// Encode PCM float32 mono → WAV bytes (16-bit PCM) — cho TtsCache/
  /// just_audio (TtsResult.audioData).
  static Uint8List encodeWavBytes(Float32List samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final buf = BytesBuilder();
    void writeAscii(String s) {
      for (final c in s.codeUnits) {
        buf.addByte(c);
      }
    }

    void writeU32(int v) {
      buf
        ..addByte(v & 0xFF)
        ..addByte((v >> 8) & 0xFF)
        ..addByte((v >> 16) & 0xFF)
        ..addByte((v >> 24) & 0xFF);
    }

    void writeU16(int v) {
      buf
        ..addByte(v & 0xFF)
        ..addByte((v >> 8) & 0xFF);
    }

    writeAscii('RIFF');
    writeU32(36 + dataSize);
    writeAscii('WAVE');
    writeAscii('fmt ');
    writeU32(16); // fmt chunk size
    writeU16(1); // PCM
    writeU16(1); // mono
    writeU32(sampleRate);
    writeU32(sampleRate * 2); // byte rate
    writeU16(2); // block align
    writeU16(16); // bits per sample
    writeAscii('data');
    writeU32(dataSize);
    for (final s in samples) {
      final v = (s * 32767).round().clamp(-32768, 32767);
      buf
        ..addByte(v & 0xFF)
        ..addByte((v >> 8) & 0xFF);
    }
    return buf.toBytes();
  }

  /// Giải phóng pointer — chỉ khi app dừng hẳn (pointer singleton).
  void dispose() {
    try {
      _tts?.free();
    } catch (_) {}
    _tts = null;
    _activeVoice = null;
  }
}
