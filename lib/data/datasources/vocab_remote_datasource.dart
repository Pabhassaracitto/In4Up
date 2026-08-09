// lib/data/datasources/vocab_remote_datasource.dart
//
// DataSource remote cho vocab — Firestore (hiện tại)
// Sau này có thể thêm SupabaseVocabRemoteDataSource implement cùng interface.

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/word_entry.dart';

/// Interface chung để dễ swap Firestore <-> Supabase
abstract class VocabRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchAll(String uid, {DateTime? after});
  Future<void> upsert(String uid, WordEntry entry);
  Future<void> upsertBatch(String uid, List<WordEntry> entries);
  Future<void> delete(String uid, String wordId);
  Future<void> deleteBatch(String uid, List<String> wordIds);
  Future<DateTime?> getCheckpoint(String uid);
  Future<void> setCheckpoint(String uid, DateTime ts);
}

/// Firestore implementation (đang dùng)
class FirestoreVocabRemoteDataSource implements VocabRemoteDataSource {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('vocabulary');

  DocumentReference<Map<String, dynamic>> _checkpointDoc(String uid) =>
      _db.collection('users').doc(uid).collection('vocab_meta').doc('checkpoint');

  @override
  Future<List<Map<String, dynamic>>> fetchAll(String uid, {DateTime? after}) async {
    Query<Map<String, dynamic>> q = _col(uid);
    if (after != null) {
      q = q.where('_syncedAt', isGreaterThan: Timestamp.fromDate(after));
    }
    final snap = await q.get();
    return snap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['id'] = d.id;
      return m;
    }).toList();
  }

  @override
  Future<void> upsert(String uid, WordEntry entry) async {
    final map = entry.toJson();
    map['_syncedAt'] = FieldValue.serverTimestamp();
    await _col(uid).doc(entry.id).set(map);
  }

  @override
  Future<void> upsertBatch(String uid, List<WordEntry> entries) async {
    if (entries.isEmpty) return;
    final col = _col(uid);
    for (int i = 0; i < entries.length; i += 400) {
      final batch = _db.batch();
      final chunk = entries.skip(i).take(400);
      for (final e in chunk) {
        final map = e.toJson();
        map['_syncedAt'] = FieldValue.serverTimestamp();
        batch.set(col.doc(e.id), map);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> delete(String uid, String wordId) async {
    await _col(uid).doc(wordId).delete();
  }

  @override
  Future<void> deleteBatch(String uid, List<String> wordIds) async {
    if (wordIds.isEmpty) return;
    for (int i = 0; i < wordIds.length; i += 400) {
      final batch = _db.batch();
      final chunk = wordIds.skip(i).take(400);
      for (final id in chunk) {
        batch.delete(_col(uid).doc(id));
      }
      await batch.commit();
    }
  }

  @override
  Future<DateTime?> getCheckpoint(String uid) async {
    try {
      final doc = await _checkpointDoc(uid).get();
      final ts = doc.data()?['lastSyncedAt'] as Timestamp?;
      return ts?.toDate();
    } catch (e) {
      debugPrint('FirestoreVocabRemote.getCheckpoint error: $e');
      return null;
    }
  }

  @override
  Future<void> setCheckpoint(String uid, DateTime ts) async {
    try {
      await _checkpointDoc(uid).set({'lastSyncedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('FirestoreVocabRemote.setCheckpoint error: $e');
    }
  }
}

/// Stub cho Supabase — chỉ cần implement interface này là xong.
/// Để trống, khi bạn quyết định migrate thì điền vào, không đụng tới
/// code UI/Provider.
class SupabaseVocabRemoteDataSource implements VocabRemoteDataSource {
  @override
  Future<List<Map<String, dynamic>>> fetchAll(String uid, {DateTime? after}) async {
    // TODO: supabase.from('vocabulary').select().eq('user_id', uid).gt('synced_at', ...)
    debugPrint('SupabaseVocabRemote.fetchAll stub - chưa cấu hình');
    return [];
  }

  @override
  Future<void> upsert(String uid, WordEntry entry) async {
    // TODO: supabase.from('vocabulary').upsert({...})
    debugPrint('SupabaseVocabRemote.upsert stub');
  }

  @override
  Future<void> upsertBatch(String uid, List<WordEntry> entries) async {
    debugPrint('SupabaseVocabRemote.upsertBatch stub: ${entries.length} items');
  }

  @override
  Future<void> delete(String uid, String wordId) async {
    debugPrint('SupabaseVocabRemote.delete stub');
  }

  @override
  Future<void> deleteBatch(String uid, List<String> wordIds) async {
    debugPrint('SupabaseVocabRemote.deleteBatch stub');
  }

  @override
  Future<DateTime?> getCheckpoint(String uid) async => null;

  @override
  Future<void> setCheckpoint(String uid, DateTime ts) async {}
}
