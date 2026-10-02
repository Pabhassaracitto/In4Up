// lib/models/audio_playlist.dart
// I4U18-LISTEN-LIB-001 — Playlist THỦ CÔNG cho tab Nghe.
//
// Playlist chỉ lưu DANH SÁCH libraryId (khoá ổn định của AudioLibraryEntry) —
// KHÔNG sao chép metadata → không phá transcript/LRC/reopen (những thứ đó key
// bằng audioPath/audioId ở nơi khác, playlist không đụng tới).

import 'dart:convert';

import 'package:crypto/crypto.dart';

class AudioPlaylist {
  final String id;
  String name;

  /// Danh sách libraryId các bài trong playlist (giữ thứ tự người dùng thêm).
  final List<String> trackIds;

  final DateTime createdAt;
  DateTime updatedAt;

  AudioPlaylist({
    required this.id,
    required this.name,
    List<String>? trackIds,
    required this.createdAt,
    required this.updatedAt,
  }) : trackIds = trackIds ?? [];

  int get length => trackIds.length;
  bool get isEmpty => trackIds.isEmpty;

  bool contains(String trackId) => trackIds.contains(trackId);

  /// Thêm bài (không trùng); trả true nếu có thay đổi.
  bool add(String trackId) {
    if (trackIds.contains(trackId)) return false;
    trackIds.add(trackId);
    updatedAt = DateTime.now();
    return true;
  }

  /// Bỏ bài; trả true nếu có thay đổi.
  bool remove(String trackId) {
    final ok = trackIds.remove(trackId);
    if (ok) updatedAt = DateTime.now();
    return ok;
  }

  /// Di chuyển bài (kéo-thả). Giữ trong biên.
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= trackIds.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target > trackIds.length - 1) target = trackIds.length - 1;
    final item = trackIds.removeAt(oldIndex);
    trackIds.insert(target, item);
    updatedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trackIds': trackIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AudioPlaylist.fromJson(Map<String, dynamic> j) => AudioPlaylist(
        id: (j['id'] as String?) ?? _genId(),
        name: (j['name'] as String?) ?? 'Playlist',
        trackIds: ((j['trackIds'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  factory AudioPlaylist.create(String name) {
    final now = DateTime.now();
    return AudioPlaylist(
      id: _genId(),
      name: name.trim().isEmpty ? 'Playlist' : name.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _genId() {
    final seed = '${DateTime.now().microsecondsSinceEpoch}';
    return 'pl_${md5.convert(utf8.encode(seed)).toString().substring(0, 12)}';
  }
}
