// lib/data/repositories/impl/offline_first_text_library_repository.dart
//
// Offline-first TextLibrary: Hive cache + Firestore remote
// Đọc: ưu tiên cache local (0ms), đồng thời fetch remote nền và cập nhật cache
// Ghi: ghi cache trước, enqueue -> remote khi có mạng

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../services/text_library_service.dart';
import '../../datasources/text_library_local_datasource.dart';
import '../../datasources/text_library_remote_datasource.dart';
import '../interfaces/text_library_repository.dart';

class OfflineFirstTextLibraryRepository implements TextLibraryRepository {
  OfflineFirstTextLibraryRepository({
    TextLibraryLocalDataSource? local,
    TextLibraryRemoteDataSource? remote,
  })  : _local = local ?? TextLibraryLocalDataSource(),
        _remote = remote ?? FirestoreTextLibraryRemoteDataSource();

  final TextLibraryLocalDataSource _local;
  final TextLibraryRemoteDataSource _remote;

  final ValueNotifier<bool> _isSyncing = ValueNotifier(false);
  StreamSubscription? _remoteSub;
  StreamSubscription? _localSub;
  final _controller = StreamController<List<TextLibraryEntry>>.broadcast();
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    await _local.init();
    _initialized = true;

    // Forward local changes -> stream
    _localSub?.cancel();
    _localSub = _local.watch().listen((_) {
      if (!_controller.isClosed) _controller.add(_local.getAll());
    });

