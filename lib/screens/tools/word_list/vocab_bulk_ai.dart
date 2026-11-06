// PLAN-043 mục 3 (WORDLIST-AI-IMPORT-001) — sinh PROMPT tạo từ vựng hàng
// loạt. File THUẦN (không import Flutter/service): cả hai đường dùng chung
//   (1) Tầng 0: người dùng copy prompt mang sang AI bên ngoài bất kỳ;
//   (2) Tầng 1: app gửi đúng prompt này qua tầng Server API.
// Kết quả ở cả hai đường đều đổ vào ô Dán của sheet nhập hàng loạt → qua
// cùng parser + màn xem trước + smart-fill sẵn có (người duyệt trước khi
// nhập — KHÔNG có đường nào chen thẳng vào kho từ).

/// Ba kịch bản sinh từ vựng.
enum VocabBulkAiScenario {
  /// Sinh danh sách từ theo chủ đề + trình độ.
  byTopic,

  /// Làm giàu danh sách từ người dùng đưa (bổ sung nghĩa/IPA/ví dụ).
  enrichList,

  /// Trích từ vựng đáng học từ một đoạn văn.
  extractFromText,
}

/// Header CSV chuẩn — PHẢI khớp đúng thứ `WordTableParser` hiểu
/// (`word_import_sheet.dart`). Đổi ở đây thì đổi cả hướng dẫn trong sheet.
const String kVocabCsvHeader =
    'word, meaning, ipa, topic, example, example_simple, example_complex, language';

/// Optional media extension understood by WordTableParser. AI prompts use the
/// core header above so they never invent image URLs; users may append this
/// column when importing a hand-authored CSV.
const String kVocabCsvHeaderWithImage = '$kVocabCsvHeader, image_url';

/// System prompt cho đường AI trong app (đường copy dùng user prompt là đủ).
const String kVocabBulkAiSystemPrompt =
    'You are a precise vocabulary dataset generator for language learners. '
    'You output ONLY the CSV data requested — no explanations, no markdown, '
    'no code fences.';

/// Số từ tối đa trong MỘT request làm-giàu (chia lô để output không bị cắt
/// giữa chừng vì trần token; service gọi tuần tự từng lô rồi ghép).
const int kVocabBulkAiChunkSize = 20;

/// Tách danh sách từ đầu vào (mỗi dòng 1 từ/cụm; bỏ dòng trống; cắt phần
/// sau dấu phẩy đầu tiên nếu người dùng dán cả "word, nghĩa sơ sơ").
List<String> splitVocabAiInputWords(String input) {
  final words = <String>[];
  for (final raw in input.split(RegExp(r'\r?\n'))) {
    var line = raw.trim();
    if (line.isEmpty) continue;
    // Bỏ đánh số đầu dòng kiểu "1. apple" / "- apple".
    line = line.replaceFirst(RegExp(r'^(\d+[.)]|[-*•])\s*'), '');
    final comma = line.indexOf(',');
    if (comma > 0) line = line.substring(0, comma).trim();
    if (line.isNotEmpty) words.add(line);
  }
  return words;
}

/// Chia danh sách thành các lô tối đa [chunkSize] phần tử.
List<List<String>> chunkVocabAiWords(List<String> words,
    {int chunkSize = kVocabBulkAiChunkSize}) {
  final size = chunkSize < 1 ? 1 : chunkSize;
  final chunks = <List<String>>[];
  for (var i = 0; i < words.length; i += size) {
    final end = (i + size > words.length) ? words.length : i + size;
    chunks.add(words.sublist(i, end));
  }
  return chunks;
}

String _formatRules({
  required String wordLanguageName,
  required String meaningLanguageName,
  required String wordLanguageCode,
  required String topicValue,
}) =>
    '''
ĐỊNH DẠNG BẮT BUỘC (chỉ trả về đúng phần này, không thêm lời dẫn/giải thích, không dùng markdown hay ```):
- Dòng đầu tiên PHẢI là header này, nguyên văn:
$kVocabCsvHeader
- Mỗi dòng tiếp theo là MỘT từ/cụm từ, đủ 8 cột ngăn bằng dấu phẩy.
- Ô nào chứa dấu phẩy thì bọc trong dấu nháy kép "..." (dấu nháy kép bên trong ô viết thành "").
QUY ƯỚC NỘI DUNG:
- word: từ/cụm từ tiếng $wordLanguageName ở dạng nguyên thể (dạng từ điển/lemma), chữ thường trừ danh từ riêng.
- meaning: nghĩa tiếng $meaningLanguageName ngắn gọn kiểu từ điển cho người học; nghĩa phổ biến nhất trước; nếu có 2 nghĩa hay dùng thì ngăn bằng "; ".
- ipa: phiên âm IPA chuẩn trong cặp /.../ (để trống nếu thực sự không chắc).
- topic: $topicValue
- example: 1 câu ví dụ tự nhiên bằng tiếng $wordLanguageName có chứa đúng từ/cụm đó.
- example_simple: 1 câu RẤT đơn giản (mức A2) cũng chứa từ/cụm đó.
- example_complex: để trống.
- language: luôn là $wordLanguageCode''';

