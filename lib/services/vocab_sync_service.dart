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

enum SyncStatus { idle, syncing, success, error }

class VocabSyncService {
  static final VocabSyncService _instance = VocabSyncService._();
  factory VocabSyncService() => _instance;
  VocabSyncService._();

  final _db = FirebaseFirestore.instance;
  static const _pendingBoxName = 'vocab_sync_pending';
  static const _vocabBoxName = 'vocabulary_v2';

  bool _isSyncing = false;
  Timer? _debounceTimer;
  StreamSubscription? _connectivitySub;
  String? _currentUid;

  final ValueNotifier<SyncStatus> status = ValueNotifier(SyncStatus.idle);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);

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

    // Load last sync checkpoint
    await _loadCheckpoint();
    await pullFromFirestore();
  }

  Future<void> _loadCheckpoint() async {
    if (_currentUid == null) return;
    try {
      final doc = await _db
          .collection('users')
          .doc(_currentUid)
          .collection('vocab_meta')
          .doc('checkpoint')
          .get();
      if (doc.exists) {
        final ts = doc.data()?['lastSyncedAt'] as Timestamp?;
        lastSyncedAt.value = ts?.toDate();
      }
    } catch (_) {}
  }

  void dispose() {
    _connectivitySub?.cancel();
    _debounceTimer?.cancel();
  }

  void markDirty(String wordId) {
    if (!Hive.isBoxOpen(_pendingBoxName)) return;
    Hive.box<String>(_pendingBoxName).put(wordId, wordId);

    // Debounce: Đợi 5 giây sau lần thay đổi cuối cùng mới flush
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      flushPending();
    });
  }

  void markDeleted(String wordId) => markDirty('__del__$wordId');

  Future<void> flushPending() async {
    if (_isSyncing || _currentUid == null) return;
    if (!Hive.isBoxOpen(_pendingBoxName)) return;

    final pendingBox = Hive.box<String>(_pendingBoxName);
    if (pendingBox.isEmpty) {
      status.value = SyncStatus.idle;
      return;
    }

    final conn = await Connectivity().checkConnectivity();
    final hasNetwork = conn.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
    if (!hasNetwork) return;

    _isSyncing = true;
    status.value = SyncStatus.syncing;
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
            if (json == null) {
              await pendingBox.delete(id);
              continue;
            }
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

      final now = DateTime.now();
      await _db
          .collection('users')
          .doc(_currentUid)
          .collection('vocab_meta')
          .doc('checkpoint')
          .set({'lastSyncedAt': FieldValue.serverTimestamp()});

      lastSyncedAt.value = now;
      status.value = SyncStatus.success;
      debugPrint('✅ VocabSync: flushed ${ids.length} items');

      // Delay reset status to idle
      Future.delayed(const Duration(seconds: 3), () {
        if (status.value == SyncStatus.success) status.value = SyncStatus.idle;
      });
    } catch (e) {
      status.value = SyncStatus.error;
      debugPrint('⚠️ VocabSync flush error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> pullFromFirestore() async {
    if (_currentUid == null || _isSyncing) return 0;
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

      status.value = SyncStatus.syncing;

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
        // Chỉ lấy những bản ghi có _syncedAt mới hơn checkpoint
        query = query.where('_syncedAt', isGreaterThan: lastSync);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        status.value = SyncStatus.idle;
        return 0;
      }

      int updated = 0;
      for (final doc in snapshot.docs) {
        final remoteData = Map<String, dynamic>.from(doc.data());
        remoteData.remove('_syncedAt');

        final localJson = vocabBox.get(doc.id);
        if (localJson != null) {
          try {
            final local = jsonDecode(localJson) as Map<String, dynamic>;
            final localUpdateStr = local['updatedAt'] ?? local['lastReviewed'];
            final remoteUpdateStr =
                remoteData['updatedAt'] ?? remoteData['lastReviewed'];

            final localTs = DateTime.tryParse(localUpdateStr ?? '');
            final remoteTs = DateTime.tryParse(remoteUpdateStr ?? '');

            // QUY TẮC: Bản ghi nào có updatedAt mới hơn sẽ thắng
            if (localTs != null &&
                remoteTs != null &&
                localTs.isAfter(remoteTs)) {
              // Local mới hơn -> Đánh dấu để đẩy lên Cloud thay vì tải về
              markDirty(doc.id);
              continue;
            }
          } catch (_) {}
        }

        await vocabBox.put(doc.id, jsonEncode(remoteData));
        updated++;
      }

      if (updated > 0) {
        lastSyncedAt.value = DateTime.now();
      }

      status.value = SyncStatus.success;
      debugPrint('✅ VocabSync: pulled $updated words');

      Future.delayed(const Duration(seconds: 3), () {
        if (status.value == SyncStatus.success) status.value = SyncStatus.idle;
      });

      return updated;
    } catch (e) {
      status.value = SyncStatus.error;
      debugPrint('⚠️ VocabSync pull error: $e');
      return 0;
    }
  }

  Future<void> pushAll() async {
    if (_currentUid == null) return;
    if (!Hive.isBoxOpen(_pendingBoxName)) {
      await Hive.openBox<String>(_pendingBoxName);
    }
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
