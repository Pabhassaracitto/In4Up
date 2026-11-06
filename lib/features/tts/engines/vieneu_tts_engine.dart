// lib/features/tts/engines/vieneu_tts_engine.dart
//
// VieNeu-TTS v3 Turbo engine (audio.cpp C API, GGUF, on-device, offline) cho
// TtsService (ticket TTS-VIENEU-001).
//
// Chỉ đọc tiếng Việt (vi-VN) — không đọc Pali/mūla gốc. TtsService lọc theo
// trường ngôn ngữ của từng đoạn Tipiṭaka trước khi đưa qua engine này.
// Nếu native lib/model chưa sẵn sàng ⇒ isAvailable() = false ⇒ TtsService
// fallback qua engine kế tiếp (Piper → Offline → Edge…), không crash.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import './tts_engine.dart';
import 'package:in4up_stt/tts/vieneu_tts_core.dart';

/// VieNeu-TTS v3 Turbo neural TTS chạy hoàn toàn on-device (CPU, audio.cpp
/// GGUF). Không cần mạng, không cần Python runtime.
class VieneuTtsEngine implements TtsEngine {
  VieneuTtsEngine._();
  static final VieneuTtsEngine instance = VieneuTtsEngine._();

  final VieneuTtsCore _core = VieneuTtsCore.instance;

  /// File model + lib native đã tồn tại (chưa nạp native).
  bool _modelResolved = false;
  /// Native worker đã init xong (sẵn sàng synthesize).
  bool _initialized = false;
  String? _modelPath;
  String? _voicesDir;
  String? _selectedVoiceId;

  @override
  String get name => 'VieNeu-TTS (native)';

  @override
  String get id => 'vieneu_tts';

  @override
  int get maxCharsPerRequest => 3000; // audio.cpp tự chia đoạn dài (chunk)

  @override
  List<String> get supportedLanguages => const ['vi-VN'];

  /// Có thể dùng ngay bây giờ? (native lib + model file đã import)
  ///
  /// Nhanh, không block UI: chỉ kiểm tra file + load symbol. Việc nạp model
  /// 170 MB GGUF diễn ra lazy tại [init].
  @override
  Future<bool> isAvailable() async {
    if (!_modelResolved) {
      final libOk = await VieneuTtsCore.isNativeLibraryAvailable();
      final model = await VieneuTtsCore.modelPath();
      if (libOk && model != null) {
        _modelPath = model;
        _voicesDir = p.join(p.dirname(model), 'voices');
        _modelResolved = true;
      }
    }
    return _modelResolved && _initialized;
  }

  /// Giọng preset đã import (đọc từ voices/ bên cạnh model file).
  @override
  Future<List<TtsVoice>> getAvailableVoices(String language) async {
    if (!language.startsWith('vi')) return [];
    await isAvailable();
    if (_voicesDir == null) return [];
    final voices = <VieneuTtsVoice>[];
    final dir = Directory(_voicesDir!);
    if (await dir.exists()) {
      // Tìm các thư mục giọng: voices/<id>/ref_codes.txt (+ speaker.emb.txt).
      final entries = await dir.list().toList();
      for (final entry in entries) {
        if (entry is! Directory) continue;
        final id = p.basename(entry.path);
        final refCodes = File(p.join(entry.path, 'ref_codes.txt'));
        if (!await refCodes.exists()) continue;
        voices.add(VieneuTtsVoice(
          id: id,
          name: id.replaceAll('_', ' '),
          region: '', // TODO: đọc voices/manifest.json sau khi có file metadata
          refCodesPath: refCodes.path,
          speakerEmbeddingPath:
              await File(p.join(entry.path, 'speaker.emb.txt')).exists()
                  ? p.join(entry.path, 'speaker.emb.txt')
                  : null,
        ));
      }
    }
    // Nếu không tìm thấy voice preset nào (chỉ import .gguf), vẫn trả về
    // giọng mặc định embed trong GGUF. Audio.cpp chấp nhận refCodes=nullptr
    // và dùng giọng mặc định của model.
    if (voices.isEmpty) {
      voices.add(VieneuTtsVoice(
        id: VieneuTtsCore.defaultVoiceId,
        name: VieneuTtsCore.defaultVoiceId.replaceAll('_', ' '),
        region: '',
        refCodesPath: '',
        speakerEmbeddingPath: null,
      ));
    }
    // Giọng mặc định lên đầu nếu có.
    voices.sort((a, b) {
      final aDefault = a.id == VieneuTtsCore.defaultVoiceId ? 0 : 1;
      final bDefault = b.id == VieneuTtsCore.defaultVoiceId ? 0 : 1;
      return aDefault.compareTo(bDefault);
    });
    return voices
        .map((v) => TtsVoice(
              id: v.id,
              name: v.name,
              language: 'vi-VN',
              gender: 'unknown',
              engine: id,
              isNeural: true,
            ))
        .toList();
  }

  /// Khởi tạo (nạp model vào native worker isolate). Gọi từ TtsService trước
  /// lần synthesize đầu tiên; thất bại thì engine cứ remains unavailable và
  /// TtsService fallback bình thường.
  Future<void> init({String? voiceId}) async {
    final model = await VieneuTtsCore.modelPath();
    if (model == null) return;
    _modelPath = model;
    _voicesDir = p.join(p.dirname(model), 'voices');
    _selectedVoiceId = voiceId ?? VieneuTtsCore.defaultVoiceId;
    try {
      await _core.init(modelPath: model, voiceId: _selectedVoiceId);
      _initialized = true;
      _modelResolved = true;
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS init error: $e');
      _initialized = false;
    }
  }

  /// Đổi giọng đọc (cài đặt). Không nạp lại model.
  Future<void> selectVoice(String voiceId) async {
    if (_voicesDir == null) return;
    _selectedVoiceId = voiceId;
    await _core.selectVoice(voiceId, _voicesDir!);
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String language,
    double speed = 1.0,
    double pitch = 1.0,
    String? voiceId,
  }) async {
    // Chỉ đọc tiếng Việt — guard phòng hộ cho read mode đa ngôn ngữ
    // (Tipiṭaka: Pali = 'hi', Anh = 'en' đọc bằng engine khác).
    if (!language.startsWith('vi')) {
      return TtsResult.failure(
        error: 'VieNeu-TTS chỉ hỗ trợ tiếng Việt ($language)',
        engine: name,
      );
    }

    await init(voiceId: voiceId ?? _selectedVoiceId);
    if (!_initialized) {
      return TtsResult.failure(
        error: 'VieNeu-TTS chưa sẵn sàng (chưa import model .gguf)',
        engine: name,
      );
    }

    try {
      // Nếu người dùng chọn giọng khác với giọng đang dùng trong worker,
      // chuyển trước khi synthesize.
      if (voiceId != null && voiceId != _selectedVoiceId) {
        await selectVoice(voiceId);
      }

      final result = await _core.synthesize(
        text: text,
        language: language,
        speed: speed,
        pitch: pitch,
        voiceId: _selectedVoiceId,
      );
      if (result == null) {
        return TtsResult.failure(
          error: 'VieNeu-TTS không tổng hợp được âm thanh',
          engine: name,
        );
      }

      return TtsResult.successBytes(
        data: result.wavBytes,
        engine: name,
      );
    } catch (e) {
      debugPrint('⚠️ VieNeu-TTS synthesize error: $e');
      return TtsResult.failure(
        error: 'VieNeu-TTS lỗi: $e',
        engine: name,
      );
    }
  }

  void dispose() {
    _core.dispose();
    _initialized = false;
  }
}
