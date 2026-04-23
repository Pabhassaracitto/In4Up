import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
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

  // ── Platform Library Loading ─────────────────────────────

  /// Load llama.cpp library theo platform
  /// Pattern giống UltraEngineFFIV2.load() trong project
  static DynamicLibrary? _loadNativeLibrary() {
    try {
      if (Platform.isAndroid) {
        return DynamicLibrary.open('libllama.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        // iOS: llama.cpp compile thành static lib, link vào app
        return DynamicLibrary.process();
      } else if (Platform.isWindows) {
        return DynamicLibrary.open('llama.dll');
      }
    } catch (e) {
      debugPrint('[AiEngineGemma] Native library not found: $e');
    }
    return null;
  }

  // ── Public API ─────────────────────────────────────────

  @override
  Future<bool> initialize({required String modelPath}) async {
    if (_state == AiEngineState.ready) return true;
    _state = AiEngineState.loading;
    _modelPath = modelPath;

    try {
      await _spawnIsolate(modelPath);
      _state = AiEngineState.ready;
      debugPrint('[AiEngineGemma] ✅ Engine ready');
      return true;
    } catch (e) {
      _state = AiEngineState.error;
      debugPrint('[AiEngineGemma] ❌ Initialize failed: $e');
      return false;
    }
  }

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
    _sendPort!.send(_IsolateMessage(
      prompt: prompt,
      replyPort: responsePort.sendPort,
      temperature: temperature,
    ));

    await for (final message in responsePort) {
      if (message is _IsolateResponse) {
        if (message.isComplete) {
          final analysis = AiModelMapper.parse(
            rawOutput: message.fullText,
            inputText: text,
            type: type,
          );
          _state = AiEngineState.ready;
          yield analysis;
          responsePort.close();
          break;
        }
      } else if (message is _IsolateError) {
        _state = AiEngineState.ready;
        yield AiAnalysis.fallback(text, errorReason: message.error);
        responsePort.close();
        break;
      }
    }
  }

  @override
  Future<void> warmUp() async {
    if (_state != AiEngineState.ready) return;
    debugPrint('[AiEngineGemma] 🔥 Warming up...');
    try {
      await analyze(
        text: 'hello',
        type: AiAnalysisType.wordLookup,
      ).first.timeout(const Duration(seconds: 15));
      debugPrint('[AiEngineGemma] ✅ Warm-up complete');
    } catch (e) {
      debugPrint('[AiEngineGemma] ⚠️ Warm-up timeout (normal): $e');
    }
  }

  @override
  Future<void> dispose() async {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
    _state = AiEngineState.disposed;
  }

  // ── Isolate ──────────────────────────────────────────────

  Future<void> _spawnIsolate(String modelPath) async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _IsolateInit(
        modelPath: modelPath,
        mainSendPort: _receivePort!.sendPort,
      ),
      debugName: 'GemmaIsolate',
    );

    // Chờ Isolate gửi SendPort về
    final completer = Completer<SendPort>();
    late StreamSubscription sub;
    sub = _receivePort!.listen((msg) {
      if (msg is SendPort) {
        completer.complete(msg);
        sub.cancel();
        // Tiếp tục listen cho các message sau
      }
    });

    _sendPort = await completer.future.timeout(const Duration(seconds: 30));
  }

  /// Chạy trong Isolate riêng - KHÔNG có Flutter context
  static void _isolateEntryPoint(_IsolateInit init) async {
    final receivePort = ReceivePort();
    init.mainSendPort.send(receivePort.sendPort);

    // Thử load llama.cpp
    // Sprint 2: Uncomment và implement FFI thực tế
    // final lib = _loadNativeLibrary();
    // final llamaContext = lib != null ? _initLlama(lib, init.modelPath) : null;

    debugPrint('[GemmaIsolate] Started, model: ${init.modelPath}');

    await for (final message in receivePort) {
      if (message is _IsolateMessage) {
        try {
          String output;

          // Sprint 1: Mock output
          // Sprint 2: output = _runLlamaInference(llamaContext, message.prompt)
          output = _mockInference(message.prompt, message.temperature);

          message.replyPort.send(_IsolateResponse(
            fullText: output,
            isComplete: true,
          ));
        } catch (e) {
          message.replyPort.send(_IsolateError(error: e.toString()));
        }
      }
    }
  }

  /// Mock inference cho Sprint 1
  /// Trả về JSON chuẩn để test toàn bộ pipeline
  static String _mockInference(String prompt, double temperature) {
    // Extract từ từ prompt (đơn giản)
    final wordMatch = RegExp(r'"([^"]+)"').firstMatch(prompt);
    final word = wordMatch?.group(1) ?? 'unknown';

    return '''
{
  "type": "wordLookup",
  "word_detail": {
    "word": "$word",
    "meaning": "nghĩa của $word",
    "phonetic": "/mɒk/",
    "cefr_level": "B2",
    "word_type": "noun",
    "etymology_hint": "Mock etymology for testing",
    "memory_hook": "Hình dung một hình ảnh sinh động liên quan đến $word"
  },
  "visual_prompt": "Một cảnh sinh động thể hiện ý nghĩa của '$word'",
  "pao_suggestions": [
    "Einstein (P) khám phá (A) điều bí ẩn (O) → $word",
    "Hermione (P) đọc thần chú (A) cuốn sách cổ (O) → $word",
    "Bạn (P) nhận ra (A) bí mật quan trọng (O) → $word"
  ],
  "context_examples": [
    "This is an example sentence with $word.",
    "Another example showing how to use $word correctly."
  ],
  "ipa_fallback": "/mɒk/"
}''';
  }
}

// ── Isolate DTOs ────────────────────────────────────────────

class _IsolateInit {
  final String modelPath;
  final SendPort mainSendPort;
  const _IsolateInit({
    required this.modelPath,
    required this.mainSendPort,
  });
}

class _IsolateMessage {
  final String prompt;
  final SendPort replyPort;
  final double temperature;
  const _IsolateMessage({
    required this.prompt,
    required this.replyPort,
    this.temperature = 0.1,
  });
}

class _IsolateResponse {
  final String fullText;
  final bool isComplete;
  const _IsolateResponse({
    required this.fullText,
    required this.isComplete,
  });
}

class _IsolateError {
  final String error;
  const _IsolateError({required this.error});
}
