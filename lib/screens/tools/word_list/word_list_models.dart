import 'package:flutter/material.dart';

// ─── Sort Mode ─────────────────────────────────────────────

enum WordListSortMode {
  addTime('Thời gian thêm', Icons.access_time),
  alphabetical('A → Z', Icons.sort_by_alpha),
  alphabeticalDesc('Z → A', Icons.sort_by_alpha),
  rankDescending('Độ thuần thục ↓', Icons.trending_down),
  familiarity('Quen thuộc', Icons.favorite_outline),
  random('Ngẫu nhiên', Icons.shuffle),
  sm2Due('SM-2: Cần ôn hôm nay', Icons.alarm),
  hardFirst('Khó → Dễ', Icons.keyboard_double_arrow_up),
  easyFirst('Dễ → Khó', Icons.keyboard_double_arrow_down);

  final String label;
  final IconData icon;
  const WordListSortMode(this.label, this.icon);
}

// ─── Settings ──────────────────────────────────────────────

class WordListSettings {
  final bool showWord;
  final bool showPhonetic;
  final bool showNumber;
  final bool showShortDefinition;
  final bool showFullDefinition;
  final bool showExample;
  final bool definitionsExpanded;

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
  }) {
    return WordListSettings(
      showWord: showWord ?? this.showWord,
      showPhonetic: showPhonetic ?? this.showPhonetic,
      showNumber: showNumber ?? this.showNumber,
      showShortDefinition: showShortDefinition ?? this.showShortDefinition,
      showFullDefinition: showFullDefinition ?? this.showFullDefinition,
      showExample: showExample ?? this.showExample,
      definitionsExpanded: definitionsExpanded ?? this.definitionsExpanded,
    );
  }
}

// ─── Folders ───────────────────────────────────────────────

class WordFolder {
  final String id;
  final String name;
  final IconData icon;

  const WordFolder({
    required this.id,
    required this.name,
    required this.icon,
  });

  static const allWords = WordFolder(
    id: 'all',
    name: 'Tất cả',
    icon: Icons.all_inclusive,
  );

  static const defaultFolder = WordFolder(
    id: 'default',
    name: 'Mặc định',
    icon: Icons.folder,
  );
}

// ─── Folder Tree (★ MỚI) ───────────────────────────────────

class FolderNode {
  final String id;
  String name;
  Color color;
  IconData icon;
  String? parentId;
  final List<FolderNode> children;
  bool isExpanded;

  FolderNode({
    required this.id,
    required this.name,
    this.color = const Color(0xFF6C63FF),
    this.icon = Icons.folder_outlined,
    this.parentId,
    List<FolderNode>? children,
    this.isExpanded = true,
  }) : children = children ?? [];
}

class FolderTreeManager {
  final List<FolderNode> _roots = [
    FolderNode(
      id: 'default',
      name: 'Mặc định',
      color: Color(0xFF6C63FF),
      icon: Icons.folder_outlined,
    ),
  ];

  List<FolderNode> get roots => List.unmodifiable(_roots);

  FolderNode? findById(String id) {
    FolderNode? search(List<FolderNode> nodes) {
      for (final n in nodes) {
        if (n.id == id) return n;
        final found = search(n.children);
        if (found != null) return found;
      }
      return null;
    }

    return search(_roots);
  }

  FolderNode addFolder({
    required String name,
    String? parentId,
    Color color = const Color(0xFF6C63FF),
    IconData icon = Icons.folder_outlined,
  }) {
    final node = FolderNode(
      id: 'folder_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      color: color,
      icon: icon,
      parentId: parentId,
    );
    if (parentId == null) {
      _roots.add(node);
    } else {
      findById(parentId)?.children.add(node);
    }
    return node;
  }

  void removeFolder(String id) {
    bool remove(List<FolderNode> nodes) {
      for (int i = 0; i < nodes.length; i++) {
        if (nodes[i].id == id) {
          nodes.removeAt(i);
          return true;
        }
        if (remove(nodes[i].children)) return true;
      }
      return false;
    }

    remove(_roots);
  }

  List<({FolderNode node, int depth})> flattenAll() {
    final result = <({FolderNode node, int depth})>[];
    void flatten(List<FolderNode> nodes, int depth) {
      for (final n in nodes) {
        result.add((node: n, depth: depth));
        if (n.isExpanded) flatten(n.children, depth + 1);
      }
    }

    flatten(_roots, 0);
    return result;
  }
}

// ─── Entry ─────────────────────────────────────────────────

class WordEntry {
  final String id;
  final String word;
  final String? meaning;
  final String? shortDefinition;
  final String? fullDefinition;
  final String? phonetic;
  final String? example;
  final String? wordType;
  final String folderId;
  final DateTime addedAt;
  final double strength;
  final DateTime? nextReview;

  const WordEntry({
    required this.id,
    required this.word,
    this.meaning,
    this.shortDefinition,
    this.fullDefinition,
    this.phonetic,
    this.example,
    this.wordType,
    this.folderId = 'default',
    required this.addedAt,
    this.strength = 0.0,
    this.nextReview,
  });

  factory WordEntry.manual({
    required String id,
    required String word,
    String? shortDefinition,
    String? phonetic,
    String? example,
    String? wordType,
    String folderId = 'default',
  }) {
    return WordEntry(
      id: id,
      word: word,
      shortDefinition: shortDefinition,
      meaning: shortDefinition,
      phonetic: phonetic,
      example: example,
      wordType: wordType,
      folderId: folderId,
      addedAt: DateTime.now(),
    );
  }

  bool get isSm2Due {
    if (nextReview == null) return false;
    return DateTime.now().isAfter(nextReview!);
  }

  WordEntry copyWith({
    String? id,
    String? word,
    String? folderId,
    String? shortDefinition,
    String? phonetic,
    String? example,
    String? wordType,
  }) {
    return WordEntry(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: shortDefinition ?? this.meaning,
      shortDefinition: shortDefinition ?? this.shortDefinition,
      phonetic: phonetic ?? this.phonetic,
      example: example ?? this.example,
      wordType: wordType ?? this.wordType,
      folderId: folderId ?? this.folderId,
      addedAt: addedAt,
      strength: strength,
      nextReview: nextReview,
      fullDefinition: fullDefinition,
    );
  }

  factory WordEntry.fromMemoryItem(dynamic item) {
    return WordEntry(
      id: item.id as String,
      word: item.word as String,
      shortDefinition: item.meaning as String?,
      meaning: item.meaning as String?,
      phonetic: item.phonetic as String?,
      folderId: WordFolder.allWords.id,
      addedAt: DateTime.now(),
      strength: (item.strength as num?)?.toDouble() ?? 0.0,
      nextReview: item.nextReviewAt as DateTime?,
    );
  }
}
