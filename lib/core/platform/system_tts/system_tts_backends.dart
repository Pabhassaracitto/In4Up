// lib/core/platform/system_tts/system_tts_backends.dart
//
// PSRC-221 — nối worker "giọng đọc hệ thống" vào các engine TTS OFFLINE có
// sẵn của app. KHÔNG thay engine nội bộ: chỉ gọi lại `PiperTtsEngine` /
// `VieneuTtsEngine` đúng như tab Đọc đang gọi.
//
// Cố ý KHÔNG có:
//   * engine online (Edge/Google/FPT/Zalo/OpenAI) — phiếu L8: chưa đăng ký
//     giọng cần mạng ở bước này;
//   * `OfflineTtsEngine` (flutter_tts) — nó ĐỌC BẰNG giọng hệ thống; khi
//     in4up chính là giọng hệ thống thì đó là vòng lặp tự gọi mình.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/tts/sherpa_piper_tts_core.dart';

import '../../../features/tts/engines/piper_tts_engine.dart';
import '../../../features/tts/engines/tts_engine.dart';
import '../../../features/tts/engines/vieneu_tts_engine.dart';
import '../../../features/tts/piper_voice_prefs.dart';
import 'system_tts_worker.dart';

/// Locale của một giọng Piper.
///
/// 1. Suy từ tên model (`vi_VN-vais1000-medium` → `vi-VN`).
/// 2. Tên không mang mã ngôn ngữ (model tự đặt tên, ví dụ `calmwoman3688`)
///    ⇒ dùng ngôn ngữ mà người dùng đã gán giọng đó trong Cài đặt
///    ([preferred]: ngôn ngữ → tên giọng). Ưu tiên khoá có vùng (`vi-VN`).
/// 3. Không biết ⇒ chuỗi rỗng: Android bắt buộc mỗi giọng có locale nên
///    giọng này không được liệt kê.
String piperSystemTtsLocale(String voiceName, Map<String, String> preferred) {
  final fromName = SherpaPiperTtsCore.langFromVoiceName(voiceName);
  if (fromName.isNotEmpty) return fromName;
  String best = '';
  for (final entry in preferred.entries) {
    if (entry.value != voiceName) continue;
    final locale = normalizeSystemTtsLocale(entry.key);
    if (locale.isEmpty) continue;
    if (locale.contains('-')) return locale;
    if (best.isEmpty) best = locale;
  }
  return best;
}

/// Giọng người dùng đã chọn cho một ngôn ngữ đứng TRƯỚC các giọng khác cùng
/// ngôn ngữ ⇒ nó là giọng mặc định khi Android chỉ yêu cầu theo locale.
List<SystemTtsBackendVoice> orderPiperSystemVoices(
  List<SystemTtsBackendVoice> voices,
  Map<String, String> preferred,
) {
  final chosen = preferred.values.toSet();
  final first = <SystemTtsBackendVoice>[];
  final rest = <SystemTtsBackendVoice>[];
  for (final voice in voices) {
    (chosen.contains(voice.voiceId) ? first : rest).add(voice);
  }
  return <SystemTtsBackendVoice>[...first, ...rest];
}

class PiperSystemTtsBackend implements SystemTtsBackend {
  PiperSystemTtsBackend({PiperTtsEngine? engine})
      : _engine = engine ?? PiperTtsEngine.instance;

  final PiperTtsEngine _engine;

  @override
  String get id => 'piper';

  @override
  Future<List<SystemTtsBackendVoice>> voices() async {
    // Cùng một cửa với tab Đọc: thiếu espeak-ng-data / model hỏng ⇒ không
    // quảng cáo giọng (xuống native lúc đó là tiến trình tự thoát).
    if (!await _engine.isAvailable()) return const <SystemTtsBackendVoice>[];

    Map<String, String> preferred = const <String, String>{};
    try {
      preferred = await PiperVoicePrefs.instance.all();
    } catch (e) {
      debugPrint('⚠️ system tts: không đọc được giọng Piper ưa thích: $e');
    }

    final found = <SystemTtsBackendVoice>[];
    for (final voice in await SherpaPiperTtsCore.discoverVoices()) {
      if (!SherpaPiperTtsCore.isVoiceFilesPlausible(voice)) continue;
      final locale = piperSystemTtsLocale(voice.name, preferred);
      if (locale.isEmpty) continue;
      found.add(SystemTtsBackendVoice(voiceId: voice.name, locale: locale));
    }
    return orderPiperSystemVoices(found, preferred);
  }

  @override
  Future<Uint8List?> synthesizeWav({
    required String voiceId,
    required String locale,
    required String text,
    required double rate,
    required double pitch,
  }) async {
    final result = await _engine.synthesize(
      text: text,
      language: locale,
      speed: rate,
      pitch: pitch,
      voiceId: voiceId,
    );
    return _wavOrThrow(result);
  }
}

class VieneuSystemTtsBackend implements SystemTtsBackend {
  VieneuSystemTtsBackend({VieneuTtsEngine? engine})
      : _engine = engine ?? VieneuTtsEngine.instance;

  final VieneuTtsEngine _engine;

  static const String _locale = 'vi-VN';

  @override
  String get id => 'vieneu';

  @override
  Future<List<SystemTtsBackendVoice>> voices() async {
    // Model .gguf + lib native + từ điển phát âm: thiếu một thứ là engine
    // không đọc được ⇒ không quảng cáo giọng.
    if (!await _engine.isAvailable()) return const <SystemTtsBackendVoice>[];
    if (!await _engine.hasPhonemeDictionary()) {
      return const <SystemTtsBackendVoice>[];
    }
    final voices = await _engine.getAvailableVoices(_locale);
    return voices
        .map((voice) =>
            SystemTtsBackendVoice(voiceId: voice.id, locale: _locale))
        .toList();
  }

  @override
  Future<Uint8List?> synthesizeWav({
    required String voiceId,
    required String locale,
    required String text,
    required double rate,
    required double pitch,
  }) async {
    final result = await _engine.synthesize(
      text: text,
      language: _locale,
      speed: rate,
      pitch: pitch,
      voiceId: voiceId,
    );
    return _wavOrThrow(result);
  }
}

Uint8List? _wavOrThrow(TtsResult result) {
  if (!result.isSuccess) {
    throw StateError(result.error ?? 'synthesis failed');
  }
  return result.audioData;
}
