// (bisect trigger 3)
// (bisect trigger 2)
// lib/features/tts/engines/piper_tts_engine.dart
//
// PiperTtsEngine — TTS offline Piper (FastSpeech2 + HiFiGAN) qua sherpa_onnx.
// Bọc SherpaPiperTtsCore (package in4up_stt) — PLAN-008/009 step
// "TTS VITS/Piper — offline hoàn toàn" (đãi cát tìm vàng: VAD ✓ → TTS ✓).
//
// Convention model (user push vào máy, KHÔNG đóng gói APK — tránh phình):
//   <app documents>/sherpa_piper_models/
//     espeak-ng-data/                 ← phonemizer data, DÙNG CHUNG
//     <voice>.onnx + <voice>_tokens.txt [+ <voice>.onnx.json]
//
// Language suy ra từ tên file giọng (quy ước Piper):
//   "en_US-lessac-medium"    → 'en-US'
//   "vi_VN-hcmu19b-medium"   → 'vi-VN'
//   "calmwoman3688" (không có locale) → universal (mọi language)
//
// Engine dạng BYTES: synthesize() trả WAV 16-bit mono → TtsService tự
// cache + phát qua just_audio (đường chuẩn, không cần speakDirect).
//
// Pointer FFI: SherpaPiperTtsCore giữ OfflineTts singleton — KHÔNG
// re-init liên tục, tránh xung đột FFI giữa whisper.cpp + sherpa_onnx.

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';

import 'tts_engine.dart';

class PiperTtsEngine implements TtsEngine {
  /// Core dùng chung (pointer singleton) — mọi instance engine chỉ là
  /// facade, state nằm ở đây.
  static final SherpaPiperTtsCore _core = SherpaPiperTtsCore();

  /// Prefix voiceId trong UI (khu biệt giọng Piper vs giọng online).
  static const String voiceIdPrefix = 'piper_';

  @override
  String get name => 'Piper (offline)';

  @override
  String get id => 'piper_tts';

  /// Piper chịu được câu dài (FastSpeech2 không giới hạn như TTS API).
  @override
  int get maxCharsPerRequest => 2000;

  @override
  List<String> get supportedLanguages => const [
        'vi-VN',
        'en-US',
        'en-GB',
        'zh-CN',
        'ja-JP',
        'de-DE',
        'es-ES',
        'fr-FR',
      ];

  /// Language từ tên file giọng Piper; '' = universal (không có locale).
  static String langFromVoiceName(String name) {
    final m = RegExp(r'^([a-z]{2})[_-]([A-Za-z]{2})(?:[-_].*)?$').firstMatch(name);
    if (m == null) return '';
    return '${m.group(1)}-${m.group(2)!.toUpperCase()}';
  }

  /// Chọn giọng: voiceId cụ thể (piper_<name>) → khớp language → universal.
  PiperTtsVoice? _pickVoice(
    List<PiperTtsVoice> voices,
    String? voiceId,
    String language,
  ) {
    if (voiceId != null) {
      if (!voiceId.startsWith(voiceIdPrefix)) return null; // giọng engine khác
      final target = voiceId.substring(voiceIdPrefix.length);
      for (final v in voices) {
        if (v.name == target) return v;
      }
      return null;
    }
    for (final v in voices) {
      if (langFromVoiceName(v.name) == language) return v;
    }
    for (final v in voices) {
      if (langFromVoiceName(v.name).isEmpty) return v;
    }
    return null;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return (await SherpaPiperTtsCore.discoverVoices()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final voices = await SherpaPiperTtsCore.discoverVoices();
      if (voices.isEmpty) {
        return TtsResult.failure(
          error:
              'Chưa có model Piper — push <voice>.onnx + <voice>_tokens.txt '
              '+ espeak-ng-data/ vào <documents>/sherpa_piper_models/',
          engine: name,
        );
      }

      final voice = _pickVoice(voices, voiceId, language);
      if (voice == null) {
        return TtsResult.failure(
          error: 'Không có giọng Piper khớp $language',
          engine: name,
        );
      }

      // selectVoice idempotent (giọng đang chọn = giọng này → trả ngay).
      if (!await _core.selectVoice(voice.name)) {
        return TtsResult.failure(
          error: 'Không load được model Piper "${voice.name}"',
          engine: name,
        );
      }

      final audio = await _core.generate(text: text, speed: speed);
      if (audio == null) {
        return TtsResult.failure(
          error: 'Piper không sinh được audio cho text này',
          engine: name,
        );
      }

      // pitch: Piper không hỗ trợ pitch control — bỏ qua (giữ API chung).
      final wav = SherpaPiperTtsCore.encodeWavBytes(
        audio.samples,
        audio.sampleRate,
      );
      sw.stop();
      return TtsResult.successBytes(
        data: wav,
        engine: name,
        responseTime: sw.elapsed,
      );
    } catch (e) {
      debugPrint('⚠️ PiperTtsEngine.synthesize: $e');
      return TtsResult.failure(error: '$e', engine: name);
    }
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    try {
      final voices = await SherpaPiperTtsCore.discoverVoices();
      final result = <TtsVoice>[];
      for (final v in voices) {
        final lang = langFromVoiceName(v.name);
        if (lang.isEmpty || lang == language) {
          result.add(TtsVoice(
            id: '${voiceIdPrefix}${v.name}',
            name: v.name,
            language: lang.isEmpty ? 'auto' : lang,
            gender: 'unknown',
            engine: name,
            isNeural: true,
          ));
        }
      }
      return result;
    } catch (e) {
      debugPrint('⚠️ PiperTtsEngine.getAvailableVoices: $e');
      return const [];
    }
  }
}
/// (bisect trigger)
