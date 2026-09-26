// packages/in4up_ai/lib/src/provider/ai_provider_store.dart
//
// WP0 (API-001) — Nơi lưu trữ cấu hình provider + routing prefs.
//
// ⚠️ ADR-0007: apiKey hiện lưu SharedPreferences (tiền lệ Zalo/FPT key) —
// interface này thiết kế để migrate sang flutter_secure_storage sau mà
// KHÔNG đổi caller: chỉ đổi phần đọc/ghi nội bộ (_read/_write).
//
// KHÔNG bao giờ log apiKey (quy tắc bảo mật tầng API — prompt WP0 mục 2.7).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_provider_config.dart';

class AiProviderStore extends ChangeNotifier {
  AiProviderStore._();
  static final AiProviderStore instance = AiProviderStore._();

  static const _kProvidersJson = 'ai_providers_json_v1';
  static const _kRoutingJson = 'ai_routing_json_v1';

  List<AiProviderConfig> _providers = const [];
  AiRoutingPrefs _routing = const AiRoutingPrefs();
  bool _loaded = false;

  List<AiProviderConfig> get providers => List.unmodifiable(_providers);
  AiRoutingPrefs get routing => _routing;

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
    _loaded = true;
    notifyListeners();
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvidersJson, encodeProviders(_providers));
    await prefs.setString(_kRoutingJson, jsonEncode(_routing.toJson()));
    notifyListeners();
  }

  /// Trả về provider nên dùng cho năng lực [c] theo routing hiện tại,
  /// hoặc null khi: offlineOnly / không có provider bật nào hỗ trợ.
  ///
  /// Ưu tiên: preferred provider (nếu còn hợp lệ) → provider bật đầu tiên
  /// có model cho năng lực.
  AiProviderConfig? resolveProvider(AiRouteCapability c) {
    if (_routing.modeOf(c) == AiRouteMode.offlineOnly) return null;
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
