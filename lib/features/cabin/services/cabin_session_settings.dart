import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:in4up/features/cabin/models/cabin_session.dart';

/// CABIN-SAVE-001 — cài đặt lưu phiên Cabin (SharedPreferences).
///
/// Mặc định chốt với người sở hữu (PLAN-030): text song ngữ, ghi âm WAV,
/// hỏi trước khi lưu (tự lưu là tuỳ chọn).
class CabinSessionSettings extends ChangeNotifier {
  CabinSessionSettings._();
  static final CabinSessionSettings instance = CabinSessionSettings._();

  static const _kRecordAudio = 'cabin_save.record_audio';
  static const _kAutoSave = 'cabin_save.auto_save';
  static const _kTextMode = 'cabin_save.text_mode';
  static const _kAudioFormat = 'cabin_save.audio_format';

  bool _loaded = false;
  bool _recordAudio = true;
  bool _autoSave = false;
  CabinTextMode _textMode = CabinTextMode.bilingual;
  CabinAudioFormat _audioFormat = CabinAudioFormat.wav;

  bool get recordAudio => _recordAudio;
  bool get autoSave => _autoSave;
  CabinTextMode get textMode => _textMode;
  CabinAudioFormat get audioFormat => _audioFormat;

  /// Nén audio chưa có thư viện (PLAN-030 R2) ⇒ UI hiện "sắp có".
  static const bool compressedAvailable = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      _recordAudio = p.getBool(_kRecordAudio) ?? true;
      _autoSave = p.getBool(_kAutoSave) ?? false;
      _textMode = CabinTextMode.values.firstWhere(
        (m) => m.name == p.getString(_kTextMode),
        orElse: () => CabinTextMode.bilingual,
      );
      _audioFormat = CabinAudioFormat.values.firstWhere(
        (m) => m.name == p.getString(_kAudioFormat),
        orElse: () => CabinAudioFormat.wav,
      );
      if (!compressedAvailable) _audioFormat = CabinAudioFormat.wav;
    } catch (e) {
      debugPrint('⚠️ CabinSessionSettings load error: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save(void Function(SharedPreferences p) write) async {
    notifyListeners();
    try {
      write(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('⚠️ CabinSessionSettings save error: $e');
    }
  }

  Future<void> setRecordAudio(bool v) {
    _recordAudio = v;
    return _save((p) => p.setBool(_kRecordAudio, v));
  }

  Future<void> setAutoSave(bool v) {
    _autoSave = v;
    return _save((p) => p.setBool(_kAutoSave, v));
  }

  Future<void> setTextMode(CabinTextMode v) {
    _textMode = v;
    return _save((p) => p.setString(_kTextMode, v.name));
  }

  Future<void> setAudioFormat(CabinAudioFormat v) {
    if (v == CabinAudioFormat.compressed && !compressedAvailable) {
      return Future.value();
    }
    _audioFormat = v;
    return _save((p) => p.setString(_kAudioFormat, v.name));
  }
}
