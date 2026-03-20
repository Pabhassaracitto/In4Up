//
// Models, enums, settings cho Word List tool.

import 'package:flutter/material.dart';
import '../../memory_mode/models/memory_item.dart';
import '../../memory_mode/models/memory_stage.dart';

// ─── Sort Mode ────────────────────────────────────────────
enum WordListSortMode {
  addTime('Thời gian thêm', Icons.access_time),
  alphabetical('A → Z', Icons.sort_by_alpha),
  alphabeticalDesc('Z → A', Icons.sort_by_alpha),
  rankDescending('Độ thuần thục ↓', Icons.trending_down),
  familiarity('Quen thuộc', Icons.favorite_outline),
  random('Ngẫu nhiên', Icons.shuffle);

  final String label;
  final IconData icon;
  const WordListSortMode(this.label, this.icon);
}

// ─── Display Settings ─────────────────────────────────────
class WordListSettings {
  final bool showWord;
  final bool showPhonetic;
  final bool showNumber;
  final bool showShortDefinition;
  final bool showFullDefinition;
  final bool showExample;
  final bool definitionsExpanded; // global expand/collapse

  const WordListSettings({
    this.showWord = true,
    this.showPhonetic = true,
    this.showNumber = true,
    this.showShortDefinition = true,
    this.showFullDefinition = false,
    this.showExample = false,
    this.definitionsExpanded = false,
  });

  WordListSettings copyWith({
    bool? showWord,
    bool? showPhonetic,
    bool? showNumber,
    bool? showShortDefinition,
    bool? showFullDefinition,
    bool? showExample,
    bool? definitionsExpanded,
  }) =>
      WordListSettings(
        showWord: showWord ?? this.showWord,
        showPhonetic: showPhonetic ?? this.showPhonetic,
        showNumber: showNumber ?? this.showNumber,
        showShortDefinition: showShortDefinition ?? this.showShortDefinition,
        showFullDefinition: showFullDefinition ?? this.showFullDefinition,
        showExample: showExample ?? this.showExample,
        definitionsExpanded: definitionsExpanded ?? this.definitionsExpanded,
      );
}

// ─── Word Entry (unified — từ MemoryItem hoặc tự thêm) ────
class WordEntry {
  final String id;
  final String word;
  final String? phonetic;
  final String? shortDefinition; // = meaning ngắn
  final String? fullDefinition;  // = meaning đầy đủ
  final String? example;
  final String? wordType;        // noun, verb, adj...
  final MemoryStage? stage;      // null nếu tự thêm (không qua SRS)
  final double strength;         // 0.0 → 1.0
  final DateTime addedAt;
  int repeatCount;               // số lần phát TTS (mặc định 1)
  final bool isFromMemory;       // true = từ MemoryMode

  WordEntry({
    required this.id,
    required this.word,
    this.phonetic,
    this.shortDefinition,
    this.fullDefinition,
    this.example,
    this.wordType,
    this.stage,
    this.strength = 0.0,
    required this.addedAt,
    this.repeatCount = 1,
    this.isFromMemory = false,
  });

  // Tạo từ MemoryItem
  factory WordEntry.fromMemoryItem(MemoryItem item) => WordEntry(
        id: item.id,
        word: item.word,
        phonetic: item.phonetic,
        shortDefinition: item.meaning,
        fullDefinition: item.meaning, // extend sau nếu có
        example: item.example ?? item.context,
        wordType: item.wordType,
        stage: item.stage,
        strength: item.strength,
        addedAt: item.createdAt,
        isFromMemory: true,
      );

  // Tạo thủ công
  factory WordEntry.manual({
    required String id,
    required String word,
    String? phonetic,
    String? shortDefinition,
    String? fullDefinition,
    String? example,
    String? wordType,
  }) =>
      WordEntry(
        id: id,
        word: word,
        phonetic: phonetic,
        shortDefinition: shortDefinition,
        fullDefinition: fullDefinition,
        example: example,
        wordType: wordType,
        addedAt: DateTime.now(),
        isFromMemory: false,
      );

  WordEntry copyWithRepeat(int count) => WordEntry(
        id: id,
        word: word,
        phonetic: phonetic,
        shortDefinition: shortDefinition,
        fullDefinition: fullDefinition,
        example: example,
        wordType: wordType,
        stage: stage,
        strength: strength,
        addedAt: addedAt,
        repeatCount: count,
        isFromMemory: isFromMemory,
      );
}

// ─── Folder / Group ───────────────────────────────────────
class WordFolder {
  static const WordFolder defaultFolder = WordFolder(
    id: 'default',
    name: 'Default',
    icon: Icons.folder_outlined,
    color: Color(0xFF6C63FF),
  );

  static const WordFolder allWords = WordFolder(
    id: '_all',
    name: 'All words',
    icon: Icons.list_alt,
    color: Color(0xFF2196F3),
  );

  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const WordFolder({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}
