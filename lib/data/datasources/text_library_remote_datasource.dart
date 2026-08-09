// lib/data/datasources/text_library_remote_datasource.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/text_library_service.dart';

abstract class TextLibraryRemoteDataSource {
  CollectionReference<Map<String, dynamic>>? get collection;
  Stream<List<TextLibraryEntry>> watchAll();
  Future<List<TextLibraryEntry>> fetchAll();
  Future<TextLibraryEntry?> add({required String title, required String content, String? category});
  Future<bool> update(TextLibraryEntry entry);
  Future<bool> delete(String id);
  Future<TextLibraryEntry?> getById(String id);
}

class FirestoreTextLibraryRemoteDataSource implements TextLibraryRemoteDataSource {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  CollectionReference<Map<String, dynamic>>? get collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('text_library');
  }

  @override
  Stream<List<TextLibraryEntry>> watchAll() {
    final col = collection;
    if (col == null) return Stream.value([]);
    return col.orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(TextLibraryEntry.fromFirestore).toList(),
        );
  }

  @override
  Future<List<TextLibraryEntry>> fetchAll() async {
    final col = collection;
    if (col == null) return [];
    try {
      final snap = await col.orderBy('updatedAt', descending: true).get();
      return snap.docs.map(TextLibraryEntry.fromFirestore).toList();
    } catch (e) {
      debugPrint('FirestoreTextLibraryRemote.fetchAll error: $e');
      return [];
    }
  }

  @override
  Future<TextLibraryEntry?> add({required String title, required String content, String? category}) async {
    final col = collection;
    if (col == null) return null;
    try {
      final wc = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final now = DateTime.now();
      final ref = await col.add({
        'title': title.trim(),
        'content': content.trim(),
        'category': category?.trim(),
        'wordCount': wc,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      final snap = await ref.get();
      return TextLibraryEntry.fromFirestore(snap);
    } catch (e) {
      debugPrint('FirestoreTextLibraryRemote.add error: $e');
      return null;
    }
  }

  @override
  Future<bool> update(TextLibraryEntry entry) async {
    final col = collection;
    if (col == null) return false;
    try {
      await col.doc(entry.id).update(entry.copyWith().toFirestore());
      return true;
    } catch (e) {
      debugPrint('FirestoreTextLibraryRemote.update error: $e');
      return false;
    }
  }

  @override
  Future<bool> delete(String id) async {
    final col = collection;
    if (col == null) return false;
    try {
      await col.doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('FirestoreTextLibraryRemote.delete error: $e');
      return false;
    }
  }

  @override
  Future<TextLibraryEntry?> getById(String id) async {
    final col = collection;
    if (col == null) return null;
    try {
      final snap = await col.doc(id).get();
      if (!snap.exists) return null;
      return TextLibraryEntry.fromFirestore(snap);
    } catch (e) {
      debugPrint('FirestoreTextLibraryRemote.getById error: $e');
      return null;
    }
  }
}

/// Stub Supabase — implement khi bật Supabase flag
class SupabaseTextLibraryRemoteDataSource implements TextLibraryRemoteDataSource {
  @override
  CollectionReference<Map<String, dynamic>>? get collection => null;
  @override
  Stream<List<TextLibraryEntry>> watchAll() => Stream.value([]);
  @override
  Future<List<TextLibraryEntry>> fetchAll() async => [];
  @override
  Future<TextLibraryEntry?> add({required String title, required String content, String? category}) async {
    debugPrint('SupabaseTextLibraryRemote.add stub');
    return null;
  }

  @override
  Future<bool> update(TextLibraryEntry entry) async => false;
  @override
  Future<bool> delete(String id) async => false;
  @override
  Future<TextLibraryEntry?> getById(String id) async => null;
}
