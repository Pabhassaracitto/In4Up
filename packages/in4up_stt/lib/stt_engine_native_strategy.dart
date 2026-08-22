// packages/in2up_stt/lib/stt_engine_native_strategy.dart
//
// NativeSttEngine — adapter của SttEngineNative theo interface SttEngine
// (Strategy Pattern). Chỉ dùng cho live mic; không transcribe file.

import 'dart:async';

import 'models/stt_result.dart';
import 'stt_engine.dart';
import 'stt_engine_native.dart';

class NativeSttEngine implements SttEngine {
  final SttEngineNative _native;

  NativeSttEngine(this._native);

  @override
  String get engineName => 'native';

  @override
  SttEngineCapabilities get capabilities => const SttEngineCapabilities(
        supportsLiveMic: true,
      );

  @override
  Future<void> initialize() async {
    await _native.initialize();
  }

  @override
  Future<SttResult> transcribeFile(
    String audioPath, {
    Map<String, dynamic>? options,
  }) async {
    // Native không hỗ trợ file → trả rỗng để facade fallback.
    final language = (options?['language'] as String?) ?? 'en-US';
    return _native.transcribeFile(audioPath, language: language);
  }

  @override
  Stream<SttResult> get liveResultStream => _native.resultStream;

  @override
  Future<bool> startListening({String language = 'en-US'}) async =>
      _native.startListening(language: language);

  @override
  Future<void> stopListening() async => _native.stopListening();

  @override
  Future<void> dispose() async => _native.dispose();
}
