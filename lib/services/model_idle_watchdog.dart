// lib/services/model_idle_watchdog.dart
//
// PERF-001-B — "người gác cổng" nhả model khi rảnh.
//
// Bối cảnh (đọc code trước khi sửa): các engine offline đều ĐÃ có nút tắt
// (`HyMtEngine.disposeRuntime()` ở
// `lib/features/translation/engines/hymt_engine.dart:835`,
// `VieneuTtsEngine.dispose()` ở
// `lib/features/tts/engines/vieneu_tts_engine.dart:221`,
// `AiEngineGemma.dispose()` ở
// `packages/in4up_ai/lib/src/engine/ai_engine_gemma.dart:275`) nhưng KHÔNG ai
// gọi chúng theo THỜI GIAN: dịch xong 1 đoạn là model GGUF (~1,1 GB Hy-MT,
// 170 MB VieNeu Q8_0, ~292 MB Gemma bf16) nằm nguyên trong RAM tới khi app
// bị hệ thống thu hồi. Watchdog này chỉ gọi đúng nút tắt đã có, sau một
// khoảng rảnh, và chỉ khi model KHÔNG đang được dùng.
//
// Vì sao KHÔNG nhét vào `lib/services/offline_model_gate.dart`: file đó là
// hàm PHÁN XÉT ("có nên dùng model này không"), không quản lý tài nguyên.
//
// Nguyên tắc thiết kế (để test được 100% trên host VM, không cần thiết bị):
//   • Đồng hồ BƠM TỪ NGOÀI (`now`) ⇒ test không `sleep`, không flaky.
//   • `autoStart: false` cho test (không có Timer treo cuối test).
//   • Mọi lần `unload()` bọc try/catch: model hỏng/engine ném lỗi KHÔNG được
//     làm crash app — các id khác vẫn tiếp tục được xử lý.
//   • Sau khi unload, entry vẫn ĐĂNG KÝ nhưng đánh dấu `unloaded = true`
//     ⇒ không gọi unload lặp lại mỗi tick. Lần dùng kế tiếp gọi `touch()`
//     ⇒ hạ cờ ⇒ engine nạp lại model ở lần dùng sau (lazy reload).
//   • Có 2 lớp chặn "đang dùng": `retain()/release()` (đếm tham chiếu) và
//     `isBusy` (predicate do engine cung cấp).
//
// Cách dùng (xem 3 engine đã nối):
//   ModelIdleWatchdog.instance.register('hymt', engine.disposeRuntime);
//   ModelIdleWatchdog.instance.touch('hymt');   // mỗi lượt dùng
//
// Log: `[in4up-perf] unload <id> sau <N>s rảnh` để owner đọc được logcat.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Hàm nhả model của một engine (thường là `dispose`/`disposeRuntime` có sẵn).
typedef ModelUnloadFn = Future<void> Function();

/// Engine tự báo "đang có thao tác chạy" ⇒ watchdog KHÔNG được nhả.
typedef ModelBusyFn = bool Function();

class _IdleEntry {
  _IdleEntry({
    required this.id,
    required this.unload,
    required this.lastActivity,
  });

  final String id;
  ModelUnloadFn unload;
  ModelBusyFn? isBusy;

  /// Mốc (theo đồng hồ bơm từ ngoài) của lượt dùng gần nhất.
  DateTime lastActivity;

  /// Số tham chiếu đang giữ model (retain/release).
  int retained = 0;

  /// Đã nhả vì rảnh (chờ `touch()` để bật lại). Tránh gọi unload lặp.
  bool unloaded = false;

  /// Số lần đã nhả — chỉ để test/telemetry.
  int unloadCount = 0;
}

class ModelIdleWatchdog {
  ModelIdleWatchdog({
    Duration idleTimeout = defaultIdleTimeout,
    DateTime Function()? now,
    bool enabled = defaultEnabled,
    bool autoStart = true,
    Duration tick = defaultTick,
    void Function(String message)? log,
  })  : _idleTimeout = idleTimeout,
        _now = now ?? DateTime.now,
        _enabled = enabled,
        _tick = tick,
        _log = log ?? debugPrint {
    if (autoStart) _start();
  }

  /// Mặc định 5 phút: đủ dài để không nhả model giữa 2 câu đọc liên tiếp,
  /// đủ ngắn để RAM tụt trong một phiên dùng bình thường.
  static const Duration defaultIdleTimeout = Duration(minutes: 5);

  /// Nhịp kiểm tra — rẻ (chỉ so sánh mốc thời gian), không đụng native.
  static const Duration defaultTick = Duration(seconds: 30);

  /// Mặc định BẬT (owner: "tiết kiệm RAM" là mặc định tốt cho máy yếu).
  static const bool defaultEnabled = true;

  /// Khoá SharedPreferences cho công tắc ở Settings (đọc/ghi ở màn Settings,
  /// watchdog giữ THUẦN — không I/O).
  static const String prefEnabledKey = 'perf_model_idle_unload_enabled';

  /// Singleton cho app thật. Test LUÔN tạo instance riêng.
  static final ModelIdleWatchdog instance = ModelIdleWatchdog();

  final Duration _idleTimeout;
  final Duration _tick;
  final DateTime Function() _now;
  final void Function(String message) _log;

  bool _enabled;
  Timer? _timer;
  bool _disposed = false;

  final Map<String, _IdleEntry> _entries = <String, _IdleEntry>{};

