// packages/in4up_ai/lib/src/provider/ai_provider_store.dart
//
// WP0 (API-001) — Nơi lưu trữ cấu hình provider + routing prefs.
//
// ⚠️ ADR-0008: apiKey hiện lưu SharedPreferences (tiền lệ Zalo/FPT key) —
// interface này thiết kế để migrate sang flutter_secure_storage sau mà
// KHÔNG đổi caller: chỉ đổi phần đọc/ghi nội bộ (_read/_write).
//
// KHÔNG bao giờ log apiKey (quy tắc bảo mật tầng API — prompt WP0 mục 2.7).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/ai_connectivity_routing.dart'; // YT-AUDIT-06 (IN4-104)
import 'ai_provider_config.dart';
import 'ai_settings_sync.dart';
import 'builtin_ai_providers.dart';

class AiProviderStore extends ChangeNotifier {
  AiProviderStore._();
  static final AiProviderStore instance = AiProviderStore._();

  static const _kProvidersJson = 'ai_providers_json_v1';
  static const _kRoutingJson = 'ai_routing_json_v1';

  /// API-SYNC-001 — mốc sửa gần nhất (ms) + bia mộ id đã xoá, dùng để hòa
  /// giải với bản trên Firebase (`mergeAiSettings`).
  static const _kUpdatedAtMs = 'ai_settings_updated_at_ms_v1';
  static const _kTombstonesJson = 'ai_settings_tombstones_v1';

  int _updatedAtMs = 0;
  Map<String, int> _tombstones = const {};

  /// Mốc sửa gần nhất của cấu hình (ms) — cloud sync dùng để LWW.
  int get updatedAtMs => _updatedAtMs;

  /// id provider đã xoá (id → ms) — chống "sống lại" khi máy khác push.
  Map<String, int> get tombstones => Map.unmodifiable(_tombstones);

  /// Cờ "đã seed provider có sẵn" — để seed MỘT LẦN (user xoá được mà
  /// không bị thêm lại).
  static const _kBuiltinSeeded = 'ai_builtin_providers_seeded_v1';

  List<AiProviderConfig> _providers = const [];
  AiRoutingPrefs _routing = const AiRoutingPrefs();
  bool _loaded = false;

  List<AiProviderConfig> get providers => List.unmodifiable(_providers);
  AiRoutingPrefs get routing => _routing;

  /// WP1: facade cần biết cấu hình đã nạp chưa (chưa nạp ⇒ coi như chưa có
  /// provider — hành xử như trước khi có tầng API, không gọi API mù).
  bool get isLoaded => _loaded;

  /// Provider đang bật (routing chỉ xét các provider này).
  List<AiProviderConfig> get enabledProviders =>
      List.unmodifiable(_providers.where((p) => p.enabled));

