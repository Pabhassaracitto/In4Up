import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';

import '../../../services/offline_model_gate.dart';
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

  /// Lý do giọng Piper gần nhất bị từ chối (mã của bước khám giọng —
  /// PSRC-187), `null` nếu lần nạp gần nhất thành công.
  String? get lastVoiceProblem => _core.lastProblem;

  @override
  Future<bool> isAvailable() async {
    final voices = await SherpaPiperTtsCore.discoverVoices();
    final espeakReady = await SherpaPiperTtsCore.isEspeakReady();
    final plausible = voices.any(SherpaPiperTtsCore.isVoiceFilesPlausible);
    // AUDIT-1.21.0 #2 (cùng cụm model/offline với #7): một cửa đánh giá
    // duy nhất, có log để đối chiếu `adb logcat` trên máy thật.
    final verdict = assessOfflineModel(
      installed: voices.isNotEmpty && espeakReady,
      filesPlausible: plausible,
    );
    if (!verdict.canUse) {
      debugPrint('⛔ [TTS-NATIVE] Piper blocked — ${verdict.issue.name}: '
          'voices=${voices.length}, espeakReady=$espeakReady, '
          'plausible=$plausible');
    }
    return verdict.canUse;
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

  /// Giọng THẬT sẽ dùng cho [language] — PSRC-230: `null` nghĩa là KHÔNG có
  /// giọng Piper phù hợp, caller phải fallback engine khác thay vì đọc câu
  /// tiếng Anh bằng giọng tiếng Việt.
  ///
  /// [TtsService] gọi hàm này TRƯỚC khi tổng hợp để (a) biết chắc giọng nào
  /// đang đọc và (b) dùng đúng tên giọng đó làm một phần khoá cache.
  Future<String?> resolveVoiceName(String language, {String? voiceId}) =>
      _resolveVoiceName(language, voiceId);

  /// Ngôn ngữ của một giọng: ưu tiên metadata `<name>.onnx.json`
  /// (`language.code` / `espeak.voice` — PSRC-230), rồi mới đoán theo tên.
  static String _voiceLanguage(PiperTtsVoice voice) =>
      voice.languageCode.isNotEmpty
          ? voice.languageCode
          : SherpaPiperTtsCore.langFromVoiceName(voice.name);

  Future<String?> _resolveVoiceName(String language, String? voiceId) async {
    final voices = await SherpaPiperTtsCore.discoverVoices();
    if (voices.isEmpty) return null;

    // 1. Giọng người dùng chỉ định — CHỈ nhận khi đúng ngôn ngữ của câu.
    //    (Bản cũ nhận bừa ⇒ chọn giọng Việt trong setting là mọi câu tiếng
    //    Anh cũng đọc bằng giọng Việt.)
    final explicit = (voiceId ?? '').trim();
    if (explicit.isNotEmpty &&
        PiperVoicePrefs.isVoiceCompatibleWithLanguage(explicit, language)) {
      for (final v in voices) {
        if (v.name == explicit) return v.name;
      }
    }

    // 2. Giọng đã lưu cho CHÍNH ngôn ngữ này (không rơi về giọng ngôn ngữ
    //    khác — PSRC-230).
    final preferred = await PiperVoicePrefs.instance.voiceForLang(language);
    if (preferred != null) {
      for (final v in voices) {
        if (v.name == preferred) return v.name;
      }
    }

    final want = PiperVoicePrefs.normalizeLang(language);
    if (want.isNotEmpty) {
      // 3. Khớp chính xác locale (e.g. `vi-VN` == `vi-VN`)
      for (final v in voices) {
        if (_voiceLanguage(v).toLowerCase() == want.toLowerCase()) {
          return v.name;
        }
      }
      // 4. Khớp mã ngôn ngữ 2 ký tự (e.g. `vi` == `vi-VN`). `zh` KHÔNG dùng
      //    chéo: giản thể và phồn thể là hai mặt chữ.
      final short = want.split('-').first.toLowerCase();
      if (short != 'zh') {
        for (final v in voices) {
          final lang = _voiceLanguage(v);
          if (lang.isNotEmpty && lang.split('-').first.toLowerCase() == short) {
            return v.name;
          }
        }
      }
      // 5. Giọng chưa rõ ngôn ngữ (tên không có mã) — lựa chọn cuối, tốt hơn
      //    im lặng.
      for (final v in voices) {
        if (_voiceLanguage(v).isEmpty) return v.name;
      }

      // Không có giọng Piper phù hợp ⇒ null để TtsService fallback engine kế.
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
    // AUDIT-1.21.0 #2: chặn luôn cả đường gọi trực tiếp `synthesize()` (không
    // chỉ đường `TtsService._trySpeakPiper`). Một lần gọi native với model
    // chưa nạp là một lần có thể SIGSEGV ở C++ — Dart không catch được.
    if (!await isAvailable()) {
      return TtsResult.failure(
        error: 'Piper is not ready (missing .onnx model / espeak-ng-data)',
        // `name` là BIẾN CỤC BỘ khai báo ở dòng dưới ⇒ phải dùng `this.name`
        // (getter engine id), nếu không CFE báo "referenced before declared".
        engine: this.name,
      );
    }
    final name = await _resolveVoiceName(language, voiceId);
    if (name == null) {
      return TtsResult.failure(
        error: 'Chưa có giọng Piper cho $language',
        engine: this.name,
      );
    }
    // Marker cho `adb logcat` (AUDIT #2): nếu app vẫn văng ngay sau dòng này
    // thì crash nằm ở sherpa-onnx/ORT native, KHÔNG còn là Dart/plugin.
    try {
      final voices = await SherpaPiperTtsCore.discoverVoices();
      for (final v in voices) {
        if (v.name == name) {
          debugPrint('[TTS-NATIVE] selectVoice=$name '
              'onnx=${File(v.modelPath).lengthSync()}B '
              'tokens=${File(v.tokensPath).lengthSync()}B '
              'espeak=${await SherpaPiperTtsCore.isEspeakReady()} '
              'lang=$language');
          break;
        }
      }
    } catch (_) {}
    final ok = await _core.selectVoice(name);
    if (!ok) {
      // PSRC-187: lý do cụ thể từ bước khám giọng (thiếu file espeak, model
      // thiếu metadata sherpa-onnx, tokens sai…) thay cho câu đoán chung.
      final problem = _core.lastProblem ?? 'unknown';
      debugPrint('⛔ [TTS-NATIVE] Piper voice "$name" rejected: $problem');
      return TtsResult.failure(
        error: 'Piper voice "$name" cannot be loaded ($problem)',
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
