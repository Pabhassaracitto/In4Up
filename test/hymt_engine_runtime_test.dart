import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/engines/hymt_engine.dart';
import 'package:in4up/features/translation/engines/hymt_prompts.dart';

/// Backend giả cho Hy-MT — kiểm tra logic single-flight/retry/chunk/timeout
/// của engine MÀ không cần isolate, native lib hay model 600MB (HYMT-002).
class _FakeHyMtBackend implements HyMtBackend {
  _FakeHyMtBackend({this.delay = Duration.zero});

  /// Hàm sinh output; null = trả 'OUT:<số-lần-gọi>'.
  Future<String> Function(String prompt)? generateFn;
  final Duration delay;

  bool alive = true;
  bool loaded = true;
  bool restartShouldFail = false;
  String? loadError;

  /// Simulate native HUNG: trả future không bao giờ complete
  /// (KHÔNG dùng Timer — tránh "timer still active" khi test kết thúc).
  bool hang = false;

  int pingCalls = 0;
  int generateCalls = 0;
  int restartCalls = 0;
  int disposeCalls = 0;
  int _concurrency = 0;
  int maxConcurrency = 0;

  @override
  bool get isAlive => alive && loaded;

  @override
  String? get lastLoadError => loadError;

  @override
  Future<bool> ping() async {
    pingCalls++;
    return isAlive;
  }

  @override
  Future<String> generate(String prompt) async {
    generateCalls++;
    _concurrency++;
    maxConcurrency = math.max(maxConcurrency, _concurrency);
    try {
      if (!isAlive) {
        throw const HyMtRuntimeFailure(
          HyMtErrorCode.isolateDead,
          'Isolate Hy-MT không còn sống (simulated)',
        );
      }
      if (hang) return Completer<String>().future; // never completes
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final fn = generateFn;
      return fn == null ? 'OUT:$generateCalls' : await fn(prompt);
    } finally {
      _concurrency--;
    }
  }

  @override
  Future<bool> restart() async {
    restartCalls++;
    if (restartShouldFail) {
      loadError = 'llama_model_load_from_file thất bại: (simulated)';
      alive = false;
      loaded = false;
      return false;
    }
    loadError = null;
    alive = true;
    loaded = true;
    return true;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    alive = false;
    loaded = false;
  }
}

