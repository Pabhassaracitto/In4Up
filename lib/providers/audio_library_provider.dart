// lib/providers/audio_library_provider.dart
// Thư viện âm thanh (P1) — trạng thái: entries, quyền, đang quét, lỗi.
//
// Quyền dùng permission_handler (đã có sẵn trong dự án):
//  - Android 13+: Permission.audio → READ_MEDIA_AUDIO
//  - Android ≤12 : Permission.audio → READ_EXTERNAL_STORAGE
//  - iOS         : Permission.audio → NSMicrophoneUsageDescription (không dùng cho thư viện)

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/audio_library_entry.dart';
import '../services/audio_library_service.dart';
import '../services/storage_service.dart';

class AudioLibraryProvider extends ChangeNotifier {
  final AudioLibraryService _service = AudioLibraryService();
  final StorageService _storage = StorageService();

  List<AudioLibraryEntry> _entries = [];
  bool _loaded = false;
  bool _scanning = false;
  bool _permissionGranted = false;
  String? _error;

  List<AudioLibraryEntry> get entries => List.unmodifiable(_entries);
  bool get isLoaded => _loaded;
  bool get isScanning => _scanning;
  bool get hasPermission => _permissionGranted;
  String? get error => _error;
  int get count => _entries.length;

  /// Nạp chỉ mục đã lưu (không quét).
  Future<void> load() async {
    if (_loaded) return;
    _entries = _storage.getAllAudioLibraryEntries();
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

  List<AudioLibraryEntry> search(String query) =>
      AudioLibraryService.search(_entries, query);
}
