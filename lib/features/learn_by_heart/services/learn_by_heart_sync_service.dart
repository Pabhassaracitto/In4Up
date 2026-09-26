// lib/features/learn_by_heart/services/learn_by_heart_sync_service.dart
//
// LHB-006 — Đồng bộ lưu trữ Thuộc Lòng đa thiết bị (offline-first).
//
// Cùng kiến trúc với `VocabSyncService` (WordList) nhưng cho dữ liệu LHB:
//   1. SharedPreferences ghi TRƯỚC (instant) + `markDirty(id)` → hàng đợi pending
//   2. Có mạng → `flushPending()` đẩy doc lên Firestore (debounce 5s)
//   3. Mở app / bật sync → `pullFromFirestore()` kéo doc mới hơn checkpoint
//      rồi HÒA GIẢI qua [LearnByHeartMerge] (LWW + bia mộ)
//
// Schema Firestore (không tạo collection mới ngoài nhánh `users/{uid}`):
//   users/{uid}/learn_by_heart/{itemId}  = item JSON + updatedAt + deleted
//   users/{uid}/lhb_meta/checkpoint      = { lastSyncedAt }
//   users/{uid}/lhb_meta/stats           = { streak, lastActiveDate, updatedAt }
//
// Linux (không có plugin cloud_firestore) → đi qua Firestore REST đúng như
// ADR-0005 (AuthService/FirebaseRestAuth dùng chung uid với Android/Windows).

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../services/firebase_rest_auth.dart';
import '../../../services/firestore_rest_client.dart';
import '../models/learn_by_heart_item.dart';
import '../models/learn_by_heart_stats.dart';
import 'learn_by_heart_merge.dart';
import 'learn_by_heart_storage.dart';

enum LhbSyncStatus { idle, syncing, success, error }

class LearnByHeartSyncService {
  static final LearnByHeartSyncService instance = LearnByHeartSyncService._();
  LearnByHeartSyncService._();

  static const String _collection = 'learn_by_heart';
  static const String _metaCollection = 'lhb_meta';
  static const String _checkpointDoc = 'checkpoint';
  static const String _statsDoc = 'stats';
  static const String _fieldSyncedAt = '_syncedAt';

  static const Duration _debounceDelay = Duration(seconds: 5);

  /// Giới hạn ghi của Firestore: 500 writes/commit → chừa biên an toàn.
  static const int _pluginBatchSize = 400;
  static const int _restBatchSize = 200; // mỗi doc = 2 writes (update + transform)

  final LearnByHeartStorage _storage = LearnByHeartStorage.instance;

  FirebaseFirestore? _db;
  bool? _pluginOk;

  /// Trạng thái cho UI badge.
  final ValueNotifier<LhbSyncStatus> status = ValueNotifier(LhbSyncStatus.idle);

