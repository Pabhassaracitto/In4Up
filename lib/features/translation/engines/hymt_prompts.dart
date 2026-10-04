/// Prompt templates cho Tencent HY-MT1.5 (không system prompt).
/// ZH↔XX dùng tiếng Trung; các cặp khác dùng tiếng Anh.
class HyMtPrompts {
  HyMtPrompts._();

  static const supported = <String>{
    'ZH', 'ZH-HANT', 'ZH-TW', 'EN', 'FR', 'PT', 'ES', 'JA', 'TR', 'RU',
    'AR', 'KO', 'TH', 'IT', 'DE', 'VI', 'MS', 'ID', 'TL', 'HI', 'PL',
    'CS', 'NL', 'KM', 'MY', 'FA', 'GU', 'UR', 'TE', 'MR', 'HE', 'BN',
    'TA', 'UK', 'BO', 'KK', 'MN', 'UG', 'YUE',
  };

  static String normalizeCode(String raw) {
    var c = raw.trim().replaceAll('_', '-').toUpperCase();
    if (c == 'ZH-CN' || c == 'ZH-HANS' || c == 'CN') return 'ZH';
    if (c == 'ZH-TW' || c == 'ZH-HK' || c == 'ZH-HANT') return 'ZH-HANT';
    if (c.contains('-')) c = c.split('-').first;
    return c;
  }

  static bool supports(String code) => supported.contains(normalizeCode(code));

  static bool involvesChinese(String a, String b) {
    final x = normalizeCode(a);
    final y = normalizeCode(b);
    return x == 'ZH' || x == 'ZH-HANT' || x == 'YUE' ||
        y == 'ZH' || y == 'ZH-HANT' || y == 'YUE';
  }

  static String languageDisplayName(String code, {required bool chinese}) {
    final n = normalizeCode(code);
    const en = {
      'ZH': 'Chinese',
      'ZH-HANT': 'Traditional Chinese',
      'EN': 'English',
      'FR': 'French',
      'PT': 'Portuguese',
      'ES': 'Spanish',
      'JA': 'Japanese',
      'TR': 'Turkish',
      'RU': 'Russian',
      'AR': 'Arabic',
      'KO': 'Korean',
      'TH': 'Thai',
      'IT': 'Italian',
      'DE': 'German',
      'VI': 'Vietnamese',
      'MS': 'Malay',
      'ID': 'Indonesian',
      'TL': 'Filipino',
      'HI': 'Hindi',
      'PL': 'Polish',
      'CS': 'Czech',
      'NL': 'Dutch',
      'KM': 'Khmer',
      'MY': 'Burmese',
      'FA': 'Persian',
      'GU': 'Gujarati',
      'UR': 'Urdu',
      'TE': 'Telugu',
      'MR': 'Marathi',
      'HE': 'Hebrew',
      'BN': 'Bengali',
      'TA': 'Tamil',
      'UK': 'Ukrainian',
      'BO': 'Tibetan',
      'KK': 'Kazakh',
      'MN': 'Mongolian',
      'UG': 'Uyghur',
      'YUE': 'Cantonese',
    };
    const zh = {
      'ZH': '中文',
      'ZH-HANT': '繁体中文',
      'EN': '英语',
      'FR': '法语',
      'PT': '葡萄牙语',
      'ES': '西班牙语',
      'JA': '日语',
      'TR': '土耳其语',
      'RU': '俄语',
      'AR': '阿拉伯语',
      'KO': '韩语',
      'TH': '泰语',
      'IT': '意大利语',
      'DE': '德语',
      'VI': '越南语',
      'MS': '马来语',
      'ID': '印尼语',
      'TL': '菲律宾语',
      'HI': '印地语',
      'PL': '波兰语',
      'CS': '捷克语',
      'NL': '荷兰语',
      'KM': '高棉语',
      'MY': '缅甸语',
      'FA': '波斯语',
      'GU': '古吉拉特语',
      'UR': '乌尔都语',
      'TE': '泰卢固语',
      'MR': '马拉地语',
      'HE': '希伯来语',
      'BN': '孟加拉语',
      'TA': '泰米尔语',
      'UK': '乌克兰语',
      'BO': '藏语',
      'KK': '哈萨克语',
      'MN': '蒙古语',
      'UG': '维吾尔语',
      'YUE': '粤语',
    };
    return (chinese ? zh : en)[n] ?? n;
  }

  static String build({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) {
    final chinese = involvesChinese(sourceLang, targetLang);
    final targetName = languageDisplayName(targetLang, chinese: chinese);
    if (chinese) {
      return '将以下文本翻译为$targetName，注意只需要输出翻译后的结果，不要额外解释：\n\n$text';
    }
    return 'Translate the following segment into $targetName, without additional explanation.\n\n$text';
  }

  /// Bỏ rác chat-template / lời giải thích nếu model vẫn nhả thêm.
  static String cleanOutput(String raw, String sourceText) {
    var out = raw.trim();
    const fences = ['</s>', '<|im_end|>', '<|end|>', '<end>'];
    for (final f in fences) {
      final i = out.indexOf(f);
      if (i >= 0) out = out.substring(0, i).trim();
    }
    // Nếu model lặp lại prompt, lấy phần sau source.
    final src = sourceText.trim();
    if (src.length > 8 && out.contains(src)) {
      final i = out.lastIndexOf(src);
      if (i >= 0 && i + src.length < out.length) {
        out = out.substring(i + src.length).trim();
      }
    }
    const prefixes = [
      'Translation:',
      'Translated text:',
      '译文：',
      '翻译：',
    ];
    for (final p in prefixes) {
      if (out.startsWith(p)) {
        out = out.substring(p.length).trim();
      }
    }
    return out.trim();
  }
}
