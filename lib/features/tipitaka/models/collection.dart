import 'package:equatable/equatable.dart';

class TipitakaCollection extends Equatable {
  final int id;
  final String namePali;
  final String nameEn;
  final String nameVi;
  final int orderIndex;

  const TipitakaCollection({
    required this.id,
    required this.namePali,
    required this.nameEn,
    required this.nameVi,
    required this.orderIndex,
  });

  factory TipitakaCollection.fromMap(Map<String, dynamic> m) => TipitakaCollection(
        id: m['id'] as int,
        namePali: m['name_pali'] ?? m['namePali'] ?? '',
        nameEn: m['name_en'] ?? m['nameEn'] ?? '',
        nameVi: m['name_vi'] ?? m['nameVi'] ?? '',
        orderIndex: m['order_index'] ?? m['orderIndex'] ?? 0,
      );

  @override
  List<Object?> get props => [id, namePali, nameEn, nameVi, orderIndex];
}