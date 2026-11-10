// PSRC-181 (owner 2026-11-10) — *"Đặt openrouter/free làm model mặc định
// trong Server API Setting Home"*.
//
// Vì sao `openrouter/free`: đây là **Free Models Router** của OpenRouter —
// tự chọn một model free còn sống cho từng request, nên không "chết" khi
// một model `:free` cụ thể bị gỡ khỏi danh sách.
//
// Máy đã cài trước bản này lưu model mặc định CŨ
// (`minimax/minimax-m3.1-flash:free`) trong `SharedPreferences` ⇒ phải
// migrate, nhưng TUYỆT ĐỐI không ghi đè model user tự chọn.
//
// Test thuần + source-scan (không plugin, không mạng) nên chạy được trên CI.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

void main() {
  AiProviderConfig openRouterWith(String? model) => AiProviderConfig(
        id: kBuiltinOpenRouterId,
        label: kBuiltinOpenRouterLabel,
        baseUrl: kBuiltinOpenRouterBaseUrl,
        chatModel: model,
      );

  group('PSRC-181 — model mặc định của provider có sẵn', () {
    test('provider seed dùng đúng `openrouter/free`', () {
      final p = builtinOpenRouterProvider();
      expect(p.chatModel, 'openrouter/free');
      expect(kBuiltinOpenRouterChatModel, 'openrouter/free');
      // Vẫn phải phục vụ được chat/dịch (routing chọn provider theo model).
      expect(p.supports(AiRouteCapability.chat), isTrue);
      expect(p.modelFor(AiRouteCapability.translation), 'openrouter/free',
          reason: 'Chưa chọn model dịch riêng ⇒ dùng chat model, nên dịch '
              'cũng phải đi `openrouter/free`.');
      expect(p.enabled, isTrue);
    });

    test('mô hình cũ `minimax/…:free` được nâng lên `openrouter/free`', () {
      expect(kBuiltinOpenRouterLegacyChatModels,
          contains('minimax/minimax-m3.1-flash:free'));
      final migrated = migrateBuiltinProviderChatModel(
        openRouterWith('minimax/minimax-m3.1-flash:free'),
      );
      expect(migrated.chatModel, 'openrouter/free');
      expect(migrated.id, kBuiltinOpenRouterId,
          reason: 'Migrate chỉ đổi model, không đổi danh tính provider.');
    });

    test('KHÔNG ghi đè model user tự chọn / provider khác', () {
      // User tự gõ một model khác.
      final custom = migrateBuiltinProviderChatModel(
        openRouterWith('google/gemma-4-31b-it:free'),
      );
      expect(custom.chatModel, 'google/gemma-4-31b-it:free');
      // User bỏ trống model (chọn "None").
      final cleared = migrateBuiltinProviderChatModel(openRouterWith(null));
      expect(cleared.chatModel, isNull);
      // Provider không phải loại có sẵn.
      final other = migrateBuiltinProviderChatModel(
        AiProviderConfig(
          id: 'groq',
          label: 'Groq',
          baseUrl: 'https://api.groq.com/openai/v1',
          chatModel: 'minimax/minimax-m3.1-flash:free',
        ),
      );
      expect(other.chatModel, 'minimax/minimax-m3.1-flash:free');
      // Đã đúng mặc định ⇒ giữ nguyên.
      final already = migrateBuiltinProviderChatModel(
        openRouterWith('openrouter/free'),
      );
      expect(already.chatModel, 'openrouter/free');
    });

    test('store chạy migrate sau khi seed (máy đã cài vẫn đổi được)', () {
      final store =
          File('packages/in4up_ai/lib/src/provider/ai_provider_store.dart')
              .readAsStringSync();
      final loadIdx = store.indexOf('Future<void> ensureLoaded()');
      expect(loadIdx, greaterThan(0));
      final loadBody = store.substring(loadIdx);
      final seedIdx = loadBody.indexOf('_seedBuiltinProviders(prefs)');
      final migIdx = loadBody.indexOf('_migrateBuiltinProviderDefaults()');
      expect(seedIdx, greaterThan(0));
      expect(migIdx, greaterThan(seedIdx),
          reason: 'Migrate phải chạy SAU seed (seed mới thêm provider, '
              'migrate mới nâng model mặc định của provider đã có).');
      // Là thao tác của APP, không phải user ⇒ không bump mốc LWW.
      final migBody = store.substring(store.indexOf(
          'Future<void> _migrateBuiltinProviderDefaults()'));
      expect(migBody, contains('touch: false'));
      expect(migBody, contains('notifySync: false'));
    });

    test('package export hàm migrate (app dùng được, test pin được)', () {
      final pkg = File('packages/in4up_ai/lib/in4up_ai.dart').readAsStringSync();
      expect(pkg, contains('builtin_ai_providers.dart'));
    });
  });
}
