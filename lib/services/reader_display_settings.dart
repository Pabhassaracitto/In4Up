import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_color_style.dart';

/// ═══════════════════════════════════════════════════════════════
/// READER DISPLAY SETTINGS — hiển thị tab Đọc (PDF + Web)
///
/// READ-630-03: marker "từ đã lưu" (outline/chấm bao quanh từ) TẮT
/// mặc định (đọc sạch, không nhiễu thị giác); người dùng BẬT khi cần
/// qua nút trong toolbar. Persist qua SharedPreferences.
/// ═══════════════════════════════════════════════════════════════
class ReaderDisplaySettings {
  static const String _keyRecallMarkers = 'reader_show_recall_markers';
  static const String _keyWordTapBoxes = 'reader_word_tap_boxes';
  static const String _keyWordColorStyle = 'reader_word_color_style';
  static const String _keyColorModeDetails = 'reader_show_color_mode_details';

  static final ReaderDisplaySettings _instance = ReaderDisplaySettings._();

  /// Dùng instance chung cho cả PDF + Web reader.
  factory ReaderDisplaySettings() => _instance;

  ReaderDisplaySettings._();

  bool _showRecallMarkers = false;
  bool _wordTapBoxes = false;
  WordColorStyle _wordColorStyle = WordColorStyle.textOnly;
  bool _showColorModeDetails = true;

  /// true = hiện marker bao quanh từ đã lưu (green = đã lưu,
  /// amber = có ghi chú, red = đến kỳ ôn).
  bool get showRecallMarkers => _showRecallMarkers;

  /// false (mặc định) = bôi nhiều chữ như chế độ không màu.
  /// true = mỗi từ một box, tap/long-press lưu từng từ (nền hàng loạt).
  bool get wordTapBoxes => _wordTapBoxes;

  /// READ-WORDSTYLE-001: kiểu hiển thị từ khi tô màu (nền / chỉ màu chữ /
  /// gạch chân) — người đọc lâu chọn "chỉ màu chữ" để đỡ phân tâm.
  WordColorStyle get wordColorStyle => _wordColorStyle;

  bool get showColorModeDetails => _showColorModeDetails;

  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showRecallMarkers = prefs.getBool(_keyRecallMarkers) ?? false;
      _wordTapBoxes = prefs.getBool(_keyWordTapBoxes) ?? false;
      _wordColorStyle =
          WordColorStyle.fromStorage(prefs.getString(_keyWordColorStyle));
      _showColorModeDetails = prefs.getBool(_keyColorModeDetails) ?? true;
    } catch (e) {
      debugPrint('ReaderDisplaySettings.init error: $e');
    }
  }

  Future<void> setShowRecallMarkers(bool value) async {
    if (_showRecallMarkers == value) return;
    _showRecallMarkers = value;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRecallMarkers, value);
    } catch (e) {
      debugPrint('ReaderDisplaySettings.save error: $e');
    }
  }

  Future<void> setWordTapBoxes(bool value) async {
    if (_wordTapBoxes == value) return;
    _wordTapBoxes = value;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyWordTapBoxes, value);
    } catch (e) {
      debugPrint('ReaderDisplaySettings.save wordTapBoxes error: $e');
    }
  }

  Future<void> setShowColorModeDetails(bool value) async {
    if (_showColorModeDetails == value) return;
    _showColorModeDetails = value;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyColorModeDetails, value);
    } catch (e) {
      debugPrint('ReaderDisplaySettings.save color mode details error: $e');
    }
  }

  /// READ-WORDSTYLE-001 — đổi kiểu hiển thị từ (nền màu / chỉ màu chữ /
  /// gạch chân). Người nghe (TextProvider) tự notify để tab Đọc vẽ lại.
  Future<void> setWordColorStyle(WordColorStyle style) async {
    if (_wordColorStyle == style) return;
    _wordColorStyle = style;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWordColorStyle, style.storageKey);
    } catch (e) {
      debugPrint('ReaderDisplaySettings.save wordColorStyle error: $e');
    }
  }
}
