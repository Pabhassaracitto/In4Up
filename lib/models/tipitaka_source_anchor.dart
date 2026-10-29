import 'dart:convert';

/// A stable pointer from a worklist item back to a Tipiṭaka paragraph.
///
/// The selected text is deliberately kept as a snapshot. Segment/book IDs are
/// the preferred resolver key, while the book code, reference, source row and
/// selected text let older or replaced databases be resolved gracefully.
class TipitakaSourceAnchor {
  final String sourceType;
  final String sourceDatabaseId;
  final int bookId;
  final String bookCode;
  final int segmentId;
  final String reference;
  final int? paragraphNo;
  final int startOffset;
  final int endOffset;
  final String selectedText;
  final String sourceTable;
  final String sourceRowKey;

  const TipitakaSourceAnchor({
    this.sourceType = 'tipitaka',
    required this.sourceDatabaseId,
    required this.bookId,
    required this.bookCode,
    required this.segmentId,
    required this.reference,
    required this.paragraphNo,
    required this.startOffset,
    required this.endOffset,
    required this.selectedText,
    this.sourceTable = '',
    this.sourceRowKey = '',
  });

  bool get isRangeValid =>
      startOffset >= 0 && endOffset >= startOffset && selectedText.isNotEmpty;

  String get stableKey =>
      '$sourceType:$bookId:$segmentId:$startOffset:$endOffset';

  TipitakaSourceAnchor copyWith({
    String? sourceDatabaseId,
    int? bookId,
    String? bookCode,
    int? segmentId,
    String? reference,
    int? paragraphNo,
    int? startOffset,
    int? endOffset,
    String? selectedText,
    String? sourceTable,
    String? sourceRowKey,
  }) {
    return TipitakaSourceAnchor(
      sourceType: sourceType,
      sourceDatabaseId: sourceDatabaseId ?? this.sourceDatabaseId,
      bookId: bookId ?? this.bookId,
      bookCode: bookCode ?? this.bookCode,
      segmentId: segmentId ?? this.segmentId,
      reference: reference ?? this.reference,
      paragraphNo: paragraphNo ?? this.paragraphNo,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      selectedText: selectedText ?? this.selectedText,
      sourceTable: sourceTable ?? this.sourceTable,
      sourceRowKey: sourceRowKey ?? this.sourceRowKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceType': sourceType,
        'sourceDatabaseId': sourceDatabaseId,
        'bookId': bookId,
        'bookCode': bookCode,
        'segmentId': segmentId,
        'reference': reference,
        'paragraphNo': paragraphNo,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'selectedText': selectedText,
        'sourceTable': sourceTable,
        'sourceRowKey': sourceRowKey,
      };

  factory TipitakaSourceAnchor.fromJson(Map<String, dynamic> json) {
    return TipitakaSourceAnchor(
      sourceType: json['sourceType'] as String? ?? 'tipitaka',
      sourceDatabaseId: json['sourceDatabaseId'] as String? ?? '',
      bookId: (json['bookId'] as num?)?.toInt() ?? 0,
      bookCode: json['bookCode'] as String? ?? '',
      segmentId: (json['segmentId'] as num?)?.toInt() ?? 0,
      reference: json['reference'] as String? ?? '',
      paragraphNo: (json['paragraphNo'] as num?)?.toInt(),
      startOffset: (json['startOffset'] as num?)?.toInt() ?? 0,
      endOffset: (json['endOffset'] as num?)?.toInt() ?? 0,
      selectedText: json['selectedText'] as String? ?? '',
      sourceTable: json['sourceTable'] as String? ?? '',
      sourceRowKey: json['sourceRowKey'] as String? ?? '',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory TipitakaSourceAnchor.fromJsonString(String value) =>
      TipitakaSourceAnchor.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
}

/// Text captured alongside an anchor so a worklist item remains useful when
/// the installed database is replaced or a translation is unavailable.
class TipitakaContextSnapshot {
  final String paliText;
  final String translationText;
  final String translationLanguage;
  final String contextBefore;
  final String contextAfter;
  final String translationVersion;
  final int? paragraphNo;
  final DateTime capturedAt;

  const TipitakaContextSnapshot({
    required this.paliText,
    this.translationText = '',
    this.translationLanguage = 'vi',
    this.contextBefore = '',
    this.contextAfter = '',
    this.translationVersion = '',
    this.paragraphNo,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'paliText': paliText,
        'translationText': translationText,
        'translationLanguage': translationLanguage,
        'contextBefore': contextBefore,
        'contextAfter': contextAfter,
        'translationVersion': translationVersion,
        'paragraphNo': paragraphNo,
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory TipitakaContextSnapshot.fromJson(Map<String, dynamic> json) {
    return TipitakaContextSnapshot(
      paliText: json['paliText'] as String? ?? '',
      translationText: json['translationText'] as String? ?? '',
      translationLanguage: json['translationLanguage'] as String? ?? 'vi',
      contextBefore: json['contextBefore'] as String? ?? '',
      contextAfter: json['contextAfter'] as String? ?? '',
      translationVersion: json['translationVersion'] as String? ?? '',
      paragraphNo: (json['paragraphNo'] as num?)?.toInt(),
      capturedAt: json['capturedAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['capturedAt'] as String) ?? DateTime.now(),
    );
  }
}
