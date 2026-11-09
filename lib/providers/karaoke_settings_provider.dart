// lib/providers/karaoke_settings_provider.dart
//
// Cấu hình hiển thị karaoke: cỡ chữ, màu, căn lề, và bật/tắt bản dịch.
// Lưu qua SharedPreferences để giữ giữa các lần mở app.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared by Listen and Understand; the existing contextual list remains the
/// default for installations without a stored preference.
enum KaraokeDisplayMode { context, currentLineOnly }

class KaraokeStyle {
  final KaraokeDisplayMode displayMode;
  final double fontSize;
  final double inactiveFontSize;
  final Color activeColor;
  final Color inactiveColor;
  final Color highlightBackground;
  final TextAlign textAlign;
  final bool showTranslation;

  const KaraokeStyle({
    this.displayMode = KaraokeDisplayMode.context,
    this.fontSize = 17,
    this.inactiveFontSize = 13.5,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0xFF8A8A9E),
    this.highlightBackground = const Color(0xFF6C63FF),
    this.textAlign = TextAlign.center,
    this.showTranslation = false,
  });

  KaraokeStyle copyWith({
    KaraokeDisplayMode? displayMode,
    double? fontSize,
    double? inactiveFontSize,
    Color? activeColor,
    Color? inactiveColor,
    Color? highlightBackground,
    TextAlign? textAlign,
    bool? showTranslation,
  }) {
    return KaraokeStyle(
      displayMode: displayMode ?? this.displayMode,
      fontSize: fontSize ?? this.fontSize,
      inactiveFontSize: inactiveFontSize ?? this.inactiveFontSize,
      activeColor: activeColor ?? this.activeColor,
      inactiveColor: inactiveColor ?? this.inactiveColor,
      highlightBackground: highlightBackground ?? this.highlightBackground,
      textAlign: textAlign ?? this.textAlign,
      showTranslation: showTranslation ?? this.showTranslation,
    );
  }
}

class KaraokeSettingsProvider extends ChangeNotifier {
  static const _kDisplayMode = 'karaoke_display_mode';
  static const _kFontSize = 'karaoke_font_size';
  static const _kInactiveFontSize = 'karaoke_inactive_font_size';
  static const _kActiveColor = 'karaoke_active_color';
  static const _kHighlight = 'karaoke_highlight';
  static const _kAlign = 'karaoke_align';
  static const _kShowTranslation = 'karaoke_show_translation';

  KaraokeStyle _style = const KaraokeStyle();
  KaraokeStyle get style => _style;

  bool _loaded = false;
  int _revision = 0;
  Future<void> _saveTail = Future<void>.value();

  Future<void> load() async {
    if (_loaded) return;
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      // A choice made while preferences were loading must win.
      if (revision != _revision) return;
      _style = KaraokeStyle(
        displayMode: _displayModeFromString(prefs.getString(_kDisplayMode)) ??
            _style.displayMode,
        fontSize: prefs.getDouble(_kFontSize) ?? _style.fontSize,
        inactiveFontSize:
            prefs.getDouble(_kInactiveFontSize) ?? _style.inactiveFontSize,
        activeColor:
            _colorFromInt(prefs.getInt(_kActiveColor)) ?? _style.activeColor,
        highlightBackground:
            _colorFromInt(prefs.getInt(_kHighlight)) ??
                _style.highlightBackground,
        textAlign: _alignFromString(prefs.getString(_kAlign)) ??
            _style.textAlign,
        showTranslation:
            prefs.getBool(_kShowTranslation) ?? _style.showTranslation,
      );
      _loaded = true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> update(KaraokeStyle style) {
    _revision++;
    _loaded = true;
    _style = style;
    notifyListeners();
    // Preserve the order of quick successive saves across async preference IO.
    final save = _saveTail.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kDisplayMode, style.displayMode.name);
        await prefs.setDouble(_kFontSize, style.fontSize);
        await prefs.setDouble(_kInactiveFontSize, style.inactiveFontSize);
        await prefs.setInt(_kActiveColor, style.activeColor.toARGB32());
        await prefs.setInt(_kHighlight, style.highlightBackground.toARGB32());
        await prefs.setString(_kAlign, style.textAlign.name);
        await prefs.setBool(_kShowTranslation, style.showTranslation);
      } catch (_) {}
    });
    _saveTail = save;
    return save;
  }

  static KaraokeDisplayMode? _displayModeFromString(String? value) {
    for (final mode in KaraokeDisplayMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  static Color? _colorFromInt(int? v) => v == null ? null : Color(v);
  static TextAlign? _alignFromString(String? s) {
    if (s == null) return null;
    for (final a in TextAlign.values) {
      if (a.name == s) return a;
    }
    return null;
  }
}
