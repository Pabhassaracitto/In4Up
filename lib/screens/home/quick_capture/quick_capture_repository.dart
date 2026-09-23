// lib/screens/home/quick_capture/quick_capture_repository.dart
//
// HOME-QUICK-001 — tầng lưu cho transcript của "Nạp tri thức nhanh".
//
// Hai đích lưu thật (không mock, không random):
//  * WordList: đi qua `VocabularyBridge.addContextual` — ĐÚNG đường mà
//    SelectionSaveSheet (tab Đọc) đang dùng, nên entry hiện ngay trong
//    WordList, có ngữ cảnh nguồn, topic/language và SRS như từ lưu tay.
//  * Ghi chú: `QuickCaptureNoteStore` — kho ghi chú nói local (JSON trong
//    box `settings` của `StorageService` có sẵn), xem/xoá ngay trong sheet.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../models/vocab_context.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_bridge.dart';
import '../../../services/storage_service.dart';

/// Một ghi chú bằng giọng nói đã lưu.
class QuickCaptureNote {
  const QuickCaptureNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.language = '',
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final String language;

  /// Bản xem trước 1 dòng cho danh sách ghi chú gần đây.
  String get preview {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 120
        ? normalized
        : '${normalized.substring(0, 117)}…';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'language': language,
      };

  static QuickCaptureNote? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final text = (json['text'] as String?)?.trim() ?? '';
    if (id.isEmpty || text.isEmpty) return null;
    return QuickCaptureNote(
      id: id,
      text: text,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      language: (json['language'] as String?) ?? '',
    );
  }
}

typedef QuickCaptureNoteRead = String? Function(String key);
typedef QuickCaptureNoteWrite = Future<void> Function(String key, String? value);

/// Kho ghi chú nói (local, offline-first) — lưu JSON trong storage có sẵn.
class QuickCaptureNoteStore {
  QuickCaptureNoteStore({
    required QuickCaptureNoteRead read,
    required QuickCaptureNoteWrite write,
    this.maxNotes = 200,
  })  : _read = read,
        _write = write;

  /// Adapter trên [StorageService] (box `settings` — đã mở sẵn trong
  /// `StorageService.initialize()` ở `main()`).
  factory QuickCaptureNoteStore.onStorageService([StorageService? storage]) {
    final service = storage ?? StorageService();
    return QuickCaptureNoteStore(
      read: (key) {
        try {
          return service.getSetting<String>(key);
        } catch (e) {
          debugPrint('⚠️ QuickCaptureNoteStore read error: $e');
          return null;
        }
      },
      write: (key, value) async {
        try {
          if (value == null) {
            await service.saveSetting(key, '');
          } else {
            await service.saveSetting(key, value);
          }
        } catch (e) {
          debugPrint('⚠️ QuickCaptureNoteStore write error: $e');
        }
      },
    );
  }

  static const String storageKey = 'quick_capture_notes_v1';

  final QuickCaptureNoteRead _read;
  final QuickCaptureNoteWrite _write;
  final int maxNotes;

  /// Đọc toàn bộ ghi chú (mới nhất trước). Không ném lỗi — storage hỏng
  /// thì trả danh sách rỗng để UI vẫn mở được.
  List<QuickCaptureNote> load() {
    final raw = _read(storageKey);
    if (raw == null || raw.trim().isEmpty) return <QuickCaptureNote>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <QuickCaptureNote>[];
      final notes = decoded
          .whereType<Map<String, dynamic>>()
          .map(QuickCaptureNote.fromJson)
          .whereType<QuickCaptureNote>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notes;
    } catch (e) {
      debugPrint('⚠️ QuickCaptureNoteStore.load corrupt data: $e');
      return <QuickCaptureNote>[];
    }
  }

  /// Thêm một ghi chú. Trả `null` nếu nội dung rỗng.
  Future<QuickCaptureNote?> add(
    String text, {
    String language = '',
    DateTime? now,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return null;

    final createdAt = now ?? DateTime.now();
    final note = QuickCaptureNote(
      id: 'qn_${createdAt.microsecondsSinceEpoch}',
      text: normalized,
      createdAt: createdAt,
      language: language,
    );

    final notes = <QuickCaptureNote>[note, ...load()];
    await _persist(notes.take(maxNotes).toList());
    return note;
  }

  Future<void> delete(String id) async {
    final notes = load().where((n) => n.id != id).toList();
    await _persist(notes);
  }

  Future<void> _persist(List<QuickCaptureNote> notes) {
    final payload = notes.isEmpty
        ? null
        : jsonEncode(notes.map((n) => n.toJson()).toList());
    return _write(storageKey, payload);
  }
}

/// Seam lưu WordList — mặc định đi qua [VocabularyBridge] (đường dùng
/// chung của toàn app), test có thể thay bằng sink giả.
typedef QuickCaptureWordSink = WordEntry? Function({
  required String text,
  required String language,
  required VocabContext context,
});

class QuickCaptureWordSaveResult {
  const QuickCaptureWordSaveResult({
    required this.success,
    this.entry,
    this.isNewEntry = false,
    this.reason,
  });

  final bool success;
  final WordEntry? entry;

  /// `true` = entry mới; `false` = từ đã có, chỉ bổ sung ngữ cảnh/tag.
  final bool isNewEntry;

  /// Lý do thất bại (chưa dịch — UI tự map thông báo).
  final String? reason;
}

/// Lưu transcript vào WordList / ghi chú.
class QuickCaptureSaver {
  QuickCaptureSaver({
    required this.notes,
    QuickCaptureWordSink? wordSink,
  }) : _wordSink = wordSink ?? _defaultWordSink;

  final QuickCaptureNoteStore notes;
  final QuickCaptureWordSink _wordSink;

  /// WordList đã gắn provider chưa (bridge init trong `main_shell`).
  bool get isWordListReady => VocabularyBridge.isReady;

  /// Lưu transcript thành một entry WordList (từ/cụm/câu tự phân loại).
  QuickCaptureWordSaveResult saveToWordList({
    required String text,
    required String language,
  }) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const QuickCaptureWordSaveResult(
        success: false,
        reason: 'empty_transcript',
      );
    }
    if (!VocabularyBridge.isReady) {
      return const QuickCaptureWordSaveResult(
        success: false,
        reason: 'word_list_not_ready',
      );
    }

    final existedBefore = VocabularyBridge.hasWord(normalized);
    final entry = _wordSink(
      text: normalized,
      language: language,
      context: VocabContext.manual(note: normalized),
    );
    if (entry == null) {
      return const QuickCaptureWordSaveResult(
        success: false,
        reason: 'save_failed',
      );
    }
    return QuickCaptureWordSaveResult(
      success: true,
      entry: entry,
      isNewEntry: !existedBefore,
    );
  }

  /// Lưu transcript thành ghi chú nói.
  Future<QuickCaptureNote?> saveNote({
    required String text,
    required String language,
  }) {
    return notes.add(text, language: language);
  }

  static WordEntry? _defaultWordSink({
    required String text,
    required String language,
    required VocabContext context,
  }) {
    return VocabularyBridge.addContextual(
      text: text,
      meaning: '',
      example: text,
      context: context,
      language: language,
    );
  }
}
