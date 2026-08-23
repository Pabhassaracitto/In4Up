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

  // ── Đọc tất cả ──────────────────────────────────────────────
  Future<List<RecentAudio>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    return _loadFromDisk();
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
  Future<void> addOrUpdate(RecentAudio audio) async {
    final list = List<RecentAudio>.from(await getAll());
    list.removeWhere((a) =>
        a.id == audio.id ||
        (audio.localPath != null &&
            a.localPath != null &&
            a.localPath!.toLowerCase() == audio.localPath!.toLowerCase()));
    list.insert(0, audio.copyWith(lastOpened: DateTime.now()));
    await _saveToDisk(list.take(_maxItems).toList());
  }

  // ── Cập nhật vị trí nghe ────────────────────────────────────
  Future<void> updatePosition(
    String audioId, {
    required Duration position,
    required Duration totalDuration,
  }) async {
    final list = List<RecentAudio>.from(await getAll());
    final idx = list.indexWhere((a) => a.id == audioId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(
      lastPosition: position,
      totalDuration: totalDuration,
      lastOpened: DateTime.now(),
    );
    await _saveToDisk(list);
  }

  // ── Xóa ─────────────────────────────────────────────────────
  Future<void> remove(String audioId) async {
    final list = List<RecentAudio>.from(await getAll());
    list.removeWhere((a) => a.id == audioId);
    await _saveToDisk(list);
  }

  Future<void> clearAll() async {
    _cache = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

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
