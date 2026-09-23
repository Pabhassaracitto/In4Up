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

import 'firebase_rest_auth.dart';
import 'firestore_rest_client.dart';

enum SyncStatus { idle, syncing, success, error }

class VocabSyncService {
  static final VocabSyncService _instance = VocabSyncService._();
  factory VocabSyncService() => _instance;
  VocabSyncService._();

  FirebaseFirestore? _db;
  FirebaseFirestore get db {
    _db ??= _tryGetFirestore();
    return _db!;
  }

  bool? _pluginDbOk;

  /// True khi plugin cloud_firestore khả dụng (Android/iOS/macOS/Windows/Web).
  bool get hasDb => _pluginDbOk ??= _tryHasDb();

  bool _tryHasDb() {
    try {
      _db ??= FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Linux: plugin cloud_firestore không tồn tại → đồng bộ qua Firestore REST
  /// (token lấy từ FirebaseRestAuth — cùng uid với Android/Windows).
  bool get _useRestSync => !hasDb;

  FirestoreRestClient get _rest => FirestoreRestClient();

  FirebaseFirestore? _tryGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('⚠️ VocabSyncService: FirebaseFirestore not available (Linux offline): $e');
      return null;
    }
  }

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
    if (!hasDb) {
      if (_useRestSync && FirebaseRestAuth().currentUser != null) {
        debugPrint('🔁 VocabSyncService.initialize: REST mode (Linux) uid=$uid');
      } else {
        debugPrint(
            '⚠️ VocabSyncService.initialize: no Firestore & no REST auth, skip sync');
        return;
      }
    }
    if (!Hive.isBoxOpen(_pendingBoxName)) {
      await Hive.openBox<String>(_pendingBoxName);
    }
    _connectivitySub?.cancel();
    try {
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen((results) {
        final hasNetwork = results.any((r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet);
        if (hasNetwork) flushPending();
      });
    } catch (e) {
      // Desktop (Linux) có thể không có connectivity plugin → bỏ qua listener,
      // flushPending vẫn chạy qua debounce + các điểm gọi trực tiếp.
      debugPrint('⚠️ VocabSync: connectivity listener không khả dụng: $e');
    }

    // Load last sync checkpoint
    await _loadCheckpoint();
    await pullFromFirestore();
  }

