// lib/features/translation/engines/llm_mt_prompts.dart
//
// Prompt dịch LLM (WP3/API-004) + lớp làm sạch output — THUẦN Dart
// (không Flutter/IO), test bằng `flutter test` như hymt_prompts.
//
// Hợp đồng với TranslationService: glossary chuyên ngữ chạy TRƯỚC engine
// nên text đầu vào có thể chứa slot `__G{n}__` — prompt BẮT model giữ
// nguyên slot, output KHÔNG được chứa giải thích/giải nghĩa thêm.

/// Slot glossary `__G{n}__` (n = số thứ tự placeholder do tầng chuyên ngữ
/// sinh). Regex dùng chung cho prompt-engine + test.
final RegExp llMtSlotPattern = RegExp(r'__G(\d+)__');

class LlmMtPrompts {
  LlmMtPrompts._();

  /// Nhiệt độ thấp — dịch là việc XÁC ĐỊNH, không "sáng tạo"
  /// (0.0 bị một số server từ chối nên lấy 0.1).
  static const double temperature = 0.1;

  /// Tên ngôn ngữ cho prompt — phủ 26 locale trong catalog app
  /// (AppLanguageCatalog). Code lạ → trả nguyên code (model vẫn hiểu
  /// "VI"/"EN"); không đoán tên sai.
  static const Map<String, String> _languageNames = <String, String>{
    'AR': 'Arabic',
    'BN': 'Bengali',
    'BO': 'Tibetan',
    'DE': 'German',
    'EN': 'English',
    'ES': 'Spanish',
    'FR': 'French',
    'HI': 'Hindi',
    'ID': 'Indonesian',
    'IT': 'Italian',
    'JA': 'Japanese',
    'KM': 'Khmer',
    'KO': 'Korean',
    'LO': 'Lao',
    'MN': 'Mongolian',
    'MR': 'Marathi',
    'MY': 'Burmese',
    'PT': 'Portuguese',
    'RU': 'Russian',
    'SI': 'Sinhala',
    'TA': 'Tamil',
    'TE': 'Telugu',
    'TH': 'Thai',
    'VI': 'Vietnamese',
    'ZH': 'Chinese (Simplified)',
    'ZH-TW': 'Chinese (Traditional)',
  };

  static String normalizeCode(String raw) =>
      raw.trim().replaceAll('_', '-').toUpperCase();

  /// Tên hiển thị của [code] trong prompt (fallback: code gốc).
  static String languageDisplayName(String code) =>
      _languageNames[normalizeCode(code)] ?? normalizeCode(code);

  /// System prompt — hợp đồng nghiêm ngặt (AT WP3):
  /// "chỉ dịch, không giải thích, giữ nguyên chỗ trống `__G{n}__`".
  static String buildSystemPrompt({
    required String targetLang,
    String sourceLang = 'auto',
  }) {
    final target = languageDisplayName(targetLang);
    final buffer = StringBuffer()
      ..writeln('You are a professional translation engine.')
      ..writeln('Translate the user message into $target.')
      ..writeln('Rules (MUST follow):')
      ..writeln(
          '- Output ONLY the translated text. No explanation, no notes, '
          'no pronunciation, no quotes around the answer.')
      ..writeln('- Do not add, remove, or summarize content.')
      ..writeln(
          '- Placeholders that look like __G1__ or __G23__ are protected '
          'terms. Copy them EXACTLY as they are, character for character, '
          'at the matching position in the translation. Never translate, '
          'rename, reorder, split, or drop them.')
      ..writeln('- Keep line breaks and paragraph structure.')
      ..writeln(
          '- For Buddhist Pali/Sanskrit terms (nibbāna, dhamma, saṅgha, '
          'kamma…), use the established $target rendering when one exists.');
    final source = normalizeCode(sourceLang);
    if (source.isNotEmpty && source != 'AUTO') {
      buffer.writeln(
          '- The source text is ${languageDisplayName(source)}; translate '
          'it faithfully even if it mixes languages (e.g. Pali passages in '
          'Latin script).');
    }
    return buffer.toString().trim();
  }

  /// User prompt = ĐÚNG text nguồn. Chỉ dẫn nằm riêng ở system message
  /// để model không lẫn "mệnh lệnh" với nội dung cần dịch (nội dung do
  /// user mang vào — PDF/Web/LRC — không được coi là chỉ dẫn).
  static String buildUserPrompt(String text) => text;

