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

  String get plainDefinition {
    return definition
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

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
