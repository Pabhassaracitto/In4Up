import 'package:equatable/equatable.dart';

class TipitakaSegment extends Equatable {
  final int id;
  final int bookId;
  final int? sectionId;
  final String reference; // citation e.g. DN 1.1
  final int? paragraphNo;
  final String paliText;
  final String? translationEn;
  final String? translationVi;
  final String? translationMy;
  final String? translationTh;
  final int orderIndex;

  const TipitakaSegment({
    required this.id,
    required this.bookId,
    this.sectionId,
    required this.reference,
    this.paragraphNo,
    required this.paliText,
    this.translationEn,
    this.translationVi,
    this.translationMy,
    this.translationTh,
    required this.orderIndex,
  });

  factory TipitakaSegment.fromMap(Map<String, dynamic> m) => TipitakaSegment(
        id: m['id'] as int,
        bookId: m['book_id'] ?? m['bookId'] ?? 0,
        sectionId: m['section_id'] ?? m['sectionId'],
        reference: m['reference'] ?? '',
        paragraphNo: m['paragraph_no'] ?? m['paragraphNo'],
        paliText: m['pali_text'] ?? m['paliText'] ?? '',
        translationEn: m['translation_en'] ?? m['translationEn'],
        translationVi: m['translation_vi'] ?? m['translationVi'],
        translationMy: m['translation_my'] ?? m['translationMy'],
        translationTh: m['translation_th'] ?? m['translationTh'],
        orderIndex: m['order_index'] ?? m['orderIndex'] ?? 0,
      );

  @override
  List<Object?> get props => [
        id,
        bookId,
        sectionId,
        reference,
        paragraphNo,
        paliText,
        translationEn,
        translationVi,
        orderIndex,
      ];
}