  /// Các slot `__G{n}__` có trong [text] (duy nhất, theo thứ tự xuất hiện).
  static List<String> slotsIn(String text) => llMtSlotPattern
      .allMatches(text)
      .map((m) => m.group(0)!)
      .toSet()
      .toList();

  /// Slot đầu tiên bị MẤT trong [output]; null = giữ đủ hết.
  /// Không phân biệt hoa/thường — tầng restore còn pass 2 cho `__g3__`.
  static String? lostSlot(String input, String output) {
    for (final match in llMtSlotPattern.allMatches(input)) {
      final id = match.group(1)!;
      final probe = RegExp('__G${id}__', caseSensitive: false);
      if (!probe.hasMatch(output)) return match.group(0)!;
    }
    return null;
  }

  /// Bỏ "rác" phổ biến nếu model vẫn nhả thêm (AT: output KHÔNG chứa giải
  /// thích/giải nghĩa): fence code, lời dẫn "Translation:", lặp lại đoạn
  /// nguồn. Chỉ cắt phần nhận diện CHẮC CHẮN; guard bằng nguồn để không
  /// đụng nội dung bản dịch hợp lệ (vd bản dịch của câu bắt đầu bằng
  /// "Result:" khi câu nguồn cũng bắt đầu như vậy).
  static String cleanOutput(String raw, {String? sourceText}) {
    var out = raw.trim();

    // 1) Bọc trong ``` fence → bỏ fence. CHỈ khi nguồn không chứa fence
    //    (nguồn có fence = fence là nội dung thật, giữ nguyên).
    if (out.startsWith('```') &&
        (sourceText == null || !sourceText.contains('```'))) {
      final firstNewline = out.indexOf('\n');
      if (firstNewline < 0) {
        out = out.replaceAll('```', '').trim();
      } else {
        out = out.substring(firstNewline + 1);
        final lastFence = out.lastIndexOf('```');
        if (lastFence >= 0) out = out.substring(0, lastFence);
        out = out.trim();
      }
    }

    // 2) Lời dẫn "polite" ở đầu — lặp tối đa 3 lần cho kiểu
    //    "Sure. Here is the translation:\n…".
    for (var i = 0; i < 3; i++) {
      final stripped = _stripLeadIn(out, sourceText: sourceText);
      if (stripped == out) break;
      out = stripped;
    }

    // 3) Model lặp lại đoạn nguồn rồi mới dịch → lấy phần sau nguồn
    //    (cùng pattern cleanOutput của Hy-MT).
    final src = sourceText?.trim();
    if (src != null && src.length > 8 && out.contains(src)) {
      final index = out.lastIndexOf(src);
      if (index >= 0 && index + src.length < out.length) {
        out = out.substring(index + src.length).trim();
      }
    }
    return out.trim();
  }

  static String _stripLeadIn(String out, {String? sourceText}) {
    for (final leadIn in _leadIns) {
      if (!out.toLowerCase().startsWith(leadIn.toLowerCase())) continue;
      // Guard: nguồn cũng bắt đầu bằng lời dẫn này → đó là nội dung thật
      // (vd dịch câu "Result: …" sang tiếng Anh).
      final src = sourceText?.trim();
      if (src != null &&
          src.toLowerCase().startsWith(leadIn.toLowerCase())) {
        continue;
      }
      var rest = out.substring(leadIn.length);
      rest = rest.replaceFirst(RegExp(r'^[\s:—–\-]+'), '');
      return rest.trim();
    }
    return out;
  }

  /// Lời dẫn phổ biến model hay thêm trước bản dịch (tiếng Anh + tiếng
  /// Việt). Lowercase khi so khớp.
  static const List<String> _leadIns = <String>[
    'Translation:',
    'Translated text:',
    'Translated:',
    'Bản dịch:',
    'Dịch:',
    'Dưới đây là bản dịch:',
    'Here is the translation:',
    "Here's the translation:",
    'Here is the translated text:',
    'Sure, here is the translation:',
    "Sure, here's the translation:",
    'Sure! Here is the translation:',
    'Certainly! Here is the translation:',
  ];
}
