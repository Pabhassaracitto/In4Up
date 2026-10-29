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

  /// Trả đường dẫn PHÁT ĐƯỢC: content:// → copy sang cache (file thật) vì
  /// just_audio/ExoPlayer trong app phát content:// không ổn định trên nhiều
  /// thiết bị. Non-content → trả nguyên.
  /// (Fix "mở bài hát không chạy được" từ tab Thư viện.)
  Future<String> resolvePlayablePath(String uri) async {
    if (!uri.startsWith('content://')) return uri;
    final path = await AudioLibraryChannel.copyContentToCache(uri);
    return path ?? uri;
  }

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
              favorite: old.favorite, // GIỮ yêu thích khi quét lại
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

  /// Bật/tắt yêu thích + lưu Hive; trả entry đã cập nhật.
  Future<AudioLibraryEntry> toggleFavorite(AudioLibraryEntry entry) async {
    final updated = entry.copyWith(favorite: !entry.favorite);
    await _storage.saveAudioLibraryEntry(updated);
    return updated;
  }

  /// Tìm kiếm theo tên/artist/album (chữ thường, contains).
  static List<AudioLibraryEntry> search(
    List<AudioLibraryEntry> entries,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) {
      if (e.title.toLowerCase().contains(q)) return true;
      if (e.artist?.toLowerCase().contains(q) ?? false) return true;
      if (e.album?.toLowerCase().contains(q) ?? false) return true;
      return false;
    }).toList();
  }

  // ── Bộ lọc + smart playlist (I4U18-LISTEN-LIB-001) ───────────
  // Tất cả PURE static để test dễ.

  /// Danh sách album duy nhất (bỏ null/rỗng), đã sắp xếp.
  static List<String> albums(List<AudioLibraryEntry> entries) =>
      _distinct(entries.map((e) => e.album));

  /// Danh sách nghệ sĩ/tác giả duy nhất.
  static List<String> artists(List<AudioLibraryEntry> entries) =>
      _distinct(entries.map((e) => e.artist));

  /// Danh sách thư mục duy nhất.
  static List<String> folders(List<AudioLibraryEntry> entries) =>
      _distinct(entries.map((e) => e.folder));

  static List<String> _distinct(Iterable<String?> values) {
    final set = <String>{};
    for (final v in values) {
      final s = (v ?? '').trim();
      if (s.isNotEmpty) set.add(s);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Lọc theo album (khớp chính xác, không phân biệt hoa thường).
  static List<AudioLibraryEntry> byAlbum(
          List<AudioLibraryEntry> entries, String album) =>
      entries
          .where((e) =>
              (e.album ?? '').toLowerCase() == album.trim().toLowerCase())
          .toList();

  /// Lọc theo nghệ sĩ/tác giả.
  static List<AudioLibraryEntry> byArtist(
          List<AudioLibraryEntry> entries, String artist) =>
      entries
          .where((e) =>
              (e.artist ?? '').toLowerCase() == artist.trim().toLowerCase())
          .toList();

  /// Lọc theo thư mục.
  static List<AudioLibraryEntry> byFolder(
          List<AudioLibraryEntry> entries, String folder) =>
      entries
          .where((e) => e.folder.toLowerCase() == folder.trim().toLowerCase())
          .toList();

  /// Chỉ mục yêu thích.
  static List<AudioLibraryEntry> favorites(List<AudioLibraryEntry> entries) =>
      entries.where((e) => e.favorite).toList();

  /// Smart playlist "Gần đây": đã phát trong [days] ngày, sắp xếp mới → cũ.
  static List<AudioLibraryEntry> recent(
    List<AudioLibraryEntry> entries, {
    int days = 30,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final list = entries
        .where((e) =>
            e.lastPlayed != null &&
            ref.difference(e.lastPlayed!).inDays.abs() <= days)
        .toList()
      ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return list;
  }

  /// Smart playlist "Chưa nghe": chưa từng phát (lastPlayed == null).
  static List<AudioLibraryEntry> unplayed(List<AudioLibraryEntry> entries) =>
      entries.where((e) => e.lastPlayed == null).toList();

  /// Áp một smart playlist theo enum (dùng chung cho provider/UI).
  static List<AudioLibraryEntry> applySmart(
    List<AudioLibraryEntry> entries,
    SmartPlaylist kind, {
    DateTime? now,
  }) {
    switch (kind) {
      case SmartPlaylist.recent:
        return recent(entries, now: now);
      case SmartPlaylist.favorite:
        return favorites(entries);
      case SmartPlaylist.unplayed:
        return unplayed(entries);
      case SmartPlaylist.all:
        return entries;
    }
  }
}

/// Smart playlist tối thiểu (I4U18-LISTEN-LIB-001).
enum SmartPlaylist { all, recent, favorite, unplayed }
