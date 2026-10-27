// packages/in4up_ai/lib/src/provider/ai_settings_sync.dart
//
// API-SYNC-001 — Đồng bộ cấu hình Server & API (provider + routing) lên
// Firebase, để **đăng nhập lại là có sẵn**, không phải nhập lại key.
//
// Tách 2 lớp để test được không cần mạng/không cần Firebase:
//   • phần THUẦN ở file này: snapshot JSON + hòa giải LWW (newest-wins) +
//     bia mộ (tombstone) cho provider đã xoá;
//   • phần I/O (Firestore REST / plugin) ở app layer
//     `lib/services/ai_settings_cloud_sync.dart`.
//
// Vì sao cần bia mộ: nếu chỉ LWW theo `updatedAt` của từng provider, máy A xoá
// provider X (mất khỏi danh sách) rồi máy B push lại danh sách cũ ⇒ X "sống
// lại". Tombstone giữ id + thời điểm xoá, để lần merge sau vẫn xoá được.
//
// Bảo mật: apiKey nằm trong document `users/{uid}/ai_settings/current` —
// cùng chỗ với dữ liệu học của user (Firestore rules của project chỉ cho chủ
// tài khoản đọc/ghi). KHÔNG log key ở bất kỳ đâu (kể cả message lỗi).

import 'ai_provider_config.dart';

/// Phiên bản schema snapshot — tăng khi đổi cấu trúc để lần sau migrate.
const int kAiSettingsSchemaVersion = 1;

/// Snapshot cấu hình AI của MỘT người dùng (đã chuẩn hoá để lưu cloud).
class AiSettingsSnapshot {
  /// Providers đang có (đã sắp theo id để so sánh/ghi ổn định).
  final List<AiProviderConfig> providers;

  final AiRoutingPrefs routing;

  /// id → thời điểm xoá (ms). Giữ để xoá lan sang máy khác.
  final Map<String, int> tombstones;

  /// Lần sửa gần nhất của TOÀN document (ms).
  final int updatedAtMs;

  final int schemaVersion;

  const AiSettingsSnapshot({
    this.providers = const [],
    this.routing = const AiRoutingPrefs(),
    this.tombstones = const {},
    this.updatedAtMs = 0,
    this.schemaVersion = kAiSettingsSchemaVersion,
  });

  bool get isEmpty => providers.isEmpty && tombstones.isEmpty;

  /// Số provider ĐANG bật — UI hiển thị "n provider".
  int get enabledCount => providers.where((p) => p.enabled).length;

  AiSettingsSnapshot copyWith({
    List<AiProviderConfig>? providers,
    AiRoutingPrefs? routing,
    Map<String, int>? tombstones,
    int? updatedAtMs,
  }) => AiSettingsSnapshot(
        providers: providers ?? this.providers,
        routing: routing ?? this.routing,
        tombstones: tombstones ?? this.tombstones,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        schemaVersion: schemaVersion,
      );

  /// JSON để lưu (Firestore field `payload` dạng string — tránh giới hạn
  /// độ sâu/ký tự của field name khi tên model có dấu `.`/`/`).
  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'updatedAtMs': updatedAtMs,
        'providers': [for (final p in providers) p.toJson()],
        'routing': routing.toJson(),
        'tombstones': tombstones.map((k, v) => MapEntry(k, v)),
      };

  static AiSettingsSnapshot fromJson(Map<String, dynamic> json) {
    final rawProviders = json['providers'];
    final providers = <AiProviderConfig>[];
    if (rawProviders is List) {
      for (final entry in rawProviders) {
        if (entry is Map) {
          try {
            providers.add(
              AiProviderConfig.fromJson(Map<String, dynamic>.from(entry)),
            );
          } catch (_) {
            // 1 provider hỏng không được kéo cả bản sync xuống.
          }
        }
      }
    }
    AiRoutingPrefs routing = const AiRoutingPrefs();
    final rawRouting = json['routing'];
    if (rawRouting is Map) {
      try {
        routing = AiRoutingPrefs.fromJson(Map<String, dynamic>.from(rawRouting));
      } catch (_) {
        routing = const AiRoutingPrefs();
      }
    }
    final tombstones = <String, int>{};
    final rawTombstones = json['tombstones'];
    if (rawTombstones is Map) {
      rawTombstones.forEach((key, value) {
        final ms = value is int ? value : int.tryParse('$value');
        if (ms != null) tombstones['$key'] = ms;
      });
    }
    final updated = json['updatedAtMs'];
    return AiSettingsSnapshot(
      providers: providers,
      routing: routing,
      tombstones: tombstones,
      updatedAtMs: updated is int ? updated : int.tryParse('$updated') ?? 0,
      schemaVersion: json['schemaVersion'] is int
          ? json['schemaVersion'] as int
          : kAiSettingsSchemaVersion,
    );
  }
}

/// Kết quả hòa giải 2 phía.
class AiSettingsMergeResult {
  final AiSettingsSnapshot merged;

  /// Có thay đổi so với bản LOCAL (⇒ phải ghi lại SharedPreferences).
  final bool changedLocally;

  /// Có thay đổi so với bản REMOTE (⇒ phải đẩy lên cloud).
  final bool changedRemotely;

  const AiSettingsMergeResult({
    required this.merged,
    required this.changedLocally,
    required this.changedRemotely,
  });
}

