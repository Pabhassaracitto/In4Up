class PhrasePart {
  final int startOffset;
  final int endOffset;

  const PhrasePart({
    required this.startOffset,
    required this.endOffset,
  });

  Map<String, dynamic> toJson() => {
        'startOffset': startOffset,
        'endOffset': endOffset,
      };
}

enum PhraseKind {
  np,
  vp,
  adjp,
  advp,
  pp,
  gerp,
  infp,
  partp,
  phrasalV,
  clause,
  coord,
}

extension PhraseKindInfo on PhraseKind {
  String get wireName {
    switch (this) {
      case PhraseKind.np:
        return 'NP';
      case PhraseKind.vp:
        return 'VP';
      case PhraseKind.adjp:
        return 'ADJP';
      case PhraseKind.advp:
        return 'ADVP';
      case PhraseKind.pp:
        return 'PP';
      case PhraseKind.gerp:
        return 'GerP';
      case PhraseKind.infp:
        return 'InfP';
      case PhraseKind.partp:
        return 'PartP';
      case PhraseKind.phrasalV:
        return 'PHRASAL_V';
      case PhraseKind.clause:
        return 'CLAUSE';
      case PhraseKind.coord:
        return 'COORD';
    }
  }

  String get labelKey {
    switch (this) {
      case PhraseKind.np:
        return 'Cụm danh từ';
      case PhraseKind.vp:
        return 'Cụm động từ';
      case PhraseKind.adjp:
        return 'Cụm tính từ';
      case PhraseKind.advp:
        return 'Cụm trạng từ';
      case PhraseKind.pp:
        return 'Cụm giới từ';
      case PhraseKind.gerp:
        return 'Cụm danh động từ';
      case PhraseKind.infp:
        return 'Cụm động từ nguyên thể';
      case PhraseKind.partp:
        return 'Cụm phân từ';
      case PhraseKind.phrasalV:
        return 'Cụm động từ ghép';
      case PhraseKind.clause:
        return 'Mệnh đề';
      case PhraseKind.coord:
        return 'Cụm liên hợp';
    }
  }
}

class PhraseInfo {
  final PhraseKind kind;
  final int startOffset;
  final int endOffset;
  final List<PhrasePart> parts;
  final double confidence;

  const PhraseInfo({
    required this.kind,
    required this.startOffset,
    required this.endOffset,
    this.parts = const [],
    this.confidence = 0.85,
  });

  bool get isSplit => parts.length > 1;

  String textIn(String source) {
    final start = startOffset.clamp(0, source.length).toInt();
    final end = endOffset.clamp(start, source.length).toInt();
    return source.substring(start, end);
  }

  Map<String, dynamic> toJson({String? sourceText}) => {
        'kind': kind.wireName,
        'startOffset': startOffset,
        'endOffset': endOffset,
        if (sourceText != null) 'span': textIn(sourceText),
        'parts': parts.map((part) => part.toJson()).toList(),
        'confidence': confidence,
      };
}
