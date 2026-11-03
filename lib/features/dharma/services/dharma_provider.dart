// lib/features/dharma/services/dharma_provider.dart
//
// PLAN-042 P1 — trạng thái pháp thoại: catalog + tiến độ + phát.
//
// TRÁCH NHIỆM (giữ hẹp, không thay PlayerProvider):
//  * Quét thư mục → catalog (gọi `buildDharmaCatalog` THUẦN).
//  * Giữ `DharmaProgress` theo `episodeKey` (nguồn sự thật của "nghe tiếp").
//  * Ghi tiến độ từ `PlayerProvider` khi đang phát (timer 10 s + khi đổi bài).
//  * Phát một buổi bằng `startQueue` CÓ SẴN (giữ queue PLAN-039, bài trước/sau).
//
// KHÔNG làm: tự tạo AudioPlayer, đổi tốc độ mặc định toàn cục, gọi STT.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/audio_queue_item.dart';
import '../../../providers/player_provider.dart';
import '../../../services/text_device_channel.dart';
import '../models/dharma_talk.dart';
import 'dharma_scanner.dart';
import 'dharma_store.dart';
import 'dharma_text.dart';

/// Kết quả lọc/sắp xếp cho màn danh mục (thuần — test được).
class DharmaListEntry {
  final DharmaSeries series;
  final DharmaEpisode episode;
  final DharmaProgress? progress;

  const DharmaListEntry({
    required this.series,
    required this.episode,
    this.progress,
  });

  bool get isCompleted => progress?.isCompleted ?? false;
  bool get isInProgress => progress?.isInProgress ?? false;
}

class DharmaProvider extends ChangeNotifier {
  DharmaProvider({@visibleForTesting DharmaStore? store})
      : _store = store ?? DharmaStore.instance;

  final DharmaStore _store;

  static const String _rootUriKey = 'in4up_dharma_root_uri_v1';
  static const String _rootPathKey = 'in4up_dharma_root_path_v1';
  static const String _lastSeriesKey = 'in4up_dharma_last_series_v1';

  List<DharmaSeries> _series = [];
  Map<String, DharmaProgress> _progress = {};
  Map<String, String> _overrides = {};

  bool _loaded = false;
  bool _scanning = false;
  String? _error;
  String? _rootUri;
  String? _rootPath;
  DateTime? _scannedAt;
  String? _lastSeriesKeyPlayed;

  PlayerProvider? _player;
  Timer? _progressTimer;
  String? _playingEpisodeKey;

  // ── Getters ──────────────────────────────────────────────────
  bool get isLoaded => _loaded;
  bool get isScanning => _scanning;
  String? get error => _error;
  bool get hasSource => (_rootUri != null && _rootUri!.isNotEmpty) ||
      (_rootPath != null && _rootPath!.isNotEmpty);
  String? get rootUri => _rootUri;
  String? get rootPath => _rootPath;
  DateTime? get scannedAt => _scannedAt;
  List<DharmaSeries> get series => List.unmodifiable(_series);
  int get seriesCount => _series.length;
  int get episodeCount => _series.fold<int>(0, (sum, s) => sum + s.episodeCount);
  int get completedCount =>
      _series.fold<int>(0, (sum, s) => sum + _completedIn(s));
  String? get lastSeriesKeyPlayed => _lastSeriesKeyPlayed;

  DharmaCatalog get catalog =>
      DharmaCatalog(series: _series, scannedAt: _scannedAt ?? DateTime.now());

  DharmaProgress? progressFor(String episodeKey) => _progress[episodeKey];

  int _completedIn(DharmaSeries series) {
    var count = 0;
    for (final e in series.episodes) {
      if (_progress[e.episodeKey]?.isCompleted ?? false) count++;
    }
    return count;
  }

  int completedIn(DharmaSeries series) => _completedIn(series);

