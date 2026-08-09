// lib/features/canon/models/canon_entry.dart
//
// Model cho một bài Kinh/đoạn Kinh chuẩn dạng .md
// Được parse từ file assets/canon/*.md có Front Matter YAML.

import 'package:flutter/foundation.dart';

class CanonEntry {
  final String id;
  final String slug;
  final String title;
  final String titlePali;
  final String category;
  final String collection;
  final List<String> tags;
  final String paliRef;
  final String translator;
  final String language;
  final String sourcePath;

  /// Headers đã parse (để hiển thị metadata)
  final Map<String, dynamic> rawFrontMatter;

  /// Nội dung markdown thuần (đã bỏ front matter)
  final String markdownContent;

  /// Plain text (đã strip markdown) — dùng cho FTS
  final String plainText;

  /// Ghi chú cá nhân (lưu riêng trong Hive, không nằm trong .md)
  final String? personalNote;

  /// Thời gian load (để sort)
  final DateTime loadedAt;

  const CanonEntry({
    required this.id,
    required this.slug,
    required this.title,
    required this.titlePali,
    required this.category,
    required this.collection,
    required this.tags,
    required this.paliRef,
    required this.translator,
    required this.language,
    required this.sourcePath,
    required this.rawFrontMatter,
    required this.markdownContent,
    required this.plainText,
    this.personalNote,
    required this.loadedAt,
  });

  /// Preview ngắn (200 ký tự đầu của plainText)
  String get preview {
    final t = plainText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= 200) return t;
    return '${t.substring(0, 197)}...';
  }

  /// Số từ (đếm theo whitespace)
  int get wordCount => plainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  int get lineCount => markdownContent.split('\n').where((l) => l.trim().isNotEmpty).length;

  CanonEntry copyWith({String? personalNote}) => CanonEntry(
        id: id,
        slug: slug,
        title: title,
        titlePali: titlePali,
        category: category,
        collection: collection,
        tags: tags,
        paliRef: paliRef,
        translator: translator,
        language: language,
        sourcePath: sourcePath,
        rawFrontMatter: rawFrontMatter,
        markdownContent: markdownContent,
        plainText: plainText,
        personalNote: personalNote ?? this.personalNote,
        loadedAt: loadedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'title': title,
        'titlePali': titlePali,
        'category': category,
        'collection': collection,
        'tags': tags,
        'paliRef': paliRef,
        'translator': translator,
        'language': language,
        'sourcePath': sourcePath,
        'rawFrontMatter': rawFrontMatter,
        'markdownContent': markdownContent,
        'plainText': plainText,
        'personalNote': personalNote,
        'loadedAt': loadedAt.toIso8601String(),
      };

  factory CanonEntry.fromJson(Map<String, dynamic> json) => CanonEntry(
        id: json['id'] as String,
        slug: json['slug'] as String? ?? '',
        title: json['title'] as String? ?? '',
        titlePali: json['titlePali'] as String? ?? '',
        category: json['category'] as String? ?? 'phat_phap_chuan',
        collection: json['collection'] as String? ?? '',
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        paliRef: json['paliRef'] as String? ?? '',
        translator: json['translator'] as String? ?? '',
        language: json['language'] as String? ?? 'vi',
        sourcePath: json['sourcePath'] as String? ?? '',
        rawFrontMatter: (json['rawFrontMatter'] as Map?)?.cast<String, dynamic>() ?? const {},
        markdownContent: json['markdownContent'] as String? ?? '',
        plainText: json['plainText'] as String? ?? '',
        personalNote: json['personalNote'] as String?,
        loadedAt: DateTime.tryParse(json['loadedAt'] as String? ?? '') ?? DateTime.now(),
      );

  @override
  String toString() => 'CanonEntry(id:$id, title:$title, tags:$tags)';
}
