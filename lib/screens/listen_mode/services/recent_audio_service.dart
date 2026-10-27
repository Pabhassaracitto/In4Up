import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_audio.dart';

class RecentAudioService {
  static const String _key = 'in4up_listen_recent_v1';
  static const int _maxItems = 30;

  // Singleton
  static final RecentAudioService _instance = RecentAudioService._internal();
  factory RecentAudioService() => _instance;
  RecentAudioService._internal();

  List<RecentAudio>? _cache;
  Future<List<RecentAudio>>? _loading;
  Future<void> _mutationTail = Future<void>.value();

  /// Serialize read-modify-write operations so a position update cannot be
  /// overwritten by an overlapping queue transition or removal.
  Future<void> _mutate(Future<void> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  // ── Đọc tất cả ──────────────────────────────────────────────
  Future<List<RecentAudio>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    final loading = _loading ??= _loadFromDisk();
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  Future<List<RecentAudio>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];

      final items = <RecentAudio>[];
      for (final s in raw) {
        try {
          items.add(RecentAudio.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ));
        } catch (e) {
          debugPrint('[RecentAudio] Parse error: $e');
        }
      }

      items.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
      _cache = items;
      return List.unmodifiable(items);
    } catch (e) {
      debugPrint('[RecentAudio] Load error: $e');
      _cache = [];
      return [];
    }
  }

  // ── Thêm / cập nhật ─────────────────────────────────────────
  Future<void> addOrUpdate(
    RecentAudio audio, {
    bool preservePositionIfZero = false,
  }) => _mutate(() async {
    final list = List<RecentAudio>.from(await getAll());
    bool matches(RecentAudio old) {
      final newPath = audio.localPath;
      final oldPath = old.localPath;
      if (newPath != null || oldPath != null) {
        // Match the exact source (case-sensitive on Unix/Android) to migrate
        // old case-folded IDs without merging a different file's history.
        return newPath != null && oldPath != null &&
            RecentAudio.localIdentity(newPath) == RecentAudio.localIdentity(oldPath);
      }
      return old.id == audio.id;
    }
    RecentAudio? previous;
    for (final old in list) {
      if (matches(old)) {
        previous = old;
        break;
      }
    }
    list.removeWhere(matches);
    final position = preservePositionIfZero && audio.lastPosition == Duration.zero
        ? previous?.lastPosition
        : null;
    list.insert(0, audio.copyWith(
      lastOpened: DateTime.now(),
      lastPosition: position,
      totalDuration: audio.totalDuration == Duration.zero
          ? previous?.totalDuration
          : null,
    ));
    await _saveToDisk(list.take(_maxItems).toList());
  });

  // ── Cập nhật vị trí nghe ────────────────────────────────────
  Future<void> updatePosition(
    String audioId, {
    required Duration position,
    required Duration totalDuration,
  }) => _mutate(() async {
    final list = List<RecentAudio>.from(await getAll());
    final idx = list.indexWhere((a) => a.id == audioId);
    if (idx == -1) return;
    list[idx] = list[idx].copyWith(
      lastPosition: position,
      totalDuration: totalDuration,
      lastOpened: DateTime.now(),
    );
    await _saveToDisk(list);
  });

  // ── Xóa ─────────────────────────────────────────────────────
  Future<void> remove(String audioId) => _mutate(() async {
    final list = List<RecentAudio>.from(await getAll());
    list.removeWhere((a) => a.id == audioId);
    await _saveToDisk(list);
  });

  Future<void> clearAll() => _mutate(() async {
    final loading = _loading;
    if (loading != null) await loading;
    _cache = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  });

  // ── Ghi disk ─────────────────────────────────────────────────
  Future<void> _saveToDisk(List<RecentAudio> list) async {
    _cache = List.unmodifiable(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        list.map((a) => jsonEncode(a.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('[RecentAudio] Save error: $e');
    }
  }

  void invalidateCache() => _cache = null;
}
