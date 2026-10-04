// lib/features/vocab_image/vocab_image_api_config.dart
//
// IMG-WEB-001 — Cấu hình API key cho tìm ảnh.
//
// Yêu cầu của người sở hữu: "tìm kiếm ảnh phải có key API" → mọi provider
// chính đều đi qua API có key (không scrape). Key lấy theo 2 nguồn, theo thứ
// tự ưu tiên:
//   1. Nhập trong app (sheet chọn ảnh → nút "API key") → lưu SharedPreferences
//      CHỈ trên máy người dùng (KHÔNG bao giờ commit vào repo).
//   2. Build-time: --dart-define=VOCAB_IMAGE_PROVIDER=pexels
//      --dart-define=VOCAB_IMAGE_API_KEY=xxxx (dùng cho bản build nội bộ).
//
// Openverse/Wikimedia Commons vẫn còn làm đường fallback KHÔNG cần key:
// app không được chết hoàn toàn khi user chưa kịp dán key — nhưng UI nói rõ
// là đang ở chế độ fallback.

import 'package:shared_preferences/shared_preferences.dart';

/// Provider tìm ảnh. `needsKey = true` → bắt buộc có API key mới dùng được.
enum VocabImageProvider {
  pexels(
    label: 'Pexels',
    needsKey: true,
    keyHeaderHint: 'API key (header Authorization)',
    howTo: 'https://www.pexels.com/api/',
  ),
  unsplash(
    label: 'Unsplash',
    needsKey: true,
    keyHeaderHint: 'Access Key (Client-ID)',
    howTo: 'https://unsplash.com/developers',
  ),
  openverse(
    label: 'Openverse',
    // Openverse anonymous được, nhưng rate limit rất thấp → app khuyến
    // nghị token (miễn phí) để dùng ổn định như các nguồn có key khác.
    needsKey: false,
    keyHeaderHint: 'Bearer token (khuyến nghị, miễn phí)',
    howTo: 'https://openverse.org/embedded',
  ),
  wikimedia(
    label: 'Wikimedia Commons',
    needsKey: false,
    keyHeaderHint: 'không cần key',
    howTo: 'https://commons.wikimedia.org/wiki/Special:ApiSandbox',
  );

  const VocabImageProvider({
    required this.label,
    required this.needsKey,
    required this.keyHeaderHint,
    required this.howTo,
  });

  /// Tên hiển thị (không dịch — tên thương hiệu).
  final String label;

  /// true = không có key là KHÔNG tìm được gì.
  final bool needsKey;

  /// Gợi ý kiểu key trong form nhập.
  final String keyHeaderHint;

  /// Nơi lấy key.
  final String howTo;

  /// key lưu prefs: `vocab_image_key_pexels`…
  String get storageKeyName => 'vocab_image_key_${name.toLowerCase()}';
}

/// Provider + key đang dùng cho tính năng tìm ảnh từ vựng.
class VocabImageApiSettings {
  /// Provider ưu tiên (chip "Nguồn" trong sheet).
  final VocabImageProvider provider;

  /// Keys đã lưu, theo tên provider (rỗng = chưa có).
  final Map<String, String> keys;

  /// true khi build được chạy với --dart-define=VOCAB_IMAGE_API_KEY=…
  final bool hasBuildTimeKey;

  /// Provider đã build-time (null nếu không set).
  final String? buildTimeProvider;

  /// IMG-WEB-001 (owner 2026-09-28): "Mặc định là tự tìm, chạm chọn nhưng có
  /// thể chọn thêm toggle tự gán ảnh trong cài đặt riêng."
  ///
  /// `false` (mặc định) = sheet vẫn mở, tự tìm sẵn và người dùng CHẠM CHỌN ảnh
  /// — không bao giờ gán ảnh mà chưa ai xem.
  /// `true` = luồng "thêm từ" gán luôn ảnh ĐẦU TIÊN tìm được trên mạng, không
  /// mở sheet; thất bại (mạng/key/không ra ảnh) thì im lặng bỏ qua, từ vẫn lưu
  /// bình thường và vẫn có thể gán tay sau.
  final bool autoAssignFirst;

  /// LOTTIE-001 (owner 2026-10-04): "Có thể tải về local ngay (tuy nhiên có
  /// thể thiết lập lựa chọn lazy trong cài đặt)".
  ///
  /// `false` (mặc định) = import CSV có link ảnh/Lottie thì TẢI VỀ MÁY NGAY
  /// sau import — học offline trọn vẹn (đúng triết lý ảnh tĩnh hiện có).
  /// `true` = giữ nguyên URL sau import; ảnh/animation chỉ tải và lưu về máy
  /// ở LẦN XEM ĐẦU TIÊN (VocabularyMediaWidget materialize) — tiết kiệm dữ
  /// liệu/dung lượng với bộ từ lớn, đổi lại từ chưa xem sẽ không có minh
  /// họa khi offline.
  final bool lazyDownload;

  const VocabImageApiSettings({
    required this.provider,
    required this.keys,
    required this.hasBuildTimeKey,
    this.buildTimeProvider,
    this.autoAssignFirst = false,
    this.lazyDownload = false,
  });

  /// Key hiệu dụng cho [p]: key nhập trong app, fallback key build-time
  /// (chỉ khi build chọn đúng provider đó — tránh đưa key Pexels cho Unsplash).
  String? keyFor(VocabImageProvider p) {
    final stored = keys[p.name.toLowerCase()] ?? '';
    if (stored.trim().isNotEmpty) return stored.trim();
    if (buildTimeKey.isEmpty) return null; // --dart-define không được set
    if (hasBuildTimeKey && p.name.toLowerCase() == (buildTimeProvider ?? '')) {
      return buildTimeKey;
    }
    return null;
  }

