import 'package:in4up_ai/in4up_ai.dart';

/// Pure UI policy: the optional refinement action is available only when
/// there is text worth sending to the configured AI provider.
class OcrAiRefinePolicy {
  const OcrAiRefinePolicy._();

  static bool shouldOffer(String text) => text.trim().isNotEmpty;
}

enum OcrAiRefineError { emptyInput, noProvider, noModel, emptyOutput, requestFailed }

class OcrAiRefineException implements Exception {
  final OcrAiRefineError code;
  final String? detail;

  const OcrAiRefineException(this.code, [this.detail]);

  @override
  String toString() =>
      'OcrAiRefineException(${code.name}${detail == null ? '' : ': $detail'})';
}

/// Optional OCR post-processing through the already-configured chat provider.
/// No provider/model is downloaded or enabled implicitly.
class OcrAiRefineService {
  OcrAiRefineService._();

  static final OcrAiRefineService instance = OcrAiRefineService._();

  static const Duration _timeout = Duration(seconds: 120);
  static const String _systemPrompt =
      'You are a careful OCR proofreading assistant. Correct likely OCR '
      'recognition errors, spelling, punctuation, and obvious grammar while '
      'preserving the original language, meaning, names, numbers, paragraph '
      'structure, headings, and line breaks where practical. Do not summarize, '
      'translate, add facts, or rewrite stylistically. If uncertain, preserve '
      'the source text. Return only the corrected text, without commentary or '
      'quotation marks.';

  /// The caller supplies the exact current draft; the OCR result is never sent
  /// unless the user taps the refinement action.
  Future<String> refine(String text) async {
    final input = text.trim();
    if (input.isEmpty) {
      throw const OcrAiRefineException(OcrAiRefineError.emptyInput);
    }

    final store = AiProviderStore.instance;
    await store.ensureLoaded();
    final provider = store.resolveProvider(AiRouteCapability.chat);
    if (provider == null) {
      throw const OcrAiRefineException(OcrAiRefineError.noProvider);
    }
    final model = provider.chatModel?.trim();
    if (model == null || model.isEmpty) {
      throw const OcrAiRefineException(OcrAiRefineError.noModel);
    }

    try {
      final result = await OpenAiCompatClient(
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
      ).chatCompletion(
        model: model,
        messages: [
          const OpenAiChatMessage('system', _systemPrompt),
          OpenAiChatMessage('user', input),
        ],
        temperature: 0.2,
        maxTokens: 8192,
        timeout: _timeout,
      );
      final output = result.trim();
      if (output.isEmpty) {
        throw const OcrAiRefineException(OcrAiRefineError.emptyOutput);
      }
      return output;
    } on OcrAiRefineException {
      rethrow;
    } on AiApiException catch (error) {
      throw OcrAiRefineException(
        OcrAiRefineError.requestFailed,
        error.code.name,
      );
    } catch (error) {
      throw OcrAiRefineException(
        OcrAiRefineError.requestFailed,
        error.toString(),
      );
    }
  }
}
