enum WebExtractionSort {
  priority,
  frequency,
  length,
  alphabetic,
}

class WebExtractionCandidate {
  final String text;
  final String normalized;
  final String sampleContext;
  final int frequency;
  final bool existed;
  final bool isPhrase;
  final int wordCount;
  final bool appearsInTitle;
  final bool isPriority;
  final double rankScore;

  String meaning;
  String? phonetic;
  String? topic;
  String? example;
  bool enriched;
  String enrichSource;
  bool selected;

  WebExtractionCandidate({
    required this.text,
    required this.normalized,
    required this.sampleContext,
    required this.frequency,
    required this.existed,
    required this.wordCount,
    required this.appearsInTitle,
    required this.isPriority,
    required this.rankScore,
    this.isPhrase = false,
    this.meaning = '',
    this.phonetic,
    this.topic,
    this.example,
    this.enriched = false,
    this.enrichSource = '',
    this.selected = false,
  });
}

class WebBatchImportResult {
  final int addedCount;
  final int updatedCount;
  final int skippedCount;

  const WebBatchImportResult({
    required this.addedCount,
    required this.updatedCount,
    required this.skippedCount,
  });

  int get processedCount => addedCount + updatedCount;
  bool get hasChanges => processedCount > 0;
}
