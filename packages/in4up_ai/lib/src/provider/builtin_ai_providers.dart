// packages/in4up_ai/lib/src/provider/builtin_ai_providers.dart
//
// Nhà cung cấp AI **CÓ SẴN** trong app (seed lần cài đặt đầu).
//
// Yêu cầu owner (2026-10-17): "Hãy bổ sung nhà cung cấp sẵn cho OpenRouter"
// với model `minimax/minimax-m3.1-flash:free`, ở trạng thái **bật**, và
// routing "Khi nào dùng model online" cho **Chat & Phân tích AI** ở chế độ
// **Ưu tiên online** với nhà cung cấp **OpenRouter**.
//
// ⚠️ VỀ API KEY — KHÔNG hard-code trong repo:
//   Lần đầu mình đặt key thật vào source ⇒ **GitHub chặn push** (secret
//   push protection) — đúng như thiết kế: key trong repo = ai có repo đều
//   dùng được, và nó nằm vĩnh viễn trong git history.
//
//   ⇒ Key đến từ **CI secret** `OPENROUTER_API_KEY` (owner tự thêm trong
//   Settings → Secrets) và được chèn lúc build bằng
//   `--dart-define=OPENROUTER_API_KEY=…` (workflow
//   `build_final_complete.yml` đã nối sẵn). Build cục bộ không có define
//   ⇒ provider vẫn được seed (base URL + model + routing) và user dán key
//   một lần trong Cài đặt → Sửa nhà cung cấp.
//
//   KHÔNG bao giờ log key (quy tắc tầng API) — dùng hằng số này.

import 'ai_provider_config.dart';

/// Id cố định của provider OpenRouter có sẵn (dùng làm khoá routing).
const String kBuiltinOpenRouterId = 'openrouter';

/// Base URL OpenRouter (OpenAI-compatible).
const String kBuiltinOpenRouterBaseUrl = 'https://openrouter.ai/api/v1';

/// API key OpenRouter — từ CI secret (`--dart-define`), KHÔNG nằm trong repo.
///
/// Owner thêm secret: repo → Settings → Secrets and variables → Actions →
/// New repository secret → `OPENROUTER_API_KEY` = key OpenRouter của bạn.
const String kBuiltinOpenRouterApiKey =
    String.fromEnvironment('OPENROUTER_API_KEY');

/// Có key trong build này không (dùng để báo trong UI khi user cần dán tay).
bool get hasBuiltinOpenRouterApiKey => kBuiltinOpenRouterApiKey.isNotEmpty;

/// Model chat mặc định của provider có sẵn.
const String kBuiltinOpenRouterChatModel = 'minimax/minimax-m3.1-flash:free';

/// Nhãn hiển thị.
const String kBuiltinOpenRouterLabel = 'OpenRouter';

/// Provider có sẵn (seed lần đầu app mở).
AiProviderConfig builtinOpenRouterProvider() => AiProviderConfig(
      id: kBuiltinOpenRouterId,
      label: kBuiltinOpenRouterLabel,
      baseUrl: kBuiltinOpenRouterBaseUrl,
      apiKey: kBuiltinOpenRouterApiKey.isEmpty ? null : kBuiltinOpenRouterApiKey,
      chatModel: kBuiltinOpenRouterChatModel,
      enabled: true,
    );

/// Danh sách provider có sẵn.
List<AiProviderConfig> builtinAiProviders() => [builtinOpenRouterProvider()];

/// Routing mặc định khi seed provider có sẵn:
/// "Khi nào dùng model online" (Chat & Phân tích AI) → **Ưu tiên online**,
/// nhà cung cấp ưu tiên = **OpenRouter**.
AiRoutingPrefs builtinAiRouting() => const AiRoutingPrefs(
      modes: {
        AiRouteCapability.chat: AiRouteMode.onlineFirst,
      },
      preferredProviderIds: {
        AiRouteCapability.chat: kBuiltinOpenRouterId,
      },
    );
