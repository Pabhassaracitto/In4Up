// lib/features/iconize/iconize_settings.dart
//
// ICONIZE-001d — cài đặt hiển thị Iconize cho Tab Đọc (blueprint Khối B).
//
// Mirror pattern `ReaderDisplaySettings` (READ-630-03): singleton +
// SharedPreferences, mặc định TẮT (đọc sạch — user chủ động bật qua nút
// trong panel dịch). Khác ReaderDisplaySettings: extend ChangeNotifier để
// ghép được vào Listenable.merge với IconizeService.
//
// Ba cài đặt (ADR-0013 quyết định #4 + Khối B):
//  - enabled: toggle "Icon hóa" per-surface (v1: panel dịch Tab Đọc).
//  - density: 3 nấc low/medium/high ≈ 18/32/48% từ đủ điều kiện.
//  - iconizeTranslation: sub-toggle "Icon hóa cả bản dịch" — TẮT mặc định
//    (blueprint Khối B: bản dịch là chỗ dựa nghĩa, chỉ icon hóa khi user
//    chủ động muốn).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/iconize_span.dart';

class IconizeSettings extends ChangeNotifier {
  static const String _keyEnabled = 'iconize_reader_enabled';
  static const String _keyDensity = 'iconize_reader_density';
  static const String _keyTranslation = 'iconize_reader_translation';

  static final IconizeSettings _instance = IconizeSettings._();

  /// Instance chung cho mọi bề mặt Tab Đọc (như ReaderDisplaySettings).
  factory IconizeSettings() => _instance;

  IconizeSettings._();

  bool _enabled = false;
  IconizeDensity _density = IconizeDensity.medium;
  bool _iconizeTranslation = false;
  bool _loaded = false;

  bool get enabled => _enabled;
  IconizeDensity get density => _density;
  bool get iconizeTranslation => _iconizeTranslation;

  /// Nạp giá trị đã lưu — gọi lười ở lần build đầu; lỗi đọc prefs thì giữ
  /// mặc định (TẮT), không throw ra UI.
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? false;
      _iconizeTranslation = prefs.getBool(_keyTranslation) ?? false;
      final raw = prefs.getString(_keyDensity);
      _density = IconizeDensity.values.firstWhere(
        (d) => d.name == raw,
        orElse: () => IconizeDensity.medium,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('IconizeSettings.init error: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    await _saveBool(_keyEnabled, value);
  }

  Future<void> setDensity(IconizeDensity value) async {
    if (_density == value) return;
    _density = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDensity, value.name);
    } catch (e) {
      debugPrint('IconizeSettings.save density error: $e');
    }
  }

  Future<void> setIconizeTranslation(bool value) async {
    if (_iconizeTranslation == value) return;
    _iconizeTranslation = value;
    notifyListeners();
    await _saveBool(_keyTranslation, value);
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('IconizeSettings.save error: $e');
    }
  }
}
