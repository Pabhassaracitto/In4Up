import '../../models/vocab_context.dart';
import '../../models/vocabulary_type.dart';
import '../../providers/vocabulary_bridge.dart';
import '../syntax_highlighter_service.dart';
import 'vocab_batch_models.dart';

/// ═══════════════════════════════════════════════════════════════
/// VOCAB BATCH — trích xuất + nhập hàng loạt từ/cụm/câu
/// (READ-630-04)
///
/// Dùng chung cho Web Reader (batch sheet hiện có) và PDF Reader
/// (lưu hàng loạt từ đoạn chọn / trang). Logic gốc kế thừa từ
/// WebReaderController (đã audit: hoạt động tốt).
///
/// + language field (READ-630-04): mỗi candidate mang ngôn ngữ,
/// importer áp khi tạo/bổ sung entry.
/// ═══════════════════════════════════════════════════════════════
class VocabBatchExtractor {
  VocabBatchExtractor._();

  static String normalizeStudyText(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static final RegExp _wordRegex = RegExp(r"[A-Za-z][A-Za-z'-]{1,}");

  static const Set<String> _stopWords = {
    'about', 'above', 'after', 'again', 'against', 'almost', 'along', 'also',
    'among', 'amongst', 'because', 'before', 'below', 'beneath', 'between',
    'beyond', 'could', 'doing', 'during', 'every', 'first', 'from', 'have',
    'having', 'into', 'itself', 'just', 'might', 'must', 'other', 'ought',
    'ours', 'ourselves', 'over', 'quite', 'rather', 'should', 'since',
    'still', 'such', 'than', 'that', 'their', 'theirs', 'them', 'themselves',
    'there', 'these', 'they', 'this', 'those', 'through', 'toward', 'towards',
    'under', 'until', 'very', 'what', 'when', 'where', 'which', 'while',
    'with', 'within', 'without', 'would', 'your', 'yours', 'yourself',
    'yourselves', 'onto', 'upon', 'were', 'been', 'being', 'does',
    'did', 'done', 'then', 'here', 'therefore', 'however', 'across',
    'beforehand', 'cannot', 'couldn', 'didn', 'doesn', 'hadn', 'hasn', 'haven',
    'isn', 'aren', 'wasn', 'weren', 'won', 'wouldn', 'shan', 'shouldn', 'the',
    'and', 'for', 'are', 'you', 'our', 'but', 'not', 'can', 'all', 'any',
    'why', 'who', 'how', 'out', 'its', "it's", 'his', 'her', 'she', 'him',
    'was', 'has', 'had', 'let', 'may', 'use', 'used', 'using', 'many', 'much',
    'more', 'most', 'some', 'same', 'each', 'only', 'both', 'few', 'ever',
    'even', 'well', 'back', 'gets', 'get', 'got', 'make', 'made', 'take',
    'took', 'come', 'came', 'goes', 'went', 'go', 'said', 'says', 'say',
    'look', 'looks', 'looking', 'know', 'knows', 'known', 'like', 'liked',
    'whose', 'whom', 'mine', 'myself', 'himself', 'herself', 'it', 'a', 'an',
    'to', 'of', 'in', 'on', 'at', 'by', 'or', 'if', 'be', 'is', 'am', 'as',
    'we', 'he', 'do', 'my', 'me', 'i'
  };

  /// Trích ứng viên (word + phrase 2–3 từ) từ văn bản nguồn, xếp theo
  /// độ ưu tiên. `pageTitle` (tên file PDF / tiêu đề web) dùng để tăng
  /// điểm cho từ xuất hiện trong tiêu đề.
  static List<WebExtractionCandidate> extract(
    String sourceText, {
    int minLength = 4,
    int maxItems = 120,
    bool includePhrases = true,
    bool allowSingleMentionPhrases = false,
    String pageTitle = '',
  }) {
    final cleanedSource = _normalizeSourceText(sourceText);
    if (cleanedSource.isEmpty) return const [];

    final titleNormalized = _normalizeStudyText(pageTitle).toLowerCase();
    final wordFrequencies = <String, int>{};
    final phraseFrequencies = <String, int>{};
    final samples = <String, String>{};
    final phraseWordCounts = <String, int>{};

    final sentences = _splitIntoSentences(cleanedSource);
    for (final sentence in sentences) {
      final sample = _normalizeStudyText(sentence);
      if (sample.isEmpty) continue;

      final rawTokens = _wordRegex
          .allMatches(sample)
          .map((m) => _normalizeWordToken(m.group(0) ?? ''))
          .where((token) => token.isNotEmpty)
          .toList();

      for (final token in rawTokens) {
        if (!_isUsefulBatchWord(token, minLength: minLength)) continue;
        wordFrequencies[token] = (wordFrequencies[token] ?? 0) + 1;
        samples[token] ??= sample;
      }

      if (!includePhrases || rawTokens.length < 2) continue;

      for (final phrase in _extractSentencePhrases(rawTokens,
          minLength: minLength)) {
        phraseFrequencies[phrase] = (phraseFrequencies[phrase] ?? 0) + 1;
        samples[phrase] ??= sample;
        phraseWordCounts[phrase] = phrase.split(' ').length;
      }
    }

    final candidates = <WebExtractionCandidate>[];

    for (final entry in wordFrequencies.entries) {
      final appearsInTitle = _containsAsTerm(titleNormalized, entry.key);
      final existed = VocabularyBridge.hasWord(entry.key);
      final isPriority = appearsInTitle ||
          entry.value >= 3 ||
          (entry.value >= 2 && entry.key.length >= minLength + 2);
      candidates.add(
        WebExtractionCandidate(
          text: entry.key,
          normalized: entry.key,
          sampleContext: samples[entry.key] ?? entry.key,
          frequency: entry.value,
          existed: existed,
          wordCount: 1,
          appearsInTitle: appearsInTitle,
          isPriority: isPriority,
          rankScore: _rankCandidate(
            text: entry.key,
            frequency: entry.value,
            existed: existed,
            isPhrase: false,
            wordCount: 1,
            appearsInTitle: appearsInTitle,
          ),
          selected: !existed,
        ),
      );
    }

    for (final entry in phraseFrequencies.entries) {
      final phrase = entry.key;
      final wordCount = phraseWordCounts[phrase] ?? phrase.split(' ').length;
      final appearsInTitle = _containsAsTerm(titleNormalized, phrase);
      if (!allowSingleMentionPhrases && !appearsInTitle && entry.value < 2) {
        continue;
      }
      final existed = VocabularyBridge.hasWord(phrase);
      final isPriority = appearsInTitle || entry.value >= 2 || wordCount >= 3;
      candidates.add(
        WebExtractionCandidate(
          text: phrase,
          normalized: phrase,
          sampleContext: samples[phrase] ?? phrase,
          frequency: entry.value,
          existed: existed,
          isPhrase: true,
          wordCount: wordCount,
          appearsInTitle: appearsInTitle,
          isPriority: isPriority,
          rankScore: _rankCandidate(
            text: phrase,
            frequency: entry.value,
            existed: existed,
            isPhrase: true,
            wordCount: wordCount,
            appearsInTitle: appearsInTitle,
          ),
          selected: !existed,
        ),
      );
    }

    candidates.sort(_compareCandidatesByPriority);

    if (candidates.length > maxItems) {
      return candidates.take(maxItems).toList();
    }
    return candidates;
  }

  /// Làm giàu local (nghĩa + IPA từ dict nội địa + topic heuristic)
  /// — không cần AI, chạy offline.
  static void enrichCandidateLocally(
    WebExtractionCandidate candidate, {
    String pageTitle = '',
  }) {
    final topic = _inferTopic(
      '${pageTitle.trim()} ${candidate.sampleContext} ${candidate.text}',
    );
    candidate.topic ??= topic;
    candidate.example ??= candidate.sampleContext;

    final direct = SyntaxHighlighterService.instance.analyzeWord(
        candidate.normalized);
    if (candidate.meaning.trim().isEmpty) {
      candidate.meaning = (direct.meaning ?? '').trim();
    }
    candidate.phonetic ??= direct.phonetic;

    if (candidate.isPhrase && candidate.meaning.trim().isEmpty) {
      final partHints = candidate.normalized
          .split(' ')
          .map((part) => SyntaxHighlighterService.instance.analyzeWord(part))
          .map((analysis) => analysis.meaning?.trim() ?? '')
          .where((meaning) => meaning.isNotEmpty)
          .take(3)
          .toList();
      if (partHints.isNotEmpty) {
        candidate.meaning = partHints.join(' · ');
      }
    }

    candidate.enriched = true;
    candidate.enrichSource =
        direct.meaning != null || direct.phonetic != null
            ? 'local'
            : 'heuristic';
  }
}

/// Nhập candidates (đã chọn) vào WordList qua VocabularyBridge.
/// `contextBuilder` do caller xây (web: url/scroll; pdf: page/rect) —
/// BẢO ĐẢM giữ reopen đúng vị trí nguồn (AGENTS.md rule 3).
class VocabBatchImporter {
  VocabBatchImporter._();

