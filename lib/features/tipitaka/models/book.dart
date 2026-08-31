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

  const TipitakaBook({
    required this.id,
    required this.collectionId,
    required this.code,
    required this.namePali,
    required this.nameEn,
    required this.nameVi,
    required this.orderIndex,
    this.metadataJson,
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
      );

  @override
  List<Object?> get props => [id, collectionId, code, namePali, nameEn, nameVi, orderIndex];
}