// packages/vipsound_ai/lib/src/engine/ai_engine_gemma.dart
// v11.0-final — fix param analysisType (không phải type)

import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'ai_engine.dart';

class AiEngineGemma implements AiEngine {
  @override
  AiEngineState get state => _state;
  AiEngineState _state = AiEngineState.uninitialized;

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  bool _disposed = false;

  @override
  Future<bool> initialize({required String modelPath}) async {
    if (_state == AiEngineState.ready) return true;
    _state = AiEngineState.loading;
    try {
      await _spawnIsolate(modelPath);
      _state = AiEngineState.ready;
      debugPrint('[AiEngineGemma] ✅ Ready: $modelPath');
      return true;
    } catch (e) {
      _state = AiEngineState.error;
      debugPrint('[AiEngineGemma] ❌ Init failed: $e');
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
    if (_disposed || _state != AiEngineState.ready || _sendPort == null) {
      yield AiAnalysis.fallback(
        text,
        errorReason: 'Engine not ready',
        analysisType: type,
      );
      return;
    }

    _state = AiEngineState.processing;
    final prompt = _buildPrompt(type, text, context);
    final responsePort = ReceivePort();
    final weakEngine = WeakReference(this);

    _sendPort!.send(_IsolateMessage(
      prompt: prompt,
      replyPort: responsePort.sendPort,
      temperature: temperature,
    ));

    await for (final msg in responsePort) {
      final engine = weakEngine.target;
      if (engine == null || engine._disposed) {
        responsePort.close();
        return;
      }

      if (msg is _IsolateResponse && msg.isComplete) {
        engine._state = AiEngineState.ready;
        yield AiAnalysis.fromGemmaJson(
          msg.fullText,
          analysisType: type,
        );
        responsePort.close();
        break;
      } else if (msg is _IsolateError) {
        engine._state = AiEngineState.ready;
        yield AiAnalysis.fallback(
          text,
          errorReason: msg.error,
          analysisType: type,
        );
        responsePort.close();
        break;
      }
    }
  }

  @override
  Future<void> warmUp() async {
    if (_state != AiEngineState.ready) return;
    try {
      await analyze(text: 'hello', type: AiAnalysisType.wordLookup)
          .first
          .timeout(const Duration(seconds: 15));
      debugPrint('[AiEngineGemma] 🔥 Warm-up done');
    } catch (e) {
      debugPrint('[AiEngineGemma] ⚠️ Warm-up timeout: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
    _state = AiEngineState.disposed;
  }

  Future<void> _spawnIsolate(String modelPath) async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(
      _isolateEntry,
      _IsolateInit(modelPath: modelPath, mainSendPort: _receivePort!.sendPort),
      debugName: 'GemmaIsolate',
    );

    final completer = Completer<SendPort>();
    late StreamSubscription sub;
    sub = _receivePort!.listen((msg) {
      if (msg is SendPort) {
        completer.complete(msg);
        sub.cancel();
      }
    });
    _sendPort = await completer.future.timeout(const Duration(seconds: 30));
  }

  static void _isolateEntry(_IsolateInit init) async {
    final port = ReceivePort();
    init.mainSendPort.send(port.sendPort);
    await for (final msg in port) {
      if (msg is _IsolateMessage) {
        try {
          msg.replyPort.send(_IsolateResponse(
            fullText: _mockInference(msg.prompt),
            isComplete: true,
          ));
        } catch (e) {
          msg.replyPort.send(_IsolateError(error: e.toString()));
        }
      }
    }
  }

  static String _mockInference(String prompt) => '''
{
  "summary": "Phân tích các khái niệm kỹ thuật và thuật ngữ chuyên ngành.",
  "topics": ["Technology", "Language Learning"],
  "technical_terms": [
    {
      "text": "Isolate",
      "definition": "Luồng thực thi độc lập trong Dart.",
      "importance": 0.95,
      "sourceJoinKey": "0|isolate",
      "speakerId": 1
    }
  ],
  "action_items": [],
  "language": "en"
}''';

  String _buildPrompt(AiAnalysisType type, String text, String? ctx) => '''
SYSTEM: Bạn là Gemma AI offline của VipSound. Chỉ trả JSON hợp lệ.
TYPE: ${type.name}
INPUT: $text
${ctx != null ? 'CONTEXT: $ctx' : ''}
OUTPUT SCHEMA:
{
  "summary": "string",
  "topics": ["string"],
  "technical_terms": [{"text":"","definition":"","importance":0.0,"sourceJoinKey":"","speakerId":0}],
  "action_items": ["string"],
  "language": "en|vi"
}''';
}

class _IsolateInit {
  final String modelPath;
  final SendPort mainSendPort;
  const _IsolateInit({required this.modelPath, required this.mainSendPort});
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
  const _IsolateResponse({required this.fullText, required this.isComplete});
}

class _IsolateError {
  final String error;
  const _IsolateError({required this.error});
}
