/// Metadata cho 1 từ điển đã import
class DictInfo {
  final String id; // unique ID (hash of filename)
  final String name; // tên hiển thị (từ MDX header hoặc filename)
  final String? sourceLang; // ngôn ngữ nguồn (en, ja, zh, pali…)
  final String? targetLang; // ngôn ngữ đích (vi, en…)
  final int entryCount; // số entry
  final String dbPath; // đường dẫn SQLite DB
  final String? resourcePath; // đường dẫn MDD resources
  final bool enabled; // bật/tắt
  final DateTime importedAt;

  const DictInfo({
    required this.id,
    required this.name,
    this.sourceLang,
    this.targetLang,
    required this.entryCount,
    required this.dbPath,
    this.resourcePath,
    this.enabled = true,
    required this.importedAt,
  });

  /// Label ngôn ngữ hiển thị
  String get langPairLabel {
    final s = sourceLang?.toUpperCase() ?? '?';
    final t = targetLang?.toUpperCase() ?? '?';
    return '$s → $t';
  }

  DictInfo copyWith({
    String? name,
    String? sourceLang,
    String? targetLang,
    int? entryCount,
    String? dbPath,
    String? resourcePath,
    bool? enabled,
  }) =>
      DictInfo(
        id: id,
        name: name ?? this.name,
        sourceLang: sourceLang ?? this.sourceLang,
        targetLang: targetLang ?? this.targetLang,
        entryCount: entryCount ?? this.entryCount,
        dbPath: dbPath ?? this.dbPath,
        resourcePath: resourcePath ?? this.resourcePath,
        enabled: enabled ?? this.enabled,
        importedAt: importedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'entry_count': entryCount,
        'db_path': dbPath,
        'resource_path': resourcePath,
        'enabled': enabled,
        'imported_at': importedAt.toIso8601String(),
      };

  factory DictInfo.fromJson(Map<String, dynamic> json) => DictInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        sourceLang: json['source_lang'] as String?,
        targetLang: json['target_lang'] as String?,
        entryCount: json['entry_count'] as int,
        dbPath: json['db_path'] as String,
        resourcePath: json['resource_path'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        importedAt: DateTime.parse(json['imported_at'] as String),
      );
}
