// lib/providers/audio_library_provider.dart
// Thư viện âm thanh (P1 + I4U18-LISTEN-LIB-001) — trạng thái: entries, quyền,
// đang quét, lỗi, YÊU THÍCH, bộ lọc (album/tác giả/thư mục), smart playlist,
// và PLAYLIST THỦ CÔNG.
//
// Quyền dùng permission_handler (đã có sẵn trong dự án):
//  - Android 13+: Permission.audio → READ_MEDIA_AUDIO
//  - Android ≤12 : Permission.audio → READ_EXTERNAL_STORAGE
//
// LƯU Ý: playlist chỉ giữ libraryId — KHÔNG đụng transcript/LRC/reopen
// timestamp (những dữ liệu đó key bằng audioPath ở lớp khác).

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/audio_library_entry.dart';
import '../models/audio_playlist.dart';
import '../services/audio_library_service.dart';
import '../services/storage_service.dart';

class AudioLibraryProvider extends ChangeNotifier {
  final AudioLibraryService _service = AudioLibraryService();
  final StorageService _storage = StorageService();

  List<AudioLibraryEntry> _entries = [];
  List<AudioPlaylist> _playlists = [];
  bool _loaded = false;
  bool _scanning = false;
  bool _permissionGranted = false;
  String? _error;

  List<AudioLibraryEntry> get entries => List.unmodifiable(_entries);
  List<AudioPlaylist> get playlists => List.unmodifiable(_playlists);
  bool get isLoaded => _loaded;
  bool get isScanning => _scanning;
  bool get hasPermission => _permissionGranted;
  String? get error => _error;
  int get count => _entries.length;

  // ── Facet lists (cho UI bộ lọc) ──────────────────────────────
  List<String> get albums => AudioLibraryService.albums(_entries);
  List<String> get artists => AudioLibraryService.artists(_entries);
  List<String> get folders => AudioLibraryService.folders(_entries);
  int get favoriteCount => _entries.where((e) => e.favorite).length;

  /// Nạp chỉ mục + playlist đã lưu (không quét).
  Future<void> load() async {
    if (_loaded) return;
    _entries = _storage.getAllAudioLibraryEntries();
    _playlists = _storage.getAllAudioPlaylists();
    _loaded = true;
    notifyListeners();
  }

  /// Kiểm tra + xin quyền truy cập audio (gọi khi mở tab Thư viện).
  Future<bool> ensurePermission() async {
    var status = await Permission.audio.status;
    if (!status.isGranted) {
      status = await Permission.audio.request();
    }
    _permissionGranted = status.isGranted;
    if (!_permissionGranted && status.isPermanentlyDenied) {
      await openAppSettings();
    }
    notifyListeners();
    return _permissionGranted;
  }

  /// Quét MediaStore + hợp nhất + lưu Hive.
  Future<void> scan() async {
    if (_scanning) return;
    _scanning = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.scanMediaStore();
      _entries = result;
      _permissionGranted = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  /// Đánh dấu đã nghe + cập nhật local.
  Future<void> markPlayed(AudioLibraryEntry entry) async {
    await _service.markPlayed(entry);
    final idx = _entries.indexWhere((e) => e.libraryId == entry.libraryId);
    if (idx >= 0) {
      _entries[idx] = entry.copyWith(lastPlayed: DateTime.now());
      notifyListeners();
    }
  }

  /// Bật/tắt yêu thích.
  Future<void> toggleFavorite(AudioLibraryEntry entry) async {
    final updated = await _service.toggleFavorite(entry);
    final idx = _entries.indexWhere((e) => e.libraryId == entry.libraryId);
    if (idx >= 0) {
      _entries[idx] = updated;
      notifyListeners();
    }
  }

  AudioLibraryEntry? findById(String libraryId) {
    for (final e in _entries) {
      if (e.libraryId == libraryId) return e;
    }
    return null;
  }

  List<AudioLibraryEntry> search(String query) =>
      AudioLibraryService.search(_entries, query);

  /// Áp bộ lọc + tìm kiếm gộp (dùng cho tab Thư viện).
  List<AudioLibraryEntry> filtered({
    String query = '',
    SmartPlaylist smart = SmartPlaylist.all,
    String? album,
    String? artist,
    String? folder,
  }) {
    var list = AudioLibraryService.applySmart(_entries, smart);
    if (album != null && album.isNotEmpty) {
      list = AudioLibraryService.byAlbum(list, album);
    }
    if (artist != null && artist.isNotEmpty) {
      list = AudioLibraryService.byArtist(list, artist);
    }
    if (folder != null && folder.isNotEmpty) {
      list = AudioLibraryService.byFolder(list, folder);
    }
    if (query.trim().isNotEmpty) {
      list = AudioLibraryService.search(list, query);
    }
    return list;
  }

  // ── Playlist thủ công ────────────────────────────────────────
  Future<AudioPlaylist> createPlaylist(String name) async {
    final pl = AudioPlaylist.create(name);
    _playlists.insert(0, pl);
    await _storage.saveAudioPlaylist(pl);
    notifyListeners();
    return pl;
  }

  Future<void> renamePlaylist(String id, String name) async {
    final pl = _playlistById(id);
    if (pl == null) return;
    pl.name = name.trim().isEmpty ? pl.name : name.trim();
    pl.updatedAt = DateTime.now();
    await _storage.saveAudioPlaylist(pl);
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _storage.deleteAudioPlaylist(id);
    notifyListeners();
  }

  Future<void> addToPlaylist(String playlistId, String trackId) async {
    final pl = _playlistById(playlistId);
    if (pl == null) return;
    if (pl.add(trackId)) {
      await _storage.saveAudioPlaylist(pl);
      _resortPlaylists();
      notifyListeners();
    }
  }

  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    final pl = _playlistById(playlistId);
    if (pl == null) return;
    if (pl.remove(trackId)) {
      await _storage.saveAudioPlaylist(pl);
      notifyListeners();
    }
  }

  Future<void> reorderPlaylist(
      String playlistId, int oldIndex, int newIndex) async {
    final pl = _playlistById(playlistId);
    if (pl == null) return;
    pl.reorder(oldIndex, newIndex);
    await _storage.saveAudioPlaylist(pl);
    notifyListeners();
  }

  /// Các entry trong một playlist theo đúng thứ tự (bỏ track không còn tồn tại).
  List<AudioLibraryEntry> playlistTracks(String playlistId) {
    final pl = _playlistById(playlistId);
    if (pl == null) return const [];
    final byId = {for (final e in _entries) e.libraryId: e};
    return [
      for (final tid in pl.trackIds)
        if (byId[tid] != null) byId[tid]!,
    ];
  }

  AudioPlaylist? _playlistById(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _resortPlaylists() {
    _playlists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
