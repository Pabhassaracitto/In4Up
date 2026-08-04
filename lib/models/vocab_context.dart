/// Ngữ cảnh gặp từ vựng.
/// Mỗi lần user gặp lại từ ở nguồn/vị trí mới → tạo 1 VocabContext.
/// Nguyên tắc Context-Accumulation: nhiều context = từ quan trọng hơn.
class VocabContext {
  final String id;
  final String sourceType; // 'pdf', 'web', 'youtube', 'manual', 'clipboard'
  final String? sourceName; // "ML_101.pdf", "https://...", "YouTube: TED Talk"
  final String? pageOrPosition; // "trang 42", "02:15", "đoạn 3"
  final String surroundingText; // Câu/đoạn văn chứa từ (để bold highlight)
  final DateTime encounteredAt;

  const VocabContext({
    required this.id,
    required this.sourceType,
    this.sourceName,
    this.pageOrPosition,
    required this.surroundingText,
    required this.encounteredAt,
  });

  /// Nhãn hiển thị ngắn gọn cho UI
  String get displaySource {
    if (sourceName != null && sourceName!.isNotEmpty) {
      final short = sourceName!.length > 30
          ? '${sourceName!.substring(0, 27)}...'
          : sourceName!;
      if (pageOrPosition != null) return '$short, $pageOrPosition';
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceType': sourceType,
        'sourceName': sourceName,
        'pageOrPosition': pageOrPosition,
        'surroundingText': surroundingText,
        'encounteredAt': encounteredAt.toIso8601String(),
      };

  factory VocabContext.fromJson(Map<String, dynamic> json) => VocabContext(
        id: json['id'] as String? ?? '',
        sourceType: json['sourceType'] as String? ?? 'manual',
        sourceName: json['sourceName'] as String?,
        pageOrPosition: json['pageOrPosition'] as String?,
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
  }) =>
      VocabContext(
        id: 'ctx_${DateTime.now().millisecondsSinceEpoch}',
        sourceType: 'pdf',
        sourceName: fileName,
        pageOrPosition: 'trang $page',
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
    try {
      host = Uri.parse(url).host.replaceFirst('www.', '');
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
      surroundingText: surroundingText,
      encounteredAt: DateTime.now(),
    );
  }

  /// Tạo context từ Read Mode / Story
  factory VocabContext.fromStory({
    required String storyTitle,
    required int lineIndex,
    required String surroundingText,
  }) =>
      VocabContext(
        id: 'ctx_${DateTime.now().millisecondsSinceEpoch}',
        sourceType: 'story',
        sourceName: storyTitle,
        pageOrPosition: 'dòng ${lineIndex + 1}',
        surroundingText: surroundingText,
        encounteredAt: DateTime.now(),
      );
}
