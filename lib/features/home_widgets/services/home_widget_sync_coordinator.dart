// lib/features/home_widgets/services/home_widget_sync_coordinator.dart
//
// PLAN-050 · ADR-0040 — Bộ điều phối đồng bộ tự động dữ liệu thật sang Native
// Home Screen Widgets.
//
// Tối ưu hiệu năng & pin:
//   - Lắng nghe thay đổi từ các Provider thực tế với debounce `800 ms`.
//   - Làm tròn tiến độ phát nhạc theo từng nấc 15 giây khi đang phát để tránh
//     gọi MethodChannel liên tục mỗi 200 ms.
//   - Xả tức thời (immediate flush) khi ứng dụng chuyển sang `inactive`/`paused`
//     (người dùng bấm phím Home ra ngoài màn hình chính).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../features/learn_by_heart/controllers/learn_by_heart_provider.dart';
import '../../../providers/focus_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../screens/listen_mode/models/recent_audio.dart';
import '../../../screens/listen_mode/services/recent_audio_service.dart';
import '../../../screens/read_mode/models/recent_file.dart';
import '../../../screens/read_mode/services/recent_files_service.dart';
import 'home_widget_bridge.dart';
import 'widget_snapshot_builder.dart';

class HomeWidgetSyncCoordinator with WidgetsBindingObserver {
  HomeWidgetSyncCoordinator({
    this.debounceDuration = const Duration(milliseconds: 800),
  });

  final Duration debounceDuration;

  BuildContext? _context;
  final List<Listenable> _observedListenables = <Listenable>[];
  Timer? _debounceTimer;
  bool _disposed = false;
  bool _syncInFlight = false;
  bool _pendingForceAfterFlight = false;

  String? _lastSyncedPayloadWithoutTimestamp;
  RecentAudio? _cachedRecentAudio;
  RecentFile? _cachedRecentFile;
  DateTime? _lastRecentsFetchAt;

  void attach(BuildContext context) {
    if (_disposed) return;
    detach();
    _context = context;
    WidgetsBinding.instance.addObserver(this);

    void observe<T extends Listenable>() {
      try {
        final listenable = Provider.of<T>(context, listen: false);
        listenable.addListener(_onSourceChanged);
        _observedListenables.add(listenable);
      } catch (_) {
        // Bỏ qua an toàn nếu một Provider tuỳ chọn không có trong cây test.
      }
    }

    observe<LocaleProvider>();
    observe<FocusProvider>();
    observe<VocabularyProvider>();
    observe<LearnByHeartProvider>();
    observe<PlayerProvider>();
    observe<TextProvider>();

    HomeWidgetBridge.instance.configRevision.addListener(_onConfigChanged);
    _observedListenables.add(HomeWidgetBridge.instance.configRevision);

    // Đồng bộ lần đầu sau khi khung giao diện đầu tiên đã vẽ xong.
    scheduleSync();
  }

