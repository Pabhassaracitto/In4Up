// packages/in4up_stt/lib/asr_model_routing.dart
//
// Chọn model ASR (Zipformer / Parakeet / …) + route engine live STT — LOGIC
// THUẦN (không I/O, không plugin) nên test được trên máy không có thiết bị.
//
// Ràng buộc (SHERPA-WP4-01 / CABIN-ASR-002 / SHERPA-STREAM-001 /
// PARAKEET-001):
// - 3 profile đã verify: **VI offline** (Zipformer, `OfflineRecognizer` +
//   Silero VAD = “simulated streaming”), **EN streaming** (Zipformer,
//   `OnlineRecognizer` token-by-token) và **Parakeet TDT 0.6B v3 int8**
//   (offline, 25 ngôn ngữ châu Âu — `OfflineRecognizer` + VAD).
//   KHÔNG bịa thêm profile ngôn ngữ nào khác: ngôn ngữ không có profile phải
//   được báo RÕ, không map mò về profile đầu tiên.
// - KHÔNG tự đổi ngôn ngữ nhận diện sau lưng user: chọn EN mà máy chỉ cài VI
//   thì DỪNG + báo thiếu model (kèm gợi ý fallback để user tự xác nhận),
//   tuyệt đối không nhận tiếng Anh bằng model tiếng Việt.
// - Model streaming KHÔNG BAO GIỜ đi vào `OfflineRecognizer` (SIGABRT
//   “Got N Expected 39”); model offline không đi vào `OnlineRecognizer`.
// - Model đa ngữ (Parakeet) KHÔNG được “chiếm chỗ” của profile chuyên một
//   ngôn ngữ: `profileForLanguage('en')` vẫn trả Zipformer EN streaming;
//   Parakeet chỉ là profile cho ngôn ngữ chưa có model riêng (de/fr/…).

/// Ngôn ngữ mặc định của app (người Việt) — dùng khi máy chưa cài model nào.
const String kDefaultAsrLanguage = 'vi';

/// Thứ tự ưu tiên khi nhiều profile đã cài (VI trước — theo WP4).
const List<String> kAsrLanguagePriority = ['vi', 'en'];

/// Họ model (quyết định nhãn UI + engine chạy).
enum SherpaAsrFamily {
  /// Zipformer (k2-fsa) — VI offline 30M, EN streaming 20M.
  zipformer,

  /// NeMo Parakeet TDT (encoder–decoder–joiner) — đa ngữ, offline.
  parakeet,
}

/// Id profile Parakeet TDT 0.6B v3 int8 (25 ngôn ngữ châu Âu).
///
/// Nguồn: `sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2`
/// (k2-fsa export từ `nvidia/parakeet-tdt-0.6b-v3`, license CC-BY-4.0).
const String kParakeetProfileId = 'asr-parakeet-tdt-0.6b-v3-int8';

/// Định nghĩa profile của model ASR (Zipformer / Parakeet).
///
/// `isStreaming == true` ⇒ model chỉ chạy được với `OnlineRecognizer`
/// (live token-by-token). `false` ⇒ model offline, live phải đi đường
/// simulated streaming (OfflineRecognizer + Silero VAD).
class SherpaAsrProfile {
  final String id;
  final String name;

  /// Các ngôn ngữ model nhận diện được (phần tử ĐẦU là ngôn ngữ đại diện —
  /// dùng cho `resolveDefaultLanguage` / nhãn ngắn). Model một ngôn ngữ chỉ
  /// có 1 phần tử; Parakeet có 25.
  final List<String> languages;

  final bool isStreaming;
  final int approxSizeMB;
  final String downloadUrl;
  final String archiveName;
  final SherpaAsrFamily family;