  Duration get idleTimeout => _idleTimeout;
  bool get enabled => _enabled;
  bool get isRunning => _timer?.isActive ?? false;

  /// Id đang được theo dõi (đã đăng ký).
  Iterable<String> get registeredIds => _entries.keys;

  bool isRegistered(String id) => _entries.containsKey(id);

  /// Đã nhả vì rảnh và chưa dùng lại.
  bool isUnloaded(String id) => _entries[id]?.unloaded ?? false;

  /// Số lần đã nhả (test/telemetry).
  int unloadCountOf(String id) => _entries[id]?.unloadCount ?? 0;

  /// Bật/tắt công tắc "Nhả model khi rảnh" (Settings gọi).
  ///
  /// Tắt ⇒ huỷ Timer (không tốn pin) và KHÔNG nhả gì thêm. Bật lại ⇒ chạy
  /// tiếp. Không tự nhả model đang giữ khi vừa tắt.
  void setEnabled(bool value) {
    if (_disposed || _enabled == value) return;
    _enabled = value;
    if (_enabled) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
    _log('[in4up-perf] idle-watchdog ${_enabled ? "bật" : "tắt"}');
  }

  /// Đăng ký (hoặc cập nhật) cách nhả model của một engine.
  ///
  /// Gọi nhiều lần với cùng [id] là AN TOÀN (idempotent) — 3 engine đã nối gọi
  /// ở mỗi lượt dùng nên không cần cờ "đã đăng ký" ở phía engine.
  void register(String id, ModelUnloadFn unload, {ModelBusyFn? isBusy}) {
    if (_disposed) return;
    final existing = _entries[id];
    if (existing == null) {
      _entries[id] = _IdleEntry(
        id: id,
        unload: unload,
        lastActivity: _now(),
      )..isBusy = isBusy;
      return;
    }
    existing.unload = unload;
    if (isBusy != null) existing.isBusy = isBusy;
  }

  /// Đánh dấu vừa dùng model [id]: reset đồng hồ rảnh + hạ cờ "đã nhả".
  ///
  /// Engine chưa đăng ký thì `touch()` là no-op (không tự tạo entry rỗng —
  /// tránh nhả một model chưa có hàm nhả).
  void touch(String id) {
    if (_disposed) return;
    final entry = _entries[id];
    if (entry == null) return;
    entry.lastActivity = _now();
    entry.unloaded = false;
  }

  /// Giữ model [id] trong lúc đang có thao tác (đếm tham chiếu).
  void retain(String id) {
    if (_disposed) return;
    final entry = _entries[id];
    if (entry == null) return;
    entry.retained++;
    entry.lastActivity = _now();
    entry.unloaded = false;
  }

  /// Trả tham chiếu đã giữ ở [retain]; về 0 mới được nhả khi rảnh.
  void release(String id) {
    if (_disposed) return;
    final entry = _entries[id];
    if (entry == null) return;
    if (entry.retained > 0) entry.retained--;
    entry.lastActivity = _now();
  }

  bool isRetained(String id) => (_entries[id]?.retained ?? 0) > 0;

  /// Bỏ theo dõi [id] (KHÔNG nhả model — engine/app tự quyết định).
  void unregister(String id) {
    _entries.remove(id);
  }

  /// Một nhịp kiểm tra. Trả về `true` nếu lần này có ít nhất 1 model được nhả.
  ///
  /// Public để test bơm đồng hồ rồi gọi trực tiếp (không cần Timer).
  Future<bool> checkIdle() async {
    if (_disposed || !_enabled) return false;
    final snapshot = _entries.values.toList(growable: false);
    final now = _now();
    var unloadedAny = false;
    for (final entry in snapshot) {
      if (_disposed) break;
      // Entry có thể vừa bị unregister trong lúc await unload của entry trước.
      if (!identical(_entries[entry.id], entry)) continue;
      if (entry.unloaded) continue;
      if (entry.retained > 0) continue;
      var busy = false;
      try {
        busy = entry.isBusy?.call() ?? false;
      } catch (e) {
        // Predicate hỏng ⇒ coi như ĐANG BẬN (an toàn: thà không nhả).
        busy = true;
        _log('[in4up-perf] isBusy(${entry.id}) lỗi: $e — bỏ qua nhịp này');
      }
      if (busy) {
        entry.lastActivity = now;
        continue;
      }
      final idle = now.difference(entry.lastActivity);
      if (idle < _idleTimeout) continue;

      // Đánh dấu TRƯỚC khi await: nếu unload chậm, nhịp sau không gọi chồng.
      entry.unloaded = true;
      entry.unloadCount++;
      unloadedAny = true;
      _log('[in4up-perf] unload ${entry.id} sau ${idle.inSeconds}s rảnh');
      try {
        await entry.unload();
      } catch (e) {
        // Không bao giờ để một engine hỏng làm sập app / chặn engine khác.
        _log('[in4up-perf] unload ${entry.id} lỗi (đã bỏ qua): $e');
      }
    }
    return unloadedAny;
  }

  void _start() {
    if (_disposed || !_enabled) return;
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) {
      unawaited(checkIdle());
    });
  }

  /// Dừng đồng hồ + quên mọi entry. KHÔNG nhả model (app đang thoát thì OS
  /// thu hồi; gọi unload lúc dispose dễ race với chính engine đang dispose).
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _entries.clear();
  }
}
