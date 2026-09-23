// packages/in4up_stt/lib/asr_model_routing.dart
//
// Chọn model Zipformer ASR + route engine live STT — LOGIC THUẦN (không I/O,
// không plugin) nên test được trên máy không có thiết bị.
//
// Ràng buộc (SHERPA-WP4-01 / CABIN-ASR-002 / SHERPA-STREAM-001):
// - App chỉ có 2 profile: **VI offline** (`OfflineRecognizer` + Silero VAD =
//   “simulated streaming”) và **EN streaming** (`OnlineRecognizer` =
//   token-by-token). KHÔNG bịa thêm profile ngôn ngữ nào khác: ngôn ngữ
//   không có profile phải được báo RÕ, không map mò về profile đầu tiên.
// - KHÔNG tự đổi ngôn ngữ nhận diện sau lưng user: chọn EN mà máy chỉ cài VI
//   thì DỪNG + báo thiếu model (kèm gợi ý fallback để user tự xác nhận),
//   tuyệt đối không nhận tiếng Anh bằng model tiếng Việt.
// - Model streaming KHÔNG BAO GIỜ đi vào `OfflineRecognizer` (SIGABRT
//   “Got N Expected 39”); model offline không đi vào `OnlineRecognizer`.

/// Ngôn ngữ mặc định của app (người Việt) — dùng khi máy chưa cài model nào.
const String kDefaultAsrLanguage = 'vi';

/// Thứ tự ưu tiên khi nhiều profile đã cài (VI trước — theo WP4).
const List<String> kAsrLanguagePriority = ['vi', 'en'];

/// Định nghĩa profile của model Zipformer ASR.
///
/// `isStreaming == true` ⇒ model chỉ chạy được với `OnlineRecognizer`
/// (live token-by-token). `false` ⇒ model offline, live phải đi đường
/// simulated streaming (OfflineRecognizer + Silero VAD).
class SherpaAsrProfile {
  final String id;
  final String name;
  final String language;
  final bool isStreaming;
  final int approxSizeMB;
  final String downloadUrl;
  final String archiveName;

  const SherpaAsrProfile({
    required this.id,
    required this.name,
    required this.language,
    required this.isStreaming,
    required this.approxSizeMB,
    required this.downloadUrl,
    required this.archiveName,
  });

  /// Model offline dùng được cho file/LRC (streaming thì KHÔNG — xem
  /// `SherpaModelManager.isStreamingEncoderOnnx`).
  bool get isOffline => !isStreaming;
}

/// Danh sách profile Zipformer ASR được hỗ trợ sẵn.
///
/// URL/size lấy từ danh sách đã verify với docs k2-fsa trong
/// `docs/Bangiao/bangiao_sherpa_wp4_live_stt.md` — không thêm URL mới.
const List<SherpaAsrProfile> kSherpaAsrProfiles = [
  SherpaAsrProfile(
    id: 'asr-vi-30M-int8',
    name: 'Tiếng Việt (Zipformer 30M int8)',
    language: 'vi',
    isStreaming: false,
    approxSizeMB: 32,
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'sherpa-onnx-zipformer-vi-30M-int8-2026-02-09.tar.bz2',
    archiveName: 'sherpa-onnx-zipformer-vi-30M-int8-2026-02-09.tar.bz2',
  ),
  SherpaAsrProfile(
    id: 'asr-en-20M-streaming-int8',
    name: 'English (Zipformer 20M int8 streaming)',
    language: 'en',
    isStreaming: true,
    approxSizeMB: 20,
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2',
    archiveName: 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2',
  ),
];

/// Lý do model chưa dùng được cho ngôn ngữ đang chọn.
enum AsrModelIssue {
  /// Model đã cài — dùng được.
  none,

  /// App KHÔNG có profile Zipformer cho ngôn ngữ này (vd zh/fr/ja) →
  /// phải nói rõ “chưa hỗ trợ offline”, gợi ý engine Hệ thống.
  noProfileForLanguage,

  /// Có profile nhưng model chưa nằm trên máy → Quản lý Model AI.
  profileNotInstalled,
}

/// Đường chạy live STT tương ứng với profile.
enum AsrLiveRoute {
  /// Model streaming → `OnlineRecognizer`, partial token-by-token.
  onlineStreaming,

  /// Model offline → `OfflineRecognizer` + Silero VAD (simulated streaming,
  /// partial theo chunk).
  simulatedOffline,
}

/// Phân giải 1 ngôn ngữ đang chọn thành profile + trạng thái cài đặt.
class AsrModelSelection {
  /// Ngôn ngữ user đang chọn (đã normalize, vd `en-US` → `en`).
  final String requestedLanguage;

  /// Profile tương ứng — `null` khi app KHÔNG có profile cho ngôn ngữ này.
  final SherpaAsrProfile? profile;

  /// Model của [profile] đã nằm trên máy.
  final bool isInstalled;

  /// Profile khác ĐÃ CÀI, ưu tiên VI — chỉ để GỢI Ý fallback cho user xác
  /// nhận. KHÔNG tự động dùng.
  final SherpaAsrProfile? installedAlternative;

  const AsrModelSelection({
    required this.requestedLanguage,
    this.profile,
    this.isInstalled = false,
    this.installedAlternative,
  });

  bool get isReady => profile != null && isInstalled;

