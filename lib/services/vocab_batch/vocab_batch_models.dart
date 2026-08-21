enum WebExtractionSort {
  priority,
  frequency,
  length,
  alphabetic,
}

class WebExtractionDraft {
  final String id;
  final String sourceLabel;
  final String sourceText;
  final bool fromSelection;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<WebExtractionCandidate> candidates;

  const WebExtractionDraft({
    required this.id,
    required this.sourceLabel,
    required this.sourceText,
    required this.fromSelection,
    required this.createdAt,
    required this.updatedAt,
    required this.candidates,
  });

  WebExtractionDraft copyWith({
    String? id,
    String? sourceLabel,
    String? sourceText,
    bool? fromSelection,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<WebExtractionCandidate>? candidates,
  }) {
    return WebExtractionDraft(
      id: id ?? this.id,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      sourceText: sourceText ?? this.sourceText,
      fromSelection: fromSelection ?? this.fromSelection,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      candidates: candidates ?? this.candidates,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceLabel': sourceLabel,
        'sourceText': sourceText,
        'fromSelection': fromSelection,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'candidates': candidates.map((e) => e.toJson()).toList(),
      };

  factory WebExtractionDraft.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    final fromSelection = json['fromSelection'] == true;
    const legacySelectionPrefix = 'Đoạn đã chọn · ';
    final storedSourceLabel = (json['sourceLabel'] ?? '').toString();
    final sourceLabel = fromSelection &&
            storedSourceLabel.startsWith(legacySelectionPrefix)
        ? storedSourceLabel.substring(legacySelectionPrefix.length)
        : storedSourceLabel;
    return WebExtractionDraft(
      id: (json['id'] ?? '').toString(),
      sourceLabel: sourceLabel,
      sourceText: (json['sourceText'] ?? '').toString(),
      fromSelection: fromSelection,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      candidates: rawCandidates is List
          ? rawCandidates
              .whereType<Map>()
              .map((e) =>
                  WebExtractionCandidate.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
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
  /// READ-630-04: ngôn ngữ áp khi nhập vào WordList (mặc định 'en').
  String language;
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
    this.language = 'en',
    this.enriched = false,
    this.enrichSource = '',
    this.selected = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'normalized': normalized,
        'sampleContext': sampleContext,
        'frequency': frequency,
        'existed': existed,
        'isPhrase': isPhrase,
        'wordCount': wordCount,
        'appearsInTitle': appearsInTitle,
        'isPriority': isPriority,
        'rankScore': rankScore,
        'meaning': meaning,
        'phonetic': phonetic,
        'topic': topic,
        'example': example,
        'language': language,
        'enriched': enriched,
        'enrichSource': enrichSource,
        'selected': selected,
      };

  factory WebExtractionCandidate.fromJson(Map<String, dynamic> json) {
    return WebExtractionCandidate(
      text: (json['text'] ?? '').toString(),
      normalized: (json['normalized'] ?? '').toString(),
      sampleContext: (json['sampleContext'] ?? '').toString(),
      frequency: (json['frequency'] as num?)?.toInt() ?? 0,
      existed: json['existed'] == true,
      isPhrase: json['isPhrase'] == true,
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 1,
      appearsInTitle: json['appearsInTitle'] == true,
      isPriority: json['isPriority'] == true,
      rankScore: ((json['rankScore'] as num?) ?? 0).toDouble(),
      meaning: (json['meaning'] ?? '').toString(),
      phonetic: (json['phonetic'] ?? '').toString().trim().isEmpty
          ? null
          : (json['phonetic'] ?? '').toString(),
      topic: (json['topic'] ?? '').toString().trim().isEmpty
          ? null
          : (json['topic'] ?? '').toString(),
      example: (json['example'] ?? '').toString().trim().isEmpty
          ? null
          : (json['example'] ?? '').toString(),
      language: (json['language'] ?? '').toString().trim().isEmpty
          ? 'en'
          : (json['language'] ?? '').toString(),
      enriched: json['enriched'] == true,
      enrichSource: (json['enrichSource'] ?? '').toString(),
      selected: json['selected'] == true,
    );
  }

  bool get hasMeaning => meaning.trim().isNotEmpty;
  bool get hasTopic => (topic ?? '').trim().isNotEmpty;
  bool get hasExample =>
      ((example ?? '').trim().isNotEmpty) || sampleContext.trim().isNotEmpty;
  bool get isImportReady => hasMeaning && hasTopic && hasExample;
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
