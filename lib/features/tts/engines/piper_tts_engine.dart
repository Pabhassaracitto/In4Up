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
    if (voiceId != null && voiceId.isNotEmpty) return voiceId;
    final preferred = await PiperVoicePrefs.instance.voiceForLang(language);
    final voices = await SherpaPiperTtsCore.discoverVoices();
    if (voices.isEmpty) return null;
    if (preferred != null) {
      for (final v in voices) {
        if (v.name == preferred) return v.name;
      }
    }
    final want = PiperVoicePrefs.normalizeLang(language);
    if (want.isNotEmpty) {
      for (final v in voices) {
        final lang = SherpaPiperTtsCore.langFromVoiceName(v.name);
        if (lang.toLowerCase() == want.toLowerCase()) return v.name;
      }
      final short = want.split('-').first.toLowerCase();
      for (final v in voices) {
        final lang = SherpaPiperTtsCore.langFromVoiceName(v.name);
        if (lang.split('-').first.toLowerCase() == short) return v.name;
      }
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
      return TtsResult.failure(error: 'Chưa có giọng Piper', engine: this.name);
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