  static WebBatchImportResult import(
    Iterable<WebExtractionCandidate> candidates, {
    bool onlyReady = false,
    VocabContext Function(String sampleText, WebExtractionCandidate c)?
        contextBuilder,
  }) {
    int addedCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;

    for (final candidate in candidates) {
      if (!candidate.selected) continue;
      if (onlyReady && !candidate.isImportReady) {
        skippedCount++;
        continue;
      }
      final normalized =
          VocabBatchExtractor.normalizeStudyText(candidate.normalized)
              .toLowerCase();
      if (normalized.isEmpty || normalized.length < 2) {
        skippedCount++;
        continue;
      }

      final existed = VocabularyBridge.hasWord(normalized);
      final example = (candidate.example ?? '').trim().isEmpty
          ? candidate.sampleContext
          : candidate.example;

      final entry = VocabularyBridge.addContextual(
        text: normalized,
        meaning: candidate.meaning.trim(),
        phonetic: candidate.phonetic,
        example: example,
        topic: candidate.topic,
        language: candidate.language,
        forceType: candidate.isPhrase
            ? VocabularyType.phrase
            : (normalized.split(' ').length > 6
                ? VocabularyType.sentence
                : null),
        context: contextBuilder?.call(candidate.sampleContext, candidate),
      );

      if (entry == null) {
        skippedCount++;
      } else if (existed) {
        updatedCount++;
      } else {
        addedCount++;
      }
    }

    return WebBatchImportResult(
      addedCount: addedCount,
      updatedCount: updatedCount,
      skippedCount: skippedCount,
    );
  }
}

// ─── Helpers (kế thừa logic WebReaderController) ───────────

String _normalizeSourceText(String text) =>
    text.replaceAll(RegExp(r'\r\n?'), '\n').trim();

String _normalizeStudyText(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

List<String> _splitIntoSentences(String source) {
  return source
      .split(RegExp(r'(?<=[\.!?\n])\s+'))
      .map(_normalizeStudyText)
      .where((s) => s.isNotEmpty)
      .toList();
}

String _normalizeWordToken(String raw) {
  return raw
      .toLowerCase()
      .replaceAll(RegExp(r"^[^a-z]+|[^a-z']+$"), '')
      .trim();
}

Iterable<String> _extractSentencePhrases(
  List<String> tokens, {
  required int minLength,
}) sync* {
  for (int start = 0; start < tokens.length; start++) {
    for (int size = 3; size >= 2; size--) {
      if (start + size > tokens.length) continue;
      final window = tokens.sublist(start, start + size);
      if (window.any((token) => !_isUsefulPhraseToken(token))) continue;
      final phrase = window.join(' ');
      if (!_isUsefulBatchPhrase(phrase, minLength: minLength)) continue;
      yield phrase;
    }
  }
}

bool _isUsefulPhraseToken(String token) {
  if (token.length < 2) return false;
  if (VocabBatchExtractor._stopWords.contains(token)) return false;
  if (!RegExp(r'[a-z]').hasMatch(token)) return false;
  return true;
}

bool _isUsefulBatchPhrase(String phrase, {required int minLength}) {
  final words = phrase.split(' ');
  if (words.length < 2) return false;
  final phraseLength = phrase.replaceAll(' ', '').length;
  if (phraseLength < minLength + 2) return false;
  if (words.every((word) => word.length < minLength)) return false;
  return true;
}

bool _isUsefulBatchWord(String token, {required int minLength}) {
  if (token.length < minLength) return false;
  if (VocabBatchExtractor._stopWords.contains(token)) return false;
  if (!RegExp(r"[a-z]").hasMatch(token)) return false;
  if (token.startsWith("'") || token.endsWith("'")) return false;
  return true;
}

bool _containsAsTerm(String haystack, String needle) {
  if (haystack.trim().isEmpty || needle.trim().isEmpty) return false;
  final escaped =
      RegExp.escape(needle.trim().toLowerCase()).replaceAll(' ', r'\s+');
  return RegExp('\\b$escaped\\b').hasMatch(haystack);
}

double _rankCandidate({
  required String text,
  required int frequency,
  required bool existed,
  required bool isPhrase,
  required int wordCount,
  required bool appearsInTitle,
}) {
  final lengthScore = text.replaceAll(' ', '').length.toDouble();
  final frequencyScore = frequency * (isPhrase ? 11.0 : 9.0);
  final phraseBonus = isPhrase ? (wordCount * 5.5) : 0.0;
  final titleBonus = appearsInTitle ? (isPhrase ? 26.0 : 18.0) : 0.0;
  final noveltyBonus = existed ? -4.0 : 6.0;
  final repeatBonus = frequency > 1 ? frequency * 2.5 : 0.0;
  return frequencyScore +
      phraseBonus +
      titleBonus +
      noveltyBonus +
      repeatBonus +
      (lengthScore * 0.35);
}

int _compareCandidatesByPriority(
  WebExtractionCandidate a,
  WebExtractionCandidate b,
) {
  final scoreCompare = b.rankScore.compareTo(a.rankScore);
  if (scoreCompare != 0) return scoreCompare;
  if (a.isPriority != b.isPriority) return a.isPriority ? -1 : 1;
  if (a.existed != b.existed) return a.existed ? 1 : -1;
  if (a.isPhrase != b.isPhrase) return a.isPhrase ? -1 : 1;
  final frequencyCompare = b.frequency.compareTo(a.frequency);
  if (frequencyCompare != 0) return frequencyCompare;
  final lengthCompare = b.normalized.length.compareTo(a.normalized.length);
  if (lengthCompare != 0) return lengthCompare;
  return a.normalized.compareTo(b.normalized);
}

String _inferTopic(String source) {
  final haystack = source.toLowerCase();
  if (RegExp(r'\b(dharma|buddha|sutta|meditation|mindfulness|monk)\b')
      .hasMatch(haystack)) {
    return 'dharma';
  }
  if (RegExp(r'\b(learning english|voa|bbc learning|english|grammar|vocabulary)\b')
      .hasMatch(haystack)) {
    return 'english_learning';
  }
  if (RegExp(r'\b(news|reuters|guardian|bbc|cnn|report)\b').hasMatch(haystack)) {
    return 'news';
  }
  if (RegExp(r'\b(science|research|study|physics|biology|chemistry)\b')
      .hasMatch(haystack)) {
    return 'science';
  }
  return '';
}