/// Hợp nhất snapshot cục bộ với snapshot trên cloud — **per-provider newest-wins + bia mộ**, KHÔNG phải
/// "cả gói thắng":
/// * id chỉ có ở MỘT phía ⇒ **nhận** (union). Đây là điểm quan trọng: máy mới
///   cài đã seed provider có sẵn (OpenRouter…, chưa có key) với mốc 0 ⇒ nếu
///   coi "remote không có" là "đã xoá" thì cấu hình của máy cũ sẽ bị dọn sạch
///   hoặc ngược lại key vừa nhập bị ghi đè — đúng lỗi owner cần tránh
///   (*"đăng nhập máy khác là có luôn, không phải nhập lại key"*).
/// * id có ở CẢ HAI ⇒ bản của phía có `updatedAtMs` LỚN HƠN thắng; bằng nhau
///   thì giữ local (không tự ghi đè cấu hình đang chạy trên máy này).
/// * **Bia mộ thắng**: id có bia mộ ⇒ bỏ, TRỪ KHI một phía có mốc document
///   MỚI HƠN bia mộ mà vẫn còn provider đó (tức user đã thêm lại sau khi xoá).
/// * Routing: lấy nguyên từ phía có `updatedAtMs` lớn hơn (không trộn từng
///   năng lực — tránh trạng thái nửa nọ nửa kia khó hiểu cho người dùng).
AiSettingsMergeResult mergeAiSettings({
  required AiSettingsSnapshot local,
  required AiSettingsSnapshot remote,
}) {
  final tombstones = <String, int>{};

  void mergeTombstone(String id, int ms) {
    final current = tombstones[id];
    if (current == null || ms > current) tombstones[id] = ms;
  }

  local.tombstones.forEach(mergeTombstone);
  remote.tombstones.forEach(mergeTombstone);

  final localById = {for (final p in local.providers) p.id: p};
  final remoteById = {for (final p in remote.providers) p.id: p};
  final remoteNewer = remote.updatedAtMs > local.updatedAtMs;
  final localNewer = local.updatedAtMs > remote.updatedAtMs;

  final merged = <String, AiProviderConfig>{};
  final allIds = <String>{...localById.keys, ...remoteById.keys};
  for (final id in allIds) {
    final l = localById[id];
    final r = remoteById[id];

    // Bia mộ: có hiệu lực trừ khi provider được thêm lại SAU thời điểm xoá
    // (document của phía đó mới hơn bia mộ mà vẫn còn provider).
    final tomb = tombstones[id];
    if (tomb != null) {
      final aliveLocal = l != null && local.updatedAtMs > tomb;
      final aliveRemote = r != null && remote.updatedAtMs > tomb;
      if (!aliveLocal && !aliveRemote) continue;
    }

    if (l != null && r != null) {
      merged[id] = remoteNewer ? r : l;
    } else {
      merged[id] = (l ?? r)!;
    }
  }

  // Dọn bia mộ vô dụng: provider đã chết ở CẢ 2 phía và cả 2 document đều mới
  // hơn mốc xoá ⇒ không còn ai cần biết. Giữ tối đa [_kTombstoneCap] cái mới
  // nhất để map không phình vô hạn theo năm tháng.
  tombstones.removeWhere((id, ms) {
    if (merged.containsKey(id)) return false;
    return ms < local.updatedAtMs && ms < remote.updatedAtMs;
  });
  if (tombstones.length > _kTombstoneCap) {
    final newest = tombstones.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    tombstones
      ..clear()
      ..addEntries(newest.take(_kTombstoneCap));
  }

  final routing = remoteNewer ? remote.routing : local.routing;

  final providerList = merged.values.toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  final mergedSnapshot = AiSettingsSnapshot(
    providers: providerList,
    routing: routing,
    tombstones: tombstones,
    updatedAtMs: local.updatedAtMs > remote.updatedAtMs
        ? local.updatedAtMs
        : remote.updatedAtMs,
  );

  return AiSettingsMergeResult(
    merged: mergedSnapshot,
    changedLocally: !_sameProviders(local.providers, providerList) ||
        !_sameRouting(local.routing, routing) ||
        !_sameTombstones(local.tombstones, tombstones),
    changedRemotely: !_sameProviders(remote.providers, providerList) ||
        !_sameRouting(remote.routing, routing) ||
        !_sameTombstones(remote.tombstones, tombstones),
  );
}

/// Trần số bia mộ giữ lại (chống phình vô hạn; quá số này thì bia mộ cũ nhất
/// bị bỏ ⇒ nguy cơ hồi sinh chỉ với provider đã xoá từ rất lâu).
const int _kTombstoneCap = 200;

bool _sameProviders(List<AiProviderConfig> a, List<AiProviderConfig> b) {
  if (a.length != b.length) return false;
  final byId = {for (final p in a) p.id: p};
  for (final p in b) {
    final other = byId[p.id];
    if (other == null) return false;
    if (other.label != p.label ||
        other.baseUrl != p.baseUrl ||
        other.apiKey != p.apiKey ||
        other.chatModel != p.chatModel ||
        other.translationModel != p.translationModel ||
        other.sttModel != p.sttModel ||
        other.ttsModel != p.ttsModel ||
        other.enabled != p.enabled) {
      return false;
    }
  }
  return true;
}

bool _sameRouting(AiRoutingPrefs a, AiRoutingPrefs b) {
  for (final cap in AiRouteCapability.values) {
    if (a.modeOf(cap) != b.modeOf(cap)) return false;
    if (a.preferredProviderOf(cap) != b.preferredProviderOf(cap)) return false;
  }
  return true;
}

bool _sameTombstones(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
