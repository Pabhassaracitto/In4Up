import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/tts/piper_voice_catalog.dart';

/// Bản sao NHỎ của `voices.json` (huggingface.co/rhasspy/piper-voices, khảo
/// sát 2026-11-19) để test offline: mọi id trong catalog phải có thật. Các id
/// từng có trong catalog cũ nhưng KHÔNG còn: ja_JP-tsuida-medium,
/// th_TH-thai_female-medium, vi_VN-25hours_single-medium.
const Set<String> _verifiedVoiceIds = {
  'vi_VN-vais1000-medium',
  'vi_VN-25hours_single-low',
  'vi_VN-vivos-x_low',
  'en_US-lessac-medium',
  'en_US-libritts_r-medium',
  'en_US-amy-medium',
  'en_US-ryan-medium',
  'en_GB-alan-medium',
  'en_GB-alba-medium',
  'en_GB-cori-medium',
  'zh_CN-huayan-medium',
  'zh_CN-chaowen-medium',
  'zh_CN-xiao_ya-medium',
  'zh_CN-huayan-x_low',
  'hi_IN-pratham-medium',
  'hi_IN-priyamvada-medium',
  'hi_IN-rohan-medium',
  'ja_JP-hi_fi_captain-medium',
  'th_TH-tsync2-medium',
  'fr_FR-siwis-medium',
  'de_DE-thorsten-medium',
  'es_ES-sharvard-medium',
  'ar_JO-kareem-medium',
  'bn_BD-google-medium',
  'nl_NL-mls-medium',
  'pl_PL-darkman-medium',
  'pt_BR-faber-medium',
  'ru_RU-irina-medium',
  'uk_UA-ukrainian_tts-medium',
  'it_IT-paola-medium',
  'ko_KR-kss-medium',
  'tr_TR-dfki-medium',
  'sv_SE-nst-medium',
  'fa_IR-gyro-medium',
};

void main() {
  test('priority languages are featured first', () {
    final featured = PiperVoiceCatalog.featured();
    expect(featured.any((v) => v.languageCode == 'vi_VN'), isTrue);
    expect(featured.any((v) => v.languageCode.startsWith('en_')), isTrue);
    expect(featured.any((v) => v.languageCode == 'zh_CN'), isTrue);
    expect(featured.any((v) => v.languageCode == 'hi_IN'), isTrue);
    expect(featured.any((v) => v.languageCode == 'ja_JP'), isTrue);
    expect(featured.any((v) => v.languageCode == 'th_TH'), isTrue);
    // Sri Lanka KHÔNG phải mã ngôn ngữ; không có giọng si/ta trong Piper.
    expect(featured.any((v) => v.languageCode.startsWith('si')), isFalse);
    expect(PiperVoiceCatalog.all.any((v) => v.languageCode.startsWith('ta')),
        isFalse);
  });

  test('ids are unique and match the verified HuggingFace voices.json', () {
    final ids = PiperVoiceCatalog.all.map((v) => v.id).toSet();
    expect(ids.length, PiperVoiceCatalog.all.length);
    expect(ids.difference(_verifiedVoiceIds), isEmpty,
        reason: 'Model không có thật trên piper-voices: '
            '${ids.difference(_verifiedVoiceIds)}');
    for (final v in PiperVoiceCatalog.all) {
      expect(v.hfOnnxRel.endsWith('.onnx'), isTrue);
      expect(v.hfOnnxUrl.contains('rhasspy/piper-voices'), isTrue);
      expect(v.hfJsonUrl.endsWith('.onnx.json'), isTrue);
      expect(PiperVoiceCatalog.byId(v.id), same(v));
    }
  });

  test('every priority language has multiple native voice options', () {
    for (final code in PiperVoiceCatalog.priorityLanguageCodes) {
      final voices = PiperVoiceCatalog.all
          .where((v) => v.languageCode == code)
          .toList();
      if (code == 'ja_JP' || code == 'th_TH') {
        expect(voices.length, greaterThanOrEqualTo(1),
            reason: '$code: Piper chỉ có 1 giọng bản xứ');
      } else {
        expect(voices.length, greaterThanOrEqualTo(3), reason: '$code');
      }
    }
  });

  test('grouping keeps priority order and unavailable languages are honest', () {
    final grouped = PiperVoiceCatalog.groupByLanguage(
      PiperVoiceCatalog.featured(),
      languageCodes: PiperVoiceCatalog.priorityLanguageCodes,
    );
    expect(grouped.keys.toList(), PiperVoiceCatalog.priorityLanguageCodes);
    expect(
      PiperVoiceCatalog.unavailableLanguages.map((v) => v.languageCode),
      containsAll(<String>['my_MM', 'si_LK', 'ta_LK']),
    );
  });

  test('show-more list is non-empty', () {
    expect(PiperVoiceCatalog.more(), isNotEmpty);
  });
}
