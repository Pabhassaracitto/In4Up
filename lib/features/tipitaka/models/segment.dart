import 'package:equatable/equatable.dart';

class TipitakaSegment extends Equatable {
  final int id;
  final int bookId;
  final int? sectionId;
  final String reference; // citation e.g. DN 1.1
  final int? paragraphNo;
  final String blockType;
  final String paliText;
  final String? translationEn;
  final String? translationVi;
  final String? translationMy;
  final String? translationTh;
  final String sourceTable;
  final String sourceRowKey;
  final Map<String, String> translations;
  final int orderIndex;

  const TipitakaSegment({
    required this.id,
    required this.bookId,
    this.sectionId,
    required this.reference,
    this.paragraphNo,
    this.blockType = 'paragraph',
    required this.paliText,
    this.translationEn,
    this.translationVi,
    this.translationMy,
    this.translationTh,
    this.sourceTable = '',
    this.sourceRowKey = '',
    this.translations = const {},
    required this.orderIndex,
  });

  factory TipitakaSegment.fromMap(Map<String, dynamic> m) => TipitakaSegment(
        id: m['id'] as int,
        bookId: m['book_id'] ?? m['bookId'] ?? 0,
        sectionId: m['section_id'] ?? m['sectionId'],
        reference: m['reference'] ?? '',
        paragraphNo: m['paragraph_no'] ?? m['paragraphNo'],
        blockType: m['block_type'] ?? m['blockType'] ?? 'paragraph',
        paliText: m['pali_text'] ?? m['paliText'] ?? '',
        translationEn: m['translation_en'] ?? m['translationEn'],
        translationVi: m['translation_vi'] ?? m['translationVi'],
        translationMy: m['translation_my'] ?? m['translationMy'],
        translationTh: m['translation_th'] ?? m['translationTh'],
        sourceTable: m['source_table'] ?? m['sourceTable'] ?? '',
        sourceRowKey: m['source_row_key'] ?? m['sourceRowKey'] ?? '',
        translations: m['translations'] is Map
            ? Map<String, String>.from(m['translations'] as Map)
            : const {},
        orderIndex: m['order_index'] ?? m['orderIndex'] ?? 0,
      );

  String translationFor(String languageCode) {
    switch (languageCode) {
      case 'vi':
        return translationVi ?? '';
      case 'en':
        return translationEn ?? '';
      case 'my':
        return translationMy ?? '';
      case 'th':
        return translationTh ?? '';
      default:
        return translations[languageCode] ?? '';
    }
  }

  MapEntry<String, String>? get firstTranslation {
    for (final entry in <String, String?>{
      'vi': translationVi,
      'en': translationEn,
      'my': translationMy,
      'th': translationTh,
      ...translations,
    }.entries) {
      if ((entry.value ?? '').trim().isNotEmpty) {
        return MapEntry(entry.key, entry.value!);
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        sectionId,
        reference,
        paragraphNo,
        blockType,
        paliText,
        translationEn,
        translationVi,
        translationMy,
        translationTh,
        sourceTable,
        sourceRowKey,
        translations,
        orderIndex,
      ];
}