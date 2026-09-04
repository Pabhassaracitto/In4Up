import '../../../core/language/app_language.dart';
import '../../tts/language_detector.dart';

/// Which side of a bilingual item the learner recites.
enum MemorizeSide { source, target }

/// Recitation languages (Pali/Sanskrit + app catalog).
///
/// Kept out of [AppLanguageCatalog] so translation engines never see `PI`.
class RecitationLanguage {
  final String code;
  final String ttsLocale;
  final String sttCode;
  final String flag;
  final String labelEn;
  final String labelVi;

  const RecitationLanguage({
    required this.code,
    required this.ttsLocale,
    required this.sttCode,
    required this.flag,
    required this.labelEn,
    required this.labelVi,
  });

  String displayName(String locale) =>
      locale.toLowerCase().startsWith('vi') ? labelVi : labelEn;

  static const pali = RecitationLanguage(
    code: 'pi',
    ttsLocale: 'en-US',
    sttCode: 'en',
    flag: '🪷',
    labelEn: 'Pali',
    labelVi: 'Pali',
  );

  static const sanskrit = RecitationLanguage(
    code: 'sa',
    ttsLocale: 'en-US',
    sttCode: 'en',
    flag: '🕉️',
    labelEn: 'Sanskrit',
    labelVi: 'Sanskrit',
  );

  static RecitationLanguage get english =>
      _fromCatalog(AppLanguageCatalog.english);
  static RecitationLanguage get vietnamese =>
      _fromCatalog(AppLanguageCatalog.vietnamese);

  /// Compact picker: liturgical + common study languages.
  static List<RecitationLanguage> get pickerLanguages {
    const extraCodes = [
      'EN',
      'VI',
      'MY',
      'SI',
      'ZH',
      'TH',
      'HI',
      'FR',
      'DE',
      'JA',
      'KO',
      'KM',
      'LO',
      'TA',
      'BN',
    ];
    final list = <RecitationLanguage>[pali, sanskrit];
    final seen = <String>{'pi', 'sa'};
    for (final code in extraCodes) {
      final lang = fromCode(code);
      if (seen.add(lang.code)) list.add(lang);
    }
    return list;
  }

  static RecitationLanguage fromCode(String? raw) {
    final normalized = _normalize(raw);
    if (normalized == 'pi') return pali;
    if (normalized == 'sa') return sanskrit;
    final catalog = AppLanguageCatalog.maybeFromCode(normalized);
    if (catalog != null) return _fromCatalog(catalog);
    return english;
  }

  /// TTS locale for one utterance. Never keep a Vietnamese voice on
  /// English/Pali, and never keep an English voice on Vietnamese diacritics.
  static String speakLocale({
    required String declaredCode,
    required String text,
  }) {
    final declared = fromCode(declaredCode);
    final detected = detectCode(text);
    if (detected != null && _shouldOverride(declared.code, detected)) {
      return fromCode(detected).ttsLocale;
    }
    return declared.ttsLocale;
  }

  static String sttCodeFor(String declaredCode) => fromCode(declaredCode).sttCode;

  /// Best-effort identity of [text] (`pi`, `vi`, `en`, …).
  static String? detectCode(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    if (_paliHints.hasMatch(trimmed) && !_vietnameseHints.hasMatch(trimmed)) {
      return 'pi';
    }
    if (_vietnameseHints.hasMatch(trimmed)) return 'vi';

    final detected = LanguageDetector.detectLanguage(trimmed);
    return detected.shortCode.toLowerCase();
  }

  static RecitationLanguage _fromCatalog(AppLanguage language) {
    return RecitationLanguage(
      code: language.shortCode.toLowerCase(),
      ttsLocale: language.ttsLocale,
      sttCode: language.shortCode.toLowerCase(),
      flag: language.flag,
      labelEn: language.englishName,
      labelVi: language.vietnameseName,
    );
  }

  static String _normalize(String? raw) {
    if (raw == null) return 'en';
    final value = raw.trim().toLowerCase().replaceAll('_', '-');
    if (value.isEmpty || value == 'auto' || value == 'system') return 'en';
    if (value == 'pali' ||
        value == 'pli' ||
        value == 'pi-latn' ||
        value.startsWith('pi')) {
      return 'pi';
    }
    if (value == 'sanskrit' ||
        value == 'san' ||
        value == 'sa-deva' ||
        value.startsWith('sa')) {
      return 'sa';
    }
    if (value.startsWith('zh-tw') ||
        value.startsWith('zh-hant') ||
        value == 'zh-hk') {
      return 'zh-tw';
    }
    return value.split('-').first;
  }

  static bool _shouldOverride(String declared, String detected) {
    if (declared == detected) return false;
    // Pali/Sanskrit are spoken with an English-capable voice.
    if (_liturgicalLatin(declared) && _liturgicalLatin(detected)) return false;
    return true;
  }

  static bool _liturgicalLatin(String code) =>
      code == 'pi' || code == 'sa' || code == 'en';

  static final _paliHints = RegExp(
    r'[āīūṃṁṅñṭḍṇḷĀĪŪṂṀṄÑṬḌṆḶ]|'
    r'\b(dhamma|buddha|sa[nṅ]gha|sutta|bhikkhu|nibb[aā]na|metta|dukkha|'
    r'mano|gacch[aā]mi|sara[nṇ]a[mṃ])\b',
    caseSensitive: false,
  );

  static final _vietnameseHints = RegExp(
    r'[ăâđêôơưĂÂĐÊÔƠƯ]|[ạảấầẩẫậắằẳẵặẹẻếềểễệịỉọỏốồổỗộớờởỡợụủứừửữựỵỷỹ]',
  );
}