    // Lắng remote nếu có user, sẽ sync vào cache
    _listenRemote();
  }

  void _listenRemote() {
    _remoteSub?.cancel();
    final stream = _remote.watchAll();
    _remoteSub = stream.listen((remoteEntries) async {
      if (remoteEntries.isEmpty) return;
      // So sánh updatedAt, chỉ ghi những bản ghi mới hơn cache
      final cached = {for (final e in _local.getAll()) e.id: e};
      final toCache = <TextLibraryEntry>[];
      for (final r in remoteEntries) {
        final c = cached[r.id];
        if (c == null || r.updatedAt.isAfter(c.updatedAt)) {
          toCache.add(r);
        }
      }
      if (toCache.isNotEmpty) {
        await _local.putAll(toCache);
        if (!_controller.isClosed) _controller.add(_local.getAll());
      }
    }, onError: (e) {
      debugPrint('OfflineFirstTextLibrary remote listen error: $e');
    });
  }

  // ── Đọc ────────────────────────────────────────────────

  @override
  Stream<List<TextLibraryEntry>> watchAll() {
    // Đảm bảo init đã chạy
    if (!_initialized) {
      unawaited(init());
    }
    return _controller.stream;
  }

  Stream<List<TextLibraryEntry>> watchAllWithInitial() async* {
    await init();
    yield _local.getAll();
    yield* _controller.stream;
    // đồng thời trigger sync nền
    unawaited(syncFromRemote());
  }

  @override
  Future<List<TextLibraryEntry>> fetchAll() async {
    await init();
    // Trả cache ngay, đồng thời fetch remote nền
    final cached = _local.getAll();
    unawaited(syncFromRemote());
    return cached;
  }

  @override
  Future<TextLibraryEntry?> getById(String id) async {
    await init();
    final cached = _local.getById(id);
    if (cached != null) return cached;
    // fallback remote
    final remote = await _remote.getById(id);
    if (remote != null) {
      await _local.put(remote);
    }
    return remote;
  }

  @override
  Future<List<TextLibraryEntry>> search(String query) async {
    await init();
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return _local.getAll();
    return _local.getAll().where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.content.toLowerCase().contains(q) ||
          (e.category ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  List<TextLibraryEntry> getCached() => _local.getAll();

  // ── Ghi (local-first) ──────────────────────────────────

  @override
  Future<TextLibraryEntry?> add({
    required String title,
    required String content,
    String? category,
  }) async {
    await init();
    // Tạo id tạm thời (sẽ được remote ghi đè bằng id thật)
    final tempId = 'tl_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final temp = TextLibraryEntry(
      id: tempId,
      title: title,
      content: content,
      category: category,
      wordCount: content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      createdAt: now,
      updatedAt: now,
    );
    await _local.put(temp);
    if (!_controller.isClosed) _controller.add(_local.getAll());

    // Thử ghi remote
    final hasNetwork = await _hasNetwork();
    if (!hasNetwork) {
      _local.markPending(tempId, 'upsert:$tempId');
      return temp;
    }

    final remoteEntry = await _remote.add(title: title, content: content, category: category);
    if (remoteEntry != null) {
      // thay temp bằng remote id
      await _local.delete(tempId);
      await _local.put(remoteEntry);
      if (!_controller.isClosed) _controller.add(_local.getAll());
      return remoteEntry;
    } else {
      _local.markPending(tempId, 'upsert:$tempId');
      return temp;
    }
  }

  @override
  Future<bool> update(TextLibraryEntry entry) async {
    await init();
    final updated = entry.copyWith(); // copyWith tự set updatedAt = now
    await _local.put(updated);
    if (!_controller.isClosed) _controller.add(_local.getAll());

    final hasNetwork = await _hasNetwork();
    if (!hasNetwork) {
      _local.markPending(entry.id, 'upsert:${entry.id}');
      return true; // local success
    }

    final ok = await _remote.update(updated);
    if (!ok) _local.markPending(entry.id, 'upsert:${entry.id}');
    return ok;
  }

  @override
  Future<bool> delete(String id) async {
    await init();
    await _local.delete(id);
    if (!_controller.isClosed) _controller.add(_local.getAll());

    final hasNetwork = await _hasNetwork();
    if (!hasNetwork) {
      _local.markPending(id, 'delete:$id');
      return true;
    }

    final ok = await _remote.delete(id);
    if (!ok) _local.markPending(id, 'delete:$id');
    return ok;
  }

  @override
  Future<void> clearCache() async {
    await _local.clear();
    if (!_controller.isClosed) _controller.add([]);
  }

  // ── Sync ───────────────────────────────────────────────

  @override
  bool get isAvailable => _remote.collection != null;

  @override
  ValueNotifier<bool> get isSyncing => _isSyncing;

  @override
  Future<int> syncFromRemote({bool force = false}) async {
    await init();
    if (!await _hasNetwork()) return 0;
    _isSyncing.value = true;
    try {
      final remoteEntries = await _remote.fetchAll();
      if (remoteEntries.isEmpty) {
        _isSyncing.value = false;
        return 0;
      }
      final cached = {for (final e in _local.getAll()) e.id: e};
      int updated = 0;
      for (final r in remoteEntries) {
        final c = cached[r.id];
        if (c == null || force || r.updatedAt.isAfter(c.updatedAt)) {
          await _local.put(r);
          updated++;
        }
      }
      if (updated > 0 && !_controller.isClosed) {
        _controller.add(_local.getAll());
      }
      return updated;
    } catch (e) {
      debugPrint('OfflineFirstTextLibrary.syncFromRemote error: $e');
      return 0;
    } finally {
      _isSyncing.value = false;
    }
  }

  @override
  Future<void> syncPendingToRemote() async {
    if (!await _hasNetwork()) return;
    final pending = _local.pendingOps;
    if (pending.isEmpty) return;

    for (final e in pending.entries) {
      final id = e.key.toString();
      final op = e.value.toString();
      try {
        if (op.startsWith('delete:')) {
          await _remote.delete(id);
          _local.clearPending(id);
        } else if (op.startsWith('upsert:')) {
          final entry = _local.getById(id);
          if (entry == null) {
            _local.clearPending(id);
            continue;
          }
          // Thử update, nếu fail (chưa có trên remote) thì add
          final ok = await _remote.update(entry);
          if (!ok) {
            final added = await _remote.add(
              title: entry.title,
              content: entry.content,
              category: entry.category,
            );
            if (added != null) {
              await _local.delete(id);
              await _local.put(added);
            }
          }
          _local.clearPending(id);
        }
      } catch (err) {
        debugPrint('syncPending op $op failed: $err');
      }
    }
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    _localSub?.cancel();
    _controller.close();
    _isSyncing.dispose();
  }
}

/// Factory để đổi backend bằng flag
class TextLibraryRepositoryFactory {
  static TextLibraryRepository create({bool useSupabase = false}) {
    final remote = useSupabase
        ? SupabaseTextLibraryRemoteDataSource()
        : FirestoreTextLibraryRemoteDataSource();
    return OfflineFirstTextLibraryRepository(remote: remote);
  }
}
