// Curated Piper voices for in-app download.
// Catalog keys match https://huggingface.co/rhasspy/piper-voices
// (voices.json). Install prefers k2-fsa sherpa tar.bz2 (onnx+tokens+espeak),
// then HuggingFace onnx+json.

class PiperVoiceOffer {
  final String id;
  final String languageCode;
  final String languageLabelEn;
  final String quality;
  final String speaker;
  final String hfOnnxRel;
  final bool featured;
  final int approxSizeMB;

  const PiperVoiceOffer({
    required this.id,
    required this.languageCode,
    required this.languageLabelEn,
    required this.quality,
    required this.speaker,
    required this.hfOnnxRel,
    this.featured = false,
    this.approxSizeMB = 75,
  });

  String get hfOnnxUrl =>
      'https://huggingface.co/rhasspy/piper-voices/resolve/main/$hfOnnxRel';

  String get hfJsonUrl => '$hfOnnxUrl.json';

  static const hfTreeUrl =
      'https://huggingface.co/rhasspy/piper-voices/tree/main';
}

class PiperVoiceCatalog {
  PiperVoiceCatalog._();

  /// Surface first: VI, EN, ZH, HI. Sinhala is not in piper-voices (2026).
  static const List<String> priorityLanguageCodes = [
    'vi_VN',
    'en_US',
    'en_GB',
    'zh_CN',
    'hi_IN',
  ];

