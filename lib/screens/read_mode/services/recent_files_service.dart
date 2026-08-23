// lib/screens/read_mode/services/recent_files_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_file.dart';

class RecentFilesService {
  static const String _key = 'in4up_read_recent_v1';
  static const int _maxItems = 30;

  // Singleton
  static final RecentFilesService _instance = RecentFilesService._internal();
  factory RecentFilesService() => _instance;
  RecentFilesService._internal();

  // In-memory cache
  List<RecentFile>? _cache;

  // ── Đọc tất cả ──────────────────────────────────────────────
  Future<List<RecentFile>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    return _loadFromDisk();
  }

  Future<List<RecentFile>> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];

      final files = <RecentFile>[];
      for (final item in raw) {
        try {
          files.add(RecentFile.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ));
        } catch (e) {
          debugPrint('[RecentFiles] Parse error: $e');
        }
      }

      // Mới nhất lên đầu
      files.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
      _cache = files;
      return List.unmodifiable(files);
    } catch (e) {
      debugPrint('[RecentFiles] Load error: $e');
      _cache = [];
      return [];
    }
  }

  // ── Thêm hoặc cập nhật ──────────────────────────────────────
  Future<void> addOrUpdate(RecentFile file) async {
    final files = List<RecentFile>.from(await getAll());

    // Xóa nếu đã có
    files.removeWhere((f) =>
        f.id == file.id ||
        (file.localPath != null &&
            f.localPath != null &&
            f.localPath!.toLowerCase() == file.localPath!.toLowerCase()));

    // Thêm lên đầu với timestamp mới
    files.insert(
      0,
      file.copyWith(lastOpened: DateTime.now()),
    );

    // Giới hạn
    final trimmed = files.take(_maxItems).toList();
    await _saveToDisk(trimmed);
  }

  // ── Cập nhật tiến độ ────────────────────────────────────────
  Future<void> updateProgress(
    String fileId, {
    required int currentLine,
    required int totalLines,
  }) async {
    final files = List<RecentFile>.from(await getAll());
    final index = files.indexWhere((f) => f.id == fileId);
    if (index == -1) return;

    files[index] = files[index].copyWith(
      lastReadLine: currentLine,
      totalLines: totalLines,
      lastOpened: DateTime.now(),
    );

    await _saveToDisk(files);
  }

  // ── Xóa 1 file ──────────────────────────────────────────────
  Future<void> remove(String fileId) async {
    final files = List<RecentFile>.from(await getAll());
    files.removeWhere((f) => f.id == fileId);
    await _saveToDisk(files);
  }

  // ── Xóa tất cả ──────────────────────────────────────────────
  Future<void> clearAll() async {
    _cache = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ── Ghi disk ────────────────────────────────────────────────
  Future<void> _saveToDisk(List<RecentFile> files) async {
    _cache = List.unmodifiable(files);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = files.map((f) => jsonEncode(f.toJson())).toList();
      await prefs.setStringList(_key, encoded);
    } catch (e) {
      debugPrint('[RecentFiles] Save error: $e');
    }
  }

  // ── Invalidate cache ─────────────────────────────────────────
  void invalidateCache() => _cache = null;
}
