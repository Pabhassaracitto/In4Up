//
// Quản lý thư viện văn bản do người dùng tự tạo — lưu trên Firebase Firestore.
//
// Cấu trúc Firestore:
//   users/{uid}/text_library/{docId}
//     - id: String
//     - title: String          (vd: "Hội thoại tại quầy Check-in")
//     - content: String        (nội dung văn bản đầy đủ)
//     - category: String?      (vd: "Hội thoại", "Du lịch", ...)
//     - wordCount: int
//     - createdAt: Timestamp
//     - updatedAt: Timestamp

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─── Model ────────────────────────────────────────────────
class TextLibraryEntry {
  final String id;
  final String title;
  final String content;
  final String? category;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Issue 2: lưu bản dịch cũ để không phải dịch lại mỗi lần mở
  // translations: { "VI": ["dòng dịch 1", "dòng dịch 2"], "EN": [...] }
  // hoặc dạng Map<langCode, Map<lineIndex, translation>>
  final Map<String, dynamic>? translations;
  final Map<String, dynamic>? translationMeta;

  const TextLibraryEntry({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
    this.translations,
    this.translationMeta,
  });

  // Số dòng để hiển thị trong list
  int get lineCount => content.split('\n').where((l) => l.trim().isNotEmpty).length;

  // Preview ngắn (2 dòng đầu)
  String get preview {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '';
    if (lines.length == 1) return lines[0];
    return '${lines[0]}\n${lines[1]}';
  }

  factory TextLibraryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TextLibraryEntry(
      id: doc.id,
      title: data['title'] as String? ?? 'Không có tiêu đề',
      content: data['content'] as String? ?? '',
      category: data['category'] as String?,
      wordCount: data['wordCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      translations: data['translations'] as Map<String, dynamic>?,
      translationMeta: data['translationMeta'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'content': content,
    'category': category,
    'wordCount': wordCount,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    if (translations != null) 'translations': translations,
    if (translationMeta != null) 'translationMeta': translationMeta,
  };

  TextLibraryEntry copyWith({
    String? title,
    String? content,
    String? category,
    Map<String, dynamic>? translations,
    Map<String, dynamic>? translationMeta,
  }) {
    final newContent = content ?? this.content;
    return TextLibraryEntry(
      id: id,
      title: title ?? this.title,
      content: newContent,
      category: category ?? this.category,
      wordCount: newContent.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      translations: translations ?? this.translations,
      translationMeta: translationMeta ?? this.translationMeta,
    );
  }

  /// Lấy translations cho 1 ngôn ngữ đích (VD: VI)
  List<String>? getTranslationsForLang(String langCode) {
    if (translations == null) return null;
    final normalized = langCode.toUpperCase();
    final data = translations![normalized] ?? translations![normalized.toLowerCase()] ?? translations![langCode];
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    if (data is Map) {
      // dạng Map<index, translation>
      final list = List<String>.filled(lineCount, '');
      data.forEach((k, v) {
        final idx = int.tryParse(k.toString());
        if (idx != null && idx >= 0 && idx < list.length) {
          list[idx] = v.toString();
        }
      });
      return list;
    }
    return null;
  }
}

// ─── Service ──────────────────────────────────────────────
class TextLibraryService {
  static final TextLibraryService _instance = TextLibraryService._();
  factory TextLibraryService() => _instance;
  TextLibraryService._();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance!;
    } catch (e) {
      debugPrint('⚠️ TextLibraryService: Firestore not available: $e');
      throw StateError('Firestore not available');
    }
  }

  FirebaseAuth? _authInstance;
  FirebaseAuth get _auth {
    try {
      _authInstance ??= FirebaseAuth.instance;
      return _authInstance!;
    } catch (e) {
      debugPrint('⚠️ TextLibraryService: Auth not available: $e');
      throw StateError('Auth not available');
    }
  }

  bool get _hasFirebase {
    try {
      FirebaseFirestore.instance;
      FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Collection ref cho user hiện tại
  CollectionReference<Map<String, dynamic>>? get _collection {
    try {
      if (!_hasFirebase) return null;
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('text_library');
    } catch (_) {
      return null;
    }
  }

  bool get isAvailable {
    try {
      return _hasFirebase && _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  // ── Stream realtime ──────────────────────────────────────
  Stream<List<TextLibraryEntry>> watchAll() {
    final col = _collection;
    if (col == null) return Stream.value([]);

    return col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TextLibraryEntry.fromFirestore(d))
            .toList())
        .handleError((e) {
      debugPrint('TextLibraryService.watchAll error: $e');
      return <TextLibraryEntry>[];
    });
  }

  // ── Lấy toàn bộ một lần ──────────────────────────────────
  Future<List<TextLibraryEntry>> fetchAll() async {
    final col = _collection;
    if (col == null) return const [];

    try {
      final snap = await col.orderBy('updatedAt', descending: true).get();
      return snap.docs.map(TextLibraryEntry.fromFirestore).toList();
    } catch (e) {
      debugPrint('TextLibraryService.fetchAll error: $e');
      return const [];
    }
  }

  // ── Thêm mới ─────────────────────────────────────────────
  Future<TextLibraryEntry?> add({
    required String title,
    required String content,
    String? category,
  }) async {
    final col = _collection;
    if (col == null) return null;

    try {
      final wordCount = content
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      final now = DateTime.now();

      final docRef = await col.add({
        'title': title.trim(),
        'content': content.trim(),
        'category': category?.trim(),
        'wordCount': wordCount,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final snap = await docRef.get();
      return TextLibraryEntry.fromFirestore(snap);
    } catch (e) {
      debugPrint('TextLibraryService.add error: $e');
      return null;
    }
  }

  // ── Cập nhật ─────────────────────────────────────────────
  Future<bool> update(TextLibraryEntry entry) async {
    final col = _collection;
    if (col == null) return false;

    try {
      await col.doc(entry.id).update(entry.copyWith().toFirestore());
      return true;
    } catch (e) {
      debugPrint('TextLibraryService.update error: $e');
      return false;
    }
  }

  // ── Xoá ─────────────────────────────────────────────────
  Future<bool> delete(String id) async {
    final col = _collection;
    if (col == null) return false;

    try {
      await col.doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('TextLibraryService.delete error: $e');
      return false;
    }
  }

  // ── Lấy một bản ghi ─────────────────────────────────────
  Future<TextLibraryEntry?> getById(String id) async {
    final col = _collection;
    if (col == null) return null;

    try {
      final snap = await col.doc(id).get();
      if (!snap.exists) return null;
      return TextLibraryEntry.fromFirestore(snap);
    } catch (e) {
      debugPrint('TextLibraryService.getById error: $e');
      return null;
    }
  }
}
