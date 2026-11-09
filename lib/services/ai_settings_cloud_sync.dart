// lib/services/ai_settings_cloud_sync.dart
//
// API-SYNC-001 — đồng bộ "Server & API" (provider + routing + key) lên Firebase.
//
// Owner (2026-10-26): *"thiết lập 1 chỗ sync cấu hình API lên Firebase để sau
// khi đăng nhập ở máy khác/phiên khác là có luôn, không phải nhập lại key"*.
//
// Thiết kế (bám pattern Learn-by-heart / Vocab đã có trong repo):
//   • Doc: `users/{uid}/ai_settings/current`, field `payload` = JSON string
//     của [AiSettingsSnapshot] (cùng quy ước LHB/Vocab ⇒ dễ backup/đọc tay).
//   • Offline-first: user đổi cấu hình → store ghi SharedPreferences ngay;
//     ta đánh dấu dirty rồi push (debounce 3s) khi có mạng + đã đăng nhập.
//   • Hòa giải khi pull: `mergeAiSettings(local:, remote:)` per-provider LWW +
//     bia mộ ⇒ không mất provider vừa thêm, không "sống lại" provider đã xoá.
//   • Linux (không có plugin cloud_firestore) → [FirestoreRestClient] đúng như
//     LHB sync: cùng doc, cùng payload.
//
// BẢO MẬT: payload chứa apiKey (đúng yêu cầu "không phải nhập lại"), nên chỉ
// ghi vào `users/{uid}/...` (rules chặn đọc/ghi chéo user) và KHÔNG log body.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'firebase_rest_auth.dart';
import 'firestore_rest_client.dart';

/// Trạng thái đồng bộ (cho UI hiện "lần cuối đồng bộ").
enum AiSettingsSyncState { idle, syncing, ok, error, signedOut }

@immutable
class AiSettingsSyncStatus {
  final AiSettingsSyncState state;
  final DateTime? lastSyncedAt;
  final String? message;
  const AiSettingsSyncStatus({
    this.state = AiSettingsSyncState.idle,
    this.lastSyncedAt,
    this.message,
  });

  AiSettingsSyncStatus copyWith({
    AiSettingsSyncState? state,
    DateTime? lastSyncedAt,
    String? message,
  }) =>
      AiSettingsSyncStatus(
        state: state ?? this.state,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        message: message ?? this.message,
      );

}

/// Đồng bộ cấu hình AI với Firestore. Singleton — gọi được từ UI/main.
class AiSettingsCloudSync extends ChangeNotifier {
  AiSettingsCloudSync._();
  static final AiSettingsCloudSync instance = AiSettingsCloudSync._();

  static const _kLastSyncedMs = 'ai_settings_last_synced_ms_v1';
  static const _kDirty = 'ai_settings_dirty_v1';
  static const _collection = 'ai_settings';
  static const _docId = 'current';

  AiSettingsSyncStatus _status = const AiSettingsSyncStatus();
  AiSettingsSyncStatus get status => _status;

  Timer? _debounce;
  bool _busy = false;
  String? _uid;
  StreamSubscription<AppUser?>? _authSub;
  bool _wired = false;
  FirebaseFirestore? _db;
  bool? _pluginOk;

  /// True khi plugin cloud_firestore khả dụng (Android/iOS/macOS/Windows/Web).
  /// Linux: plugin không tồn tại → REST.
  bool get hasPlugin {
    _pluginOk ??= _tryPlugin();
    return _pluginOk!;
  }

  bool _tryPlugin() {
    try {
      _db ??= FirebaseFirestore.instance;
      return true;
    } catch (e) {
      debugPrint('AiSettingsCloudSync: cloud_firestore không khả dụng ($e)');
      return false;
    }
  }

  static String _docPath(String uid) => 'users/$uid/$_collection/$_docId';

  AiSettingsSyncStatus _set(AiSettingsSyncStatus next) {
    _status = next;
    notifyListeners();
    return next;
  }

