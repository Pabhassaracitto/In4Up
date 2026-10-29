// lib/features/translation/engines/translation_engine.dart

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
  });

  factory TranslationResult.success({
    required String original,
    required String translated,
    required String engine,
    String? detectedLang,
    String? targetLang,
    Duration responseTime = Duration.zero,
  }) {
    return TranslationResult(
      originalText: original,
      translatedText: translated,
      isSuccess: true,
      engineName: engine,
      detectedLang: detectedLang,
      targetLang: targetLang,
      responseTime: responseTime,
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
