class WebExtractionCandidate {
  final String text;
  final String normalized;
  final String sampleContext;
  final int frequency;
  final bool existed;
  final bool isPhrase;
  bool selected;

  WebExtractionCandidate({
    required this.text,
    required this.normalized,
    required this.sampleContext,
    required this.frequency,
    required this.existed,
    this.isPhrase = false,
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