  void detach() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    for (final listenable in _observedListenables) {
      if (identical(listenable, HomeWidgetBridge.instance.configRevision)) {
        listenable.removeListener(_onConfigChanged);
      } else {
        listenable.removeListener(_onSourceChanged);
      }
    }
    _observedListenables.clear();
    _context = null;
  }

  void dispose() {
    _disposed = true;
    detach();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Người dùng vừa rời ứng dụng ra màn hình chính: cập nhật tức thì!
      unawaited(syncNow(force: true, refreshRecents: true));
    } else if (state == AppLifecycleState.resumed) {
      scheduleSync();
    }
  }

  void _onConfigChanged() {
    unawaited(syncNow(force: true));
  }

  void _onSourceChanged() {
    scheduleSync();
  }

  void scheduleSync() {
    if (_disposed || !HomeWidgetBridge.instance.isAndroidHost) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      unawaited(syncNow(force: false));
    });
  }

  Future<void> syncNow({
    bool force = false,
    bool refreshRecents = false,
  }) async {
    if (_disposed || !HomeWidgetBridge.instance.isAndroidHost) return;
    final ctx = _context;
    if (ctx == null || !ctx.mounted) return;

    if (_syncInFlight) {
      if (force) _pendingForceAfterFlight = true;
      return;
    }

    _syncInFlight = true;
    try {
      await _refreshRecentsIfNeeded(force: refreshRecents);
      if (_disposed || !ctx.mounted) return;

      final localeCode = _resolveEffectiveLocaleCode(ctx);
      final focus = Provider.of<FocusProvider>(ctx, listen: false);
      final vocab = Provider.of<VocabularyProvider>(ctx, listen: false);
      final lhbDue = _readLhbDueCount(ctx);
      final listenInput = _resolveListenInput(ctx, forceExactPosition: force);
      final readInput = _resolveReadInput(ctx);
      final quickSlots = await HomeWidgetBridge.instance.loadQuickBarSlots();
      if (_disposed || !ctx.mounted) return;

      final streakSnap = focus.snapshot();
      final snapshot = WidgetSnapshotBuilder.build(
        localeCode: localeCode,
        streakSnapshot: streakSnap,
        dueWords: vocab.dueWords,
        fallbackWords: vocab.allWords,
        dueLhbCount: lhbDue,
        listenSource: listenInput,
        readSource: readInput,
        rawQuickBarSlotKeys: quickSlots.map((slot) => slot.wireKey),
        isAndroid: HomeWidgetBridge.instance.isAndroidHost,
        nowEpochMs: 0,
      );

      // So sánh nội dung không tính timestamp để không gọi IPC thừa khi chỉ có
      // nhịp thời gian nhạc nhảy lẻ vài trăm mili-giây.
      final signature = snapshot.toEncodedJson();
      if (!force && signature == _lastSyncedPayloadWithoutTimestamp) {
        return;
      }
      _lastSyncedPayloadWithoutTimestamp = signature;

      final stamped = WidgetSnapshotBuilder.build(
        localeCode: localeCode,
        streakSnapshot: streakSnap,
        dueWords: vocab.dueWords,
        fallbackWords: vocab.allWords,
        dueLhbCount: lhbDue,
        listenSource: _resolveListenInput(ctx, forceExactPosition: true),
        readSource: readInput,
        rawQuickBarSlotKeys: quickSlots.map((slot) => slot.wireKey),
        isAndroid: HomeWidgetBridge.instance.isAndroidHost,
      );
      await HomeWidgetBridge.instance.syncSnapshot(stamped);
    } catch (_) {
      // Tuyệt đối không để lỗi đồng bộ Widget ảnh hưởng luồng chính của ứng dụng.
    } finally {
      _syncInFlight = false;
      if (_pendingForceAfterFlight && !_disposed) {
        _pendingForceAfterFlight = false;
        unawaited(syncNow(force: true));
      }
    }
  }

  Future<void> _refreshRecentsIfNeeded({required bool force}) async {
    final now = DateTime.now();
    if (!force &&
        _lastRecentsFetchAt != null &&
        now.difference(_lastRecentsFetchAt!) < const Duration(seconds: 20)) {
      return;
    }
    _lastRecentsFetchAt = now;
    try {
      final audios = await RecentAudioService().getAll();
      _cachedRecentAudio = audios.isNotEmpty ? audios.first : null;
    } catch (_) {
      // Giữ cache cũ nếu không đọc được.
    }
    try {
      final files = await RecentFilesService().getAll();
      _cachedRecentFile = files.isNotEmpty ? files.first : null;
    } catch (_) {
      // Giữ cache cũ nếu không đọc được.
    }
  }

  String _resolveEffectiveLocaleCode(BuildContext context) {
    try {
      final chosen = Provider.of<LocaleProvider>(context, listen: false).locale;
      if (chosen != null) {
        final cc = chosen.countryCode;
        return (cc != null && cc.isNotEmpty)
            ? '${chosen.languageCode}_$cc'
            : chosen.languageCode;
      }
    } catch (_) {
      // Fallback sang ngôn ngữ hệ thống.
    }
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final cc = platformLocale.countryCode;
    return (cc != null && cc.isNotEmpty)
        ? '${platformLocale.languageCode}_$cc'
        : platformLocale.languageCode;
  }

  int _readLhbDueCount(BuildContext context) {
    try {
      return Provider.of<LearnByHeartProvider>(context, listen: false).dueCount;
    } catch (_) {
      return 0;
    }
  }

  WidgetListenSourceInput? _resolveListenInput(
    BuildContext context, {
    required bool forceExactPosition,
  }) {
    try {
      final player = Provider.of<PlayerProvider>(context, listen: false);
      final activeTitle = (player.currentSongTitle ?? '').trim();
      final activePath = player.currentSongPath;
      if (activeTitle.isNotEmpty || (activePath != null && activePath.isNotEmpty)) {
        final rawPos = player.state.position;
        final bucketedPos = forceExactPosition
            ? rawPos
            : Duration(seconds: (rawPos.inSeconds ~/ 15) * 15);
        final displayTitle = activeTitle.isNotEmpty
            ? activeTitle
            : p.basenameWithoutExtension(activePath!);
        return WidgetListenSourceInput(
          title: displayTitle,
          position: bucketedPos,
          duration: player.playbackDuration,
          isPlaying: player.isPlaying,
        );
      }
    } catch (_) {
      // Fallback sang RecentAudio bên dưới.
    }

    final recent = _cachedRecentAudio;
    if (recent != null && recent.title.trim().isNotEmpty) {
      return WidgetListenSourceInput(
        title: recent.title,
        position: recent.lastPosition,
        duration: recent.totalDuration,
        isPlaying: false,
      );
    }
    return null;
  }

  WidgetReadSourceInput? _resolveReadInput(BuildContext context) {
    final recent = _cachedRecentFile;
    // Nếu tệp mở gần nhất là PDF, ưu tiên hiển thị tiến độ trang PDF thực tế.
    if (recent != null &&
        recent.type == RecentFileType.localPdf &&
        recent.title.trim().isNotEmpty) {
      return WidgetReadSourceInput(
        title: recent.title,
        currentUnit: recent.lastReadLine,
        totalUnits: recent.totalLines,
        isPdf: true,
      );
    }

    try {
      final text = Provider.of<TextProvider>(context, listen: false);
      if (text.lines.isNotEmpty) {
        final docTitle = (text.currentDocument?.title ?? '').trim();
        final pathTitle = text.currentTextPath != null
            ? p.basenameWithoutExtension(text.currentTextPath!)
            : '';
        final resolvedTitle = docTitle.isNotEmpty ? docTitle : pathTitle;
        if (resolvedTitle.isNotEmpty) {
          final currentLine =
              (text.currentLineIndex + 1).clamp(1, text.lines.length);
          return WidgetReadSourceInput(
            title: resolvedTitle,
            currentUnit: currentLine,
            totalUnits: text.lines.length,
            isPdf: false,
          );
        }
      }
    } catch (_) {
      // Fallback sang RecentFile bên dưới.
    }

    if (recent != null && recent.title.trim().isNotEmpty) {
      final isPdf = recent.type == RecentFileType.localPdf;
      return WidgetReadSourceInput(
        title: recent.title,
        currentUnit: recent.lastReadLine,
        totalUnits: recent.totalLines,
        isPdf: isPdf,
      );
    }
    return null;
  }
}