  const SherpaAsrProfile({
    required this.id,
    required this.name,
    required this.languages,
    required this.isStreaming,
    required this.approxSizeMB,
    required this.downloadUrl,
    required this.archiveName,
    this.family = SherpaAsrFamily.zipformer,
  });
  // KHÔNG đặt `assert(languages.length > 0)` trong constructor `const`: đọc
  // `.length` của const list không phải biểu thức hằng hợp lệ (analyzer:
  // `const_eval_property_access`) ⇒ hỏng cả `kSherpaAsrProfiles`.
  // Bất biến "có ít nhất 1 ngôn ngữ" được `languages` bắt buộc + test gác.

  /// Ngôn ngữ đại diện (giữ API cũ `profile.language`).
  String get language => languages.first;

  /// Model nhiều ngôn ngữ (Parakeet) hay chuyên 1 ngôn ngữ.
  bool get isMultilingual => languages.length > 1;

  /// Model offline dùng được cho file/LRC (streaming thì KHÔNG — xem
  /// `SherpaModelManager.isStreamingEncoderOnnx`).
  bool get isOffline => !isStreaming;

  /// Nhãn ngắn cho chip/status: `VI`, `EN` hoặc `25 ngôn ngữ`.
  String get languageLabel {
    if (!isMultilingual) return language.toUpperCase();
    return '${languages.length} ngôn ngữ';
  }

  /// Model lớn (≥300MB) — UI phải hỏi xác nhận trước khi tải.
  bool get isLargeDownload => approxSizeMB >= 300;
}

/// Danh sách profile ASR được hỗ trợ sẵn (3 profile đã verify).
///
/// URL/size lấy từ docs k2-fsa (`docs/Bangiao/bangiao_sherpa_wp4_live_stt.md`
/// + trang `offline-transducer/nemo-transducer-models`) — không thêm URL mới
/// khi chưa verify tên archive.
const List<SherpaAsrProfile> kSherpaAsrProfiles = [
  SherpaAsrProfile(
    id: 'asr-vi-30M-int8',
    name: 'Tiếng Việt (Zipformer 30M int8)',
    languages: ['vi'],
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
    languages: ['en'],
    isStreaming: true,
    approxSizeMB: 20,
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2',
    archiveName: 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17.tar.bz2',
  ),
  // PARAKEET-001 — model đa ngữ (25 ngôn ngữ châu Âu) của NVIDIA, export
  // int8 bởi k2-fsa. Offline-only: sherpa-onnx KHÔNG có bản streaming cho
  // parakeet-tdt-0.6b-v3 (issue k2-fsa/sherpa-onnx#2918) ⇒ live STT đi đường
  // simulated streaming (OfflineRecognizer + Silero VAD) như profile VI.
  // Bộ file: encoder.int8.onnx (~624MB) + decoder.int8.onnx + joiner.int8.onnx
  // + tokens.txt ⇒ ~670MB, cần ~1GB RAM trống khi nạp.
  SherpaAsrProfile(
    id: kParakeetProfileId,
    name: 'Parakeet TDT 0.6B v3 (NVIDIA, int8)',
    languages: [
      'en',
      'bg',
      'hr',
      'cs',
      'da',
      'nl',
      'et',
      'fi',
      'fr',
      'de',
      'el',
      'hu',
      'it',
      'lv',
      'lt',
      'mt',
      'pl',
      'pt',
      'ro',
      'sk',
      'sl',
      'es',
      'sv',
      'ru',
      'uk',
    ],
    isStreaming: false,
    approxSizeMB: 670,
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
        'sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2',
    archiveName: 'sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2',
    family: SherpaAsrFamily.parakeet,
  ),
];

