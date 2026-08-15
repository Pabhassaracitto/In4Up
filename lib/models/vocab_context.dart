import 'package:flutter/material.dart';

/// Ngữ cảnh gặp từ vựng.
/// Mỗi lần user gặp lại từ ở nguồn/vị trí mới → tạo 1 VocabContext.
/// Nguyên tắc Context-Accumulation: nhiều context = từ quan trọng hơn.
class VocabContext {
  final String id;
  final String sourceType; // 'pdf', 'web', 'youtube', 'manual', 'clipboard', 'story'
  final String? sourceName; // "ML_101.pdf", "https://...", "YouTube: TED Talk"
  final String? pageOrPosition; // "trang 42", "02:15", "Content"
  final String? sourceRef; // reopenable ref: path / url / cloud id if available
  final String? sourceRefType; // pdfPath | webUrl | localText | cloudText
  final String surroundingText; // Câu/đoạn văn chứa từ
  final DateTime encounteredAt;

  /// Precision metadata cho phase 10.
  final String? anchorText;
  final int? pageIndexHint;
  final int? lineIndexHint;
  final int? textStartOffset;
  final int? textEndOffset;
  final double? scrollProgressHint;
  final Rect? rectHint;

  const VocabContext({
    required this.id,
    required this.sourceType,
    this.sourceName,
    this.pageOrPosition,
    this.sourceRef,
    this.sourceRefType,
    required this.surroundingText,
    required this.encounteredAt,
    this.anchorText,
    this.pageIndexHint,
    this.lineIndexHint,
    this.textStartOffset,
    this.textEndOffset,
    this.scrollProgressHint,
    this.rectHint,
  });

  /// Nhãn hiển thị ngắn gọn cho UI
  String get displaySource {
    if (sourceName != null && sourceName!.isNotEmpty) {
      final short = sourceName!.length > 30
          ? '${sourceName!.substring(0, 27)}...'
          : sourceName!;
      if (pageOrPosition != null && pageOrPosition!.isNotEmpty) {
        return '$short, $pageOrPosition';
      }
      return short;
    }
    return sourceType;
  }

  /// Icon theo loại nguồn
  String get sourceIcon {
    switch (sourceType) {
      case 'pdf':
        return '📄';
      case 'web':
        return '🌐';
      case 'youtube':
        return '▶️';
      case 'clipboard':
        return '📋';
      case 'story':
        return '📖';
      default:
        return '✏️';
    }
  }

  bool get canReopenSource =>
      sourceRef != null &&
      sourceRef!.trim().isNotEmpty &&
      sourceRefType != null &&
      sourceRefType!.trim().isNotEmpty;

  String get reopenActionLabel {
    switch (sourceRefType) {
      case 'pdfPath':
        return 'Open PDF';
      case 'webUrl':
        return 'Open Web';
      case 'localText':
      case 'cloudText':
        return 'Content';
      default:
        return 'Content';
    }
  }

