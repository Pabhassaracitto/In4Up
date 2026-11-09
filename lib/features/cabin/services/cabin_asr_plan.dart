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

/// Ngôn ngữ nguồn có model offline trong app không (VI/EN + Parakeet).
bool cabinSupportsOfflineLanguage(String language) =>
    AsrModelRouter.supportsLanguage(language);

/// Ngôn ngữ hiển thị mặc định ở dropdown Cabin — các ngôn ngữ app có UI dịch
/// và/hoặc engine hệ thống hỗ trợ (giữ nguyên thứ tự cũ để user cũ không bị
/// xáo danh sách).
const Map<String, String> kCabinBaseLanguages = {
  'en': 'English',
  'vi': 'Tiếng Việt',
  'zh': '中文 (Chinese)',
  'fr': 'Français (French)',
  'de': 'Deutsch (German)',
  'ja': '日本語 (Japanese)',
  'ko': '한국어 (Korean)',
  'th': 'ไทย (Thai)',
  'hi': 'हिन्दी (Hindi)',
  'si': 'සිංහල (Sinhala)',
  'my': 'မြန်မာ (Burmese)',
  'pi': 'Pāli',
};

/// Danh sách ngôn ngữ cho dropdown nguồn/đích của Cabin.
///
/// PARAKEET-002: bản cũ hardcode 12 ngôn ngữ nên **22 trong 25 ngôn ngữ của
/// Parakeet không chọn được** (es/it/pt/nl/pl/ru/uk/sv/…): import model xong
/// cabin vẫn không có cách nào dùng. Giờ = danh sách nền + mọi ngôn ngữ có
/// profile offline (`AsrModelRouter.supportedLanguages`), thêm vào cuối theo
/// thứ tự chữ cái để vị trí các ngôn ngữ cũ không đổi.
Map<String, String> cabinLanguageOptions() {
  final options = Map<String, String>.from(kCabinBaseLanguages);
  final extra = <String>[
    for (final language in AsrModelRouter.supportedLanguages)
      if (!options.containsKey(language)) language,
  ]..sort();
  for (final language in extra) {
    options[language] = AsrModelRouter.languageDisplayName(language);
  }
  return options;
}