  /// Lần đồng bộ thành công gần nhất.
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);

  /// Tăng mỗi khi PULL làm thay đổi dữ liệu cục bộ → provider nạp lại UI.
  final ValueNotifier<int> localRevision = ValueNotifier(0);

  String? _uid;
  bool _isSyncing = false;
  bool _statsDirty = false;
  Timer? _debounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool get isEnabled => _uid != null;
  String? get uid => _uid;

  /// True khi plugin cloud_firestore khả dụng (Android/iOS/macOS/Windows/Web).
  bool get hasDb {
    _pluginOk ??= _tryPlugin();
    return _pluginOk!;
  }

  bool _tryPlugin() {
    try {
      _db ??= FirebaseFirestore.instance;
      return true;
    } catch (e) {
      debugPrint('⚠️ LHB sync: cloud_firestore không khả dụng (Linux?): $e');
      return false;
    }
  }

  /// Linux: không plugin → Firestore REST (cần phiên FirebaseRestAuth).
  bool get _useRestSync => !hasDb;

  bool get _restReady => FirebaseRestAuth().currentUser != null;

  FirestoreRestClient get _rest => FirestoreRestClient();

  String? get _collectionPath => _uid == null ? null : 'users/$_uid/$_collection';

  // ══════════════════════════════════════════════════════════════
  // VÒNG ĐỜI
  // ══════════════════════════════════════════════════════════════

  Future<void> initialize(String uid) async {
    _uid = uid;
    if (!hasDb && !_restReady) {
      debugPrint(
          '⚠️ LHB sync: không có Firestore plugin & không có phiên REST → chỉ xếp hàng cục bộ');
    }

    _connectivitySub?.cancel();
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
        final hasNetwork = results.any((r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet);
        if (hasNetwork) {
          unawaited(pullFromFirestore());
          unawaited(flushPending());
        }
      });
    } catch (e) {
      // Desktop (Linux) có thể không có implementation connectivity → bỏ qua.
      debugPrint('⚠️ LHB sync: connectivity listener không khả dụng: $e');
    }

    await _loadCheckpoint();
    await pullFromFirestore();
    await flushPending();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _debounce?.cancel();
    _debounce = null;
    _uid = null;
    _isSyncing = false;
    status.value = LhbSyncStatus.idle;
  }

  // ══════════════════════════════════════════════════════════════
  // ĐÁNH DẤU THAY ĐỔI CỤC BỘ
  // ══════════════════════════════════════════════════════════════

  /// Bài vừa đổi ở máy → xếp hàng đẩy lên cloud (kể cả khi chưa đăng nhập:
  /// hàng đợi nằm lại SharedPreferences và được đẩy khi bật sync).
  void markDirty(String itemId) {
    if (itemId.trim().isEmpty) return;
    unawaited(_markPendingThenSchedule(itemId));
  }

  /// Bài vừa bị xoá ở máy → ghi bia mộ rồi xếp hàng đẩy.
  void markDeleted(String itemId) {
    if (itemId.trim().isEmpty) return;
    unawaited(_markDeletedAsync(itemId));
  }

  /// Nhịp học (streak/ngày hoạt động) vừa đổi → cần đẩy kèm.
  void markStatsDirty() {
    _statsDirty = true;
    _scheduleFlush();
  }

  Future<void> _markPendingThenSchedule(String id) async {
    await _storage.markPending(id);
    _scheduleFlush();
  }

  Future<void> _markDeletedAsync(String id) async {
    await _storage.addTombstone(id);
    await _storage.markPending(id);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (!isEnabled) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      unawaited(flushPending());
    });
  }

  // ══════════════════════════════════════════════════════════════
  // ĐẨY LÊN CLOUD
  // ══════════════════════════════════════════════════════════════

  Future<void> flushPending() async {
    if (!isEnabled || _isSyncing) return;

    final pending = await _storage.loadPendingIds();
    if (pending.isEmpty && !_statsDirty) {
      status.value = LhbSyncStatus.idle;
      return;
    }
    if (!await _hasNetwork()) return;

    if (_useRestSync) {
      if (!_restReady) return;
      await _flushRest(pending);
      return;
    }
    await _flushPlugin(pending);
  }

  /// Đẩy TOÀN BỘ bài cục bộ lên cloud (nút "Đẩy tất cả lên cloud").
  Future<void> pushAll() async {
    if (!isEnabled) return;
    final items = await _storage.readItems();
    await _queuePushAll(items);
    await flushPending();
  }

  Future<void> _queuePushAll(List<LearnByHeartItem> items) async {
    if (items.isEmpty) return;
    final pending = await _storage.loadPendingIds();
    for (final item in items) {
      pending.add(item.id);
    }
    await _storage.savePendingIds(pending);
  }

  Future<void> _flushPlugin(Set<String> pending) async {
    final uid = _uid;
    if (uid == null || !hasDb) return;

    _isSyncing = true;
    status.value = LhbSyncStatus.syncing;
    try {
      final firestore = FirebaseFirestore.instance;
      final col =
          firestore.collection('users').doc(uid).collection(_collection);

      final items = await _storage.readItems();
      final byId = <String, LearnByHeartItem>{for (final i in items) i.id: i};
      final tombstones = await _storage.loadTombstones();

      final ids = pending.toList();
      for (int i = 0; i < ids.length; i += _pluginBatchSize) {
        final end = (i + _pluginBatchSize) < ids.length
            ? i + _pluginBatchSize
            : ids.length;
        final chunk = ids.sublist(i, end);
        final batch = firestore.batch();
        var writes = 0;

        for (final id in chunk) {
          final at = tombstones[id];
          if (at != null) {
            final payload = _tombstonePayload(id, at);
            payload[_fieldSyncedAt] = FieldValue.serverTimestamp();
            batch.set(col.doc(id), payload);
            writes++;
            continue;
          }
          final item = byId[id];
          if (item == null) continue; // không còn cục bộ, không có bia mộ → bỏ
          final payload = _itemPayload(item);
          payload[_fieldSyncedAt] = FieldValue.serverTimestamp();
          batch.set(col.doc(id), payload);
          writes++;
        }

        if (writes > 0) await batch.commit();
        await _storage.clearPending(chunk);
      }

      if (_statsDirty) {
        await _pushStatsPlugin(firestore, uid);
        _statsDirty = false;
      }

      await firestore
          .collection('users')
          .doc(uid)
          .collection(_metaCollection)
          .doc(_checkpointDoc)
          .set({'lastSyncedAt': FieldValue.serverTimestamp()});

      _setSuccess('✅ LHB sync: đẩy ${ids.length} thay đổi');
    } catch (e) {
      status.value = LhbSyncStatus.error;
      debugPrint('⚠️ LHB sync flush error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushStatsPlugin(FirebaseFirestore firestore, String uid) async {
    final stats = await _storage.readStats();
    await firestore
        .collection('users')
        .doc(uid)
        .collection(_metaCollection)
        .doc(_statsDoc)
        .set({
      'streak': stats.streak,
      'lastActiveDate': stats.lastActiveDate,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      _fieldSyncedAt: FieldValue.serverTimestamp(),
    });
  }

  Future<void> _flushRest(Set<String> pending) async {
    final uid = _uid;
    final collectionPath = _collectionPath;
    if (uid == null || collectionPath == null) return;

    _isSyncing = true;
    status.value = LhbSyncStatus.syncing;
    try {
      final items = await _storage.readItems();
      final byId = <String, LearnByHeartItem>{for (final i in items) i.id: i};
      final tombstones = await _storage.loadTombstones();

      final ids = pending.toList();
      for (int i = 0; i < ids.length; i += _restBatchSize) {
        final end = (i + _restBatchSize) < ids.length
            ? i + _restBatchSize
            : ids.length;
        final chunk = ids.sublist(i, end);
        final writes = <Map<String, dynamic>>[];

        for (final id in chunk) {
          final path = '$collectionPath/$id';
          final at = tombstones[id];
          if (at != null) {
            writes.add(_rest.updateWrite(path, _tombstonePayload(id, at)));
          } else {
            final item = byId[id];
            if (item == null) continue;
            writes.add(_rest.updateWrite(path, _itemPayload(item)));
          }
          writes.add(_rest.serverTimeWrite(path, _fieldSyncedAt));
        }

        if (writes.isNotEmpty) await _rest.commitWrites(writes);
        await _storage.clearPending(chunk);
      }

      if (_statsDirty) {
        final stats = await _storage.readStats();
        final path = 'users/$uid/$_metaCollection/$_statsDoc';
        await _rest.commitWrites([
          _rest.updateWrite(path, {
            'streak': stats.streak,
            'lastActiveDate': stats.lastActiveDate,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }),
          _rest.serverTimeWrite(path, _fieldSyncedAt),
        ]);
        _statsDirty = false;
      }

      final cpPath = 'users/$uid/$_metaCollection/$_checkpointDoc';
      await _rest.commitWrites([
        _rest.updateWrite(cpPath, const <String, dynamic>{}),
        _rest.serverTimeWrite(cpPath, 'lastSyncedAt'),
      ]);

      _setSuccess('✅ LHB sync (REST): đẩy ${ids.length} thay đổi');
    } catch (e) {
      status.value = LhbSyncStatus.error;
      debugPrint('⚠️ LHB sync flush (REST) error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // KÉO TỪ CLOUD (+ hòa giải)
  // ══════════════════════════════════════════════════════════════

  Future<int> pullFromFirestore({bool forceAll = false}) async {
    if (!isEnabled || _isSyncing) return 0;
    if (!await _hasNetwork()) return 0;

    if (_useRestSync) {
      if (!_restReady) return 0;
      return _pullRest(forceAll: forceAll);
    }
    return _pullPlugin(forceAll: forceAll);
  }

  Future<int> _pullPlugin({bool forceAll = false}) async {
    final uid = _uid;
    if (uid == null || !hasDb) return 0;

    _isSyncing = true;
    status.value = LhbSyncStatus.syncing;
    try {
      final firestore = FirebaseFirestore.instance;
      final meta = await firestore
          .collection('users')
          .doc(uid)
          .collection(_metaCollection)
          .doc(_checkpointDoc)
          .get();
      final lastSync = meta.data()?['lastSyncedAt'] as Timestamp?;

      final localItems = await _storage.readItems();
      Query<Map<String, dynamic>> query =
          firestore.collection('users').doc(uid).collection(_collection);
      if (lastSync != null && !forceAll && localItems.isNotEmpty) {
        query = query.where(_fieldSyncedAt, isGreaterThan: lastSync);
      }

      final snapshot = await query.get();
      final records = <LearnByHeartRemoteRecord>[];
      for (final doc in snapshot.docs) {
        final record =
            LearnByHeartRemoteRecord.fromFirestoreDoc(doc.id, doc.data());
        if (record != null) records.add(record);
      }

      final applied = await _applyRecords(records);
      await _pullStatsPlugin(firestore, uid);

      // Lần đầu bật sync cho tài khoản này (chưa có checkpoint) mà cloud trống
      // trong khi máy đã có bài → đẩy toàn bộ lên để không mất dữ liệu.
      final firstSync = lastSync == null;
      if (firstSync && records.isEmpty && localItems.isNotEmpty) {
        await _queuePushAll(localItems);
      }

      _setSuccess(
          '✅ LHB sync: kéo ${records.length} doc, áp dụng $applied thay đổi');
      return applied;
    } catch (e) {
      status.value = LhbSyncStatus.error;
      debugPrint('⚠️ LHB sync pull error: $e');
      return 0;
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> _pullRest({bool forceAll = false}) async {
    final uid = _uid;
    if (uid == null) return 0;

    _isSyncing = true;
    status.value = LhbSyncStatus.syncing;
    try {
      final localItems = await _storage.readItems();
      final meta = await _rest
          .getDocument('users/$uid/$_metaCollection/$_checkpointDoc');
      final lastSync = LearnByHeartItem.parseStamp(meta?['lastSyncedAt']);

      final List<FirestoreRestDoc> docs;
      if (lastSync != null && !forceAll && localItems.isNotEmpty) {
        docs = await _rest.runQuery(
          parentPath: 'users/$uid',
          collectionId: _collection,
          filterField: _fieldSyncedAt,
          filterAfter: lastSync,
        );
      } else {
        docs = await _rest.listCollection('users/$uid/$_collection');
      }

      final records = <LearnByHeartRemoteRecord>[];
      for (final doc in docs) {
        final record = LearnByHeartRemoteRecord.fromFirestoreDoc(doc.id, doc.data);
        if (record != null) records.add(record);
      }

      final applied = await _applyRecords(records);
      await _pullStatsRest(uid);

      final firstSync = lastSync == null;
      if (firstSync && records.isEmpty && localItems.isNotEmpty) {
        await _queuePushAll(localItems);
      }

      _setSuccess(
          '✅ LHB sync (REST): kéo ${records.length} doc, áp dụng $applied thay đổi');
      return applied;
    } catch (e) {
      status.value = LhbSyncStatus.error;
      debugPrint('⚠️ LHB sync pull (REST) error: $e');
      return 0;
    } finally {
      _isSyncing = false;
    }
  }

  /// Áp các doc cloud lên kho cục bộ (hòa giải thuần ở [LearnByHeartMerge]).
  Future<int> _applyRecords(List<LearnByHeartRemoteRecord> records) async {
    if (records.isEmpty) return 0;

    final localItems = await _storage.readItems();
    final pending = await _storage.loadPendingIds();
    final tombstones = await _storage.loadTombstones();

    final result = LearnByHeartMerge.merge(
      localItems: localItems,
      remoteRecords: records,
      pendingIds: pending,
      tombstones: tombstones,
    );

    if (result.appliedCount > 0) {
      await _storage.saveItems(result.items);
    }
    if (!_sameTombstones(tombstones, result.tombstones)) {
      await _storage.saveTombstones(result.tombstones);
    }
    if (!_sameIds(pending, result.pendingIds)) {
      await _storage.savePendingIds(result.pendingIds);
    }
    if (result.appliedCount > 0) {
      localRevision.value = localRevision.value + 1;
    }
    return result.appliedCount;
  }

  Future<void> _pullStatsPlugin(FirebaseFirestore firestore, String uid) async {
    final doc = await firestore
        .collection('users')
        .doc(uid)
        .collection(_metaCollection)
        .doc(_statsDoc)
        .get();
    final data = doc.data();
    if (data == null) return;
    await _applyRemoteStats(LearnByHeartStats.fromJson(data));
  }

  Future<void> _pullStatsRest(String uid) async {
    final data =
        await _rest.getDocument('users/$uid/$_metaCollection/$_statsDoc');
    if (data == null) return;
    await _applyRemoteStats(LearnByHeartStats.fromJson(data));
  }

  Future<void> _applyRemoteStats(LearnByHeartStats remote) async {
    if (remote.isEmpty) return;
    final local = await _storage.readStats();
    final merged = LearnByHeartStats.reconcile(local, remote);
    if (merged.streak == local.streak &&
        merged.lastActiveDate == local.lastActiveDate) {
      return;
    }
    await _storage.writeStats(merged);
    localRevision.value = localRevision.value + 1;
  }

  // ══════════════════════════════════════════════════════════════
  // HELPER
  // ══════════════════════════════════════════════════════════════

  Map<String, dynamic> _itemPayload(LearnByHeartItem item) {
    final data = item.toJson();
    data['updatedAt'] = item.syncStamp.toUtc().toIso8601String();
    data['deleted'] = false;
    return data;
  }

  Map<String, dynamic> _tombstonePayload(String id, DateTime at) {
    final iso = at.toUtc().toIso8601String();
    return <String, dynamic>{
      'id': id,
      'deleted': true,
      'deletedAt': iso,
      'updatedAt': iso,
    };
  }

  Future<void> _loadCheckpoint() async {
    final uid = _uid;
    if (uid == null) return;

    if (_useRestSync) {
      if (!_restReady) return;
      try {
        final doc = await _rest
            .getDocument('users/$uid/$_metaCollection/$_checkpointDoc');
        final ts = LearnByHeartItem.parseStamp(doc?['lastSyncedAt']);
        if (ts != null) lastSyncedAt.value = ts;
      } catch (e) {
        debugPrint('⚠️ LHB sync: REST load checkpoint: $e');
      }
      return;
    }

    if (!hasDb) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(_metaCollection)
          .doc(_checkpointDoc)
          .get();
      final ts = doc.data()?['lastSyncedAt'] as Timestamp?;
      final date = ts?.toDate();
      if (date != null) lastSyncedAt.value = date;
    } catch (e) {
      debugPrint('⚠️ LHB sync: load checkpoint: $e');
    }
  }

  /// Connectivity check an toàn đa nền tảng: plugin không có (Linux) → coi như
  /// online, HTTP tự fail và hàng đợi được giữ nguyên.
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

  void _setSuccess(String message) {
    lastSyncedAt.value = DateTime.now();
    status.value = LhbSyncStatus.success;
    debugPrint(message);
    Future.delayed(const Duration(seconds: 3), () {
      if (status.value == LhbSyncStatus.success) {
        status.value = LhbSyncStatus.idle;
      }
    });
  }

  bool _sameIds(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  bool _sameTombstones(Map<String, DateTime> a, Map<String, DateTime> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !other.isAtSameMomentAs(entry.value)) return false;
    }
    return true;
  }
}