  /// "Nghe tiếp": các buổi đang nghe dở, mới nhất trước.
  List<DharmaListEntry> continueListening({int limit = 8}) {
    final out = <DharmaListEntry>[];
    for (final s in _series) {
      for (final e in s.episodes) {
        final progress = _progress[e.episodeKey];
        if (progress == null || !progress.isInProgress) continue;
        out.add(DharmaListEntry(series: s, episode: e, progress: progress));
      }
    }
    out.sort((a, b) {
      final ta = a.progress?.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.progress?.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return out.take(limit).toList(growable: false);
  }

  /// Buổi nên nghe tiếp trong một series: buổi dở → buổi chưa nghe đầu tiên.
  DharmaEpisode? nextEpisodeOf(DharmaSeries series) {
    DharmaEpisode? firstUnplayed;
    for (final e in series.episodes) {
      final progress = _progress[e.episodeKey];
      if (progress != null && progress.isInProgress) return e;
      if (firstUnplayed == null && (progress == null || progress.isNew)) {
        firstUnplayed = e;
      }
    }
    return firstUnplayed ?? (series.episodes.isEmpty ? null : series.episodes.first);
  }

  /// Nhóm theo vị Thầy cho chip lọc "Theo Thầy".
  List<DharmaSpeakerGroup> speakerGroups() {
    final byKey = <String, _SpeakerBucket>{};
    for (final s in _series) {
      final key = s.speakerGroupKey;
      final bucket = byKey.putIfAbsent(key, () => _SpeakerBucket(key));
      bucket.seriesCount++;
      bucket.episodeCount += s.episodeCount;
      bucket.completedCount += _completedIn(s);
      if (bucket.label.isEmpty && s.speakerGroupLabel.isNotEmpty) {
        bucket.label = s.speakerGroupLabel;
      }
    }
    final groups = byKey.values.map((b) => b.toGroup()).toList();
    groups.sort((a, b) {
      if (a.seriesCount != b.seriesCount) {
        return b.seriesCount.compareTo(a.seriesCount);
      }
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return groups;
  }

  List<DharmaSeries> seriesOfSpeaker(String groupKey) =>
      _series.where((s) => s.speakerGroupKey == groupKey).toList(growable: false);

  /// Tìm kiếm series theo tên/chủ đề/địa điểm/vị Thầy (bỏ dấu).
  List<DharmaSeries> search(String query) {
    final needle = _fold(query);
    if (needle.isEmpty) return List.unmodifiable(_series);
    return _series.where((s) {
      final haystack = _fold([
        s.title,
        s.topic ?? '',
        s.venue ?? '',
        s.speakerDisplay ?? '',
        s.year?.toString() ?? '',
      ].join(' '));
      return haystack.contains(needle);
    }).toList(growable: false);
  }

  static String _fold(String value) => foldDiacritics(value)
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // ── Vòng đời ─────────────────────────────────────────────────
  void attachPlayer(PlayerProvider player) {
    if (identical(_player, player)) return;
    _player?.removeListener(_onPlayerChanged);
    _player = player..addListener(_onPlayerChanged);
    _progressTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _captureProgressFromPlayer(),
    );
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _rootUri = prefs.getString(_rootUriKey);
    _rootPath = prefs.getString(_rootPathKey);
    _lastSeriesKeyPlayed = prefs.getString(_lastSeriesKey);
    _series = await _store.loadSeries();
    _progress = await _store.loadProgress();
    _overrides = await _store.loadOverrides();
    _applyOverrides();
    _loaded = true;
    notifyListeners();
  }

  void _applyOverrides() {
    if (_overrides.isEmpty) return;
    _series = _series.map((s) {
      final override = _overrides[DharmaStore.speakerOverrideKey(s.seriesKey)];
      if (override == null || override.isEmpty) return s;
      return s.copyWith(
        speakerDisplay: override,
        speakerKey: _fold(override).replaceAll(' ', '_'),
      );
    }).toList(growable: false);
  }

  // ── Chọn nguồn & quét ────────────────────────────────────────
  /// Chọn thư mục trên Android (SAF) — nhớ quyền để lần sau không hỏi lại.
  Future<bool> pickDeviceFolder() async {
    if (!dharmaSafSupported) {
      _error = 'unsupported';
      notifyListeners();
      return false;
    }
    try {
      // SAF folder picker native đã có (dùng chung với Thư viện đọc/Video).
      final uri = await TextDeviceChannel.pickFolder();
      if (uri == null || uri.isEmpty) return false;
      final normalized = await TextDeviceChannel.normalizeTreeUri(uri) ?? uri;
      await TextDeviceChannel.keepTreePermission(normalized);
      _rootUri = normalized;
      _rootPath = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rootUriKey, normalized);
      await prefs.remove(_rootPathKey);
      await rescan();
      return true;
    } catch (e) {
      _error = '$e';
      notifyListeners();
      return false;
    }
  }

  /// Đặt thư mục trên máy tính (Windows/Linux/macOS).
  Future<void> setDesktopFolder(String path) async {
    _rootPath = path.replaceAll('\\', '/');
    _rootUri = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rootPathKey, _rootPath!);
    await prefs.remove(_rootUriKey);
    await rescan();
  }

  Future<void> rescan() async {
    if (_scanning) return;
    if (!hasSource) {
      _error = 'no_source';
      notifyListeners();
      return;
    }
    _scanning = true;
    _error = null;
    notifyListeners();
    try {
      final entries = await scanDharmaFolder(
        treeUri: _rootUri,
        rootPath: _rootPath,
      );
      final built = buildDharmaCatalog(
        entries: entries,
        speakerOverrides: {
          for (final e in _overrides.entries)
            if (e.key.startsWith('speaker:')) e.key.substring(8): e.value,
        },
        rootName: _rootName(),
      );
      _series = built.series;
      _scannedAt = built.scannedAt;
      // Ghi catalog — KHÔNG chạm progress (ADR-0022).
      await _store.saveSeries(_series);
      if (entries.isEmpty) {
        _error = 'empty';
      }
    } catch (e) {
      _error = '$e';
      debugPrint('[Dharma] rescan lỗi: $e');
    } finally {
      _scanning = false;
      notifyListeners();
    }
  }

  String _rootName() {
    final source = _rootUri ?? _rootPath ?? '';
    final parts = source.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Pháp thoại';
    final last = parts.last;
    if (last.contains('%3A')) {
      return last.split('%3A').last.replaceAll('%2F', '/').split('/').last;
    }
    return last;
  }

  Future<void> forgetSource() async {
    _rootUri = null;
    _rootPath = null;
    _error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rootUriKey);
    await prefs.remove(_rootPathKey);
    notifyListeners();
  }

