// lib/features/cabin/services/cabin_asr_plan.dart
//
// Lập kế hoạch STT cho Cabin — LOGIC THUẦN (không mic/không I/O) nên test được.
//
// CABIN-ASR-002: cabin KHÔNG được mặc định cứng 'en' rồi báo thiếu model khi
// máy chỉ import VI, và KHÔNG được âm thầm nhận tiếng Anh bằng model tiếng
// Việt. Mọi quyết định “dùng model nào cho ngôn ngữ nào” đi qua đây.

import 'package:in4up_stt/asr_model_routing.dart';

/// Lựa chọn Engine STT cho Dịch Live Cabin.
enum CabinSttEngineType {
  /// Speech service hệ thống (không cần model trong app).
  system,

  /// Sherpa Zipformer offline (VI = OfflineRecognizer + VAD,
  /// EN = OnlineRecognizer streaming).
  sherpaOffline,
}

/// Kế hoạch chạy STT cabin cho 1 ngôn ngữ nguồn + engine đang chọn.
class CabinAsrPlan {
  final CabinSttEngineType engine;

  /// Ngôn ngữ user đang chọn (đã normalize).
  final String requestedLanguage;

  /// Kết quả phân giải model của engine sherpa.
  final AsrModelSelection selection;

  const CabinAsrPlan({
    required this.engine,
    required this.requestedLanguage,
    required this.selection,
  });

  bool get usesSherpa => engine == CabinSttEngineType.sherpaOffline;

  /// Có thể start phiên nghe với ngôn ngữ đang chọn.
  bool get canStart => !usesSherpa || selection.isReady;

  /// Vấn đề model (chỉ có nghĩa với engine sherpa).
  AsrModelIssue get issue =>
      usesSherpa ? selection.issue : AsrModelIssue.none;

  /// Model chưa cài + máy còn model ngôn ngữ khác → gợi ý fallback để user
  /// XÁC NHẬN (không tự đổi).
  String? get fallbackLanguage =>
      usesSherpa ? selection.fallbackLanguage : null;

  bool get hasModel => selection.isReady;

  SherpaAsrProfile? get profile => selection.profile;

  /// Live STT của profile này đi đường nào (online streaming vs VAD).
  AsrLiveRoute get liveRoute => selection.liveRoute;

  /// Profile này có dùng được cho file/LRC không (streaming thì không).
  bool get canTranscribeFiles => selection.isReady && (profile?.isOffline ?? false);

  @override
  String toString() => 'CabinAsrPlan(engine=$engine, '
      'lang=$requestedLanguage, canStart=$canStart, issue=$issue, '
      'fallback=$fallbackLanguage)';
}

/// Lập kế hoạch STT cabin.
///
/// [isInstalled] tra trạng thái cài đặt profile (truyền vào để hàm này thuần).
CabinAsrPlan planCabinAsr({
  required CabinSttEngineType engine,
  required String language,
  required bool Function(String profileId) isInstalled,
}) {
  return CabinAsrPlan(
    engine: engine,
    requestedLanguage: AsrModelRouter.normalizeLanguage(language),
    selection: AsrModelRouter.resolve(language, isInstalled: isInstalled),
  );
}

/// Ngôn ngữ nguồn mặc định khi user CHƯA chọn: ngôn ngữ đã cài model
/// (ưu tiên VI), chưa cài gì thì trả `vi` (mặc định của app — UI giải thích).
String defaultCabinSourceLanguage({
  required bool Function(String profileId) isInstalled,
}) =>
    AsrModelRouter.resolveDefaultLanguage(isInstalled: isInstalled);

/// Ngôn ngữ đích mặc định: VI nguồn → EN, còn lại → VI.
String defaultCabinTargetLanguageFor(String sourceLanguage) =>
    AsrModelRouter.normalizeLanguage(sourceLanguage) == 'vi' ? 'en' : 'vi';

/// Ngôn ngữ nguồn có model offline trong app không (VI/EN).
bool cabinSupportsOfflineLanguage(String language) =>
    AsrModelRouter.supportsLanguage(language);
