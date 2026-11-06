// PLAN-043 mục 3 Tầng 1 — sinh từ vựng hàng loạt bằng AI NGAY TRONG APP.
//
// Nguồn AI = tầng Server API sẵn có (ADR-0008): `AiProviderStore` năng lực
// `chat` + `OpenAiCompatClient` — ĐÚNG khuôn `LlmMtEngine`, không tạo
// đường API/client thứ hai, không hard-code key. Chưa cấu hình provider
// thì ném mã cấu trúc để UI báo đúng nguyên nhân + chỉ đường vào màn
// Server & API; app hành xử như chưa có tính năng (không gọi mù).
//
// Service trả output THÔ theo từng prompt; việc làm sạch/g ghép CSV do
// `WordTableParser.mergeCsvOutputs` ở sheet lo (tránh vòng import), và kết
// quả luôn qua màn xem trước dùng chung — không chen thẳng vào kho từ.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:in4up_ai/in4up_ai.dart';

import 'vocab_bulk_ai.dart';

/// Mã lỗi cấu trúc — UI phân nhánh theo mã, không match chuỗi.
enum VocabBulkAiErrorCode {
  /// Chưa cấu hình/bật provider Server API nào cho năng lực chat.
  noProvider,

  /// Provider chưa chọn model chat.
  noModel,

  /// Không có prompt nào để gửi (đầu vào rỗng).
  emptyInput,

  /// AI trả về rỗng ở mọi lô.
  emptyOutput,

  /// Request lỗi (mạng/timeout/HTTP…) — [VocabBulkAiException.detail]
  /// giữ mã lỗi gốc của tầng API để log.
  requestFailed,
}

class VocabBulkAiException implements Exception {
  final VocabBulkAiErrorCode code;
  final String? detail;
  const VocabBulkAiException(this.code, [this.detail]);

  @override
  String toString() =>
      'VocabBulkAiException(${code.name}${detail == null ? '' : ': $detail'})';
}

class VocabBulkAiService {
  VocabBulkAiService._();
  static final VocabBulkAiService instance = VocabBulkAiService._();

  /// Trần token cho một lô: 20 từ × (nghĩa + 2 ví dụ) cần rộng rãi nhưng
  /// hữu hạn — output bị cắt giữa chừng thì parser tự bỏ dòng dở.
  static const int _kMaxTokens = 4096;
  static const Duration _kTimeout = Duration(seconds: 120);

  /// Provider chat đang dùng được (đã bật + có model), hoặc ném mã lỗi.
  /// UI gọi trước để hiện đúng trạng thái ("đang dùng AI nào").
  Future<AiProviderConfig> resolveChatProvider() async {
    final store = AiProviderStore.instance;
    await store.ensureLoaded();
    final provider = store.resolveProvider(AiRouteCapability.chat);
    if (provider == null) {
      throw const VocabBulkAiException(VocabBulkAiErrorCode.noProvider);
    }
    final model = provider.chatModel;
    if (model == null || model.trim().isEmpty) {
      throw const VocabBulkAiException(VocabBulkAiErrorCode.noModel);
    }
    return provider;
  }

  /// Gửi lần lượt [prompts] (tuần tự — không dồn dập nhà cung cấp, và thứ
  /// tự lô giữ nguyên khi ghép). [onProgress] báo (đã xong, tổng số lô).
  /// Trả output thô theo từng lô theo đúng thứ tự.
  Future<List<String>> generateRawOutputs(
    List<String> prompts, {
    void Function(int done, int total)? onProgress,
  }) async {
    final clean =
        prompts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (clean.isEmpty) {
      throw const VocabBulkAiException(VocabBulkAiErrorCode.emptyInput);
    }
    final provider = await resolveChatProvider();
    final model = provider.chatModel!.trim();
    final client = OpenAiCompatClient(
      baseUrl: provider.baseUrl,
      apiKey: provider.apiKey,
    );

    final outputs = <String>[];
    for (var i = 0; i < clean.length; i++) {
      String out;
      try {
        out = await client.chatCompletion(
          model: model,
          messages: [
            const OpenAiChatMessage('system', kVocabBulkAiSystemPrompt),
            OpenAiChatMessage('user', clean[i]),
          ],
          temperature: 0.3,
          maxTokens: _kMaxTokens,
          timeout: _kTimeout,
        );
      } on AiApiException catch (e) {
        debugPrint('[VocabBulkAi] lô ${i + 1}/${clean.length} lỗi: '
            '${e.code.name} (${provider.label}/$model)');
        throw VocabBulkAiException(
            VocabBulkAiErrorCode.requestFailed, e.code.name);
      } catch (e) {
        debugPrint('[VocabBulkAi] lô ${i + 1}/${clean.length} lỗi lạ: $e');
        throw VocabBulkAiException(
            VocabBulkAiErrorCode.requestFailed, e.toString());
      }
      outputs.add(out);
      onProgress?.call(i + 1, clean.length);
    }

    if (outputs.every((o) => o.trim().isEmpty)) {
      throw const VocabBulkAiException(VocabBulkAiErrorCode.emptyOutput);
    }
    return outputs;
  }
}
