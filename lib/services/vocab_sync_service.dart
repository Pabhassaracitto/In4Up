// Offline-first sync: Hive → Firestore
//
// Luồng:
//   1. Hive ghi TRƯỚC (instant)
//   2. markDirty(wordId) → pending queue
//   3. Khi có mạng → flushPending() lên Firestore
//   4. Khi mở app → pullFromFirestore() (chỉ pull những gì mới hơn)
//
// Firestore schema:
//   users/{uid}/vocabulary/{wordId}   ← WordEntry JSON
//   users/{uid}/vocab_meta/checkpoint ← { lastSyncedAt: Timestamp }

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class VocabSyncService {
  static final VocabSyncService _instance = VocabSyncService._();
  factory VocabSyncService() => _instance;
  VocabSyncService._();

  final _db = FirebaseFirestore.instance;
  static const _pendingBoxName = 'vocab_sync_pending';
  static const _vocabBoxName = 'vocabulary_v2';

  bool _isSyncing = false;
  StreamSubscription? _connectivitySub;
  String? _currentUid;

  Future<void> initialize(String uid) async {
    _currentUid = uid;
    if (!Hive.isBoxOpen(_pendingBoxName)) {
      await Hive.openBox<String>(_pendingBoxName);
    }
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
      if (hasNetwork) flushPending();
    });
    await pullFromFirestore();
  }

  void dispose() => _connectivitySub?.cancel();

  void markDirty(String wordId) {
    if (!Hive.isBoxOpen(_pendingBoxName)) return;
    Hive.box<String>(_pendingBoxName).put(wordId, wordId);
    flushPending();
  }

  void markDeleted(String wordId) => markDirty('__del__$wordId');

  Future<void> flushPending() async {
    if (_isSyncing || _currentUid == null) return;
    if (!Hive.isBoxOpen(_pendingBoxName)) return;

    final pendingBox = Hive.box<String>(_pendingBoxName);
    if (pendingBox.isEmpty) return;

    final conn = await Connectivity().checkConnectivity();
    final hasNetwork = conn.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
    if (!hasNetwork) return;

    _isSyncing = true;
    try {
      final vocabBox = Hive.isBoxOpen(_vocabBoxName)
          ? Hive.box<String>(_vocabBoxName)
          : null;
      if (vocabBox == null) return;

      final col =
          _db.collection('users').doc(_currentUid).collection('vocabulary');
      final ids = pendingBox.keys.toList();

      for (int i = 0; i < ids.length; i += 400) {
        final batch = _db.batch();
        final chunk = ids.skip(i).take(400);
        for (final id in chunk) {
          final sid = id.toString();
          if (sid.startsWith('__del__')) {
            batch.delete(col.doc(sid.substring(7)));
          } else {
            final json = vocabBox.get(sid);
            if (json == null) continue;
            try {
              final map = jsonDecode(json) as Map<String, dynamic>;
              map['_syncedAt'] = FieldValue.serverTimestamp();
              batch.set(col.doc(sid), map);
            } catch (_) {}
          }
        }
        await batch.commit();
        for (final id in chunk) await pendingBox.delete(id);
      }

      await _db
          .collection('users')
          .doc(_currentUid)
          .collection('vocab_meta')
          .doc('checkpoint')
          .set({'lastSyncedAt': FieldValue.serverTimestamp()});

      debugPrint('✅ VocabSync: flushed ${ids.length} items');
    } catch (e) {
      debugPrint('⚠️ VocabSync flush error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> pullFromFirestore() async {
    if (_currentUid == null) return 0;
    try {
      final conn = await Connectivity().checkConnectivity();
      if (!conn.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet)) return 0;

      final vocabBox = Hive.isBoxOpen(_vocabBoxName)
          ? Hive.box<String>(_vocabBoxName)
          : null;
      if (vocabBox == null) return 0;

      final meta = await _db
          .collection('users')
          .doc(_currentUid)
          .collection('vocab_meta')
          .doc('checkpoint')
          .get();

      Query<Map<String, dynamic>> query =
          _db.collection('users').doc(_currentUid).collection('vocabulary');

      final lastSync = meta.data()?['lastSyncedAt'] as Timestamp?;
      if (lastSync != null) {
        query = query.where('_syncedAt', isGreaterThan: lastSync);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return 0;

      int updated = 0;
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data.remove('_syncedAt');
        final localJson = vocabBox.get(doc.id);
        if (localJson != null) {
          try {
            final local = jsonDecode(localJson) as Map<String, dynamic>;
            final localTs = DateTime.tryParse(local['lastReviewed'] ?? '');
            final remoteTs = DateTime.tryParse(data['lastReviewed'] ?? '');
            if (localTs != null &&
                remoteTs != null &&
                localTs.isAfter(remoteTs)) continue;
          } catch (_) {}
        }
        await vocabBox.put(doc.id, jsonEncode(data));
        updated++;
      }

      debugPrint('✅ VocabSync: pulled $updated words');
      return updated;
    } catch (e) {
      debugPrint('⚠️ VocabSync pull error: $e');
      return 0;
    }
  }

  Future<void> pushAll() async {
    if (_currentUid == null) return;
    final vocabBox =
        Hive.isBoxOpen(_vocabBoxName) ? Hive.box<String>(_vocabBoxName) : null;
    if (vocabBox == null || vocabBox.isEmpty) return;
    final pendingBox = Hive.box<String>(_pendingBoxName);
    for (final key in vocabBox.keys) {
      pendingBox.put(key.toString(), key.toString());
    }
    await flushPending();
  }
}