void main() {
  group('HyMtEngine — single-flight (HYMT-002 mục 1)', () {
    test('short text: ONE request, no chunking', () async {
      final backend = _FakeHyMtBackend();
      final engine = HyMtEngine.forTest(backend: backend);
      final result = await engine.translate(
        text: 'Xin chào thế giới.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isTrue);
      expect(backend.generateCalls, 1);
      expect(backend.maxConcurrency, 1);
    });

    test('two concurrent requests serialize; both finish; no deadlock',
        () async {
      final backend = _FakeHyMtBackend(delay: const Duration(milliseconds: 20));
      final engine = HyMtEngine.forTest(backend: backend);
      final a = engine.translate(
        text: 'First sentence here.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      final b = engine.translate(
        text: 'Second sentence here.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      final results = await Future.wait([a, b]).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw StateError('kẹt — request không hoàn tất'),
      );
      expect(results.every((r) => r.isSuccess), isTrue);
      expect(backend.maxConcurrency, 1); // chưa bao giờ 2 request cùng lúc
      expect(backend.generateCalls, 2);
    });

    test('second request waits for the first (queue) then runs', () async {
      final backend = _FakeHyMtBackend(delay: const Duration(milliseconds: 40));
      final engine = HyMtEngine.forTest(backend: backend);
      final order = <String>[];
      final a = engine
          .translate(
            text: 'First one runs first.',
            targetLang: 'VI',
            sourceLang: 'EN',
          )
          .then((_) => order.add('A'));
      final b = engine
          .translate(
            text: 'Second one waits for it.',
            targetLang: 'VI',
            sourceLang: 'EN',
          )
          .then((_) => order.add('B'));
      await Future.wait([a, b]).timeout(const Duration(seconds: 10));
      expect(order, <String>['A', 'B']);
    });

    test('busy after queue wait: structured error, no 2-minute hang',
        () async {
      final backend =
          _FakeHyMtBackend(delay: const Duration(milliseconds: 300));
      final engine = HyMtEngine.forTest(
        backend: backend,
        queueWait: const Duration(milliseconds: 80),
      );
      final first = engine.translate(
        text: 'A request that takes a while.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final sw = Stopwatch()..start();
      final second = await engine.translate(
        text: 'Another one right after.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      sw.stop();
      expect(second.isSuccess, isFalse);
      expect(second.errorCode, 'busy');
      expect(second.error, contains('đang bận'));
      expect(sw.elapsedMilliseconds, lessThan(2000)); // không treo 2 phút
      final firstResult = await first;
      expect(firstResult.isSuccess, isTrue); // request đầu không bị ảnh hưởng
    });
  });

  group('HyMtEngine — health + restart + 1 retry (HYMT-002 mục 2)', () {
    test('isolate dies mid-request: restart + retry 1 lần → success',
        () async {
      final backend = _FakeHyMtBackend();
      var calls = 0;
      backend.generateFn = (prompt) async {
        calls++;
        if (calls == 1) {
          backend.alive = false; // isolate chết trong lúc generate
          throw const HyMtRuntimeFailure(
            HyMtErrorCode.isolateDead,
            'Isolate chết (simulated)',
          );
        }
        return 'Recovered output';
      };
      final engine = HyMtEngine.forTest(backend: backend);
      final result = await engine.translate(
        text: 'Hello world.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isTrue);
      expect(result.translatedText, 'Recovered output');
      expect(backend.restartCalls, 1);
      expect(calls, 2); // 1 thử + 1 retry
    });

    test('death persists after restart: at most 1 retry, clear final error',
        () async {
      final backend = _FakeHyMtBackend()..alive = false; // chết ngay từ đầu
      var attempts = 0;
      backend.generateFn = (prompt) async {
        attempts++;
        throw const HyMtRuntimeFailure(
          HyMtErrorCode.isolateDead,
          'Still dead',
        );
      };
      final engine = HyMtEngine.forTest(backend: backend);
      final result = await engine.translate(
        text: 'Hello world.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'isolate_dead');
      expect(attempts, 2); // initial + MỘT retry — không loop vô hạn
      expect(result.error, contains('segment 1/1'));
      expect(result.error, contains('Still dead'));
    });

    test('load fails at health check: clear load error, no request sent',
        () async {
      final backend = _FakeHyMtBackend()
        ..loaded = false
        ..restartShouldFail = true;
      final engine = HyMtEngine.forTest(backend: backend);
      final result = await engine.translate(
        text: 'Hello world.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'load_failed');
      expect(result.error, contains('(simulated)'));
      expect(backend.generateCalls, 0); // không gửi request khi load hỏng
    });
  });

  group('HyMtEngine — chunking + per-chunk timeout (HYMT-002 mục 3)', () {
    test('2000+ chars: all chunks returned in exact order, nothing lost',
        () async {
      final backend = _FakeHyMtBackend();
      final prompts = <String>[];
      backend.generateFn = (prompt) async {
        prompts.add(prompt);
        return 'OUT:${prompts.length}';
      };
      final engine = HyMtEngine.forTest(backend: backend);
      final text = 'The quick brown fox jumps over the lazy dog. ' * 45;
      expect(text.length, greaterThanOrEqualTo(2000));
      final result = await engine.translate(
        text: text,
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isTrue);
      expect(prompts.length, greaterThan(1));

      // Prompt = template + chunk; join các chunk phải = text gốc (không
      // lặp/mất đoạn).
      final template = HyMtPrompts.build(
        text: '',
        sourceLang: 'EN',
        targetLang: 'VI',
      );
      final chunks = prompts
          .map((p) => p.substring(template.length))
          .toList();
      expect(chunks.join(''), text);

      // Output ghép đúng thứ tự.
      final parts = result.translatedText.split(' ');
      expect(parts.length, prompts.length);
      for (var i = 0; i < prompts.length; i++) {
        expect(parts[i], 'OUT:${i + 1}');
      }
      expect(result.responseTime, isNot(Duration.zero));
    });

    test('chunk error is NOT swallowed: final error names the segment',
        () async {
      final backend = _FakeHyMtBackend();
      var calls = 0;
      backend.generateFn = (prompt) async {
        calls++;
        if (calls >= 2) {
          throw const HyMtRuntimeFailure(
            HyMtErrorCode.requestFailed,
            'Native generate error (simulated)',
          );
        }
        return 'Out $calls';
      };
      final engine = HyMtEngine.forTest(backend: backend);
      final text =
          'First sentence here. Second sentence here too. Third ends it. ' * 20;
      expect(text.length, greaterThan(1000)); // ≥3 chunks
      final result = await engine.translate(
        text: text,
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'request_failed');
      expect(result.error, contains('segment 2/'));
      expect(result.error, contains('Native generate error (simulated)'));
    });

    test('empty output is an error, not silently dropped', () async {
      final backend = _FakeHyMtBackend();
      backend.generateFn = (prompt) async => '';
      final engine = HyMtEngine.forTest(backend: backend);
      final result = await engine.translate(
        text: 'Hello world.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'empty_output');
      expect(backend.generateCalls, 2); // 1 thử + 1 retry
    });

    test('hung chunk: per-chunk timeout → restart + 1 retry → clear error',
        () async {
      final backend = _FakeHyMtBackend()..hang = true;
      final engine = HyMtEngine.forTest(
        backend: backend,
        chunkTimeout: const Duration(milliseconds: 80),
      );
      final sw = Stopwatch()..start();
      final result = await engine.translate(
        text: 'Hello world.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      sw.stop();
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'request_timeout');
      expect(backend.restartCalls, 1);
      expect(backend.generateCalls, 2);
      // Hữu hạn: không treo theo timeout cũ (2 phút) — vài trăm ms.
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('text over hard limit: too_long error, no requests sent', () async {
      final backend = _FakeHyMtBackend();
      final engine = HyMtEngine.forTest(backend: backend, maxChunks: 2);
      final result = await engine.translate(
        text: 'Sentence one here. ' * 100, // ~2000 chars → 4 chunks
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'too_long');
      expect(backend.generateCalls, 0);
    });
  });

  group('HyMtEngine — validation', () {
    test('unsupported language pair fails fast with structured code',
        () async {
      final backend = _FakeHyMtBackend();
      final engine = HyMtEngine.forTest(backend: backend);
      final result = await engine.translate(
        text: 'Hello',
        targetLang: 'SI', // Sinhala — không hỗ trợ
        sourceLang: 'EN',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 'unsupported');
      expect(backend.generateCalls, 0);
    });

    test('slot is released after success AND after failure', () async {
      final backend = _FakeHyMtBackend()..hang = true;
      final engine = HyMtEngine.forTest(
        backend: backend,
        chunkTimeout: const Duration(milliseconds: 30),
      );
      final failed = await engine.translate(
        text: 'First one will fail.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(failed.isSuccess, isFalse);
      // Slot không được kẹt: request kế tiếp phải chạy (chứ không busy).
      backend.hang = false;
      backend.generateFn = (prompt) async => 'After failure';
      final after = await engine.translate(
        text: 'Second one must run.',
        targetLang: 'VI',
        sourceLang: 'EN',
      );
      expect(after.isSuccess, isTrue);
      expect(after.translatedText, 'After failure');
    });
  });
}
