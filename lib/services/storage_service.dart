// lib/services/storage_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/shadowing/models/shadowing_result.dart';
import '../models/segment.dart';
import '../models/text_segment.dart';

/// Service quản lý lưu trữ dữ liệu local với Hive
/// Singleton pattern - gọi StorageService() ở bất kỳ đâu
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Box names
  static const String _settingsBox = 'settings';
  static const String _audioSegmentsBox = 'audio_segments';
  static const String _textSegmentsBox = 'text_segments';
  static const String _savedPositionsBox = 'saved_positions';
  static const String _shadowingHistoryBox = 'shadowing_history';
  static const String _savedWordsBox = 'saved_words';
  static const String _dailyStatsBox = 'daily_stats';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ==================== INITIALIZATION ====================

  /// Khởi tạo Hive - gọi 1 lần trong main()
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      // Mở tất cả boxes
      await Future.wait([
        Hive.openBox(_settingsBox),
        Hive.openBox<String>(_audioSegmentsBox),
        Hive.openBox<String>(_textSegmentsBox),
        Hive.openBox<int>(_savedPositionsBox),
        Hive.openBox<String>(_shadowingHistoryBox),
        Hive.openBox<String>(_savedWordsBox),
        Hive.openBox(_dailyStatsBox),
        Hive.openBox<String>('web_reader_history'),
        Hive.openBox<String>('pdf_annotations'),
      ]);

      _initialized = true;
      debugPrint('✅ StorageService initialized');
    } catch (e) {
      debugPrint('❌ StorageService init error: $e');
    }
  }

  // ==================== SETTINGS ====================

  Box get _settings => Hive.box(_settingsBox);

  /// Lưu setting
  Future<void> saveSetting(String key, dynamic value) async {
    await _settings.put(key, value);
  }

  /// Đọc setting
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settings.get(key, defaultValue: defaultValue) as T?;
  }

  // --- Các setting cụ thể ---

  Future<void> saveLastMode(String modeName) async {
    await saveSetting('last_mode', modeName);
  }

  String getLastMode() {
    return getSetting<String>('last_mode', defaultValue: 'music') ?? 'music';
  }

  Future<void> saveFontSize(double size) async {
    await saveSetting('font_size', size);
  }

  double getFontSize() {
    return getSetting<double>('font_size', defaultValue: 18.0) ?? 18.0;
  }

  Future<void> saveTtsSpeed(double speed) async {
    await saveSetting('tts_speed', speed);
  }

  double getTtsSpeed() {
    return getSetting<double>('tts_speed', defaultValue: 1.0) ?? 1.0;
  }

  Future<void> saveColorMode(String mode) async {
    await saveSetting('color_mode', mode);
  }

  String getColorMode() {
    return getSetting<String>('color_mode', defaultValue: 'none') ?? 'none';
  }

  Future<void> saveShowTranslation(bool show) async {
    await saveSetting('show_translation', show);
  }

  bool getShowTranslation() {
    return getSetting<bool>('show_translation', defaultValue: true) ?? true;
  }

  Future<void> saveLastPlaybackSpeed(double speed) async {
    await saveSetting('last_playback_speed', speed);
  }

  double getLastPlaybackSpeed() {
    return getSetting<double>('last_playback_speed', defaultValue: 1.0) ?? 1.0;
  }

  Future<void> saveGapDuration(double gap) async {
    await saveSetting('gap_duration', gap);
  }

  double getGapDuration() {
    return getSetting<double>('gap_duration', defaultValue: 0.0) ?? 0.0;
  }

  Future<void> saveLastAudioPath(String path) async {
    await saveSetting('last_audio_path', path);
  }

  String? getLastAudioPath() {
    return getSetting<String>('last_audio_path');
  }

  Future<void> saveLastTextPath(String path) async {
    await saveSetting('last_text_path', path);
  }

  String? getLastTextPath() {
    return getSetting<String>('last_text_path');
  }

  Future<void> saveShadowingRepeatCount(int count) async {
    await saveSetting('shadowing_repeat_count', count);
  }

  int getShadowingRepeatCount() {
    return getSetting<int>('shadowing_repeat_count', defaultValue: 3) ?? 3;
  }

  Future<void> saveShadowingPlaybackSpeed(double speed) async {
    await saveSetting('shadowing_playback_speed', speed);
  }

  double getShadowingPlaybackSpeed() {
    return getSetting<double>('shadowing_playback_speed', defaultValue: 1.0) ??
        1.0;
  }

  Future<void> saveShadowingPresetLabel(String? label) async {
    if (label == null || label.trim().isEmpty) {
      await _settings.delete('shadowing_preset_label');
      return;
    }
    await saveSetting('shadowing_preset_label', label.trim());
  }

  String? getShadowingPresetLabel() {
    return getSetting<String>('shadowing_preset_label');
  }

  Future<void> saveShadowingCustomPresets(
      List<Map<String, dynamic>> presets) async {
    await saveSetting('shadowing_custom_presets', presets);
  }

  List<Map<String, dynamic>> getShadowingCustomPresets() {
    final raw = _settings.get('shadowing_custom_presets');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  Future<void> saveShellCompactMode(bool value) async {
    await saveSetting('shell_compact_mode', value);
  }

  bool getShellCompactMode() {
    return getSetting<bool>('shell_compact_mode', defaultValue: false) ?? false;
  }

  Future<void> saveShellAutoHideModeSwitch(bool value) async {
    await saveSetting('shell_auto_hide_mode_switch', value);
  }

  bool getShellAutoHideModeSwitch() {
    return getSetting<bool>('shell_auto_hide_mode_switch', defaultValue: false) ??
        false;
  }

  Future<void> saveShellLongPressModeSwitch(bool value) async {
    await saveSetting('shell_long_press_mode_switch', value);
  }

  bool getShellLongPressModeSwitch() {
    return getSetting<bool>('shell_long_press_mode_switch', defaultValue: false) ??
        false;
  }

  Future<void> saveShellRememberLastSubMode(bool value) async {
    await saveSetting('shell_remember_last_sub_mode', value);
  }

  bool getShellRememberLastSubMode() {
    return getSetting<bool>('shell_remember_last_sub_mode', defaultValue: true) ??
        true;
  }

  Future<void> saveShellListenSubMode(int index) async {
    await saveSetting('shell_listen_sub_mode', index);
  }

  int getShellListenSubMode() {
    return getSetting<int>('shell_listen_sub_mode', defaultValue: 0) ?? 0;
  }

  Future<void> saveShellReadSubMode(int index) async {
    await saveSetting('shell_read_sub_mode', index);
  }

  int getShellReadSubMode() {
    return getSetting<int>('shell_read_sub_mode', defaultValue: 0) ?? 0;
  }

  Future<void> saveShellLongPressHintSeen(bool value) async {
    await saveSetting('shell_long_press_hint_seen', value);
  }

  bool getShellLongPressHintSeen() {
    return getSetting<bool>('shell_long_press_hint_seen', defaultValue: false) ??
        false;
  }

  Future<void> saveShellModeChipHintSeen(bool value) async {
    await saveSetting('shell_mode_chip_hint_seen', value);
  }

  bool getShellModeChipHintSeen() {
    return getSetting<bool>('shell_mode_chip_hint_seen', defaultValue: false) ??
        false;
  }

  Future<void> recordQuickActionUsage(String id) async {
    final countKey = 'quick_action_count_$id';
    final lastKey = 'quick_action_last_$id';
    final current = (_settings.get(countKey, defaultValue: 0) as int?) ?? 0;
    await _settings.put(countKey, current + 1);
    await _settings.put(lastKey, DateTime.now().millisecondsSinceEpoch);
  }

  int getQuickActionUsageCount(String id) {
    return (_settings.get('quick_action_count_$id', defaultValue: 0) as int?) ?? 0;
  }

  int getQuickActionLastUsedMillis(String id) {
    return (_settings.get('quick_action_last_$id', defaultValue: 0) as int?) ?? 0;
  }

  // ==================== AUDIO SEGMENTS ====================

  Box<String> get _audioSegments => Hive.box<String>(_audioSegmentsBox);

  /// Lưu audio segment
  Future<void> saveAudioSegment(Segment segment) async {
    final json = jsonEncode(segment.toJson());
    await _audioSegments.put(segment.id, json);
  }

  /// Lưu nhiều audio segments
  Future<void> saveAllAudioSegments(List<Segment> segments) async {
    final entries = <String, String>{};
    for (final segment in segments) {
      entries[segment.id] = jsonEncode(segment.toJson());
    }
    await _audioSegments.putAll(entries);
  }

  /// Đọc tất cả audio segments
  List<Segment> getAllAudioSegments() {
    final segments = <Segment>[];
    for (final json in _audioSegments.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        segments.add(Segment.fromJson(map));
      } catch (e) {
        debugPrint('Error parsing audio segment: $e');
      }
    }
    return segments;
  }

  /// Đọc audio segments theo audio path
  List<Segment> getAudioSegmentsForFile(String audioPath) {
    return getAllAudioSegments()
        .where((s) => s.audioPath == audioPath)
        .toList();
  }

  /// Xóa audio segment
  Future<void> deleteAudioSegment(String id) async {
    await _audioSegments.delete(id);
  }

  /// Xóa tất cả audio segments
  Future<void> clearAllAudioSegments() async {
    await _audioSegments.clear();
  }

  // ==================== TEXT SEGMENTS ====================

  Box<String> get _textSegments => Hive.box<String>(_textSegmentsBox);

  /// Lưu text segment
  Future<void> saveTextSegment(TextSegment segment) async {
    final json = jsonEncode(segment.toJson());
    await _textSegments.put(segment.id, json);
  }

  /// Lưu nhiều text segments
  Future<void> saveAllTextSegments(List<TextSegment> segments) async {
    final entries = <String, String>{};
    for (final segment in segments) {
      entries[segment.id] = jsonEncode(segment.toJson());
    }
    await _textSegments.putAll(entries);
  }

  /// Đọc tất cả text segments
  List<TextSegment> getAllTextSegments() {
    final segments = <TextSegment>[];
    for (final json in _textSegments.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        segments.add(TextSegment.fromJson(map));
      } catch (e) {
        debugPrint('Error parsing text segment: $e');
      }
    }
    return segments;
  }

  /// Xóa text segment
  Future<void> deleteTextSegment(String id) async {
    await _textSegments.delete(id);
  }

  /// Xóa tất cả text segments
  Future<void> clearAllTextSegments() async {
    await _textSegments.clear();
  }

  // ==================== SAVED POSITIONS ====================

  Box<int> get _positions => Hive.box<int>(_savedPositionsBox);

  /// Lưu vị trí phát của file audio (milliseconds)
  Future<void> savePosition(String audioPath, int positionMs) async {
    if (positionMs > 5000) {
      // Chỉ lưu nếu > 5 giây
      await _positions.put(audioPath, positionMs);
    }
  }

  /// Đọc vị trí đã lưu
  int? getSavedPosition(String audioPath) {
    return _positions.get(audioPath);
  }

  /// Xóa vị trí đã lưu
  Future<void> clearPosition(String audioPath) async {
    await _positions.delete(audioPath);
  }

  /// Xóa tất cả vị trí
  Future<void> clearAllPositions() async {
    await _positions.clear();
  }

  /// Lấy tất cả files đã phát (có saved position)
  Map<String, int> getAllSavedPositions() {
    final result = <String, int>{};
    for (final key in _positions.keys) {
      result[key as String] = _positions.get(key)!;
    }
    return result;
  }

  // ==================== SHADOWING HISTORY ====================

  Box<String> get _shadowingHistory => Hive.box<String>(_shadowingHistoryBox);

  /// Lưu kết quả shadowing
  Future<void> saveShadowingResult(ShadowingResult result) async {
    final json = jsonEncode(result.toJson());
    await _shadowingHistory.put(result.id, json);
  }

  /// Đọc tất cả kết quả shadowing
  List<Map<String, dynamic>> getAllShadowingResults() {
    final results = <Map<String, dynamic>>[];
    for (final json in _shadowingHistory.values) {
      try {
        results.add(jsonDecode(json) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error parsing shadowing result: $e');
      }
    }
    return results;
  }

  /// Đọc kết quả shadowing gần nhất
  Map<String, dynamic>? getLatestShadowingResult() {
    if (_shadowingHistory.isEmpty) return null;
    try {
      final lastJson = _shadowingHistory.values.last;
      return jsonDecode(lastJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Xóa lịch sử shadowing
  Future<void> clearShadowingHistory() async {
    await _shadowingHistory.clear();
  }

  // ==================== SAVED WORDS ====================

  Box<String> get _words => Hive.box<String>(_savedWordsBox);

  /// Lưu từ vựng
  Future<void> saveWord(String word, Map<String, dynamic> data) async {
    await _words.put(word.toLowerCase(), jsonEncode(data));
  }

  /// Đọc từ vựng
  Map<String, dynamic>? getWord(String word) {
    final json = _words.get(word.toLowerCase());
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Đọc tất cả từ đã lưu
  List<Map<String, dynamic>> getAllSavedWords() {
    final words = <Map<String, dynamic>>[];
    for (final json in _words.values) {
      try {
        words.add(jsonDecode(json) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error parsing saved word: $e');
      }
    }
    return words;
  }

  /// Xóa từ
  Future<void> deleteWord(String word) async {
    await _words.delete(word.toLowerCase());
  }

  /// Kiểm tra từ đã lưu chưa
  bool isWordSaved(String word) {
    return _words.containsKey(word.toLowerCase());
  }

  // ==================== DAILY STATS ====================

  Box get _stats => Hive.box(_dailyStatsBox);

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Cập nhật thống kê ngày
  Future<void> incrementLoopCount() async {
    final key = '${_todayKey}_loops';
    final current = _stats.get(key, defaultValue: 0) as int;
    await _stats.put(key, current + 1);
  }

  /// Cập nhật thời gian nghe
  Future<void> addListeningTime(int seconds) async {
    final key = '${_todayKey}_listening_seconds';
    final current = _stats.get(key, defaultValue: 0) as int;
    await _stats.put(key, current + seconds);
  }

  /// Lấy thống kê ngày
  Map<String, dynamic> getDailyStats({String? date}) {
    final key = date ?? _todayKey;
    return {
      'date': key,
      'loops': _stats.get('${key}_loops', defaultValue: 0) as int,
      'listeningSeconds':
          _stats.get('${key}_listening_seconds', defaultValue: 0) as int,
    };
  }

  /// Lấy thống kê 7 ngày gần nhất
  List<Map<String, dynamic>> getWeeklyStats() {
    final stats = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      stats.add(getDailyStats(date: key));
    }
    return stats;
  }

  // ==================== CLEANUP ====================

  /// Xóa tất cả dữ liệu
  Future<void> clearAll() async {
    await _settings.clear();
    await _audioSegments.clear();
    await _textSegments.clear();
    await _positions.clear();
    await _shadowingHistory.clear();
    await _words.clear();
    await _stats.clear();
    debugPrint('🗑️ All storage cleared');
  }

  /// Đóng Hive
  Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }

  /// Debug: in thông tin storage
  void debugInfo() {
    debugPrint('=== StorageService Debug ===');
    debugPrint('Settings: ${_settings.length} entries');
    debugPrint('Audio Segments: ${_audioSegments.length}');
    debugPrint('Text Segments: ${_textSegments.length}');
    debugPrint('Saved Positions: ${_positions.length}');
    debugPrint('Shadowing History: ${_shadowingHistory.length}');
    debugPrint('Saved Words: ${_words.length}');
    debugPrint('Today Stats: ${getDailyStats()}');
    debugPrint('===========================');
  }
}
