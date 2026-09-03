import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';

import '../piper_voice_prefs.dart';
import 'tts_engine.dart';

/// Piper neural TTS (sherpa-onnx VITS) — offline, chọn giọng theo ngôn ngữ.
class PiperTtsEngine implements TtsEngine {
  PiperTtsEngine._();
  static final PiperTtsEngine instance = PiperTtsEngine._();

  final SherpaPiperTtsCore _core = SherpaPiperTtsCore();

  @override
  String get name => 'Piper (offline neural)';

  @override
  String get id => 'piper_tts';

  @override
  int get maxCharsPerRequest => 400;

  @override
  List<String> get supportedLanguages => const [
        'en-US',
        'en-GB',
        'vi-VN',
        'hi-IN',
        'zh-CN',
        'de-DE',
        'fr-FR',
        'es-ES',
      ];

  @override
  Future<bool> isAvailable() async {
    final voices = await SherpaPiperTtsCore.discoverVoices();
    return voices.isNotEmpty;
  }

  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    final voices = await SherpaPiperTtsCore.discoverVoices();
    final want = PiperVoicePrefs.normalizeLang(language);
    return voices
        .where((v) {
          final lang = SherpaPiperTtsCore.langFromVoiceName(v.name);
          if (want.isEmpty) return true;
          if (lang.isEmpty) return true;
          return lang.toLowerCase() == want.toLowerCase() ||
              lang.split('-').first.toLowerCase() ==
                  want.split('-').first.toLowerCase();
        })
        .map(
          (v) => TtsVoice(
            id: v.name,
            name: v.name,
            language: SherpaPiperTtsCore.langFromVoiceName(v.name).isEmpty
                ? language
                : SherpaPiperTtsCore.langFromVoiceName(v.name),
            gender: 'neural',
            engine: id,
            isNeural: true,
          ),
        )
        .toList();
  }

  Future<String?> _resolveVoiceName(String language, String? voiceId) async {
    final voices = await SherpaPiperTtsCore.discoverVoices();
    if (voices.isEmpty) return null;

    if (voiceId != null && voiceId.isNotEmpty) {
      for (final v in voices) {
        if (v.name == voiceId) return v.name;
      }
    }

    final preferred = await PiperVoicePrefs.instance.voiceForLang(language);
    if (preferred != null) {
      for (final v in voices) {
        if (v.name == preferred) return v.name;
      }
    }

    final want = PiperVoicePrefs.normalizeLang(language);
    if (want.isNotEmpty) {
      // 1. Khớp chính xác locale (e.g. `vi-VN` == `vi-VN`)
      for (final v in voices) {
        final lang = SherpaPiperTtsCore.langFromVoiceName(v.name);
        if (lang.toLowerCase() == want.toLowerCase()) return v.name;
      }
      // 2. Khớp mã ngôn ngữ 2 ký tự (e.g. `vi` == `vi`)
      final short = want.split('-').first.toLowerCase();
      for (final v in voices) {
        final lang = SherpaPiperTtsCore.langFromVoiceName(v.name);
        if (lang.isNotEmpty && lang.split('-').first.toLowerCase() == short) {
          return v.name;
        }
      }
      // 3. Fallback: nếu có voice không xác định locale (universal)
      for (final v in voices) {
        final lang = SherpaPiperTtsCore.langFromVoiceName(v.name);
        if (lang.isEmpty) return v.name;
      }

      // Không tìm thấy giọng Piper phù hợp với ngôn ngữ này → trả null để fallback sang engine khác
      return null;
    }

    return voices.first.name;
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    final name = await _resolveVoiceName(language, voiceId);
    if (name == null) {
      return TtsResult.failure(
        error: 'Chưa có giọng Piper cho $language',
        engine: this.name,
      );
    }
    final ok = await _core.selectVoice(name);
    if (!ok) {
      return TtsResult.failure(
        error: 'Không nạp được giọng Piper $name (thiếu espeak-ng-data?)',
        engine: name,
      );
    }
    final audio = await _core.generate(text: text, speed: speed);
    if (audio == null || audio.samples.isEmpty) {
      return TtsResult.failure(error: 'Piper không tạo được audio', engine: name);
    }
    final wav = SherpaPiperTtsCore.encodeWavBytes(
      audio.samples,
      audio.sampleRate,
    );
    return TtsResult.successBytes(data: wav, engine: name);
  }
}