/// Các profile ASR đa ngữ (ngôn ngữ chưa có model chuyên dụng dùng chung).
List<SherpaAsrProfile> get kMultilingualAsrProfiles => [
      for (final profile in kSherpaAsrProfiles)
        if (profile.isMultilingual) profile,
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

  /// TẤT CẢ profile nhận diện được [language], theo thứ tự ưu tiên:
  /// 1. profile chuyên đúng 1 ngôn ngữ đó (Zipformer VI/EN) — nhỏ, nhanh;
  /// 2. profile đa ngữ có chứa ngôn ngữ đó (Parakeet).
  ///
  /// Model đa ngữ KHÔNG được chen ngang profile chuyên ngôn ngữ: chọn EN mà
  /// máy có Zipformer EN streaming thì vẫn dùng Zipformer (hành vi cũ).
  static List<SherpaAsrProfile> profilesForLanguage(String language) {
    final norm = normalizeLanguage(language);
    if (norm.isEmpty) return const [];
    final dedicated = <SherpaAsrProfile>[];
    final multilingual = <SherpaAsrProfile>[];
    for (final profile in kSherpaAsrProfiles) {
      if (!profile.languages.contains(norm)) continue;
      if (profile.isMultilingual) {
        multilingual.add(profile);
      } else {
        dedicated.add(profile);
      }
    }
    return [...dedicated, ...multilingual];
  }

  /// Profile tốt nhất cho một ngôn ngữ — CHỈ khớp ngôn ngữ model hỗ trợ
  /// (không fallback mò sang ngôn ngữ khác).
  static SherpaAsrProfile? profileForLanguage(String language) {
    final matches = profilesForLanguage(language);
    return matches.isEmpty ? null : matches.first;
  }

  /// Profile theo id chính xác (null nếu không có).
  static SherpaAsrProfile? profileById(String id) {
    for (final profile in kSherpaAsrProfiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// Profile Parakeet đa ngữ (null nếu bản build không kèm).
  static SherpaAsrProfile? get parakeetProfile => profileById(kParakeetProfileId);

  /// Profile Zipformer đang có (theo họ model).
  static List<SherpaAsrProfile> get zipformerProfiles => [
        for (final profile in kSherpaAsrProfiles)
          if (profile.family == SherpaAsrFamily.zipformer) profile,
      ];

  /// Ngôn ngữ CHỈ có model đa ngữ (chưa có model chuyên dụng) — UI dùng để
  /// ghi chú "dùng Parakeet" thay vì báo "chưa hỗ trợ offline".
  static bool isMultilingualOnly(String language) {
    final matches = profilesForLanguage(language);
    return matches.isNotEmpty && matches.every((p) => p.isMultilingual);
  }

  /// Profile theo id (khớp `language` cũng được — tương thích API cũ).
  ///
  /// FIX PARAKEET-001: bản cũ normalize TRƯỚC khi so id ⇒ `asr-vi-30M-int8`
  /// bị cắt thành `asr` (normalizeLanguage cắt ở dấu '-') nên KHÔNG BAO GIỜ
  /// khớp id nào; UI import theo thẻ model vì thế mất `targetProfileId`.
  /// Giờ so id nguyên chuỗi trước, rồi mới thử như mã ngôn ngữ.
  static SherpaAsrProfile? profileForIdOrLanguage(String idOrLanguage) {
    final raw = idOrLanguage.trim().toLowerCase();
    if (raw.isEmpty) return null;
    for (final profile in kSherpaAsrProfiles) {
      if (profile.id.toLowerCase() == raw) return profile;
    }
    return profileForLanguage(raw);
  }

  /// Các ngôn ngữ app CÓ model offline (Zipformer + Parakeet), không trùng.
  static List<String> get supportedLanguages {
    final seen = <String>{};
    final out = <String>[];
    for (final profile in kSherpaAsrProfiles) {
      for (final language in profile.languages) {
        if (seen.add(language)) out.add(language);
      }
    }
    return out;
  }

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

    // Ưu tiên profile chuyên ngôn ngữ; nếu profile đó chưa cài mà model ĐA
    // NGỮ đã cài VÀ có ngôn ngữ này thì dùng luôn model đa ngữ (vẫn đúng
    // ngôn ngữ, không phải "đoán mò").
    SherpaAsrProfile? profile = profileForLanguage(norm);
    if (profile != null && !isInstalled(profile.id)) {
      for (final candidate in profilesForLanguage(norm)) {
        if (candidate.isMultilingual && isInstalled(candidate.id)) {
          profile = candidate;
          break;
        }
      }
    }
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
