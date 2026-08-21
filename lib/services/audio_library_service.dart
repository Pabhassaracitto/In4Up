// lib/services/audio_library_service.dart
// Thư viện âm thanh (P1) — quét + hợp nhất + lưu Hive.
//
// Logic merge để PURE static (test được):
//   mergeScanned(scanned, existing) — de-dupe theo uri, giữ lastPlayed/fingerprint
//   của entry cũ, giữ entry nguồn không-phải-media khi file biến mất khỏi MediaStore.

import '../models/audio_library_entry.dart';
import '../services/audio_library_channel.dart';
import '../services/storage_service.dart';

class AudioLibraryService {
  final StorageService _storage = StorageService();

  /// Quét MediaStore, hợp nhất với chỉ mục đã lưu, ghi Hive, trả danh sách mới.
  Future<List<AudioLibraryEntry>> scanMediaStore() async {
    final raw = await AudioLibraryChannel.scanMediaStore();
    final scanned = raw.map(AudioLibraryEntry.fromMediaMap).toList();
    final existing = _storage.getAllAudioLibraryEntries();
    final merged = mergeScanned(scanned, existing);
    await _storage.saveAllAudioLibraryEntries(merged);
    return merged;
  }

  /// PURE — merge danh sách quét được với chỉ mục cũ.
  ///
  /// - Entry mới (chưa có uri trong cũ) → giữ nguyên.
  /// - Entry trùng uri → giữ lastPlayed + fingerprint của bản cũ.
  /// - Entry cũ source=media không còn trong lần quét mới → bỏ (file đã xóa).
  /// - Entry cũ source≠media (picked/recent/folder) luôn giữ.
  static List<AudioLibraryEntry> mergeScanned(
    List<AudioLibraryEntry> scanned,
    List<AudioLibraryEntry> existing,
  ) {
    final byUri = <String, AudioLibraryEntry>{
      for (final e in existing) e.uri: e,
    };

    final merged = <AudioLibraryEntry>[];
    final seen = <String>{};

    for (final entry in scanned) {
      if (seen.contains(entry.uri)) continue;
      seen.add(entry.uri);
      final old = byUri[entry.uri];
      merged.add(old != null
          ? entry.copyWith(
              lastPlayed: old.lastPlayed,
              fingerprint: old.fingerprint,
            )
          : entry);
      byUri.remove(entry.uri);
    }

    // Giữ các entry nguồn không-phải-media (recent/picked/folder) dù không
    // còn trong MediaStore — người dùng có thể đã import từ nơi khác.
    for (final old in byUri.values) {
      if (old.source != AudioSource.media && !seen.contains(old.uri)) {
        merged.add(old);
      }
    }

    merged.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return merged;
  }

  /// Đánh dấu đã nghe (cập nhật lastPlayed trong Hive).
  Future<void> markPlayed(AudioLibraryEntry entry) async {
    final updated = entry.copyWith(lastPlayed: DateTime.now());
    await _storage.saveAudioLibraryEntry(updated);
  }

  /// Tìm kiếm theo tên/artist (chữ thường, contains).
  static List<AudioLibraryEntry> search(
    List<AudioLibraryEntry> entries,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) {
      if (e.title.toLowerCase().contains(q)) return true;
      if (e.artist?.toLowerCase().contains(q) ?? false) return true;
      return false;
    }).toList();
  }
}
