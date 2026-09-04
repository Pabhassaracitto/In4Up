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

  /// Language từ tên file giọng (quy ước Piper `xx_XX-...` hoặc prefix `vits-piper-xx_XX-...`);
  /// Tự động bóc tách prefix và nhận diện cả các tên model phổ biến (vi_VN, 25hours, vais1000, libritts...).
  /// Trả về BCP-47 chuẩn (e.g. `vi-VN`, `en-US`) hoặc `''` nếu không nhận diện được.
  static String langFromVoiceName(String name) {
    var clean = name.trim();
    if (clean.toLowerCase().endsWith('.onnx')) {
      clean = clean.substring(0, clean.length - '.onnx'.length);
    }

    // Bóc tách prefix thường gặp trong sherpa-onnx / piper bundles
    const prefixes = [
      'sherpa-onnx-vits-piper-',
      'sherpa_onnx_vits_piper_',
      'sherpa-onnx-vits-',
      'sherpa_onnx_vits_',
      'sherpa-onnx-',
      'sherpa_onnx_',
      'vits-piper-',
      'vits_piper_',
      'vits-vits-piper-',
      'vits-',
      'vits_',
      'piper-',
      'piper_',
    ];
    for (final pfx in prefixes) {
      if (clean.toLowerCase().startsWith(pfx)) {
        clean = clean.substring(pfx.length);
        break;
      }
    }

    // 1. Chuẩn xx_XX hoặc xx-XX ở đầu tên (e.g. `vi_VN-25hours`, `en_US-libritts`)
    final mStandard =
        RegExp(r'^([a-z]{2})[_-]([A-Za-z]{2})(?:[-_].*)?$', caseSensitive: false)
            .firstMatch(clean);
    if (mStandard != null) {
      return '${mStandard.group(1)!.toLowerCase()}-${mStandard.group(2)!.toUpperCase()}';
    }

    // 2. Chuẩn xx_... hoặc xx-... ở đầu tên (e.g. `vi_25hours`, `vi_vais1000`, `en_libritts`)
    final mBare = RegExp(r'^([a-z]{2})[-_].*$', caseSensitive: false).firstMatch(clean);
    if (mBare != null) {
      final code = mBare.group(1)!.toLowerCase();
      switch (code) {
        case 'vi':
          return 'vi-VN';
        case 'en':
          return 'en-US';
        case 'zh':
          return 'zh-CN';
        case 'fr':
          return 'fr-FR';
        case 'de':
          return 'de-DE';
        case 'es':
          return 'es-ES';
        case 'hi':
          return 'hi-IN';
        case 'ja':
          return 'ja-JP';
        case 'ko':
          return 'ko-KR';
        case 'th':
          return 'th-TH';
        case 'my':
          return 'my-MM';
        case 'km':
          return 'km-KH';
        case 'lo':
          return 'lo-LA';
        case 'si':
          return 'si-LK';
        case 'pi':
          return 'pi-IN';
        case 'sa':
          return 'sa-IN';
        case 'ta':
          return 'ta-IN';
        case 'bn':
          return 'bn-IN';
      }
    }

    // 3. Quét từ khóa ngôn ngữ / tên model phổ biến trong toàn bộ tên
    final lower = clean.toLowerCase();
    if (lower.contains('vietnamese') ||
        lower.contains('viettts') ||
        lower.contains('vais1000') ||
        lower.contains('25hours') ||
        lower.contains('vipsound') ||
        lower.contains('vi_vn') ||
        lower.contains('vi-vn')) {
      return 'vi-VN';
    }
    if (lower.contains('en_gb') || lower.contains('en-gb') || lower.contains('british')) {
      return 'en-GB';
    }
    if (lower.contains('english') ||
        lower.contains('libritts') ||
        lower.contains('lessac') ||
        lower.contains('alan') ||
        lower.contains('amy') ||
        lower.contains('ryan') ||
        lower.contains('en_us') ||
        lower.contains('en-us')) {
      return 'en-US';
    }
    if (lower.contains('french') || lower.contains('francais') || lower.contains('fr_fr') || lower.contains('fr-fr')) {
      return 'fr-FR';
    }
    if (lower.contains('german') || lower.contains('deutsch') || lower.contains('de_de') || lower.contains('de-de')) {
      return 'de-DE';
    }
    if (lower.contains('spanish') || lower.contains('espanol') || lower.contains('es_es') || lower.contains('es-es')) {
      return 'es-ES';
    }
    if (lower.contains('hindi') || lower.contains('hi_in') || lower.contains('hi-in')) {
      return 'hi-IN';
    }
    if (lower.contains('chinese') || lower.contains('mandarin') || lower.contains('zh_cn') || lower.contains('zh-cn') || lower.contains('cmn')) {
      return 'zh-CN';
    }
    if (lower.contains('japanese') || lower.contains('nihongo') || lower.contains('ja_jp') || lower.contains('ja-jp')) {
      return 'ja-JP';
    }
    if (lower.contains('korean') || lower.contains('ko_kr') || lower.contains('ko-kr')) {
      return 'ko-KR';
    }
    if (lower.contains('thai') || lower.contains('th_th') || lower.contains('th-th')) {
      return 'th-TH';
    }
    if (lower.contains('pali') || lower.contains('pli')) {
      return 'pi-IN';
    }
    if (lower.contains('sanskrit') || lower.contains('san')) {
      return 'sa-IN';
    }

    return '';
  }

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

  /// Quét thư mục model → danh sách giọng.
  ///
  /// Hỗ trợ 2 layout:
  /// 1. **rhasspy/user**: `<name>.onnx` + `<name>_tokens.txt`
  ///    [+ `<name>.onnx.json` chứa audio.sample_rate]
  /// 2. **bundle k2-fsa chính thức** (vits-piper-*.tar.bz2):
  ///    `<name>.onnx` + `tokens.txt` DÙNG CHUNG + `espeak-ng-data/`
  ///    (không có .onnx.json — fallback 22050Hz chuẩn Piper)
  static Future<List<PiperTtsVoice>> discoverVoices() async {
    try {
      final dir = await _modelsDir();
      final dataDir = p.join(dir.path, espeakDataFolder);
      final phontab = File(p.join(dataDir, 'phontab'));
      final dataOk = phontab.existsSync() && phontab.lengthSync() > 64;

      final files = dir.listSync(followLinks: true);
      final onnxFiles = <File>[];
      for (final entity in files) {
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.onnx') && !lower.endsWith('.onnx.json')) {
          final f = File(entity.path);
          if (f.existsSync()) onnxFiles.add(f);
        }
      }
      // tokens.txt dùng chung chỉ hợp lệ khi có ĐÚNG MỘT onnx
      // (tránh gán nhầm tokens của giọng khác).
      final sharedTokens = File(p.join(dir.path, 'tokens.txt'));
      final sharedTokensUsable =
          sharedTokens.existsSync() && onnxFiles.length == 1;

      final voices = <PiperTtsVoice>[];
      for (final file in onnxFiles) {
        final fileName = p.basename(file.path);
        final name =
            fileName.substring(0, fileName.length - '.onnx'.length);

        String? tokensPath;
        final perNameTokens = p.join(dir.path, '${name}_tokens.txt');
        if (File(perNameTokens).existsSync()) {
          tokensPath = perNameTokens;
        } else if (sharedTokensUsable) {
          tokensPath = sharedTokens.path;
        }
        if (tokensPath == null) continue;

        final sampleRate =
            _readSampleRate(p.join(dir.path, '$name.onnx.json')) ??
                defaultPiperSampleRate;

        voices.add(PiperTtsVoice(
          name: name,
          modelPath: file.path,
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