  int? get numericPositionHint {
    final raw = pageOrPosition ?? '';
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  bool get hasTextRangeHint =>
      textStartOffset != null &&
      textEndOffset != null &&
      textEndOffset! > textStartOffset!;

  bool get hasRectHint => rectHint != null && !rectHint!.isEmpty;

  bool get hasPreciseAnchor =>
      hasTextRangeHint ||
      hasRectHint ||
      pageIndexHint != null ||
      lineIndexHint != null ||
      scrollProgressHint != null ||
      (anchorText ?? '').trim().isNotEmpty;

  String get precisionSummary {
    final parts = <String>[];
    if (pageIndexHint != null) parts.add('trang ${pageIndexHint! + 1}');
    if (lineIndexHint != null) parts.add('Content');
    if (hasTextRangeHint) {
      parts.add('offset $textStartOffset-$textEndOffset');
    }
    if (scrollProgressHint != null) {
      parts.add('Content');
    }
    if (hasRectHint) {
      parts.add('Content');
    }
    final anchor = (anchorText ?? '').trim();
    if (anchor.isNotEmpty) {
      parts.add('neo "${_shortText(anchor, 36)}"');
    }
    return parts.join(' · ');
  }

  VocabContext copyWith({
    String? id,
    String? sourceType,
    String? sourceName,
    String? pageOrPosition,
    String? sourceRef,
    String? sourceRefType,
    String? surroundingText,
    DateTime? encounteredAt,
    String? anchorText,
    int? pageIndexHint,
    int? lineIndexHint,
    int? textStartOffset,
    int? textEndOffset,
    double? scrollProgressHint,
    Rect? rectHint,
  }) {
    return VocabContext(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceName: sourceName ?? this.sourceName,
      pageOrPosition: pageOrPosition ?? this.pageOrPosition,
      sourceRef: sourceRef ?? this.sourceRef,
      sourceRefType: sourceRefType ?? this.sourceRefType,
      surroundingText: surroundingText ?? this.surroundingText,
      encounteredAt: encounteredAt ?? this.encounteredAt,
      anchorText: anchorText ?? this.anchorText,
      pageIndexHint: pageIndexHint ?? this.pageIndexHint,
      lineIndexHint: lineIndexHint ?? this.lineIndexHint,
      textStartOffset: textStartOffset ?? this.textStartOffset,
      textEndOffset: textEndOffset ?? this.textEndOffset,
      scrollProgressHint: scrollProgressHint ?? this.scrollProgressHint,
      rectHint: rectHint ?? this.rectHint,
    );
  }

  bool isLikelyDuplicateOf(VocabContext other) {
    if (sourceType != other.sourceType) return false;

    final selfRef = (sourceRef ?? sourceName ?? '').trim();
    final otherRef = (other.sourceRef ?? other.sourceName ?? '').trim();
    if (selfRef.isNotEmpty && otherRef.isNotEmpty && selfRef != otherRef) {
      return false;
    }

    if (pageIndexHint != null || other.pageIndexHint != null) {
      if (pageIndexHint != other.pageIndexHint) return false;
    }

    if (lineIndexHint != null || other.lineIndexHint != null) {
      if (lineIndexHint != other.lineIndexHint) return false;
    }

    if (hasTextRangeHint && other.hasTextRangeHint) {
      return textStartOffset == other.textStartOffset &&
          textEndOffset == other.textEndOffset;
    }

    if (hasRectHint && other.hasRectHint) {
      return _sameRect(rectHint!, other.rectHint!);
    }

    final selfAnchor = (anchorText ?? '').trim().toLowerCase();
    final otherAnchor = (other.anchorText ?? '').trim().toLowerCase();
    if (selfAnchor.isNotEmpty && otherAnchor.isNotEmpty && selfAnchor != otherAnchor) {
      return false;
    }

    return pageOrPosition == other.pageOrPosition &&
        surroundingText == other.surroundingText;
  }

  VocabContext mergeWith(VocabContext other) {
    String? chooseText(String? a, String? b) {
      final otherText = (b ?? '').trim();
      if (otherText.isNotEmpty) return b;
      return a;
    }

    return copyWith(
      sourceName: chooseText(sourceName, other.sourceName),
      pageOrPosition: chooseText(pageOrPosition, other.pageOrPosition),
      sourceRef: chooseText(sourceRef, other.sourceRef),
      sourceRefType: chooseText(sourceRefType, other.sourceRefType),
      surroundingText: chooseText(surroundingText, other.surroundingText) ??
          surroundingText,
      encounteredAt: other.encounteredAt.isAfter(encounteredAt)
          ? other.encounteredAt
          : encounteredAt,
      anchorText: chooseText(anchorText, other.anchorText),
      pageIndexHint: other.pageIndexHint ?? pageIndexHint,
      lineIndexHint: other.lineIndexHint ?? lineIndexHint,
      textStartOffset: other.textStartOffset ?? textStartOffset,
      textEndOffset: other.textEndOffset ?? textEndOffset,
      scrollProgressHint: other.scrollProgressHint ?? scrollProgressHint,
      rectHint: other.rectHint ?? rectHint,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceType': sourceType,
        'sourceName': sourceName,
        'pageOrPosition': pageOrPosition,
        'sourceRef': sourceRef,
        'sourceRefType': sourceRefType,
        'surroundingText': surroundingText,
        'encounteredAt': encounteredAt.toIso8601String(),
        'anchorText': anchorText,
        'pageIndexHint': pageIndexHint,
        'lineIndexHint': lineIndexHint,
        'textStartOffset': textStartOffset,
        'textEndOffset': textEndOffset,
        'scrollProgressHint': scrollProgressHint,
        'rectHint': rectHint == null
            ? null
            : {
                'left': rectHint!.left,
                'top': rectHint!.top,
                'right': rectHint!.right,
                'bottom': rectHint!.bottom,
              },
      };

  factory VocabContext.fromJson(Map<String, dynamic> json) {
    final pageOrPosition = json['pageOrPosition'] as String?;
    final inferredIndex = _parseNumericHint(pageOrPosition);
    final rectRaw = json['rectHint'];
    final rectMap = rectRaw is Map ? Map<String, dynamic>.from(rectRaw) : null;

    return VocabContext(
      id: json['id'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'manual',
      sourceName: json['sourceName'] as String?,
      pageOrPosition: pageOrPosition,
      sourceRef: json['sourceRef'] as String?,
      sourceRefType: json['sourceRefType'] as String?,
      surroundingText: json['surroundingText'] as String? ?? '',
      encounteredAt: json['encounteredAt'] != null
          ? DateTime.parse(json['encounteredAt'] as String)
          : DateTime.now(),
      anchorText: json['anchorText'] as String?,
      pageIndexHint: (json['pageIndexHint'] as num?)?.toInt() ??
          ((json['sourceType'] == 'pdf' && inferredIndex != null)
              ? inferredIndex - 1
              : null),
      lineIndexHint: (json['lineIndexHint'] as num?)?.toInt() ??
          ((json['sourceType'] == 'story' && inferredIndex != null)
              ? inferredIndex - 1
              : null),
      textStartOffset: (json['textStartOffset'] as num?)?.toInt(),
      textEndOffset: (json['textEndOffset'] as num?)?.toInt(),
      scrollProgressHint: (json['scrollProgressHint'] as num?)?.toDouble(),
      rectHint: rectMap == null
          ? null
          : Rect.fromLTRB(
              (rectMap['left'] as num?)?.toDouble() ?? 0,
              (rectMap['top'] as num?)?.toDouble() ?? 0,
              (rectMap['right'] as num?)?.toDouble() ?? 0,
              (rectMap['bottom'] as num?)?.toDouble() ?? 0,
            ),
    );
  }

  /// Tạo nhanh context "thủ công" (user tự nhập, không từ file)
  factory VocabContext.manual({String? note}) => VocabContext(
        id: 'ctx_${DateTime.now().millisecondsSinceEpoch}',
        sourceType: 'manual',
        surroundingText: note ?? '',
        encounteredAt: DateTime.now(),
      );

  /// Tạo context từ PDF
  factory VocabContext.fromPdf({
    required String fileName,
    required int page,
    required String surroundingText,
    String? pdfPath,
    String? anchorText,
    int? pageIndexHint,
    int? textStartOffset,
    int? textEndOffset,
    Rect? rectHint,
  }) =>
      VocabContext(
        id: 'ctx_${DateTime.now().millisecondsSinceEpoch}',
        sourceType: 'pdf',
        sourceName: fileName,
        pageOrPosition: 'trang $page',
        sourceRef: pdfPath,
        sourceRefType:
            pdfPath == null || pdfPath.trim().isEmpty ? null : 'pdfPath',
        surroundingText: surroundingText,
        encounteredAt: DateTime.now(),
        anchorText: anchorText,
        pageIndexHint: pageIndexHint ?? (page > 0 ? page - 1 : null),
        textStartOffset: textStartOffset,
        textEndOffset: textEndOffset,
        rectHint: rectHint,
      );

  /// Tạo context từ Web Reader
  factory VocabContext.fromWeb({
    required String url,
    String? pageTitle,
    required String surroundingText,
    String? anchorText,
    double? scrollProgressHint,
  }) {
    String host;
    String normalizedUrl = url.trim();
    try {
      final uri = Uri.parse(url);
      host = uri.host.replaceFirst('www.', '');
      normalizedUrl = uri.toString();
    } catch (_) {
      host = url;
    }

    return VocabContext(
      id: 'ctx_${DateTime.now().millisecondsSinceEpoch}',
      sourceType: 'web',
      sourceName: (pageTitle != null && pageTitle.trim().isNotEmpty)
          ? pageTitle.trim()
          : host,
      pageOrPosition: host,
      sourceRef: normalizedUrl,
      sourceRefType: normalizedUrl.trim().isEmpty ? null : 'webUrl',
      surroundingText: surroundingText,
      encounteredAt: DateTime.now(),
      anchorText: anchorText,
      scrollProgressHint: scrollProgressHint,
    );
  }

  /// Tạo context từ Read Mode / Story
  factory VocabContext.fromStory({
    required String storyTitle,
    required int lineIndex,
    required String surroundingText,
    String? sourceRef,
    String? sourceRefType,
    String? anchorText,
    int? textStartOffset,
    int? textEndOffset,
  }) =>
      VocabContext(
        id: 'ctx_${DateTime.now().millisecondsSinceEpoch}',
        sourceType: 'story',
        sourceName: storyTitle,
        pageOrPosition: 'Content',
        sourceRef: sourceRef,
        sourceRefType: sourceRefType,
        surroundingText: surroundingText,
        encounteredAt: DateTime.now(),
        anchorText: anchorText,
        lineIndexHint: lineIndex,
        textStartOffset: textStartOffset,
        textEndOffset: textEndOffset,
      );

  static int? _parseNumericHint(String? raw) {
    final text = raw ?? '';
    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static String _shortText(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1)}…';
  }

  static bool _sameRect(Rect a, Rect b) {
    const epsilon = 0.5;
    return (a.left - b.left).abs() <= epsilon &&
        (a.top - b.top).abs() <= epsilon &&
        (a.right - b.right).abs() <= epsilon &&
        (a.bottom - b.bottom).abs() <= epsilon;
  }
}