  // ── Phát ─────────────────────────────────────────────────────
  /// Phát một buổi; [queueContext] = danh sách buổi của series để có
  /// bài trước/sau (dùng queue PLAN-039, không tạo trình phát riêng).
  Future<bool> playEpisode(
    DharmaSeries series,
    DharmaEpisode episode, {
    bool continueFromSaved = true,
  }) async {
    final player = _player;
    if (player == null) return false;
    await captureProgressFromPlayer();

    final episodes = series.episodes
        .where((e) => e.source.isNotEmpty)
        .toList(growable: false);
    if (episodes.isEmpty) return false;

    final startIndex = episodes.indexWhere(
      (e) => e.episodeKey == episode.episodeKey,
    );
    final queue = [
      for (final e in episodes)
        AudioQueueItem(source: e.source, title: e.title, artist: series.speakerDisplay),
    ];

    final progress = _progress[episode.episodeKey];
    Duration? initialPosition;
    if (continueFromSaved &&
        progress != null &&
        progress.isInProgress &&
        progress.lastPosition > const Duration(seconds: 5)) {
      initialPosition = progress.lastPosition;
    }

    _playingEpisodeKey = episode.episodeKey;
    _lastSeriesKeyPlayed = series.seriesKey;
    unawaited(_persistLastSeries(series.seriesKey));

    // A. Kinh tụng: luôn bắt đầu lại từ đầu, không resume (PLAN-042 §7.2).
    if (series.collection == DharmaCollection.chanting) {
      initialPosition = null;
    }

    final ok = await player.startQueue(
      queue,
      startIndex: startIndex < 0 ? 0 : startIndex,
      autoPlay: true,
      resumePosition: false,
      initialPosition: initialPosition,
    );
    if (!ok) {
      _playingEpisodeKey = null;
    } else {
      await _touchProgress(episode, position: initialPosition ?? Duration.zero);
    }
    notifyListeners();
    return ok;
  }

