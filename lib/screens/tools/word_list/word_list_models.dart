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
  }) =>
      WordListSettings(
        showWord: showWord ?? this.showWord,
        showPhonetic: showPhonetic ?? this.showPhonetic,
        showNumber: showNumber ?? this.showNumber,
        showShortDefinition:
            showShortDefinition ?? this.showShortDefinition,
        showFullDefinition:
            showFullDefinition ?? this.showFullDefinition,
        showExample: showExample ?? this.showExample,
        definitionsExpanded:
            definitionsExpanded ?? this.definitionsExpanded,
      );
}

// ─── Word Entry ───────────────────────────────────────────
class WordEntry {
  final String id;
  final String word;
  final String? phonetic;
  final String? shortDefinition;
  final String? fullDefinition;
  final String? example;
  final String? wordType;
  final MemoryStage? stage;
  final double strength;
  final DateTime addedAt;
  int repeatCount;
  final bool isFromMemory;
  /// Folder ID (chỉ áp dụng cho manual entries)
  final String? folderId;

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
    this.folderId,
  });

  factory WordEntry.fromMemoryItem(MemoryItem item) => WordEntry(
        id: item.id,
        word: item.word,
        phonetic: item.phonetic,
        shortDefinition: item.meaning,
        fullDefinition: item.meaning,
        example: item.example ?? item.context,
        wordType: item.wordType,
        stage: item.stage,
        strength: item.strength,
        addedAt: item.createdAt,
        isFromMemory: true,
      );

  factory WordEntry.manual({
    required String id,
    required String word,
    String? phonetic,
    String? shortDefinition,
    String? fullDefinition,
    String? example,
    String? wordType,
    String? folderId,
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
        folderId: folderId,
      );

  WordEntry copyWith({String? folderId, int? repeatCount}) => WordEntry(
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
        repeatCount: repeatCount ?? this.repeatCount,
        isFromMemory: isFromMemory,
        folderId: folderId ?? this.folderId,
      );
}

// ─── Folder Tree ──────────────────────────────────────────

/// Node trong cây thư mục
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

  bool get isRoot => parentId == null;

  // Thêm con
  void addChild(FolderNode child) {
    child.parentId = id;
    children.add(child);
  }

  // Xóa con
  void removeChild(String childId) {
    children.removeWhere((c) => c.id == childId);
  }

  FolderNode toWordFolder() => this;
}

/// Manager quản lý cây thư mục + persit
class FolderTreeManager {
  // Danh sách root folders (không tính allWords)
  final List<FolderNode> _roots = [
    FolderNode(
      id: 'default',
      name: 'Default',
      color: const Color(0xFF6C63FF),
      icon: Icons.folder_outlined,
    ),
  ];

  List<FolderNode> get roots => List.unmodifiable(_roots);

  /// Tìm node theo id (DFS)
  FolderNode? findById(String id) {
    FolderNode? _search(List<FolderNode> nodes) {
      for (final n in nodes) {
        if (n.id == id) return n;
        final found = _search(n.children);
        if (found != null) return found;
      }
      return null;
    }
    return _search(_roots);
  }

  /// Thêm folder mới (dưới parentId, null = root level)
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
      final parent = findById(parentId);
      parent?.addChild(node);
    }
    return node;
  }

  /// Xóa folder (và children của nó)
  void removeFolder(String id) {
    bool _remove(List<FolderNode> nodes) {
      for (int i = 0; i < nodes.length; i++) {
        if (nodes[i].id == id) {
          nodes.removeAt(i);
          return true;
        }
        if (_remove(nodes[i].children)) return true;
      }
      return false;
    }
    _remove(_roots);
  }

  /// Đổi tên folder
  void renameFolder(String id, String newName) {
    findById(id)?.name = newName;
  }

  /// Flatten tất cả nodes (cho dropdown/list)
  List<({FolderNode node, int depth})> flattenAll() {
    final result = <({FolderNode node, int depth})>[];
    void _flatten(List<FolderNode> nodes, int depth) {
      for (final n in nodes) {
        result.add((node: n, depth: depth));
        if (n.isExpanded) _flatten(n.children, depth + 1);
      }
    }
    _flatten(_roots, 0);
    return result;
  }
}

// ─── WordFolder (backward-compat static constants) ────────
class WordFolder {
  static const WordFolder allWords = WordFolder(
    id: '_all',
    name: 'All words',
    icon: Icons.list_alt,
    color: Color(0xFF2196F3),
  );

  static const WordFolder defaultFolder = WordFolder(
    id: 'default',
    name: 'Default',
    icon: Icons.folder_outlined,
    color: Color(0xFF6C63FF),
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
