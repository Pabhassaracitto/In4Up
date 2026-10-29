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

  String displayTitle(String languageCode) {
    final language = languageCode.toLowerCase().replaceAll('_', '-');
    final preferred = switch (language) {
      'pi' => [namePali, nameEn, nameVi],
      'vi' => [nameVi, namePali, nameEn],
      'en' => [nameEn, namePali, nameVi],
      _ => [namePali, nameEn, nameVi],
    };
    return preferred.map((value) => value.trim()).firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => 'Tipiṭaka',
        );
  }

  @override
  List<Object?> get props => [id, namePali, nameEn, nameVi, orderIndex];
}