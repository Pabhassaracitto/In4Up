// lib/features/dictionary/models/dict_pack.dart
//
// DICT-PACK-001 (owner 2026-10-25): "Cho phép người dùng tải bộ từ điển ở
// setting home."
//
// Trước đây muốn có từ điển, người dùng PHẢI tự tìm file .mdx/.mdd/.css trên
// mạng rồi import thủ công — quá khó với người không chuyên. Nay có danh mục
// (`catalog`) các "bộ từ điển" đóng gói sẵn (ZIP chứa mdx + mdd + css) mà app
// tải và cài bằng một nút.
//
// Thiết kế:
// - [DictPack] là MỘT dòng trong danh mục: thông tin hiển thị + URL tải +
//   (tuỳ chọn) SHA-256 để chống file hỏng/bị thay.
// - [DictPackCatalog] parse JSON danh mục, chịu lỗi tốt (field thiếu ⇒ bỏ dòng
//   đó thay vì làm sập cả danh mục) — vì danh mục do NGƯỜI dùng/owner tự host
//   (HuggingFace/GitHub Pages/CDN) nên phải giả định dữ liệu chưa hoàn hảo.
// - Model THUẦN Dart: test được bằng `flutter test`, không cần mạng/DB.
//
// Định dạng JSON (xem `assets/dictionary/packs.json` để có bản mẫu):
// {
//   "version": 1,
//   "updated": "2026-10-25",
//   "packs": [
//     {
//       "id": "en-vi-example",
//       "name": "Anh–Việt (ví dụ)",
//       "description": "…",
//       "sourceLang": "en",
//       "targetLang": "vi",
//       "sizeMb": 42.5,
//       "entryCount": 120000,
//       "version": "2026.10",
//       "downloadUrl": "https://…/dict.zip",
//       "sha256": "…",              // tuỳ chọn
//       "license": "…",             // tuỳ chọn
//       "homepage": "https://…"     // tuỳ chọn
//     }
//   ]
// }

import 'dart:convert';

/// Một bộ từ điển có thể tải trong danh mục.
class DictPack {
  final String id;
  final String name;
  final String description;
  final String? sourceLang;
  final String? targetLang;

  /// Dung lượng ước tính (MB) — chỉ để hiển thị trước khi tải.
  final double? sizeMb;

  final int? entryCount;

  /// Phiên bản của BỘ TỪ ĐIỂN (không phải của app) — dùng để nhắc cập nhật.
  final String? version;

  /// URL file ZIP (hoặc trực tiếp .mdx/.mdd) — bắt buộc.
  final String downloadUrl;

  /// SHA-256 hex (tuỳ chọn). Có thì app kiểm tra sau khi tải.
  final String? sha256;

  final String? license;
  final String? homepage;

  const DictPack({
    required this.id,
    required this.name,
    this.description = '',
    this.sourceLang,
    this.targetLang,
    this.sizeMb,
    this.entryCount,
    this.version,
    required this.downloadUrl,
    this.sha256,
    this.license,
    this.homepage,
  });

  bool get isEnglishVietnamese =>
      (sourceLang ?? '').toLowerCase() == 'en' &&
      (targetLang ?? '').toLowerCase() == 'vi';

  /// `EN → VI` (dùng cho chip ngôn ngữ).
  String get langPairLabel {
    final s = (sourceLang ?? '').toUpperCase();
    final t = (targetLang ?? '').toUpperCase();
    if (s.isEmpty && t.isEmpty) return '';
    return '${s.isEmpty ? '?' : s} → ${t.isEmpty ? '?' : t}';
  }

  /// `42.5 MB` (null ⇒ '').
  String get sizeLabel =>
      sizeMb == null ? '' : '${sizeMb!.toStringAsFixed(1)} MB';

  /// Parse MỘT dòng của danh mục. Trả null nếu thiếu trường bắt buộc.
  static DictPack? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    final url = (json['downloadUrl'] ?? json['url'] ?? '').toString().trim();
    if (id.isEmpty || url.isEmpty) return null;
    final size = json['sizeMb'];
    return DictPack(
      id: id,
      name: name.isEmpty ? id : name,
      description: (json['description'] ?? '').toString().trim(),
      sourceLang: _nullableString(json['sourceLang']),
      targetLang: _nullableString(json['targetLang']),
      sizeMb: size is num
          ? size.toDouble()
          : double.tryParse(size?.toString() ?? ''),
      entryCount: json['entryCount'] is num
          ? (json['entryCount'] as num).toInt()
          : int.tryParse(json['entryCount']?.toString() ?? ''),
      version: _nullableString(json['version']),
      downloadUrl: url,
      sha256: _nullableString(json['sha256']),
      license: _nullableString(json['license']),
      homepage: _nullableString(json['homepage']),
    );
  }

  static String? _nullableString(Object? value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  String toString() => 'DictPack($id, $downloadUrl)';
}

/// Danh mục bộ từ điển (JSON) + nguồn của nó (URL đã tải hoặc asset).
class DictPackCatalog {
  final List<DictPack> packs;
  final String? updated;

  /// URL danh mục đã dùng để tải (null khi đọc từ asset trong app).
  final String? sourceUrl;

  const DictPackCatalog({
    this.packs = const <DictPack>[],
    this.updated,
    this.sourceUrl,
  });

  static const DictPackCatalog empty = DictPackCatalog();

  bool get isEmpty => packs.isEmpty;

  DictPack? byId(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// Parse JSON danh mục. Chấp nhận cả `{"packs": [...]}` và `[...]` trần.
  /// Dòng hỏng bị BỎ, không làm hỏng cả danh mục.
  static DictPackCatalog fromJsonString(
    String raw, {
    String? sourceUrl,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return DictPackCatalog(sourceUrl: sourceUrl);
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return DictPackCatalog(sourceUrl: sourceUrl);
    }

    List<dynamic> rawPacks = const <dynamic>[];
    String? updated;
    if (decoded is Map) {
      final list = decoded['packs'];
      if (list is List) rawPacks = list;
      updated = _stringOrNull(decoded['updated']);
    } else if (decoded is List) {
      rawPacks = decoded;
    }

    final packs = <DictPack>[];
    final seen = <String>{};
    for (final item in rawPacks) {
      if (item is! Map) continue;
      final pack = DictPack.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (pack == null) continue;
      if (!seen.add(pack.id)) continue;
      packs.add(pack);
    }

    return DictPackCatalog(
      packs: packs,
      updated: updated,
      sourceUrl: sourceUrl,
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  DictPackCatalog copyWith({List<DictPack>? packs, String? updated}) =>
      DictPackCatalog(
        packs: packs ?? this.packs,
        updated: updated ?? this.updated,
        sourceUrl: sourceUrl,
      );
}
