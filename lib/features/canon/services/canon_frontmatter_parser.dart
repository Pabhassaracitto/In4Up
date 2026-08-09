// lib/features/canon/services/canon_frontmatter_parser.dart
//
// Parser Front Matter YAML đơn giản, không cần thêm dependency `yaml`.
// Đủ cho format của assets/canon/*.md:
//   ---
//   id: dhammapada_001
//   title: ...
//   tags: [a, b, c]
//   ---
//   markdown content

import '../models/canon_entry.dart';

class CanonFrontMatterParser {
  /// Parse raw markdown file -> CanonEntry
  static CanonEntry parse({
    required String raw,
    required String sourcePath,
  }) {
    final trimmed = raw.trimLeft();
    Map<String, dynamic> front = {};
    String markdown = raw;

    if (trimmed.startsWith('---')) {
      final end = trimmed.indexOf('\n---', 3);
      if (end != -1) {
        final fmRaw = trimmed.substring(3, end).trim();
        markdown = trimmed.substring(end + 4).trimLeft();
        front = _parseYamlLike(fmRaw);
      }
    }

    final plain = _stripMarkdown(markdown);

    return CanonEntry(
      id: (front['id'] ?? _slugFromPath(sourcePath)).toString(),
      slug: (front['slug'] ?? '').toString(),
      title: (front['title'] ?? _titleFromMarkdown(markdown) ?? 'Không có tiêu đề').toString(),
      titlePali: (front['title_pali'] ?? front['titlePali'] ?? '').toString(),
      category: (front['category'] ?? 'phat_phap_chuan').toString(),
      collection: (front['collection'] ?? '').toString(),
      tags: _parseTags(front['tags']),
      paliRef: (front['pali_ref'] ?? front['paliRef'] ?? '').toString(),
      translator: (front['translator'] ?? '').toString(),
      language: (front['language'] ?? 'vi').toString(),
      sourcePath: sourcePath,
      rawFrontMatter: front,
      markdownContent: markdown,
      plainText: plain,
      loadedAt: DateTime.now(),
    );
  }

  // ── Helpers ────────────────────────────────────────────

  static Map<String, dynamic> _parseYamlLike(String raw) {
    final map = <String, dynamic>{};
    final lines = raw.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final key = line.substring(0, colon).trim();
      var value = line.substring(colon + 1).trim();

      // bỏ quote
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      // list dạng [a, b, c]
      if (value.startsWith('[') && value.endsWith(']')) {
        final inner = value.substring(1, value.length - 1).trim();
        if (inner.isEmpty) {
          map[key] = <String>[];
        } else {
          final items = inner
              .split(',')
              .map((e) => e.trim().replaceAll(RegExp(r'''^["']|["']$'''), ''))
              .where((e) => e.isNotEmpty)
              .toList();
          map[key] = items;
        }
      } else {
        map[key] = value;
      }
    }
    return map;
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return const [];
      if (t.startsWith('[')) return _parseYamlLike('tags: $t')['tags'] as List<String>? ?? const [];
      return t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static String _slugFromPath(String path) {
    final name = path.split('/').last.split('.').first;
    return name;
  }

  static String? _titleFromMarkdown(String md) {
    final m = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(md);
    return m?.group(1)?.trim();
  }

  static String _stripMarkdown(String md) {
    var t = md;
    // bỏ code block, image, link giữ text
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    t = t.replaceAll(RegExp(r'`[^`]*`'), ' ');
    t = t.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
    t = t.replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '');
    // bỏ heading markers, blockquote, tables, hr
    t = t.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    t = t.replaceAll(RegExp(r'^\s*[-*]{3,}\s*$', multiLine: true), ' ');
    t = t.replaceAll(RegExp(r'\|'), ' ');
    t = t.replaceAll(RegExp(r'[*_~`#]+'), ' ');
    // HTML tags
    t = t.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // collapse whitespace
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }
}
