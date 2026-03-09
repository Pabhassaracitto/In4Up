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

  const TextLibraryEntry({
    required this.id,
    required this.title,
    required this.content,
    this.category,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
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
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'content': content,
    'category': category,
    'wordCount': wordCount,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  TextLibraryEntry copyWith({
    String? title,
    String? content,
    String? category,
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
    );
  }
}

// ─── Service ──────────────────────────────────────────────
class TextLibraryService {
  static final TextLibraryService _instance = TextLibraryService._();
  factory TextLibraryService() => _instance;
  TextLibraryService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Collection ref cho user hiện tại
  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('text_library');
  }

  bool get isAvailable => _auth.currentUser != null;

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
