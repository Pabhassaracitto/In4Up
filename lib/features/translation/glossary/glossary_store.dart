// lib/features/translation/glossary/glossary_store.dart
//
// Lớp lưu trữ glossary trên Hive (box `translation_glossary`) + nạp hạt
// giống từ asset + đồng bộ một chiều từ WordEntry.
//
// Luật quan trọng:
// - Entry ĐÃ KHÓA (locked) chỉ bị thay bằng entry priority CAO HƠN
//   (user 100 > hạt giống 0) — `resolveUpsert`.
// - Đồng bộ từ WordEntry chỉ chạy khi CHƯA CÓ entry cùng id — không bao
//   giờ ghi đè entry người dùng đã chỉnh hoặc hạt giống đã khóa.
// - Mọi thay đổi phát tín hiệu [changes] → TranslationService đổi snapshot
//   [Glossary] + clear cache dịch (bản dịch cũ có thể chứa nghĩa cũ).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/word_entry.dart';
import 'translation_glossary.dart';

class GlossaryStore {
  GlossaryStore._({List<GlossaryEntry>? seed})
      : _staticSeed = seed ?? const <GlossaryEntry>[],
        _loadsSeedAsset = seed == null;

  static final GlossaryStore _instance = GlossaryStore._();

  /// Instance dùng trong app (nạp hạt giống từ asset nếu box trống).
  factory GlossaryStore() => _instance;

  /// Instance test: không dùng instance chung, không đọc asset.
  factory GlossaryStore.test({List<GlossaryEntry> seed = const <GlossaryEntry>[]}) =>
      GlossaryStore._(seed: seed);

  static const String boxName = 'translation_glossary';
  static const String _assetPath = 'assets/glossary/buddhist_pi_en_vi.json';

  final List<GlossaryEntry> _staticSeed;
  final bool _loadsSeedAsset;

  Box<Map>? _box;
  final List<GlossaryEntry> _entries = <GlossaryEntry>[];
  final Map<String, GlossaryEntry> _byId = <String, GlossaryEntry>{};
  final StreamController<void> _controller = StreamController<void>.broadcast();
  Completer<void>? _initCompleter;

  /// Phát ra mỗi khi glossary thay đổi (thêm/sửa/xóa/đổi khóa).
  Stream<void> get changes => _controller.stream;

  /// Snapshot trong bộ nhớ (thuần, test được).
  Glossary get glossary => Glossary(List<GlossaryEntry>.unmodifiable(_entries));

  /// Entry theo thứ tự hiển thị (sourceNorm tăng).
  List<GlossaryEntry> get entries => List.unmodifiable(_entries);

  bool get isReady => _box != null;

  /// Mở box + nạp hạt giống (1 lần). An toàn gọi nhiều lần; lỗi (Hive chưa
  /// init) được nuốt để pipeline dịch vẫn chạy với glossary rỗng.
  Future<void> ensureInit() {
    final completer = _initCompleter;
    if (completer != null) return completer.future;
    final started = Completer<void>();
    _initCompleter = started;
    _doInit().then(
      (void value) => started.complete(),
      onError: (Object error) {
        debugPrint('⚠️ GlossaryStore init: $error');
        _initCompleter = null; // cho phép thử lại lần sau
        started.complete();
      },
    );
    return started.future;
  }

  Future<void> _doInit() async {
    final box = _box ?? await Hive.openBox<Map>(boxName);
    _box = box;

    if (box.isEmpty) {
      final seed = await _loadSeed();
      for (final entry in seed) {
        box.putIfAbsent(entry.id, entry.toMap());
      }
    }

    _entries
      ..clear()
      ..addAll(
        box.values
            .map((value) => GlossaryEntry.fromMap(Map<String, dynamic>.from(value)))
            .toList()
          ..sort((a, b) {
            final bySource = a.sourceNorm
                .toLowerCase()
                .compareTo(b.sourceNorm.toLowerCase());
            if (bySource != 0) return bySource;
            return a.targetLang.compareTo(b.targetLang);
          }),
      );
    _byId
      ..clear()
      ..addAll({for (final entry in _entries) entry.id: entry});
  }

