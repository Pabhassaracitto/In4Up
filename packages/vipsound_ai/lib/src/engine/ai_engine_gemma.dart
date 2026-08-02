// v11.0-final — fix param analysisType (không phải type)

import 'dart:async';
import 'dart:convert';
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
        final json = jsonDecode(msg.fullText) as Map<String, dynamic>;
        yield AiAnalysis.fromJson(
          json,
          text,
        ); // type is extracted from json['analysisType'] inside fromJson
        responsePort.close();
        break;
      } else if (msg is _IsolateError) {
        engine._state = AiEngineState.ready;
        yield AiAnalysis.fallback(
          text,
          errorReason: msg.error,
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

  static String _mockInference(String prompt) {
    if (prompt.contains('VIPSOUND_WRITE_REVIEW')) {
      return _mockWriteReview(prompt);
    }
    if (prompt.contains('VIPSOUND_REWRITE_REVIEW')) {
      return _mockRewriteReview(prompt);
    }
    if (prompt.contains('VIPSOUND_SUMMARY_REVIEW')) {
      return _mockSummaryReview(prompt);
    }

    return jsonEncode({
      'summary': 'Phân tích các khái niệm kỹ thuật và thuật ngữ chuyên ngành.',
      'topics': ['Technology', 'Language Learning'],
      'analysisType': 'sentenceParse',
      'technical_terms': [
        {
          'text': 'Isolate',
          'definition': 'Luồng thực thi độc lập trong Dart.',
          'importance': 0.95,
          'sourceJoinKey': '0|isolate',
          'speakerId': 1,
        }
      ],
      'action_items': ['Đọc lại ý chính và rút ngắn phản hồi vào 1-2 ý rõ ràng.'],
      'language': 'vi',
    });
  }

  static String _mockWriteReview(String prompt) {
    final expected = _extractLineValue(prompt, 'EXPECTED');
    final actual = _extractLineValue(prompt, 'ACTUAL');
    final totalScore = _extractIntValue(prompt, 'TOTAL_SCORE');
    final orderScore = _extractIntValue(prompt, 'ORDER_SCORE');
    final spellingScore = _extractIntValue(prompt, 'SPELLING_SCORE');
    final missing = _extractLineValue(prompt, 'MISSING');
    final extra = _extractLineValue(prompt, 'EXTRA');

    final topics = <String>['Writing', 'Recall'];
    final actions = <String>[];

    String summary;
    if (totalScore >= 90) {
      summary = 'Bài làm rất sát câu gốc, bạn đang giữ được cả ý và trật tự câu khá tốt.';
      actions.add('Có thể chuyển sang câu mới hoặc tăng tốc độ luyện một chút.');
      topics.add('High Accuracy');
    } else if (totalScore >= 75) {
      summary = 'Bài làm khá ổn, bạn đã nắm phần lớn nội dung nhưng vẫn còn vài điểm lệch nhỏ.';
      actions.add('Làm lại thêm 1 vòng ngay cùng câu để khóa phản xạ đúng.');
      topics.add('Stable Recall');
    } else if (totalScore >= 55) {
      summary = 'Bạn đã bắt được khung câu, nhưng độ chính xác chưa ổn định ở mọi phần.';
      actions.add('Chia câu thành các cụm ngắn rồi chép lại từng cụm trước khi ghép cả câu.');
      topics.add('Needs Reinforcement');
    } else {
      summary = 'Bài làm còn lệch khá nhiều so với câu gốc, nên giảm tải và luyện lại theo cụm nhỏ.';
      actions.add('Nghe chậm hơn hoặc dùng TTS để bám âm tốt hơn trước khi chép lại.');
      topics.add('Rebuild Foundation');
    }

    if (missing.isNotEmpty && missing != 'none') {
      actions.add('Tập trung nhớ lại các từ khóa còn thiếu: $missing.');
      topics.add('Missing Keywords');
    }
    if (extra.isNotEmpty && extra != 'none') {
      actions.add('Tránh thêm ý đoán; chỉ chép những gì thật sự nghe/nhớ được.');
      topics.add('Extra Words');
    }
    if (orderScore < 65) {
      actions.add('Luyện lại thứ tự cụm từ bằng cách đọc nhẩm trước khi gõ.');
      topics.add('Word Order');
    }
    if (spellingScore < 70) {
      actions.add('Mở đáp án và chép đúng mặt chữ 1 vòng để giảm lỗi chính tả.');
      topics.add('Spelling');
    }

    final grammar = _mockGrammarFromSentence(expected.isNotEmpty ? expected : actual);

    return jsonEncode({
      'summary': summary,
      'topics': topics.take(4).toList(),
      'analysisType': 'sentenceParse',
      'technical_terms': <Map<String, dynamic>>[],
      'action_items': actions.take(4).toList(),
      'grammar': grammar,
      'language': 'vi',
    });
  }

  static String _mockRewriteReview(String prompt) {
    final expected = _extractLineValue(prompt, 'EXPECTED');
    final actual = _extractLineValue(prompt, 'ACTUAL');
    final totalScore = _extractIntValue(prompt, 'TOTAL_SCORE');
    final contentScore = _extractIntValue(prompt, 'CONTENT_SCORE');
    final grammarScore = _extractIntValue(prompt, 'GRAMMAR_SCORE');
    final paraphraseScore = _extractIntValue(prompt, 'PARAPHRASE_SCORE');
    final missing = _extractLineValue(prompt, 'MISSING');
    final kept = _extractLineValue(prompt, 'KEPT');

    final topics = <String>['Rewrite', 'Output'];
    final actions = <String>[];

    String summary;
    if (totalScore >= 85) {
      summary = 'Bài viết lại giữ ý khá tốt và đã có dấu hiệu diễn đạt theo cách riêng.';
      actions.add('Thử rút ngắn thêm một chút để câu gọn hơn mà vẫn đủ ý.');
      topics.add('Strong Reformulation');
    } else if (contentScore < 45) {
      summary = 'Bài viết lại đang thiếu khá nhiều ý chính so với câu gốc.';
      actions.add('Giữ lại 3 từ khóa cốt lõi rồi viết lại chỉ quanh các từ khóa đó.');
      topics.add('Missing Core Idea');
    } else if (paraphraseScore < 40) {
      summary = 'Bạn đang bám quá sát câu gốc, chưa thật sự viết lại bằng câu khác.';
      actions.add('Đổi phần mở đầu hoặc trật tự cụm từ trước khi nộp lại.');
      topics.add('Too Close');
    } else if (grammarScore < 45) {
      summary = 'Ý có mặt nhưng câu viết lại chưa đủ trọn vẹn và tự nhiên.';
      actions.add('Viết thành câu dài hơn 4 từ, có một động từ chính rõ ràng.');
      topics.add('Sentence Shape');
    } else {
      summary = 'Bài viết lại ở mức khá, có thể tiếp tục tinh chỉnh độ tự nhiên và độ gọn.';
      actions.add('Làm lại thêm 1 vòng, ưu tiên thay từ/cụm thay vì chép khung cũ.');
      topics.add('Emerging Paraphrase');
    }

    if (missing.isNotEmpty && missing != 'none') {
      actions.add('Bổ sung lại các ý/từ khóa còn thiếu: $missing.');
      topics.add('Missing Keywords');
    }
    if (kept.isNotEmpty && kept != 'none') {
      actions.add('Bạn đã giữ được các từ khóa: $kept. Hãy giữ chúng nhưng đổi khung câu hơn nữa.');
      topics.add('Keyword Retention');
    }

    final grammar = _mockGrammarFromSentence(actual.isNotEmpty ? actual : expected);

    return jsonEncode({
      'summary': summary,
      'topics': topics.take(4).toList(),
      'analysisType': 'sentenceParse',
      'technical_terms': <Map<String, dynamic>>[],
      'action_items': actions.take(4).toList(),
      'grammar': grammar,
      'language': 'vi',
    });
  }

  static String _mockSummaryReview(String prompt) {
    final expected = _extractLineValue(prompt, 'EXPECTED');
    final actual = _extractLineValue(prompt, 'ACTUAL');
    final totalScore = _extractIntValue(prompt, 'TOTAL_SCORE');
    final contentScore = _extractIntValue(prompt, 'CONTENT_SCORE');
    final brevityScore = _extractIntValue(prompt, 'BREVITY_SCORE');
    final grammarScore = _extractIntValue(prompt, 'GRAMMAR_SCORE');
    final missed = _extractLineValue(prompt, 'MISSED');
    final kept = _extractLineValue(prompt, 'KEPT');
    final compression = _extractLineValue(prompt, 'COMPRESSION');

    final topics = <String>['Summary', 'Compression'];
    final actions = <String>[];

    String summary;
    if (totalScore >= 85) {
      summary = 'Bản tóm tắt khá gọn và vẫn giữ được ý chính của câu gốc.';
      actions.add('Thử rút xuống còn gọn hơn một chút nhưng vẫn giữ 2 từ khóa quan trọng nhất.');
      topics.add('Concise & Accurate');
    } else if (contentScore < 45) {
      summary = 'Bản tóm tắt đang mất nhiều ý cốt lõi.';
      actions.add('Giữ lại 2–3 từ khóa trọng tâm rồi viết lại một câu ngắn quanh các từ đó.');
      topics.add('Lost Core Meaning');
    } else if (brevityScore < 45) {
      summary = 'Bạn giữ ý khá tốt nhưng chưa tóm gọn đủ, vẫn còn quá dài.';
      actions.add('Lược bỏ cụm phụ, trạng từ hoặc giải thích phụ để câu sắc hơn.');
      topics.add('Too Long');
    } else if (grammarScore < 45) {
      summary = 'Bản tóm tắt khá ngắn nhưng hình dáng câu chưa đủ rõ và tự nhiên.';
      actions.add('Viết thành một câu hoàn chỉnh có động từ chính và kết thúc bằng dấu câu.');
      topics.add('Sentence Shape');
    } else {
      summary = 'Bản tóm tắt ở mức ổn, cần tinh chỉnh thêm để vừa ngắn vừa bén ý hơn.';
      actions.add('Soát lại xem có thể bỏ thêm từ nào mà không làm mất ý chính không.');
      topics.add('Refine Compression');
    }

    if (missed.isNotEmpty && missed != 'none') {
      actions.add('Bổ sung hoặc giữ lại các ý/từ khóa còn thiếu: $missed.');
      topics.add('Missing Keywords');
    }
    if (kept.isNotEmpty && kept != 'none') {
      actions.add('Bạn đã giữ được các từ khóa: $kept. Hãy dùng chúng làm trục khi rút gọn.');
      topics.add('Keyword Retention');
    }
    if (compression.isNotEmpty) {
      actions.add('Tỉ lệ hiện tại: $compression. Cân bằng giữa độ ngắn và độ đủ ý.');
    }

    final grammar = _mockGrammarFromSentence(actual.isNotEmpty ? actual : expected);

    return jsonEncode({
      'summary': summary,
      'topics': topics.take(4).toList(),
      'analysisType': 'sentenceParse',
      'technical_terms': <Map<String, dynamic>>[],
      'action_items': actions.take(4).toList(),
      'grammar': grammar,
      'language': 'vi',
    });
  }

  static String _extractLineValue(String prompt, String key) {
    final prefix = '$key:';
    for (final line in prompt.split('\n')) {
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length).trim();
      }
    }
    return '';
  }

  static int _extractIntValue(String prompt, String key) {
    final raw = _extractLineValue(prompt, key);
    return int.tryParse(raw) ?? 0;
  }

  static Map<String, dynamic> _mockGrammarFromSentence(String sentence) {
    final words = sentence
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final subject = words.isNotEmpty ? words.first : '—';
    final verb = words.length > 1 ? words[1] : '—';
    final object = words.length > 2 ? words.skip(2).take(2).join(' ') : '—';

    return {
      'subject': subject,
      'verb': verb,
      'object': object,
      'complement': '',
      'adverbial': '',
      'pattern': words.length >= 3 ? 'S + V + ...' : 'Chunk Recall',
      'explanation_vi': 'Đây là phân tích ngắn theo kiểu beta để hỗ trợ người học nhìn lại cấu trúc câu khi luyện viết.',
    };
  }

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