  static const List<PiperVoiceOffer> all = [
    PiperVoiceOffer(
      id: 'vi_VN-vais1000-medium',
      languageCode: 'vi_VN',
      languageLabelEn: 'Vietnamese',
      quality: 'medium',
      speaker: 'vais1000',
      hfOnnxRel: 'vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'vi_VN-25hours_single-medium',
      languageCode: 'vi_VN',
      languageLabelEn: 'Vietnamese',
      quality: 'medium',
      speaker: '25hours_single',
      hfOnnxRel:
          'vi/vi_VN/25hours_single/medium/vi_VN-25hours_single-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'en_US-lessac-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'lessac',
      hfOnnxRel: 'en/en_US/lessac/medium/en_US-lessac-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'en_US-libritts_r-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'libritts_r',
      hfOnnxRel: 'en/en_US/libritts_r/medium/en_US-libritts_r-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'en_US-amy-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'amy',
      hfOnnxRel: 'en/en_US/amy/medium/en_US-amy-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'en_US-ryan-medium',
      languageCode: 'en_US',
      languageLabelEn: 'English (US)',
      quality: 'medium',
      speaker: 'ryan',
      hfOnnxRel: 'en/en_US/ryan/medium/en_US-ryan-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'en_GB-alan-medium',
      languageCode: 'en_GB',
      languageLabelEn: 'English (UK)',
      quality: 'medium',
      speaker: 'alan',
      hfOnnxRel: 'en/en_GB/alan/medium/en_GB-alan-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'en_GB-alba-medium',
      languageCode: 'en_GB',
      languageLabelEn: 'English (UK)',
      quality: 'medium',
      speaker: 'alba',
      hfOnnxRel: 'en/en_GB/alba/medium/en_GB-alba-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'zh_CN-huayan-medium',
      languageCode: 'zh_CN',
      languageLabelEn: 'Chinese (Mandarin)',
      quality: 'medium',
      speaker: 'huayan',
      hfOnnxRel: 'zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'hi_IN-pratham-medium',
      languageCode: 'hi_IN',
      languageLabelEn: 'Hindi',
      quality: 'medium',
      speaker: 'pratham',
      hfOnnxRel: 'hi/hi_IN/pratham/medium/hi_IN-pratham-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'hi_IN-rohan-medium',
      languageCode: 'hi_IN',
      languageLabelEn: 'Hindi',
      quality: 'medium',
      speaker: 'rohan',
      hfOnnxRel: 'hi/hi_IN/rohan/medium/hi_IN-rohan-medium.onnx',
      featured: true,
    ),
    PiperVoiceOffer(
      id: 'fr_FR-siwis-medium',
      languageCode: 'fr_FR',
      languageLabelEn: 'French',
      quality: 'medium',
      speaker: 'siwis',
      hfOnnxRel: 'fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'de_DE-thorsten-medium',
      languageCode: 'de_DE',
      languageLabelEn: 'German',
      quality: 'medium',
      speaker: 'thorsten',
      hfOnnxRel: 'de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'es_ES-sharvard-medium',
      languageCode: 'es_ES',
      languageLabelEn: 'Spanish',
      quality: 'medium',
      speaker: 'sharvard',
      hfOnnxRel: 'es/es_ES/sharvard/medium/es_ES-sharvard-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'ja_JP-tsuida-medium',
      languageCode: 'ja_JP',
      languageLabelEn: 'Japanese',
      quality: 'medium',
      speaker: 'tsuida',
      hfOnnxRel: 'ja/ja_JP/tsuida/medium/ja_JP-tsuida-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'th_TH-thai_female-medium',
      languageCode: 'th_TH',
      languageLabelEn: 'Thai',
      quality: 'medium',
      speaker: 'thai_female',
      hfOnnxRel: 'th/th_TH/thai_female/medium/th_TH-thai_female-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'ar_JO-kareem-medium',
      languageCode: 'ar_JO',
      languageLabelEn: 'Arabic',
      quality: 'medium',
      speaker: 'kareem',
      hfOnnxRel: 'ar/ar_JO/kareem/medium/ar_JO-kareem-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'bn_BD-google-medium',
      languageCode: 'bn_BD',
      languageLabelEn: 'Bengali',
      quality: 'medium',
      speaker: 'google',
      hfOnnxRel: 'bn/bn_BD/google/medium/bn_BD-google-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'nl_NL-mls-medium',
      languageCode: 'nl_NL',
      languageLabelEn: 'Dutch',
      quality: 'medium',
      speaker: 'mls',
      hfOnnxRel: 'nl/nl_NL/mls/medium/nl_NL-mls-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'pl_PL-darkman-medium',
      languageCode: 'pl_PL',
      languageLabelEn: 'Polish',
      quality: 'medium',
      speaker: 'darkman',
      hfOnnxRel: 'pl/pl_PL/darkman/medium/pl_PL-darkman-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'pt_BR-faber-medium',
      languageCode: 'pt_BR',
      languageLabelEn: 'Portuguese (BR)',
      quality: 'medium',
      speaker: 'faber',
      hfOnnxRel: 'pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'ru_RU-irina-medium',
      languageCode: 'ru_RU',
      languageLabelEn: 'Russian',
      quality: 'medium',
      speaker: 'irina',
      hfOnnxRel: 'ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'uk_UA-ukrainian_tts-medium',
      languageCode: 'uk_UA',
      languageLabelEn: 'Ukrainian',
      quality: 'medium',
      speaker: 'ukrainian_tts',
      hfOnnxRel:
          'uk/uk_UA/ukrainian_tts/medium/uk_UA-ukrainian_tts-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'it_IT-paola-medium',
      languageCode: 'it_IT',
      languageLabelEn: 'Italian',
      quality: 'medium',
      speaker: 'paola',
      hfOnnxRel: 'it/it_IT/paola/medium/it_IT-paola-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'ko_KR-kss-medium',
      languageCode: 'ko_KR',
      languageLabelEn: 'Korean',
      quality: 'medium',
      speaker: 'kss',
      hfOnnxRel: 'ko/ko_KR/kss/medium/ko_KR-kss-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'tr_TR-dfki-medium',
      languageCode: 'tr_TR',
      languageLabelEn: 'Turkish',
      quality: 'medium',
      speaker: 'dfki',
      hfOnnxRel: 'tr/tr_TR/dfki/medium/tr_TR-dfki-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'sv_SE-nst-medium',
      languageCode: 'sv_SE',
      languageLabelEn: 'Swedish',
      quality: 'medium',
      speaker: 'nst',
      hfOnnxRel: 'sv/sv_SE/nst/medium/sv_SE-nst-medium.onnx',
    ),
    PiperVoiceOffer(
      id: 'fa_IR-gyro-medium',
      languageCode: 'fa_IR',
      languageLabelEn: 'Persian',
      quality: 'medium',
      speaker: 'gyro',
      hfOnnxRel: 'fa/fa_IR/gyro/medium/fa_IR-gyro-medium.onnx',
    ),
  ];

  static List<PiperVoiceOffer> featured() =>
      all.where((v) => v.featured).toList(growable: false);

  static List<PiperVoiceOffer> more() =>
      all.where((v) => !v.featured).toList(growable: false);

  static PiperVoiceOffer? byId(String id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return null;
  }
}
