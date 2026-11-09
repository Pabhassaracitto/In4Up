import 'package:equatable/equatable.dart';

/// A user-owned annotation attached to one canonical Tipiṭaka segment.
class TipitakaHighlight extends Equatable {
  final int id;
  final int bookId;
  final int segmentId;
  final String color;
  final String note;
  final int updatedAt;
  final String reference;
  final String paliText;
  final String translation;
  final String bookTitle;

  const TipitakaHighlight({
    required this.id,
    required this.bookId,
    required this.segmentId,
    required this.color,
    required this.note,
    required this.updatedAt,
    this.reference = '',
    this.paliText = '',
    this.translation = '',
    this.bookTitle = '',
  });

  factory TipitakaHighlight.fromMap(Map<String, Object?> map) =>
      TipitakaHighlight(
        id: map['id'] as int,
        bookId: map['book_id'] as int,
        segmentId: map['segment_id'] as int,
        color: '${map['color'] ?? 'yellow'}',
        note: '${map['note'] ?? ''}',
        updatedAt: map['updated_at'] as int? ?? 0,
        reference: '${map['reference'] ?? ''}',
        paliText: '${map['pali_text'] ?? ''}',
        translation: '${map['translation'] ?? ''}',
        bookTitle: '${map['book_title'] ?? ''}',
      );

  @override
  List<Object?> get props => [id, bookId, segmentId, color, note, updatedAt];
}
