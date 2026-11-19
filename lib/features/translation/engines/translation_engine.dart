// lib/features/translation/engines/translation_engine.dart

/// Request-scoped provenance. Never read a singleton's "last engine" to explain
/// a result: another document / screen-translation request may have finished.
class TranslationRoute {
  final String selectedEngineId;
  final String selectedEngineName;
  final String? actualEngineId;
  final List<String> attemptedEngineIds;

  TranslationRoute({
    required this.selectedEngineId,
    required this.selectedEngineName,
    required this.actualEngineId,
    required Iterable<String> attemptedEngineIds,
  }) : attemptedEngineIds = List.unmodifiable(attemptedEngineIds);

  bool get usedFallback =>
      actualEngineId != null && actualEngineId != selectedEngineId;
}

/// Kết quả dịch từ bất kỳ engine nào
class TranslationResult {
  final String originalText;
  final String translatedText;
  final bool isSuccess;
  final String? error;

  /// Mã lỗi cấu trúc (vd Hy-MT: `busy`, `isolate_dead`, `request_timeout`…
  /// — xem `HyMtErrorCode`). `null` khi success.
  final String? errorCode;
  final String? detectedLang;
  final String? targetLang;
  final String engineName;
  final Duration responseTime;
  final TranslationRoute? route;

  /// Translation code (vd 'DE') của ngôn ngữ cần model offline mà CHƯA TẢI.
  ///
  /// XLAT-MLKIT-001: hiện chỉ ML Kit set khi thiếu model. Caller có context
  /// (explicit source hay auto-detect) dựa vào đây để phân biệt lỗi "thiếu
  /// model của nguồn tự nhận diện" với lỗi engine thường — thay vì regex
  /// chuỗi error.
  final List<String>? missingModelCodes;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.isSuccess,
    required this.engineName,
    this.error,
    this.errorCode,
    this.detectedLang,
    this.targetLang,
    this.responseTime = Duration.zero,
    this.missingModelCodes,
    this.route,
  });

  factory TranslationResult.success({
    required String original,
    required String translated,
    required String engine,
    String? detectedLang,
    String? targetLang,
    Duration responseTime = Duration.zero,
    TranslationRoute? route,
  }) {
    return TranslationResult(
      originalText: original,
      translatedText: translated,
      isSuccess: true,
      engineName: engine,
      detectedLang: detectedLang,
      targetLang: targetLang,
      responseTime: responseTime,
      route: route,
    );
  }

  factory TranslationResult.failure({
    required String original,
    required String error,
    required String engine,
    String? errorCode,
    String? detectedLang,
    String? targetLang,
    List<String>? missingModelCodes,
  }) {
    return TranslationResult(
      originalText: original,
      translatedText: '',
      isSuccess: false,
      error: error,
      errorCode: errorCode,
      engineName: engine,
      detectedLang: detectedLang,
      targetLang: targetLang,
      missingModelCodes: missingModelCodes,
    );
  }

  TranslationResult withLanguages({
    required String source,
    required String target,
  }) =>
      TranslationResult(
        originalText: originalText,
        translatedText: translatedText,
        isSuccess: isSuccess,
        engineName: engineName,
        error: error,
        errorCode: errorCode,
        detectedLang: detectedLang ?? source,
        targetLang: target,
        responseTime: responseTime,
        missingModelCodes: missingModelCodes,
        route: route,
      );

  TranslationResult withRoute(TranslationRoute value) => TranslationResult(
        originalText: originalText,
        translatedText: translatedText,
        isSuccess: isSuccess,
        engineName: engineName,
        error: error,
        errorCode: errorCode,
        detectedLang: detectedLang,
        targetLang: targetLang,
        responseTime: responseTime,
        missingModelCodes: missingModelCodes,
        route: value,
      );
}

/// Interface cho mọi translation engine
abstract class TranslationEngine {
  /// Tên hiển thị
  String get name;

  /// ID ngắn gọn
  String get id;

  /// Engine có sẵn sàng không?
  Future<bool> isAvailable();

  /// Dịch text
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  });

  /// Giới hạn ký tự mỗi request
  int get maxCharsPerRequest => 5000;

  /// Delay giữa các request (tránh rate limit)
  Duration get requestDelay => const Duration(milliseconds: 100);
}
