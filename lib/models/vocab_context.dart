/// Ngữ cảnh gặp từ vựng.
/// Mỗi lần user gặp lại từ ở nguồn/vị trí mới → tạo 1 VocabContext.
/// Nguyên tắc Context-Accumulation: nhiều context = từ quan trọng hơn.
class VocabContext {
  final String id;
  final String sourceType; // 'pdf', 'web', 'youtube', 'manual', 'clipboard', 'story'
  final String? sourceName; // "ML_101.pdf", "https://...", "YouTube: TED Talk"
  final String? pageOrPosition; // "trang 42", "02:15", "dòng 3"
  final String? sourceRef; // reopenable ref: path / url / cloud id if available
  final String? sourceRefType; // pdfPath | webUrl | localText | cloudText
  final String surroundingText; // Câu/đoạn văn chứa từ
  final DateTime encounteredAt;

  const VocabContext({
    required this.id,
    required this.sourceType,
    this.sourceName,
    this.pageOrPosition,
    this.sourceRef,
    this.sourceRefType,
    required this.surroundingText,
    required this.encounteredAt,
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
      sourceRef != null && sourceRef!.trim().isNotEmpty &&
      sourceRefType != null && sourceRefType!.trim().isNotEmpty;

  String get reopenActionLabel {
    switch (sourceRefType) {
      case 'pdfPath':
        return 'Mở PDF';
      case 'webUrl':
        return 'Mở Web';
      case 'localText':
      case 'cloudText':
        return 'Mở vào Đọc';
      default:
        return 'Mở lại';
    }
  }

  int? get numericPositionHint {
    final raw = pageOrPosition ?? '';
    final match = RegExp(r'(\d+)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
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
      };

  factory VocabContext.fromJson(Map<String, dynamic> json) => VocabContext(
        id: json['id'] as String? ?? '',
        sourceType: json['sourceType'] as String? ?? 'manual',
        sourceName: json['sourceName'] as String?,
        pageOrPosition: json['pageOrPosition'] as String?,
        sourceRef: json['sourceRef'] as String?,
        sourceRefType: json['sourceRefType'] as String?,
        surroundingText: json['surroundingText'] as String? ?? '',
        encounteredAt: json['encounteredAt'] != null
            ? DateTime.parse(json['encounteredAt'] as String)
            : DateTime.now(),
      );

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
      );

  /// Tạo context từ Web Reader
  factory VocabContext.fromWeb({
    required String url,
    String? pageTitle,
    required String surroundingText,
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
      sourceRefType:
          normalizedUrl.trim().isEmpty ? null : 'webUrl',
      surroundingText: surroundingText,
      encounteredAt: DateTime.now(),
    );
  }

  /// Tạo context từ Read Mode / Story
  factory VocabContext.fromStory({
    required String storyTitle,
    required int lineIndex,
    required String surroundingText,
    String? sourceRef,
    String? sourceRefType,
  }) =>
      VocabContext(
        id: 'ctx_${DateTime.now().millisecondsSinceEpoch}',
        sourceType: 'story',
        sourceName: storyTitle,
        pageOrPosition: 'dòng ${lineIndex + 1}',
        sourceRef: sourceRef,
        sourceRefType: sourceRefType,
        surroundingText: surroundingText,
        encounteredAt: DateTime.now(),
      );
}
