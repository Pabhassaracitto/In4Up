// lib/screens/read_mode/models/recent_file.dart

enum RecentFileType { localText, localPdf, cloud }

class RecentFile {
  final String id;
  final String title;
  final String? subtitle;
  final RecentFileType type;
  final String? localPath;
  final String? cloudId;
  final String? category;
  final DateTime lastOpened;
  final int totalLines;
  final int lastReadLine;
  final String? thumbnailEmoji;

  const RecentFile({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    this.localPath,
    this.cloudId,
    this.category,
    required this.lastOpened,
    this.totalLines = 0,
    this.lastReadLine = 0,
    this.thumbnailEmoji,
  });

  // ── Computed getters ────────────────────────────────────────
  double get readProgress =>
      totalLines > 0 ? (lastReadLine / totalLines).clamp(0.0, 1.0) : 0.0;

  bool get isNew => lastReadLine == 0 && totalLines == 0;

  bool get isCompleted => totalLines > 0 && lastReadLine >= totalLines - 1;

  bool get isInProgress => !isNew && !isCompleted;

  String get progressText {
    if (totalLines == 0) return 'Content';
    if (lastReadLine == 0) return 'Add';
    if (isCompleted) return 'Done';
    return 'Content';
  }

  String get typeLabel {
    switch (type) {
      case RecentFileType.localPdf:
        return 'PDF';
      case RecentFileType.cloud:
        return 'Cloud';
      case RecentFileType.localText:
        return 'Content';
    }
  }

  String get typeEmoji {
    switch (type) {
      case RecentFileType.localPdf:
        return '📄';
      case RecentFileType.cloud:
        return '☁️';
      case RecentFileType.localText:
        return '📝';
    }
  }

  // ── Serialization ───────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'type': type.name,
        'localPath': localPath,
        'cloudId': cloudId,
        'category': category,
        'lastOpened': lastOpened.toIso8601String(),
        'totalLines': totalLines,
        'lastReadLine': lastReadLine,
        'thumbnailEmoji': thumbnailEmoji,
      };

  factory RecentFile.fromJson(Map<String, dynamic> json) {
    return RecentFile(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Content',
      subtitle: json['subtitle'] as String?,
      type: RecentFileType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? ''),
        orElse: () => RecentFileType.localText,
      ),
      localPath: json['localPath'] as String?,
      cloudId: json['cloudId'] as String?,
      category: json['category'] as String?,
      lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ??
          DateTime.now(),
      totalLines: json['totalLines'] as int? ?? 0,
      lastReadLine: json['lastReadLine'] as int? ?? 0,
      thumbnailEmoji: json['thumbnailEmoji'] as String?,
    );
  }

  // ── CopyWith ────────────────────────────────────────────────
  RecentFile copyWith({
    String? title,
    String? subtitle,
    int? lastReadLine,
    int? totalLines,
    DateTime? lastOpened,
    String? thumbnailEmoji,
  }) =>
      RecentFile(
        id: id,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        type: type,
        localPath: localPath,
        cloudId: cloudId,
        category: category,
        lastOpened: lastOpened ?? this.lastOpened,
        totalLines: totalLines ?? this.totalLines,
        lastReadLine: lastReadLine ?? this.lastReadLine,
        thumbnailEmoji: thumbnailEmoji ?? this.thumbnailEmoji,
      );

  // ── Factory helpers ──────────────────────────────────────────

  /// Từ file text local (.txt / .lrc / .srt)
  factory RecentFile.fromLocalText(String path) {
    final normalizedPath = path.replaceAll("\\", "/");
    final name = normalizedPath.split('/').last;
    final title =
        name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    return RecentFile(
      id: 'local_${normalizedPath.toLowerCase().hashCode}',
      title: title,
      subtitle: normalizedPath,
      type: RecentFileType.localText,
      localPath: normalizedPath,
      lastOpened: DateTime.now(),
      thumbnailEmoji: '📝',
    );
  }

  /// Từ file PDF local
  factory RecentFile.fromLocalPdf(String path) {
    final normalizedPath = path.replaceAll("\\", "/");
    final name = normalizedPath.split('/').last;
    final title =
        name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    return RecentFile(
      id: 'pdf_${normalizedPath.toLowerCase().hashCode}',
      title: title,
      subtitle: normalizedPath,
      type: RecentFileType.localPdf,
      localPath: normalizedPath,
      lastOpened: DateTime.now(),
      thumbnailEmoji: '📄',
    );
  }

  /// Từ Cloud (TextLibraryEntry)
  factory RecentFile.fromCloud({
    required String id,
    required String title,
    String? category,
    int totalLines = 0,
  }) =>
      RecentFile(
        id: 'cloud_$id',
        title: title,
        subtitle: category,
        type: RecentFileType.cloud,
        cloudId: id,
        category: category,
        lastOpened: DateTime.now(),
        totalLines: totalLines,
        thumbnailEmoji: '☁️',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RecentFile && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RecentFile($id, $title, ${type.name})';
}