// lib/screens/read_mode/services/playback_controller.dart
// Chỉ thay đổi type List<TextLine> → List<TextItem>

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/text_item.dart'; // ← THÊM
import '../models/playback_anchor.dart';
import '../models/playback_event.dart';
import '../models/playback_recipe.dart';
import '../models/playback_run_token.dart';
import '../models/playback_snapshot.dart';
import 'playback_engine.dart';
import 'tts_notification_service.dart';

class PlaybackController extends ChangeNotifier with WidgetsBindingObserver {
  final PlaybackEngine _engine;
  final SharedPreferences _prefs;
  final TtsNotificationService _notification;

  final ValueNotifier<int> activeLineNotifier = ValueNotifier(-1);
  final ValueNotifier<bool> isENNotifier = ValueNotifier(true);

  PlaybackRecipe _recipe = PlaybackRecipe.bilingual;
  PlaybackSnapshot? snapshot;
  PlaybackRunToken? _activeToken;
  Timer? _snapBackTimer;

  // ★ TextItem thay TextLine
  List<TextItem>? _currentLines;
  String? _currentFileId;
  bool _disposed = false;

  bool get isRunning => _activeToken != null;
  PlaybackRecipe get recipe => _recipe;

  PlaybackController(this._engine, this._prefs, this._notification) {
    WidgetsBinding.instance.addObserver(this);
    _loadRecipe();
  }

  // ── Lifecycle ─────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (_currentFileId != null) _saveAnchor(_currentFileId!);
        break;
      case AppLifecycleState.detached:
        _forceStop();
        break;
      default:
        break;
    }
  }

  // ── Public API ────────────────────────────────────────────

  Future<void> start(
    List<TextItem> lines, {
    // ← TextItem
    required String fileId,
    PlaybackAnchor? anchor,
  }) async {
    if (_disposed) return;

    _currentLines = lines;
    _currentFileId = fileId;

    _activeToken = null;
    _engine.stop();
    await Future.delayed(const Duration(milliseconds: 80));

    final token = PlaybackRunToken(DateTime.now().microsecondsSinceEpoch);
    _activeToken = token;

    unawaited(_notification.activate(
      title: 'VipSound đang phát',
      subtitle: anchor != null
          ? 'Tiếp tục từ câu ${anchor.lineIndex + 1}'
          : 'Bắt đầu từ đầu',
    ));

    _safeNotify();

    await _engine.play(
      token: token,
      lines: lines,
      recipe: _recipe,
      resumeFrom: anchor,
      onEvent: (e) {
        if (_disposed) return;
        if (_activeToken?.id != token.id) return;
        _handleEvent(e);
      },
      onDone: () {
        if (_disposed) return;
        if (_activeToken?.id != token.id) return;
        _cleanupAfterRun();
      },
      onError: (err) {
        if (_disposed) return;
        if (_activeToken?.id != token.id) return;
        debugPrint('[PlaybackController] ${err.message}: ${err.cause}');
        _cleanupAfterRun();
      },
    );
  }

  void stop({required String fileId}) {
    _saveAnchor(fileId);
    _forceStop();
  }

  Future<void> skip(int delta) async {
    if (_currentLines == null || snapshot == null) return;
    final target = (snapshot!.line + delta).clamp(0, _currentLines!.length - 1);

    final fileId = _currentFileId!;
    _saveAnchor(fileId);
    _activeToken = null;
    _engine.stop();
    await Future.delayed(const Duration(milliseconds: 80));

    final anchor = PlaybackAnchor(
      fileId: fileId,
      lineIndex: target,
      lineRepeatIndex: 0,
      savedAt: DateTime.now(),
    );
    await start(_currentLines!, fileId: fileId, anchor: anchor);
  }

  Future<void> adjustSpeed(double delta) async {
    final newSpeed = (_recipe.speed + delta).clamp(0.5, 2.0);
    if ((newSpeed - _recipe.speed).abs() < 0.01) return;
    _recipe = _recipe.copyWith(speed: newSpeed);
    await _engine.updateSpeed(newSpeed);
    await _persistRecipe();
    HapticFeedback.lightImpact();
    _safeNotify();
  }

  Future<void> updateRecipe(PlaybackRecipe r) async {
    _recipe = r;
    await _persistRecipe();
    _safeNotify();
  }

  void scheduleSnapBack(VoidCallback onSnap) {
    _snapBackTimer?.cancel();
    _snapBackTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!_disposed) onSnap();
    });
  }

  void cancelSnapBack() => _snapBackTimer?.cancel();

  PlaybackAnchor? loadAnchor(String fileId) {
    final raw = _prefs.getString('anchor_$fileId');
    if (raw == null) return null;
    try {
      return PlaybackAnchor.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  void clearAnchor(String fileId) => _prefs.remove('anchor_$fileId');

  // ── Private ───────────────────────────────────────────────

  void _handleEvent(PlaybackEvent event) {
    snapshot = event.snapshot;

    switch (event.type) {
      case PlaybackEventType.lineStart:
        HapticFeedback.lightImpact();
        activeLineNotifier.value = event.snapshot.line;
        isENNotifier.value = event.snapshot.isEN;
        unawaited(_notification.updateNotification(
          title: 'Câu ${event.snapshot.line + 1}/${event.snapshot.totalLines}',
          subtitle: event.snapshot.statusText,
        ));
        break;

      case PlaybackEventType.languageSwitch:
        HapticFeedback.selectionClick();
        isENNotifier.value = event.snapshot.isEN;
        break;

      case PlaybackEventType.phase:
        break; // chỉ update snapshot
    }

    _safeNotify();
  }

  void _saveAnchor(String fileId) {
    if (snapshot == null) return;
    final anchor = PlaybackAnchor(
      fileId: fileId,
      lineIndex: snapshot!.line,
      lineRepeatIndex: snapshot!.lineRepeat,
      savedAt: DateTime.now(),
    );
    _prefs.setString('anchor_$fileId', jsonEncode(anchor.toJson()));
  }

  void _forceStop() {
    _activeToken = null;
    _engine.stop();
    _cleanupAfterRun();
  }

  void _cleanupAfterRun() {
    _activeToken = null;
    _snapBackTimer?.cancel();
    activeLineNotifier.value = -1;
    unawaited(_notification.deactivate());
    _safeNotify();
  }

  Future<void> _persistRecipe() async {
    await _prefs.setString(
      'playback_recipe',
      jsonEncode(_recipe.toJson()),
    );
  }

  void _loadRecipe() {
    final raw = _prefs.getString('playback_recipe');
    if (raw == null) return;
    try {
      _recipe = PlaybackRecipe.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {}
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _snapBackTimer?.cancel();
    _engine.stop();
    activeLineNotifier.dispose();
    isENNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