  AiProviderConfig? byId(String? id) {
    if (id == null) return null;
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Load 1 lần lúc mở màn / trước khi engine đọc cấu hình. Idempotent.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _providers = decodeProviders(prefs.getString(_kProvidersJson));
    _updatedAtMs = prefs.getInt(_kUpdatedAtMs) ?? 0;
    final rawTomb = prefs.getString(_kTombstonesJson);
    if (rawTomb != null && rawTomb.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTomb) as Map<String, dynamic>;
        _tombstones = {
          for (final e in decoded.entries)
            if (e.value is int) e.key: e.value as int,
        };
      } catch (e) {
        debugPrint('AiProviderStore: tombstones hỏng ($e) — bỏ qua');
        _tombstones = const {};
      }
    }
    final rawRouting = prefs.getString(_kRoutingJson);
    if (rawRouting != null && rawRouting.isNotEmpty) {
      try {
        _routing = AiRoutingPrefs.fromJson(
            Map<String, dynamic>.from(_decodeMap(rawRouting)));
      } catch (e) {
        debugPrint('AiProviderStore: routing prefs hỏng ($e) — dùng mặc định');
        _routing = const AiRoutingPrefs();
      }
    }
    // Seed provider CÓ SẴN (OpenRouter) + routing "ưu tiên online" cho
    // Chat & Phân tích AI — chỉ MỘT LẦN (cờ), để user xoá được mà không
    // bị thêm lại (và không ghi đè lựa chọn của user về sau).
    //
    // QUAN TRỌNG: seed TRƯỚC khi báo "đã nạp xong" — nếu không, engine
    // có thể hỏi `resolveProvider` trong khoảnh thời gian store đã loaded
    // nhưng provider có sẵn chưa được thêm ⇒ tưởng không có API.
    await _seedBuiltinProviders(prefs);

    _loaded = true;
    notifyListeners();
  }
  /// Thêm provider có sẵn + routing mặc định (một lần duy nhất).
  Future<void> _seedBuiltinProviders(SharedPreferences prefs) async {
    try {
      if (prefs.getBool(_kBuiltinSeeded) ?? false) return;

      final existing = {for (final p in _providers) p.id};
      final added = <AiProviderConfig>[];
      for (final builtin in builtinAiProviders()) {
        if (existing.contains(builtin.id)) continue;
        added.add(builtin);
      }

      var routing = _routing;
      if (added.isNotEmpty) {
        _providers = [..._providers, ...added];
        // Routing mặc định cho provider có sẵn: "Khi nào dùng model online"
        // (Chat & Phân tích AI) → Ưu tiên online + nhà cung cấp ưu tiên.
        final builtinRouting = builtinAiRouting();
        final modes = Map<AiRouteCapability, AiRouteMode>.from(routing.modes);
        final preferred =
            Map<AiRouteCapability, String>.from(routing.preferredProviderIds);
        for (final entry in builtinRouting.modes.entries) {
          modes.putIfAbsent(entry.key, () => entry.value);
        }
        for (final entry in builtinRouting.preferredProviderIds.entries) {
          preferred.putIfAbsent(entry.key, () => entry.value);
        }
        routing = routing.copyWith(
          modes: modes,
          preferredProviderIds: preferred,
        );
        _routing = routing;
        // Seed KHÔNG phải thao tác của user: không bump `updatedAtMs` và không
        // báo cloud sync, nếu không máy mới cài sẽ tự coi mình "mới hơn" và
        // ghi đè cấu hình (kèm key) mà user đã đồng bộ từ máy khác.
        await _persist(touch: false, notifySync: false);
        debugPrint(
            'AiProviderStore: đã thêm provider có sẵn '
            '${added.map((p) => p.label).join(', ')}');
      }
      // Cờ "đã seed" đặt **SAU** khi lưu thành công (không đặt trước):
      // nếu `_persist()` lỗi (disk đầy, prefs hỏng…) mà cờ đã bật thì
      // provider có sẵn sẽ **KHÔNG BAO GIỜ** được thêm lại ở các lần mở
      // app sau. Đặt sau ⇒ lần mở sau thử seed lại; seed là idempotent
      // (`existing.contains(id)` chống thêm trùng, `putIfAbsent` chống
      // ghi đè lựa chọn của user) nên chạy lại là an toàn.
      await prefs.setBool(_kBuiltinSeeded, true);
    } catch (e) {
      debugPrint('AiProviderStore: seed provider có sẵn lỗi ($e) — bỏ qua');
    }
  }

  /// Thêm mới (id sinh bởi caller — uuid hoặc timestamp) hoặc cập nhật
  /// provider đã có cùng id.
  Future<void> upsert(AiProviderConfig config) async {
    await ensureLoaded();
    final idx = _providers.indexWhere((p) => p.id == config.id);
    if (idx >= 0) {
      _providers = [..._providers]..[idx] = config;
    } else {
      _providers = [..._providers, config];
    }
    await _persist();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _providers = _providers.where((p) => p.id != id).toList();
    // API-SYNC-001: ghi bia mộ — nếu không, máy khác push danh sách cũ sẽ
    // làm provider user VỪA XOÁ sống lại sau lần đồng bộ kế tiếp.
    _tombstones = {..._tombstones, id: DateTime.now().millisecondsSinceEpoch};
    // Dọn luôn tham chiếu preferred provider đã chết.
    final preferred = Map<AiRouteCapability, String>.from(
        _routing.preferredProviderIds)
      ..removeWhere((_, v) => v == id);
    _routing = _routing.copyWith(preferredProviderIds: preferred);
    await _persist();
  }

  Future<void> updateRouting(AiRoutingPrefs routing) async {
    await ensureLoaded();
    _routing = routing;
    await _persist();
  }

  Future<void> _persist({bool touch = true, bool notifySync = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (touch) _updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_kProvidersJson, encodeProviders(_providers));
    await prefs.setString(_kRoutingJson, jsonEncode(_routing.toJson()));
    await prefs.setInt(_kUpdatedAtMs, _updatedAtMs);
    await prefs.setString(_kTombstonesJson, jsonEncode(_tombstones));
    notifyListeners();
    if (notifySync) _onChanged?.call();
  }

  /// API-SYNC-001 — hook báo "cấu hình vừa đổi" (cloud sync đăng ký để push
  /// debounce). Giữ store thuần dữ liệu: không tự gọi Firebase ở đây.
  void Function()? _onChanged;
  void Function()? get onChanged => _onChanged;
  set onChanged(void Function()? callback) => _onChanged = callback;

  /// Snapshot hiện tại (cho cloud sync).
  AiSettingsSnapshot snapshot() => AiSettingsSnapshot(
        providers: List<AiProviderConfig>.from(_providers),
        routing: _routing,
        tombstones: Map<String, int>.from(_tombstones),
        updatedAtMs: _updatedAtMs,
      );

  /// Áp bản ĐÃ hòa giải (pull từ cloud hoặc merge) rồi ghi xuống đĩa.
  ///
  /// [touch] = false khi dữ liệu tới từ cloud: KHÔNG được bump `updatedAt` của
  /// máy này lên "now" (nếu bump, lần push sau sẽ ghi đè dữ liệu mới hơn của
  /// máy khác bằng bản cũ).
  Future<void> applySnapshot(AiSettingsSnapshot snapshot,
      {bool touch = false}) async {
    await ensureLoaded();
    _providers = List<AiProviderConfig>.from(snapshot.providers);
    _routing = snapshot.routing;
    _tombstones = Map<String, int>.from(snapshot.tombstones);
    _updatedAtMs =
        touch ? DateTime.now().millisecondsSinceEpoch : snapshot.updatedAtMs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvidersJson, encodeProviders(_providers));
    await prefs.setString(_kRoutingJson, jsonEncode(_routing.toJson()));
    await prefs.setInt(_kUpdatedAtMs, _updatedAtMs);
    await prefs.setString(_kTombstonesJson, jsonEncode(_tombstones));
    notifyListeners();
  }

  /// Trả về provider nên dùng cho năng lực [c] theo routing hiện tại,
  /// hoặc null khi: offlineOnly / không có provider bật nào hỗ trợ.
  ///
  /// Ưu tiên: preferred provider (nếu còn hợp lệ) → provider bật đầu tiên
  /// có model cho năng lực.
  /// [network] — API-DIAG-001: cho phép hỏi "nếu mạng là X thì dùng provider
  /// nào" (báo cáo "AI đang chạy" + test) mà KHÔNG phải đổi trạng thái
  /// router thật. Bỏ trống ⇒ dùng loại mạng hiện tại như cũ.
  AiProviderConfig? resolveProvider(AiRouteCapability c,
      {AiNetworkKind? network}) {
    // YT-AUDIT-06 (IN4-104): so mode THẬT (đã resolve theo loại mạng). Không
    // có mạng ⇒ `auto` resolve thành offlineOnly ⇒ không trả provider ⇒ chắc
    // chắn không tạo được request remote.
    final kind = network ?? AiConnectivityRouter.instance.kind;
    final mode = resolveRouteMode(_routing.modeOf(c), kind);
    if (mode == AiRouteMode.offlineOnly) return null;
    final candidates =
        enabledProviders.where((p) => p.supports(c)).toList();
    if (candidates.isEmpty) return null;
    final preferredId = _routing.preferredProviderOf(c);
    if (preferredId != null) {
      for (final p in candidates) {
        if (p.id == preferredId) return p;
      }
    }
    return candidates.first;
  }

  /// API có được phép dùng cho năng lực này không (mode + còn provider).
  bool apiAllowed(AiRouteCapability c) => resolveProvider(c) != null;

  static dynamic _decodeMap(String raw) {
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