/// Dựng prompt cho một kịch bản. [inputText] theo kịch bản:
/// byTopic = chủ đề; enrichList = danh sách từ (mỗi dòng 1 từ);
/// extractFromText = đoạn văn nguồn.
String buildVocabBulkPrompt({
  required VocabBulkAiScenario scenario,
  required String wordLanguageName,
  required String meaningLanguageName,
  required String wordLanguageCode,
  required String inputText,
  String topic = '',
  String level = 'B1',
  int count = 20,
}) {
  final n = count < 1 ? 1 : (count > 50 ? 50 : count);
  final topicTrimmed = topic.trim();
  final input = inputText.trim();

  switch (scenario) {
    case VocabBulkAiScenario.byTopic:
      final topicValue =
          topicTrimmed.isNotEmpty ? topicTrimmed : (input.isEmpty ? '' : input);
      return '''Hãy tạo danh sách $n từ/cụm từ tiếng $wordLanguageName hữu ích nhất thuộc chủ đề "$topicValue", phù hợp người học trình độ $level, sắp xếp từ phổ biến/dễ dùng nhất trước. Ưu tiên từ dùng được trong giao tiếp và văn bản thông thường; tránh từ quá hiếm hoặc quá chuyên môn.

${_formatRules(
        wordLanguageName: wordLanguageName,
        meaningLanguageName: meaningLanguageName,
        wordLanguageCode: wordLanguageCode,
        topicValue: 'viết đúng một chủ đề ngắn cho mọi dòng: "$topicValue".',
      )}''';

    case VocabBulkAiScenario.enrichList:
      final words = splitVocabAiInputWords(input);
      final listBlock = words.map((w) => '- $w').join('\n');
      return '''Dưới đây là danh sách ${words.length} từ/cụm từ tiếng $wordLanguageName tôi đang học. Với MỖI mục, hãy bổ sung nghĩa, phiên âm IPA và câu ví dụ cho tôi. Giữ ĐÚNG thứ tự và ĐÚNG chính tả như danh sách; không bỏ sót, không thêm từ ngoài danh sách. Nếu một mục có vẻ gõ sai chính tả, vẫn giữ nguyên mục đó và giải nghĩa theo từ đúng gần nhất.

$listBlock

${_formatRules(
        wordLanguageName: wordLanguageName,
        meaningLanguageName: meaningLanguageName,
        wordLanguageCode: wordLanguageCode,
        topicValue: topicTrimmed.isNotEmpty
            ? 'viết "$topicTrimmed" cho mọi dòng.'
            : 'tự suy ra 1 chủ đề ngắn (1-3 từ) phù hợp cho từng từ.',
      )}''';

    case VocabBulkAiScenario.extractFromText:
      return '''Đọc đoạn văn tiếng $wordLanguageName dưới đây và trích ra tối đa $n từ/cụm từ ĐÁNG HỌC nhất cho người học trình độ $level (từ xuất hiện trong bài, hữu ích ngoài bài; bỏ tên riêng, bỏ từ quá dễ/quá hiếm). Với mỗi mục, câu ví dụ ưu tiên lấy/viết lại gọn từ chính đoạn văn.

ĐOẠN VĂN:
"""
$input
"""

${_formatRules(
        wordLanguageName: wordLanguageName,
        meaningLanguageName: meaningLanguageName,
        wordLanguageCode: wordLanguageCode,
        topicValue: topicTrimmed.isNotEmpty
            ? 'viết "$topicTrimmed" cho mọi dòng.'
            : 'tự suy ra chủ đề của đoạn văn (ngắn, 1-3 từ) và dùng cho mọi dòng.',
      )}''';
  }
}

/// Dựng (các) prompt cho đường AI trong app: kịch bản làm-giàu chia lô
/// [kVocabBulkAiChunkSize] từ/request; hai kịch bản còn lại 1 prompt.
/// Người dùng đã sửa tay prompt trong ô prompt ([editedPrompt] khác rỗng,
/// kịch bản KHÔNG phải làm-giàu) thì tôn trọng bản sửa đó.
List<String> buildVocabBulkPromptsForRun({
  required VocabBulkAiScenario scenario,
  required String wordLanguageName,
  required String meaningLanguageName,
  required String wordLanguageCode,
  required String inputText,
  String topic = '',
  String level = 'B1',
  int count = 20,
  String editedPrompt = '',
}) {
  if (scenario != VocabBulkAiScenario.enrichList &&
      editedPrompt.trim().isNotEmpty) {
    return [editedPrompt.trim()];
  }
  if (scenario == VocabBulkAiScenario.enrichList) {
    final words = splitVocabAiInputWords(inputText);
    if (words.isEmpty) return const [];
    return [
      for (final chunk in chunkVocabAiWords(words))
        buildVocabBulkPrompt(
          scenario: scenario,
          wordLanguageName: wordLanguageName,
          meaningLanguageName: meaningLanguageName,
          wordLanguageCode: wordLanguageCode,
          inputText: chunk.join('\n'),
          topic: topic,
          level: level,
          count: count,
        ),
    ];
  }
  return [
    buildVocabBulkPrompt(
      scenario: scenario,
      wordLanguageName: wordLanguageName,
      meaningLanguageName: meaningLanguageName,
      wordLanguageCode: wordLanguageCode,
      inputText: inputText,
      topic: topic,
      level: level,
      count: count,
    ),
  ];
}
