/// Small, testable batching layer for translating Web Reader page content.
/// Keeps requests bounded and lets the UI stop between units.
typedef WebUnitTranslator = Future<String?> Function(String text);
typedef WebTranslationUnitCallback =
    void Function(int index, WebTranslationUnit unit);

const Duration kWebPageTranslationDelay = Duration(milliseconds: 120);
const int kWebPageTranslationMaxConsecutiveFailures = 4;

class WebTranslationUnit {
  const WebTranslationUnit({
    required this.original,
    this.translation,
  });

  final String original;
  final String? translation;

  bool get hasTranslation =>
      translation != null && translation!.trim().isNotEmpty;
}

class WebPageTranslateReport {
  const WebPageTranslateReport({
    required this.translations,
    required this.translatedCount,
    required this.failedCount,
    this.stoppedEarly = false,
  });

  final List<WebTranslationUnit> translations;
  final int translatedCount;
  final int failedCount;
  final bool stoppedEarly;
}

/// Turns rendered page DOM text into request-sized paragraph/sentence batches.
///
/// Blank lines remain paragraph boundaries. Long paragraphs are split at
/// sentence boundaries first, then at whitespace if a single sentence still
/// exceeds [maxUnitLength]. Whitespace is normalized so no request starts or
/// ends with a partial word.
List<String> splitWebTextIntoUnits(
  String text, {
  int maxUnitLength = 520,
}) {
  if (maxUnitLength < 1) {
    throw ArgumentError.value(maxUnitLength, 'maxUnitLength', 'must be positive');
  }

  final units = <String>[];
  final paragraphs = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split(RegExp(r'\n\s*\n+'))
      .map((paragraph) => paragraph.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((paragraph) => paragraph.isNotEmpty);

  for (final paragraph in paragraphs) {
    if (paragraph.length <= maxUnitLength) {
      units.add(paragraph);
      continue;
    }

    final sentences = paragraph
        .split(RegExp(r'(?<=[.!?…])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty);
    var buffer = StringBuffer();

    for (final sentence in sentences) {
      final chunks = _splitLongSentence(sentence, maxUnitLength);
      for (final chunk in chunks) {
        if (buffer.length > 0 && buffer.length + chunk.length + 1 > maxUnitLength) {
          units.add(buffer.toString().trim());
          buffer = StringBuffer();
        }
        if (buffer.length > 0) buffer.write(' ');
        buffer.write(chunk);
      }
    }

    final remainder = buffer.toString().trim();
    if (remainder.isNotEmpty) units.add(remainder);
  }

  return units;
}

Iterable<String> _splitLongSentence(String sentence, int maxUnitLength) sync* {
  var remainder = sentence.trim();
  while (remainder.length > maxUnitLength) {
    var splitAt = remainder.lastIndexOf(' ', maxUnitLength);
    if (splitAt <= 0) splitAt = maxUnitLength;
    yield remainder.substring(0, splitAt).trim();
    remainder = remainder.substring(splitAt).trim();
  }
  if (remainder.isNotEmpty) yield remainder;
}

/// Translates units sequentially (online engines are rate-limited), reporting
/// partial results as they complete. [shouldStop] is checked between requests.
Future<WebPageTranslateReport> translateWebPageUnits({
  required List<String> units,
  required WebUnitTranslator translate,
  WebTranslationUnitCallback? onUnit,
  bool Function()? shouldStop,
  Duration delayBetween = kWebPageTranslationDelay,
  int maxConsecutiveFailures = kWebPageTranslationMaxConsecutiveFailures,
}) async {
  if (units.isEmpty) {
    return const WebPageTranslateReport(
      translations: <WebTranslationUnit>[],
      translatedCount: 0,
      failedCount: 0,
    );
  }

  final translations = <WebTranslationUnit>[];
  var translatedCount = 0;
  var failedCount = 0;
  var consecutiveFailures = 0;
  var stoppedEarly = false;

  for (var index = 0; index < units.length; index++) {
    if (shouldStop?.call() ?? false) {
      stoppedEarly = true;
      break;
    }

    final original = units[index].trim();
    if (original.isEmpty) continue;

    String? translated;
    try {
      translated = await translate(original);
    } catch (_) {
      translated = null;
    }

    final value = translated?.trim();
    final successful = value != null && value.isNotEmpty;
    final result = WebTranslationUnit(
      original: original,
      translation: successful ? value : null,
    );
    translations.add(result);
    onUnit?.call(index, result);

    if (successful) {
      translatedCount++;
      consecutiveFailures = 0;
    } else {
      failedCount++;
      consecutiveFailures++;
      if (consecutiveFailures >= maxConsecutiveFailures) {
        stoppedEarly = index < units.length - 1;
        break;
      }
    }

    if (index < units.length - 1 && delayBetween > Duration.zero) {
      await Future<void>.delayed(delayBetween);
    }
  }

  return WebPageTranslateReport(
    translations: translations,
    translatedCount: translatedCount,
    failedCount: failedCount,
    stoppedEarly: stoppedEarly,
  );
}