  AsrModelIssue get issue {
    if (isReady) return AsrModelIssue.none;
    if (profile == null) return AsrModelIssue.noProfileForLanguage;
    return AsrModelIssue.profileNotInstalled;
  }

  /// Có phương án fallback đã cài để hỏi user (không tự ý đổi).
  ///
  /// Chỉ gợi ý khi app CÓ profile cho ngôn ngữ đang chọn (VI/EN) — ngôn ngữ
  /// chưa hỗ trợ offline (zh/fr/…) thì phải dùng engine Hệ thống, không đẩy
  /// user sang model khác.
  bool get hasInstalledFallback =>
      !isReady &&
      profile != null &&
      installedAlternative != null &&
      installedAlternative!.language != requestedLanguage;

  /// Ngôn ngữ của phương án fallback (nếu có).
  String? get fallbackLanguage => hasInstalledFallback ? installedAlternative!.language : null;

  /// Route live — chỉ có nghĩa khi [profile] != null.
  AsrLiveRoute get liveRoute => (profile?.isStreaming ?? false)
      ? AsrLiveRoute.onlineStreaming
      : AsrLiveRoute.simulatedOffline;

  @override
  String toString() => 'AsrModelSelection($requestedLanguage, '
      'profile=${profile?.id}, installed=$isInstalled, '
      'fallback=${installedAlternative?.id}, issue=$issue)';
}

/// Bộ định tuyến model ASR — toàn bộ logic mapping/quyết định ở một chỗ.
class AsrModelRouter {
  AsrModelRouter._();

  /// Chuẩn hoá mã ngôn ngữ: `en-US`/`en_US` → `en`, `VI ` → `vi`.
  static String normalizeLanguage(String raw) {
    final trimmed = raw.trim().toLowerCase().replaceAll('_', '-');
    if (trimmed.isEmpty) return '';
    final dash = trimmed.indexOf('-');
    return dash > 0 ? trimmed.substring(0, dash) : trimmed;
  }

  /// Profile cho một ngôn ngữ — CHỈ khớp đúng ngôn ngữ (không fallback mò).
  static SherpaAsrProfile? profileForLanguage(String language) {
    final norm = normalizeLanguage(language);
    if (norm.isEmpty) return null;
    for (final profile in kSherpaAsrProfiles) {
      if (profile.language == norm) return profile;
    }
    return null;
  }

  /// Profile theo id (khớp `language` cũng được — tương thích API cũ).
  static SherpaAsrProfile? profileForIdOrLanguage(String idOrLanguage) {
    final norm = normalizeLanguage(idOrLanguage);
    for (final profile in kSherpaAsrProfiles) {
      if (profile.id.toLowerCase() == norm) return profile;
    }
    return profileForLanguage(idOrLanguage);
  }

  /// Các ngôn ngữ app CÓ model offline (Zipformer).
  static List<String> get supportedLanguages =>
      [for (final profile in kSherpaAsrProfiles) profile.language];

  /// App có profile Zipformer cho ngôn ngữ này không.
  static bool supportsLanguage(String language) =>
      profileForLanguage(language) != null;

  /// Phân giải ngôn ngữ đang chọn. [isInstalled] là callback tra trạng thái
  /// cài đặt của profile (để module này không phụ thuộc I/O).
  static AsrModelSelection resolve(
    String language, {
    required bool Function(String profileId) isInstalled,
  }) {
    final norm = normalizeLanguage(language);
    final profile = profileForLanguage(norm);
    final installed = profile != null && isInstalled(profile.id);

    SherpaAsrProfile? alternative;
    if (!installed) {
      for (final candidate in _priorityOrder()) {
        if (candidate.language != norm && isInstalled(candidate.id)) {
          alternative = candidate;
          break;
        }
      }
    }

    return AsrModelSelection(
      requestedLanguage: norm,
      profile: profile,
      isInstalled: installed,
      installedAlternative: alternative,
    );
  }

  /// Ngôn ngữ mặc định khi user CHƯA chọn gì: ưu tiên ngôn ngữ đã cài model
  /// theo [kAsrLanguagePriority] (vi trước), nếu máy chưa cài model nào thì
  /// trả [preferred] (`vi`) kèm giải thích ở UI.
  static String resolveDefaultLanguage({
    required bool Function(String profileId) isInstalled,
    String preferred = kDefaultAsrLanguage,
  }) {
    for (final profile in _priorityOrder(preferred)) {
      if (isInstalled(profile.id)) return profile.language;
    }
    return normalizeLanguage(preferred);
  }

  /// Máy đã cài model ASR nào chưa (bất kỳ profile).
  static bool hasAnyInstalled({
    required bool Function(String profileId) isInstalled,
  }) =>
      kSherpaAsrProfiles.any((profile) => isInstalled(profile.id));

  static Iterable<SherpaAsrProfile> _priorityOrder([
    String preferred = kDefaultAsrLanguage,
  ]) {
    final norm = normalizeLanguage(preferred);
    final ordered = <SherpaAsrProfile>[];
    final seen = <String>{};
    for (final language in [norm, ...kAsrLanguagePriority]) {
      final profile = profileForLanguage(language);
      if (profile != null && seen.add(profile.id)) ordered.add(profile);
    }
    for (final profile in kSherpaAsrProfiles) {
      if (seen.add(profile.id)) ordered.add(profile);
    }
    return ordered;
  }
}