  /// Gắn vào `AuthService().authStateChanges` + hook `store.onChanged`.
  ///
  /// Gọi 1 lần trong `main.dart` sau `runApp`. Idempotent.
  void attach({AiProviderStore? store}) {
    if (_wired) return;
    _wired = true;
    final s = store ?? AiProviderStore.instance;

    s.onChanged = () => _schedulePush(s);

    _authSub = AuthService().authStateChanges.listen((user) {
      if (user == null) {
        _uid = null;
        _set(_status.copyWith(state: AiSettingsSyncState.signedOut));
        return;
      }
      _uid = user.uid;
      // Đăng nhập (máy mới/phiên mới) ⇒ pull+merge NGAY, trước đó store vẫn
      // còn dữ liệu local nên UI không bị trống.
      unawaited(syncNow(store: s, pullFirst: true));
    });

    // Khôi phục trạng thái "lần cuối đồng bộ" để UI không hiện trống.
    SharedPreferences.getInstance().then((prefs) {
      final ms = prefs.getInt(_kLastSyncedMs);
      if (ms != null) {
        _set(_status.copyWith(
          lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(ms),
        ));
      }
      if (prefs.getBool(_kDirty) ?? false) _schedulePush(s);
    });
  }

  void _schedulePush(AiProviderStore store) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDirty, true);
      if (_uid != null) unawaited(syncNow(store: store));
    });
  }

  /// Push (mặc định) hoặc pull-then-push.
  Future<AiSettingsSyncStatus> syncNow({
    AiProviderStore? store,
    bool pullFirst = false,
  }) async {
    final s = store ?? AiProviderStore.instance;
    final uid = _uid;
    if (uid == null) {
      // Chuỗi hiển thị do UI dựng (rule vàng #5) — service chỉ trả trạng thái.
      return _set(_status.copyWith(state: AiSettingsSyncState.signedOut));
    }
    if (_busy) return _status;
    _busy = true;
    _set(_status.copyWith(state: AiSettingsSyncState.syncing));

    try {
      await s.ensureLoaded();

      if (pullFirst) {
        final remote = await _read(uid);
        if (remote != null) {
          final merged = mergeAiSettings(
            local: s.snapshot(),
            remote: remote,
          );
          if (merged.changedLocally) {
            // touch:false — giữ nguyên mốc của bên mới hơn.
            await s.applySnapshot(merged.merged);
          }
        }
      }

      // Luôn push bản local (đã merge nếu pullFirst) ⇒ 2 máy hội tụ.
      await _write(uid, s.snapshot());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDirty, false);
      await prefs.setInt(
          _kLastSyncedMs, DateTime.now().millisecondsSinceEpoch);
      _busy = false;
      return _set(AiSettingsSyncStatus(
        state: AiSettingsSyncState.ok,
        lastSyncedAt: DateTime.now(),
      ));
    } catch (e) {
      _busy = false;
      return _set(_status.copyWith(
        state: AiSettingsSyncState.error,
        // Chi tiết kỹ thuật (không dịch) — UI ghép câu.
        message: '$e',
      ));
    }
  }

  /// Pull thủ công (nút "Tải từ Firebase"): merge remote vào local rồi áp.
  Future<AiSettingsSyncStatus> pullNow({AiProviderStore? store}) =>
      syncNow(store: store, pullFirst: true);

  // ── Firestore I/O ───────────────────────────────────────────────────────

  Future<AiSettingsSnapshot?> _read(String uid) async {
    final path = _docPath(uid);
    Map<String, dynamic>? raw;
    if (hasPlugin) {
      final snap = await _db!.doc(path).get();
      raw = _stringKeyed(snap.data());
    } else {
      raw = await FirestoreRestClient().getDocument(path);
      if (raw != null) raw = _stringKeyed(raw);
    }
    final payload = raw?['payload'];
    if (payload is! String || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      return AiSettingsSnapshot.fromJson(decoded);
    } catch (e) {
      debugPrint('AiSettingsCloudSync: payload hỏng ($e) — coi như không có');
      return null;
    }
  }

  Future<void> _write(String uid, AiSettingsSnapshot snapshot) async {
    final path = _docPath(uid);
    final payload = jsonEncode(snapshot.toJson());
    final data = <String, dynamic>{
      'payload': payload,
      'updatedAtMs': snapshot.updatedAtMs,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (hasPlugin) {
      await _db!.doc(path).set(data, SetOptions(merge: true));
      return;
    }
    await FirestoreRestClient().commitWrites([
      FirestoreRestClient().updateWrite(path, data),
    ]);
  }

  /// `DocumentSnapshot.data()` trả `Map<String, dynamic>` nhưng một số bản
  /// plugin trả kiểu lồng — chuẩn hóa để `payload` đọc được.
  Map<String, dynamic>? _stringKeyed(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return {
      for (final e in raw.entries) e.key: e.value,
    };
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
