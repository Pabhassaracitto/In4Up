import 'dart:convert';

import 'package:equatable/equatable.dart';

class TipitakaBook extends Equatable {
  final int id;
  final int collectionId;
  final String code; // e.g. DN, MN
  final String namePali;
  final String nameEn;
  final String nameVi;
  final int orderIndex;
  final String? metadataJson;

  /// Titles inferred from structural content rows. They are query aliases, so
  /// older normalized databases gain useful titles without a destructive
  /// migration.
  final String contentTitlePali;
  final String contentTitleEn;
  final String contentTitleVi;
  final String contentTitleLocale;

  const TipitakaBook({
    required this.id,
    required this.collectionId,
    required this.code,
    required this.namePali,
    required this.nameEn,
    required this.nameVi,
    required this.orderIndex,
    this.metadataJson,
    this.contentTitlePali = '',
    this.contentTitleEn = '',
    this.contentTitleVi = '',
    this.contentTitleLocale = '',
  });

  factory TipitakaBook.fromMap(Map<String, dynamic> m) => TipitakaBook(
        id: m['id'] as int,
        collectionId: m['collection_id'] ?? m['collectionId'] ?? 0,
        code: m['code'] ?? '',
        namePali: m['name_pali'] ?? m['namePali'] ?? '',
        nameEn: m['name_en'] ?? m['nameEn'] ?? '',
        nameVi: m['name_vi'] ?? m['nameVi'] ?? '',
        orderIndex: m['order_index'] ?? m['orderIndex'] ?? 0,
        metadataJson: m['metadata_json'] ?? m['metadataJson'],
        contentTitlePali: m['_content_title_pali'] ?? '',
        contentTitleEn: m['_content_title_en'] ?? '',
        contentTitleVi: m['_content_title_vi'] ?? '',
        contentTitleLocale: m['_content_title_locale'] ?? '',
      );

  TipitakaBookIndex get catalogIndex => TipitakaBookIndex.fromBook(this);

  /// Main catalogue titles must describe content, never expose a Pa-Auk table
  /// identifier such as `ABH01A_ATT`. Technical codes remain available through
  /// [catalogIndex] for the details/debug sheet and source anchors.
  String displayTitle(String languageCode) {
    final candidates = languageCode == 'vi'
        ? [
            contentTitleLocale,
            contentTitleVi,
            contentTitlePali,
            contentTitleEn,
            nameVi,
            namePali,
            nameEn,
          ]
        : [
            contentTitleLocale,
            contentTitleEn,
            contentTitlePali,
            contentTitleVi,
            nameEn,
            namePali,
            nameVi,
          ];
    for (final value in candidates) {
      final title = value.trim();
      if (title.isNotEmpty && !_looksTechnical(title)) return title;
    }
    return languageCode == 'vi'
        ? 'Tuyển tập chính văn ${orderIndex + 1}'
        : 'Canonical collection ${orderIndex + 1}';
  }

  bool isTechnicalTitle(String value) => _looksTechnical(value);

  bool _looksTechnical(String value) {
    final compact = value
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final normalizedCode = code
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    if (compact == normalizedCode || compact == catalogIndex.sourceTable.toUpperCase()) {
      return true;
    }
    return RegExp(r'^[A-Z]{1,8}\d{1,4}[A-Z]?(?:_[A-Z0-9]+)*$')
            .hasMatch(compact) ||
        RegExp(r'^(PĀḶI|PĀLI|SOURCE|DEMO)(?:\s|$)', caseSensitive: false)
            .hasMatch(value.trim());
  }

  @override
  List<Object?> get props => [
        id,
        collectionId,
        code,
        namePali,
        nameEn,
        nameVi,
        orderIndex,
        contentTitlePali,
        contentTitleEn,
        contentTitleVi,
        contentTitleLocale,
      ];
}

/// Stable catalogue labels for Pa-Auk identifiers such as
/// `abh01a_att`, `ABH01A_ATT`, and `vin01m_mul`.
class TipitakaBookIndex {
  final String canonicalCode;
  final String editionCode;
  final String normalizedCode;
  final String sourceTable;

  const TipitakaBookIndex({
    required this.canonicalCode,
    required this.editionCode,
    required this.normalizedCode,
    required this.sourceTable,
  });

  factory TipitakaBookIndex.fromBook(TipitakaBook book) {
    final normalized = book.code
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceFirst(RegExp(r'^_'), '')
        .replaceFirst(RegExp(r'_$'), '');
    String? metadataSource;
    final metadata = book.metadataJson?.trim();
    if (metadata != null && metadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadata);
        if (decoded is Map) {
          final value = decoded['source_table'];
          if (value is String && value.trim().isNotEmpty) {
            metadataSource = value.trim();
          }
        }
      } on FormatException {
        // Legacy rows can contain non-JSON metadata; use the code fallback.
      }
    }
    final source = metadataSource ??
        (book.namePali.trim().isEmpty
            ? normalized.toLowerCase()
            : book.namePali.trim());
    final match = RegExp(r'^([A-Z]{2,6}\d{1,3}[MAT])(?:_?([A-Z]+))?$')
        .firstMatch(normalized);
    if (match != null) {
      return TipitakaBookIndex(
        canonicalCode: match.group(1)!,
        editionCode: match.group(2) ?? '',
        normalizedCode: normalized,
        sourceTable: source,
      );
    }
    final parts = normalized.split(RegExp(r'[_\s-]+'));
    return TipitakaBookIndex(
      canonicalCode: parts.first,
      editionCode: parts.length > 1 ? parts.sublist(1).join('_') : '',
      normalizedCode: normalized,
      sourceTable: source,
    );
  }

  String get editionLabel {
    switch (editionCode) {
      case 'MUL':
        return 'Mūla';
      case 'ATT':
        return 'Aṭṭhakathā';
      case 'TIK':
        return 'Ṭīkā';
      default:
        return editionCode;
    }
  }

  /// Edition-independent family (`VIN01M`/`VIN01A`/`VIN01T` → `VIN01`).
  String get parallelFamilyCode {
    final match = RegExp(r'^([A-Z]{2,6}\d{1,3})[MAT]$').firstMatch(canonicalCode);
    return match?.group(1) ?? canonicalCode;
  }

  String get compactLabel => editionCode.isEmpty
      ? canonicalCode
      : '$canonicalCode · $editionCode';
}
