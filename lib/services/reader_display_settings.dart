import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════
/// READER DISPLAY SETTINGS — hiển thị tab Đọc (PDF + Web)
///
/// READ-630-03: marker "từ đã lưu" (outline/chấm bao quanh từ) TẮT
/// mặc định (đọc sạch, không nhiễu thị giác); người dùng BẬT khi cần
/// qua nút trong toolbar. Persist qua SharedPreferences.
/// ═══════════════════════════════════════════════════════════════
class ReaderDisplaySettings {
  static const String _keyRecallMarkers = 'reader_show_recall_markers';

  static final ReaderDisplaySettings _instance = ReaderDisplaySettings._();

  /// Dùng instance chung cho cả PDF + Web reader.
  factory ReaderDisplaySettings() => _instance;

  ReaderDisplaySettings._();

  bool _showRecallMarkers = false;

  /// true = hiện marker bao quanh từ đã lưu (green = đã lưu,
  /// amber = có ghi chú, red = đến kỳ ôn).
  bool get showRecallMarkers => _showRecallMarkers;

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
}