  Future<void> _loadCheckpoint() async {
    if (_currentUid == null) return;
    if (!hasDb) {
      // REST (Linux)
      if (!_useRestSync) return;
      try {
        final doc =
            await _rest.getDocument('users/$_currentUid/vocab_meta/checkpoint');
        final ts = doc?['lastSyncedAt'];
        if (ts is DateTime) lastSyncedAt.value = ts;
      } catch (e) {
        debugPrint('⚠️ VocabSync: REST load checkpoint: $e');
      }
      return;
    }
    try {
      final firestore = db;
      final doc = await firestore
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
    if (_useRestSync) {
      await _flushPendingRest();
      return;
    }
    if (!hasDb) return;
    if (!Hive.isBoxOpen(_pendingBoxName)) return;

    final pendingBox = Hive.box<String>(_pendingBoxName);
    if (pendingBox.isEmpty) {
      status.value = SyncStatus.idle;
      return;
    }

    if (!await _hasNetwork()) return;

    _isSyncing = true;
    status.value = SyncStatus.syncing;
    try {
      final vocabBox = Hive.isBoxOpen(_vocabBoxName)
          ? Hive.box<String>(_vocabBoxName)
          : null;
      if (vocabBox == null) return;

      final firestore = db;
      final col =
          firestore.collection('users').doc(_currentUid).collection('vocabulary');
      final ids = pendingBox.keys.toList();

      for (int i = 0; i < ids.length; i += 400) {
        final batch = firestore.batch();
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
      await firestore
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

  // ═══════════════════════════════════════════════════════════
  // Shared & REST (Linux) helpers
  // ═══════════════════════════════════════════════════════════

  /// Connectivity check an toàn đa nền tảng: nếu connectivity plugin không
  /// khả dụng (Linux desktop) → coi như online, HTTP call sẽ tự fail và
  /// pending queue được giữ lại nếu thật sự offline.
  Future<bool> _hasNetwork() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      return conn.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    } catch (_) {
      return true;
    }
  }

  /// Áp dụng 1 doc kéo về: quy tắc "updatedAt mới hơn thắng".
  /// Trả về true nếu local được cập nhật từ remote.
  Future<bool> _applyPulledDoc(
    String docId,
    Map<String, dynamic> remoteData,
    Box<String> vocabBox,
  ) async {
    remoteData.remove('_syncedAt');

    final localJson = vocabBox.get(docId);
    if (localJson != null) {
      try {
        final local = jsonDecode(localJson) as Map<String, dynamic>;
        final localUpdateStr = local['updatedAt'] ?? local['lastReviewed'];
        final remoteUpdateStr =
            remoteData['updatedAt'] ?? remoteData['lastReviewed'];

        final localTs = DateTime.tryParse(localUpdateStr ?? '');
        final remoteTs = DateTime.tryParse(remoteUpdateStr ?? '');

        // QUY TẮC: Bản ghi nào có updatedAt mới hơn sẽ thắng
        if (localTs != null && remoteTs != null && localTs.isAfter(remoteTs)) {
          // Local mới hơn -> Đánh dấu để đẩy lên Cloud thay vì tải về
          markDirty(docId);
          return false;
        }
      } catch (_) {}
    }

    await vocabBox.put(docId, jsonEncode(_jsonSafe(remoteData)));
    return true;
  }

  /// Chuyển giá trị không jsonEncode được (Timestamp/DateTime) thành ISO
  /// string — phòng khi remote có field timestamp ngoài _syncedAt.
  dynamic _jsonSafe(dynamic v) {
    if (v is DateTime) return v.toIso8601String();
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is Map) {
      return {
        for (final e in v.entries) e.key.toString(): _jsonSafe(e.value),
      };
    }
    if (v is Iterable) return [for (final e in v) _jsonSafe(e)];
    return v;
  }

  // ─── REST (Linux): flush pending queue lên Firestore ───────
  Future<void> _flushPendingRest() async {
    if (_isSyncing || _currentUid == null) return;
    if (!Hive.isBoxOpen(_pendingBoxName)) return;

    final pendingBox = Hive.box<String>(_pendingBoxName);
    if (pendingBox.isEmpty) {
      status.value = SyncStatus.idle;
      return;
    }
    if (!await _hasNetwork()) return;

    _isSyncing = true;
    status.value = SyncStatus.syncing;
    try {
      final vocabBox = Hive.isBoxOpen(_vocabBoxName)
          ? Hive.box<String>(_vocabBoxName)
          : null;
      if (vocabBox == null) return;

      final ids = pendingBox.keys.toList();

      // Mỗi doc cần ≤ 2 writes (update + serverTime transform) → chunk 200
      // để luôn nằm dưới limit 500 writes/commit của Firestore.
      const chunkSize = 200;
      for (int i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.skip(i).take(chunkSize);
        final writes = <Map<String, dynamic>>[];
        final doneIds = <dynamic>[];

        for (final id in chunk) {
          final sid = id.toString();
          if (sid.startsWith('__del__')) {
            writes.add(_rest.deleteWrite(
                'users/$_currentUid/vocabulary/${sid.substring(7)}'));
          } else {
            final json = vocabBox.get(sid);
            if (json == null) {
              await pendingBox.delete(id);
              continue;
            }
            try {
              final map = jsonDecode(json) as Map<String, dynamic>;
              final path = 'users/$_currentUid/vocabulary/$sid';
              writes.add(_rest.updateWrite(path, map));
              writes.add(_rest.serverTimeWrite(path, '_syncedAt'));
            } catch (_) {}
          }
          doneIds.add(id);
        }

        if (writes.isNotEmpty) await _rest.commitWrites(writes);
        for (final id in doneIds) {
          await pendingBox.delete(id);
        }
      }

      // Checkpoint (giống plugin: FieldValue.serverTimestamp())
      final cpPath = 'users/$_currentUid/vocab_meta/checkpoint';
      await _rest.commitWrites([
        _rest.updateWrite(cpPath, const <String, dynamic>{}),
        _rest.serverTimeWrite(cpPath, 'lastSyncedAt'),
      ]);

      final now = DateTime.now();
      lastSyncedAt.value = now;
      status.value = SyncStatus.success;
      debugPrint('✅ VocabSync (REST): flushed ${ids.length} items');

      Future.delayed(const Duration(seconds: 3), () {
        if (status.value == SyncStatus.success) status.value = SyncStatus.idle;
      });
    } catch (e) {
      status.value = SyncStatus.error;
      debugPrint('⚠️ VocabSync flush (REST) error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ─── REST (Linux): pull từ Firestore về Hive ───────────────
  Future<int> _pullRest({bool forceAll = false}) async {
    if (_currentUid == null || _isSyncing) return 0;
    try {
      if (!await _hasNetwork()) return 0;

      final vocabBox = Hive.isBoxOpen(_vocabBoxName)
          ? Hive.box<String>(_vocabBoxName)
          : null;
      if (vocabBox == null) return 0;

      status.value = SyncStatus.syncing;

      final meta =
          await _rest.getDocument('users/$_currentUid/vocab_meta/checkpoint');
      DateTime? lastSync;
      final rawTs = meta?['lastSyncedAt'];
      if (rawTs is DateTime) lastSync = rawTs;

      final List<FirestoreRestDoc> docs;
      if (lastSync != null && !forceAll && vocabBox.isNotEmpty) {
        // Chỉ lấy những bản ghi có _syncedAt mới hơn checkpoint
        docs = await _rest.runQuery(
          parentPath: 'users/$_currentUid',
          collectionId: 'vocabulary',
          filterField: '_syncedAt',
          filterAfter: lastSync,
        );
      } else {
        docs = await _rest.listCollection('users/$_currentUid/vocabulary');
      }

      if (docs.isEmpty) {
        status.value = SyncStatus.idle;
        return 0;
      }

      int updated = 0;
      for (final doc in docs) {
        if (await _applyPulledDoc(doc.id, doc.data, vocabBox)) updated++;
      }

      if (updated > 0) {
        lastSyncedAt.value = DateTime.now();
      }

      status.value = SyncStatus.success;
      debugPrint(
          '✅ VocabSync (REST): pulled ${docs.length} docs, $updated applied');

      Future.delayed(const Duration(seconds: 3), () {
        if (status.value == SyncStatus.success) status.value = SyncStatus.idle;
      });

      return updated;
    } catch (e) {
      status.value = SyncStatus.error;
      debugPrint('⚠️ VocabSync pull (REST) error: $e');
      return 0;
    }
  }

  Future<int> pullFromFirestore({bool forceAll = false}) async {
    if (_currentUid == null || _isSyncing) return 0;
    if (_useRestSync) return _pullRest(forceAll: forceAll);
    try {
      if (!await _hasNetwork()) return 0;

      final vocabBox = Hive.isBoxOpen(_vocabBoxName)
          ? Hive.box<String>(_vocabBoxName)
          : null;
      if (vocabBox == null) return 0;

      status.value = SyncStatus.syncing;

      final firestore = db;
      final meta = await firestore
          .collection('users')
          .doc(_currentUid)
          .collection('vocab_meta')
          .doc('checkpoint')
          .get();

      Query<Map<String, dynamic>> query =
          firestore.collection('users').doc(_currentUid).collection('vocabulary');

      final lastSync = meta.data()?['lastSyncedAt'] as Timestamp?;
      if (lastSync != null && !forceAll && vocabBox.isNotEmpty) {
        // Chỉ lấy những bản ghi có _syncedAt mới hơn checkpoint nếu không forceAll và local có dữ liệu
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
        if (await _applyPulledDoc(doc.id, remoteData, vocabBox)) updated++;
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