  Future<List<GlossaryEntry>> _loadSeed() async {
    if (!_loadsSeedAsset) return _staticSeed;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <GlossaryEntry>[];
      final list = decoded['entries'];
      if (list is! List) return const <GlossaryEntry>[];
      final out = <GlossaryEntry>[];
      for (final item in list) {
        if (item is! Map) continue;
        try {
          out.add(GlossaryEntry.fromMap(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('⚠️ Glossary seed entry hỏng: $e');
        }
      }
      return out;
    } catch (e) {
      debugPrint('⚠️ Glossary seed asset không đọc được: $e');
      return const <GlossaryEntry>[];
    }
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void _replaceInMemory(GlossaryEntry entry) {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      _entries[index] = entry;
    } else {
      _entries.add(entry);
      _entries.sort((a, b) =>
          a.sourceNorm.toLowerCase().compareTo(b.sourceNorm.toLowerCase()));
    }
    _byId[entry.id] = entry;
  }

  /// Quy tắc merge thuần (test được):
  /// - Chưa có entry → nhận [incoming].
  /// - Entry đang khóa chỉ bị thay bằng entry priority CAO HƠN.
  /// - Entry chưa khóa → thay tự do.
  static GlossaryEntry? resolveUpsert(
    GlossaryEntry? existing,
    GlossaryEntry incoming,
  ) {
    if (existing == null) return incoming;
    if (existing.locked && incoming.priority <= existing.priority) {
      return null;
    }
    return incoming;
  }

  /// Thêm/sửa entry (tuân thủ luật khóa). Trả về false nếu bị bỏ qua.
  Future<bool> upsert(GlossaryEntry entry) async {
    await ensureInit();
    final box = _box;
    if (box == null) return false;
    final resolved = resolveUpsert(_byId[entry.id], entry);
    if (resolved == null) return false;
    await box.put(resolved.id, resolved.toMap());
    _replaceInMemory(resolved);
    _emit();
    return true;
  }

  Future<bool> remove(String id) async {
    await ensureInit();
    final box = _box;
    if (box == null || !box.containsKey(id)) return false;
    await box.delete(id);
    _entries.removeWhere((e) => e.id == id);
    _byId.remove(id);
    _emit();
    return true;
  }

  /// Đồng bộ MỘT CHIỀU từ WordEntry:
  /// language chứa Pali (hoặc topic Phật học) + meaning không rỗng →
  /// tạo entry `domain=user, locked=true, priority=100` nếu CHƯA CÓ.
  /// Không ghi đè entry đã tồn tại.
  Future<void> syncFromWordEntry(WordEntry entry) async {
    final proposed = GlossarySync.fromWordEntry(entry);
    if (proposed == null) return;
    await ensureInit();
    if (_byId.containsKey(proposed.id)) return;
    await upsert(proposed);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Chuyển WordEntry → entry glossary (chỉ khi đủ điều kiện Phật học/Pali).
class GlossarySync {
  GlossarySync._();

  /// Gợi ý topic Phật học sau khi bỏ dấu (so khớp phần tử).
  static const List<String> _buddhistTopicHints = <String>[
    'phat',
    'buddh',
    'pali',
    'dhamma',
    'kinh',
    'tam tang',
    'tripitaka',
  ];

  static final RegExp _vietnameseChars = RegExp(
    r'[đĐơƠưƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹýàáảãạèéẻẽẹ'
    r'ìíỉĩịòóỏõọùúủũụ]',
  );

  /// Entry đề xuất, hoặc null nếu WordEntry không thuộc diện đồng bộ.
  static GlossaryEntry? fromWordEntry(WordEntry entry) {
    final word = entry.word.trim();
    final meaning = entry.meaning.trim();
    if (word.isEmpty || meaning.isEmpty) return null;

    final langs = entry.languages
        .map((l) => l.trim().toLowerCase())
        .where((l) => l.isNotEmpty)
        .toSet();
    final isPali = langs.any((l) => l == 'pi' || l == 'pali' || l.contains('pali'));
    final isBuddhistTopic = entry.topics.any((t) {
      final normalized = normalizeTerm(t);
      return _buddhistTopicHints.any((hint) => normalized.contains(hint));
    });
    if (!isPali && !isBuddhistTopic) return null;

    var sourceLang = langs.isEmpty ? 'en' : langs.first;
    if (sourceLang == 'pali') sourceLang = GlossaryLang.pali;
    if (isPali && langs.isNotEmpty) {
      // Từ Pali: ưu tiên gắn sourceLang Pali dù entry có nhiều ngôn ngữ.
      sourceLang = GlossaryLang.pali;
    }

    final targetLang = _vietnameseChars.hasMatch(meaning)
        ? GlossaryLang.vietnamese
        : GlossaryLang.english;

    return GlossaryEntry(
      id: GlossaryEntry.makeId(word, sourceLang, targetLang),
      sourceNorm: word,
      sourceLang: sourceLang,
      targetLang: targetLang,
      targetText: meaning,
      locked: true,
      domain: GlossaryDomain.user,
      priority: GlossaryPriority.user,
    );
  }
}
