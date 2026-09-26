// test/ai_provider_wp0_test.dart — WP0 (API-001)
//
// Test logic thuần của tầng Server API (không network, không SharedPreferences):
// - OpenAiCompatClient.normalizeBaseUrl / isCleartextAllowed (guard bảo mật)
// - OpenAiModelsParser (body /v1/models chuẩn OpenAI + biến thể Gemini)
// - AiProviderConfig / AiRoutingPrefs JSON round-trip + routing mặc định

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

void main() {
  group('normalizeBaseUrl', () {
    test('thêm /v1 khi user nhập gốc (Ollama/LM Studio)', () {
      expect(
        OpenAiCompatClient.normalizeBaseUrl('http://192.168.1.10:11434'),
        'http://192.168.1.10:11434/v1',
      );
      expect(
        OpenAiCompatClient.normalizeBaseUrl('http://192.168.1.10:1234/'),
        'http://192.168.1.10:1234/v1',
      );
    });

    test('giữ nguyên URL đã có /v1 hoặc path riêng (Groq/Gemini)', () {
      expect(
        OpenAiCompatClient.normalizeBaseUrl('https://api.groq.com/openai/v1'),
        'https://api.groq.com/openai/v1',
      );
      expect(
        OpenAiCompatClient.normalizeBaseUrl(
            'https://generativelanguage.googleapis.com/v1beta/openai'),
        'https://generativelanguage.googleapis.com/v1beta/openai',
      );
    });

    test('chuẩn hoá khoảng trắng + trailing slash', () {
      expect(
        OpenAiCompatClient.normalizeBaseUrl('  https://api.openai.com/v1/ '),
        'https://api.openai.com/v1',
      );
    });
  });

  group('isCleartextAllowed — guard bảo mật', () {
    test('http chỉ cho LAN/localhost/IP riêng/đuôi nhà', () {
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://localhost:11434/v1/models')), isTrue);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://127.0.0.1:1234/v1/models')), isTrue);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://192.168.1.20:11434/v1/models')), isTrue);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://10.0.0.5:11434/v1/models')), isTrue);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://172.16.0.5:11434/v1/models')), isTrue);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://deskpc:11434/v1/models')), isTrue);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://mybox.local:11434/v1/models')), isTrue);
    });

    test('http công cộng BỊ CHẶN — key không đi qua cleartext', () {
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://api.groq.com/openai/v1/models')), isFalse);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://example.com/v1/models')), isFalse);
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('http://8.8.8.8/v1/models')), isFalse);
    });

    test('https luôn cho phép', () {
      expect(OpenAiCompatClient.isCleartextAllowed(
          Uri.parse('https://api.openai.com/v1/models')), isTrue);
    });
  });

  group('OpenAiModelsParser', () {
    test('body chuẩn OpenAI: data[].id, sắp xếp, bỏ rỗng', () {
      const body =
          '{"object":"list","data":[{"id":"llama3.1:8b"},{"id":"gemma2:2b"},'
          '{"id":""},{"object":"model","id":"qwen2.5:7b"}]}';
      expect(OpenAiCompatClient.parseModelsBody(body),
          ['gemma2:2b', 'llama3.1:8b', 'qwen2.5:7b']);
    });

    test('biến thể khoá models (Gemini compat)', () {
      const body = '{"models":[{"id":"gemini-2.0-flash"}]}';
      expect(OpenAiCompatClient.parseModelsBody(body), ['gemini-2.0-flash']);
    });

    test('body sai format → AiApiException invalidResponse', () {
      expect(
        () => OpenAiCompatClient.parseModelsBody('{"foo": 1}'),
        throwsA(isA<AiApiException>()),
      );
      expect(
        () => OpenAiCompatClient.parseModelsBody('[1,2]'),
        throwsA(isA<AiApiException>()),
      );
    });
  });

  group('AiProviderConfig JSON round-trip', () {
    test('giữ nguyên trường + không lộ apiKey rỗng', () {
      const config = AiProviderConfig(
        id: 'p1',
        label: 'Ollama nhà',
        baseUrl: 'http://192.168.1.10:11434/v1',
        chatModel: 'llama3.1:8b',
        sttModel: null,
        ttsModel: 'kokoro',
      );
      final decoded =
          AiProviderConfig.fromJson(config.toJson());
      expect(decoded.id, 'p1');
      expect(decoded.label, 'Ollama nhà');
      expect(decoded.baseUrl, 'http://192.168.1.10:11434/v1');
      expect(decoded.chatModel, 'llama3.1:8b');
      expect(decoded.sttModel, isNull);
      expect(decoded.ttsModel, 'kokoro');
      expect(decoded.enabled, isTrue);
      expect(config.supports(AiRouteCapability.chat), isTrue);
      expect(config.supports(AiRouteCapability.sttFile), isFalse);
      expect(config.supports(AiRouteCapability.translation), isTrue);
      expect(config.supports(AiRouteCapability.tts), isTrue);
    });

    test('encode/decode list provider', () {
      const a = AiProviderConfig(
          id: 'a', label: 'A', baseUrl: 'https://a.example/v1');
      const b = AiProviderConfig(
          id: 'b', label: 'B', baseUrl: 'http://10.0.0.2:11434/v1');
      final decoded = decodeProviders(encodeProviders([a, b]));
      expect(decoded.length, 2);
      expect(decoded[1].baseUrl, 'http://10.0.0.2:11434/v1');
      expect(decodeProviders(null), isEmpty);
      expect(decodeProviders('not json'), isEmpty);
    });
  });

  group('AiRoutingPrefs JSON round-trip + mặc định offline-first', () {
    test('mặc định: mọi năng lực offlineFirst, không preferred provider', () {
      const prefs = AiRoutingPrefs();
      for (final cap in AiRouteCapability.values) {
        expect(prefs.modeOf(cap), AiRouteMode.offlineFirst);
        expect(prefs.preferredProviderOf(cap), isNull);
      }
      final decoded = AiRoutingPrefs.fromJson(prefs.toJson());
      for (final cap in AiRouteCapability.values) {
        expect(decoded.modeOf(cap), AiRouteMode.offlineFirst);
      }
    });

    test('round-trip đầy đủ mode + preferred', () {
      const prefs = AiRoutingPrefs(
        modes: {
          AiRouteCapability.chat: AiRouteMode.onlineFirst,
          AiRouteCapability.sttFile: AiRouteMode.offlineFirst,
          AiRouteCapability.translation: AiRouteMode.offlineOnly,
        },
        preferredProviderIds: {
          AiRouteCapability.chat: 'groq-home',
          AiRouteCapability.tts: 'ollama-pc',
        },
      );
      final decoded = AiRoutingPrefs.fromJson(prefs.toJson());
      expect(decoded.modeOf(AiRouteCapability.chat), AiRouteMode.onlineFirst);
      expect(decoded.modeOf(AiRouteCapability.sttFile), AiRouteMode.offlineFirst);
      expect(
          decoded.modeOf(AiRouteCapability.translation), AiRouteMode.offlineOnly);
      expect(decoded.modeOf(AiRouteCapability.tts), AiRouteMode.offlineFirst);
      expect(decoded.preferredProviderOf(AiRouteCapability.chat), 'groq-home');
      expect(decoded.preferredProviderOf(AiRouteCapability.tts), 'ollama-pc');
      expect(decoded.preferredProviderOf(AiRouteCapability.sttFile), isNull);
    });
  });
}
