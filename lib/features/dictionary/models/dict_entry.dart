import '../services/dict_text_cleaner.dart';

/// Model cho 1 entry trong từ điển MDX
class DictEntry {
  final String headword;
  final String definition;
  final String? phonetic;
  final String? audioPath;
  final String? partOfSpeech;
  final String dictId;

  const DictEntry({
    required this.headword,
    required this.definition,
    this.phonetic,
    this.audioPath,
    this.partOfSpeech,
    required this.dictId,
  });

  /// Text nghĩa đã làm sạch HTML/CSS/script/entity + dòng lặp headword.
  ///
  /// DICT-CLEAN-001: thay pipeline `replaceAll('<[^>]*>')` cũ (vẫn để lại
  /// `{color:…}`, `&nbsp;`, script, URL, tiêu đề lặp). Vẫn GIỮ chuỗi IPA
  /// trong text để `IpaDefinitionExtractor` trích được (ADR-0005).
  String get plainDefinition =>
      DictTextCleaner.plain(definition, headword: headword);

  /// Nội dung có cấu trúc (IPA + nhóm loại từ + nghĩa đánh số + ví dụ).
  ///
  /// Dùng cho hiển thị từ điển thật; `plainDefinition` chỉ là chuỗi phẳng.
  DictDefinition get definitionView =>
      DictTextCleaner.parse(definition, headword: headword);

  /// Nghĩa cô đọng (2 nghĩa đầu, tối đa ~200 ký tự) cho auto-fill, popup,
  /// preview — KHÔNG đổ cả entry dài vào ô "nghĩa" của thẻ từ.
  String get compactDefinition =>
      definitionView.compactMeaning(maxSenses: 2, maxChars: 200);

  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'headword': headword,
        'definition': definition,
        'phonetic': phonetic,
        'audio_path': audioPath,
        'part_of_speech': partOfSpeech,
        'dict_id': dictId,
      };

  factory DictEntry.fromMap(Map<String, dynamic> map) => DictEntry(
        headword: map['headword'] as String,
        definition: map['definition'] as String,
        phonetic: map['phonetic'] as String?,
        audioPath: map['audio_path'] as String?,
        partOfSpeech: map['part_of_speech'] as String?,
        dictId: map['dict_id'] as String,
      );

  @override
  String toString() => 'DictEntry($headword, dict=$dictId)';
}