  Future<void> _persistLastSeries(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeriesKey, key);
  }

  // ── Tiến độ ──────────────────────────────────────────────────
  void _onPlayerChanged() {
    // Player đã rời khỏi buổi pháp thoại (đổi sang file khác hoặc đóng bài):
    // ghi nốt tiến độ rồi thôi theo dõi, để không ghi nhầm vị trí của bài khác
    // vào buổi này.
    final key = _playingEpisodeKey;
    if (key == null) return;
    final player = _player;
    if (player == null) return;
    if (player.currentSongPath == null) {
      unawaited(_captureProgressFromPlayer());
      _playingEpisodeKey = null;
    }
  }

  /// Đọc vị trí hiện tại từ player và ghi vào store tiến độ.
  Future<void> captureProgressFromPlayer() => _captureProgressFromPlayer(
        updateUi: true,
      );

  Future<void> _captureProgressFromPlayer({bool updateUi = false}) async {
    final key = _playingEpisodeKey;
    final player = _player;
    if (key == null || player == null) return;
    final state = player.state;
    if (state.duration <= Duration.zero) return;
    final existing = _progress[key];
    final next = DharmaProgress(
      episodeKey: key,
      lastPosition: state.position,
      duration: state.duration,
      completedManually: existing?.completedManually ?? false,
      lastPlayedAt: DateTime.now(),
    );
    _progress[key] = next;
    await _store.putProgress(next);
    if (updateUi) notifyListeners();
  }

  Future<void> _touchProgress(
    DharmaEpisode episode, {
    required Duration position,
  }) async {
    final existing = _progress[episode.episodeKey];
    final next = DharmaProgress(
      episodeKey: episode.episodeKey,
      lastPosition: position,
      duration: existing?.duration ?? Duration.zero,
      completedManually: existing?.completedManually ?? false,
      lastPlayedAt: DateTime.now(),
    );
    _progress[episode.episodeKey] = next;
    await _store.putProgress(next);
  }

  /// Người dùng bấm "Đã nghe xong" — thắng mọi suy luận tự động.
  Future<void> markCompleted(DharmaEpisode episode, {bool completed = true}) async {
    final existing = _progress[episode.episodeKey] ??
        DharmaProgress(
          episodeKey: episode.episodeKey,
          lastPlayedAt: DateTime.now(),
        );
    final next = existing.copyWith(
      completedManually: completed,
      lastPlayedAt: DateTime.now(),
      duration: existing.duration,
    );
    _progress[episode.episodeKey] = next;
    await _store.putProgress(next);
    notifyListeners();
  }

  Future<void> resetProgress(DharmaEpisode episode) async {
    _progress.remove(episode.episodeKey);
    await _store.clearProgress(episode.episodeKey);
    notifyListeners();
  }

  /// Sửa tay tên vị Thầy cho một series — lưu vào overrides (thắng parser).
  Future<void> overrideSpeaker(DharmaSeries series, String speaker) async {
    await _store.putOverride(
      DharmaStore.speakerOverrideKey(series.seriesKey),
      speaker,
    );
    _overrides[DharmaStore.speakerOverrideKey(series.seriesKey)] = speaker.trim();
    _series = _series.map((s) {
      if (s.seriesKey != series.seriesKey) return s;
      if (speaker.trim().isEmpty) return s;
      return s.copyWith(
        speakerDisplay: speaker.trim(),
        speakerKey: _fold(speaker).replaceAll(' ', '_'),
      );
    }).toList(growable: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _player?.removeListener(_onPlayerChanged);
    super.dispose();
  }
}

class DharmaSpeakerGroup {
  final String key;
  final String label;
  final int seriesCount;
  final int episodeCount;
  final int completedCount;

  const DharmaSpeakerGroup({
    required this.key,
    required this.label,
    required this.seriesCount,
    required this.episodeCount,
    required this.completedCount,
  });

  bool get isUnknown => key == '__unknown__';
}

class _SpeakerBucket {
  final String key;
  String label = '';
  int seriesCount = 0;
  int episodeCount = 0;
  int completedCount = 0;

  _SpeakerBucket(this.key);

  DharmaSpeakerGroup toGroup() => DharmaSpeakerGroup(
        key: key,
        label: label.isEmpty ? '—' : label,
        seriesCount: seriesCount,
        episodeCount: episodeCount,
        completedCount: completedCount,
      );
}
