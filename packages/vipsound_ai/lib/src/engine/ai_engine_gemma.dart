// THAY THẾ HOÀN TOÀN file cũ

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../ffi/llama_ffi_bindings.dart';
import '../models/ai_analysis.dart';
import '../prompts/ai_prompts_library.dart';
import '../mapper/ai_model_mapper.dart';
import 'ai_engine.dart';

class AiEngineGemma implements AiEngine {
  @override
  AiEngineState get state => _state;
  AiEngineState _state = AiEngineState.uninitialized;

  String? _modelPath;
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;

  // ── Initialize ───────────────────────────────────────────

  @override
  Future<bool> initialize({required String modelPath}) async {
    if (_state == AiEngineState.ready) return true;

    _state = AiEngineState.loading;
    _modelPath = modelPath;

    try {
      await _spawnIsolate(modelPath);
      _state = AiEngineState.ready;
      debugPrint('[AiEngineGemma] ✅ Ready - model: $modelPath');
      return true;
    } catch (e) {
      _state = AiEngineState.error;
      debugPrint('[AiEngineGemma] ❌ Failed: $e');
      return false;
    }
  }

  // ── Analyze ──────────────────────────────────────────────

  @override
  Stream<AiAnalysis> analyze({
    required String text,
    required AiAnalysisType type,
    String? context,
    double temperature = 0.1,
  }) async* {
    if (_state != AiEngineState.ready || _sendPort == null) {
      yield AiAnalysis.fallback(text, errorReason: 'Engine not ready');
      return;
    }

    _state = AiEngineState.processing;

    final prompt = AiPromptsLibrary.buildPrompt(
      type: type,
      text: text,
      context: context,
    );

    final responsePort = ReceivePort();

    _sendPort!.send(_GemmaRequest(
      prompt: prompt,
      replyPort: responsePort.sendPort,
      temperature: temperature,
      maxTokens: type == AiAnalysisType.sentenceAnalysis ? 768 : 512,
    ));

    bool received = false;

    await for (final message in responsePort) {
      if (message is _GemmaResponse) {
        received = true;
        responsePort.close();

        final analysis = AiModelMapper.parse(
          rawOutput: message.output,
          inputText: text,
          type: type,
        );

        _state = AiEngineState.ready;
        yield analysis;
        break;
      } else if (message is _GemmaError) {
        received = true;
        responsePort.close();
        _state = AiEngineState.ready;
        yield AiAnalysis.fallback(text, errorReason: message.error);
        break;
      }
    }

    if (!received) {
      _state = AiEngineState.ready;
      yield AiAnalysis.fallback(text, errorReason: 'Timeout');
    }
  }

  // ── Warm Up ──────────────────────────────────────────────

  @override
  Future<void> warmUp() async {
    if (_state != AiEngineState.ready) return;

    debugPrint('[AiEngineGemma] 🔥 Warm-up bắt đầu...');
    try {
      await analyze(
        text: 'test',
        type: AiAnalysisType.wordLookup,
      ).first.timeout(const Duration(seconds: 20));
      debugPrint('[AiEngineGemma] ✅ Warm-up xong');
    } on TimeoutException {
      debugPrint('[AiEngineGemma] ⚠️ Warm-up timeout (bình thường lần đầu)');
    }
  }

  // ── Isolate ──────────────────────────────────────────────

  Future<void> _spawnIsolate(String modelPath) async {
    _receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateMain,
      _GemmaIsolateInit(
        modelPath: modelPath,
        mainPort: _receivePort!.sendPort,
      ),
      debugName: 'VipsoundGemmaIsolate',
      errorsAreFatal: false,
    );

    // Chờ handshake SendPort
    final completer = Completer<SendPort>();
    final sub = _receivePort!.listen((msg) {
      if (msg is SendPort && !completer.isCompleted) {
        completer.complete(msg);
      }
    });

    _sendPort = await completer.future
        .timeout(const Duration(seconds: 60));

    // Tiếp tục listen sau khi có sendPort
    // (sub đã cancel implicit vì completer completed)
    sub.cancel();