  /// Chuỗi build-time — chỉ để đọc qua getter, KHÔNG log/hiển thị.
  static const String buildTimeKey =
      String.fromEnvironment('VOCAB_IMAGE_API_KEY');

  static const String buildTimeProviderName =
      String.fromEnvironment('VOCAB_IMAGE_PROVIDER');

  /// Provider mặc định khi user chưa chọn: key build-time nếu được set,
  /// nếu không thì Pexels (nguồn có key, chất lượng ảnh cao cho từ vựng).
  static VocabImageProvider resolveDefaultProvider(String? stored) {
    for (final p in VocabImageProvider.values) {
      if (stored != null && p.name.toLowerCase() == stored.toLowerCase()) {
        return p;
      }
    }
    if (hasBuildTimeKeyValue && buildTimeProviderName.isNotEmpty) {
      for (final p in VocabImageProvider.values) {
        if (p.name.toLowerCase() == buildTimeProviderName.toLowerCase()) {
          return p;
        }
      }
    }
    return VocabImageProvider.pexels;
  }

  static bool get hasBuildTimeKeyValue => buildTimeKey.isNotEmpty;

  VocabImageApiSettings copyWith({
    VocabImageProvider? provider,
    Map<String, String>? keys,
    bool? autoAssignFirst,
    bool? lazyDownload,
  }) =>
      VocabImageApiSettings(
        provider: provider ?? this.provider,
        keys: keys ?? this.keys,
        hasBuildTimeKey: hasBuildTimeKey,
        buildTimeProvider: buildTimeProvider,
        autoAssignFirst: autoAssignFirst ?? this.autoAssignFirst,
        lazyDownload: lazyDownload ?? this.lazyDownload,
      );

  /// Provider hiện chọn có dùng được không (có key, hoặc không cần key).
  bool get selectedProviderUsable =>
      !provider.needsKey || (keyFor(provider) != null);

  /// Danh sách provider dùng được theo thứ tự ưu tiên gọi:
  /// provider đã chọn trước, rồi tới các nguồn còn lại có key/không cần key.
  List<VocabImageProvider> searchOrder() {
    final ordered = <VocabImageProvider>[provider];
    for (final p in VocabImageProvider.values) {
      if (ordered.contains(p)) continue;
      if (!p.needsKey || keyFor(p) != null) ordered.add(p);
    }
    return ordered;
  }
}

/// Store prefs cho [VocabImageApiSettings].
class VocabImageApiConfig {
  VocabImageApiConfig._();
  static final VocabImageApiConfig instance = VocabImageApiConfig._();

  static const String _providerKey = 'vocab_image_provider';

  /// Toggle "tự gán ảnh đầu tiên" (IMG-WEB-001) — chỉ trên máy, không đồng bộ.
  static const String _autoAssignKey = 'vocab_image_auto_assign';

  /// Toggle "chỉ tải media khi xem" (LOTTIE-001) — chỉ trên máy.
  static const String _lazyDownloadKey = 'vocab_image_lazy_download';

  SharedPreferences? _prefs;
  VocabImageApiSettings? _cached;

  Future<SharedPreferences> _ensure() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Đọc cấu hình (cache trong phiên — sheet mở/tắt nhiều lần không đọc disk).
  Future<VocabImageApiSettings> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await _ensure();
    final keys = <String, String>{};
    for (final p in VocabImageProvider.values) {
      final v = prefs.getString(p.storageKeyName);
      if (v != null && v.trim().isNotEmpty) keys[p.name.toLowerCase()] = v.trim();
    }
    final settings = VocabImageApiSettings(
      provider: VocabImageApiSettings.resolveDefaultProvider(
        prefs.getString(_providerKey),
      ),
      keys: keys,
      hasBuildTimeKey: VocabImageApiSettings.hasBuildTimeKeyValue,
      buildTimeProvider: VocabImageApiSettings.buildTimeProviderName.isEmpty
          ? null
          : VocabImageApiSettings.buildTimeProviderName.toLowerCase(),
      autoAssignFirst: prefs.getBool(_autoAssignKey) ?? false,
      lazyDownload: prefs.getBool(_lazyDownloadKey) ?? false,
    );
    return _cached = settings;
  }

  Future<void> saveKey(VocabImageProvider provider, String key) async {
    final prefs = await _ensure();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(provider.storageKeyName);
    } else {
      await prefs.setString(provider.storageKeyName, trimmed);
    }
    _cached = null;
  }

  Future<void> saveProvider(VocabImageProvider provider) async {
    final prefs = await _ensure();
    await prefs.setString(_providerKey, provider.name.toLowerCase());
    _cached = null;
  }

  /// Bật/tắt "tự gán ảnh đầu tiên khi thêm từ". Xóa hẳn key khi tắt để prefs
  /// không mang giá trị thừa.
  Future<void> saveAutoAssign(bool enabled) async {
    final prefs = await _ensure();
    if (enabled) {
      await prefs.setBool(_autoAssignKey, true);
    } else {
      await prefs.remove(_autoAssignKey);
    }
    _cached = null;
  }

  /// Bật/tắt "chỉ tải ảnh/animation về máy ở lần xem đầu" (LOTTIE-001).
  Future<void> saveLazyDownload(bool enabled) async {
    final prefs = await _ensure();
    if (enabled) {
      await prefs.setBool(_lazyDownloadKey, true);
    } else {
      await prefs.remove(_lazyDownloadKey);
    }
    _cached = null;
  }

  /// Chỉ test: dọn cache trong phiên.
  void clearCacheForTest() => _cached = null;
}