    // Re-listen cho các inference requests
    _receivePort!.listen((_) {});
  }

  // ── Isolate Entry Point ──────────────────────────────────

  /// Chạy trong Isolate riêng
  /// KHÔNG import bất kỳ Flutter widget nào ở đây
  static void _isolateMain(_GemmaIsolateInit init) async {
    final receivePort = ReceivePort();
    init.mainPort.send(receivePort.sendPort);

    // Load FFI bindings
    final ffi = LlamaFfiBindings();
    final libLoaded = ffi.load();

    debugPrint('[GemmaIsolate] FFI loaded: $libLoaded');

    // Tạo llama context
    Pointer<Void> llamaCtx = nullptr;

    if (libLoaded) {
      debugPrint('[GemmaIsolate] Loading model: ${init.modelPath}');
      llamaCtx = ffi.createContext(
        init.modelPath,
        nCtx: 2048,
        nThreads: _getOptimalThreadCount(),
      );

      if (llamaCtx == nullptr || !ffi.isContextValid(llamaCtx)) {
        debugPrint('[GemmaIsolate] ❌ Model load failed');
        llamaCtx = nullptr;
      } else {
        debugPrint('[GemmaIsolate] ✅ Model loaded: ${ffi.getModelInfo(llamaCtx)}');
      }
    }

    // Main loop
    await for (final message in receivePort) {
      if (message is _GemmaRequest) {
        try {
          String output;

          if (llamaCtx != nullptr && ffi.isContextValid(llamaCtx)) {
            // ── Real inference ──────────────────────────
            ffi.resetContext(llamaCtx); // Clear KV cache

            final result = ffi.runInference(
              llamaCtx,
              message.prompt,
              maxTokens: message.maxTokens,
              temperature: message.temperature,
            );

            output = result ?? '';

            if (output.isEmpty) {
              message.replyPort.send(
                _GemmaError(error: 'Empty output from llama.cpp'),
              );
              continue;
            }
          } else {
            // ── Fallback Mock (khi FFI không load được) ──
            debugPrint('[GemmaIsolate] ⚠️ Using mock (no native lib)');
            output = _buildMockOutput(message.prompt);
          }

          message.replyPort.send(_GemmaResponse(output: output));
        } catch (e, stack) {
          debugPrint('[GemmaIsolate] Error: $e\n$stack');
          message.replyPort.send(_GemmaError(error: e.toString()));
        }
      }
    }

    // Cleanup
    if (llamaCtx != nullptr) {
      ffi.destroyContext(llamaCtx);
    }
  }

  /// Tối ưu số thread cho từng platform
  static int _getOptimalThreadCount() {
    // iOS: Efficiency cores + Performance cores
    // Android: Depends on device
    // Mặc định 4 là an toàn cho hầu hết thiết bị
    return 4;
  }

  /// Mock output - fallback khi native lib chưa sẵn sàng
  static String _buildMockOutput(String prompt) {
    final wordMatch = RegExp(r'"([^"]{2,30})"').firstMatch(prompt);
    final word = wordMatch?.group(1) ?? 'unknown';

    return '''{
  "type": "wordLookup",
  "word_detail": {
    "word": "$word",
    "meaning": "[Mock] nghĩa của $word",
    "cefr_level": "B1",
    "word_type": "noun",
    "memory_hook": "Hình dung một cảnh sinh động về $word"
  },
  "visual_prompt": "Cảnh sinh động thể hiện $word",
  "pao_suggestions": [
    "Einstein khám phá bí mật của $word",
    "Bạn nhớ mãi khoảnh khắc gặp $word",
    "Sherlock Holmes suy luận về $word"
  ],
  "context_examples": [
    "The $word was remarkable.",
    "She studied the $word carefully."
  ],
  "ipa_fallback": "/mɒk/"
}''';
  }

  // ── Dispose ──────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
    _state = AiEngineState.disposed;
    debugPrint('[AiEngineGemma] Disposed');
  }
}

// ── Isolate message types ─────────────────────────────────

class _GemmaIsolateInit {
  final String modelPath;
  final SendPort mainPort;
  const _GemmaIsolateInit({required this.modelPath, required this.mainPort});
}

class _GemmaRequest {
  final String prompt;
  final SendPort replyPort;
  final double temperature;
  final int maxTokens;
  const _GemmaRequest({
    required this.prompt,
    required this.replyPort,
    this.temperature = 0.1,
    this.maxTokens = 512,
  });
}

class _GemmaResponse {
  final String output;
  const _GemmaResponse({required this.output});
}

class _GemmaError {
  final String error;
  const _GemmaError({required this.error});
}
