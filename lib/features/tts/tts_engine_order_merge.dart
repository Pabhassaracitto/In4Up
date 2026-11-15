// lib/features/tts/tts_engine_order_merge.dart
//
// PSRC-245 — TRỘN thứ tự engine TTS đã lưu với danh sách engine hiện có.
//
// Lỗi gốc (bản 1.29.0-Beta): `TtsService._loadPersistedSettings` nối mọi
// engine MỚI xuống CUỐI rồi đánh lại `priority` theo vị trí. Người dùng nâng
// cấp từ ≤1.28 đã có prefs `piper, offline, edge…` (chưa có `vieneu_tts`) ⇒
// VieNeu-TTS bị xếp sau cả `offline_tts` (giọng máy). `orderTtsCandidates`
// sắp theo `priority`, và giọng máy thì luôn phát được ⇒ VieNeu **không bao
// giờ được gọi**, dù đã import đủ model + giọng. Người dùng thấy "vẫn phát
// bằng Piper/hệ thống" và tưởng lỗi native.
//
// Cách sửa: engine mới được CHÈN vào đúng chỗ theo **mức ưu tiên mặc định**
// của nó (vieneu=0 < piper=1 < offline=2 < edge=3 …), không phải nối cuối.
// Thứ tự TƯƠNG ĐỐI của các engine người dùng đã sắp được giữ nguyên — hàm
// chỉ chèn, không sắp lại toàn bộ.
//
// Hàm thuần (không Flutter, không SharedPreferences) để test được không cần
// dựng singleton TtsService.

import 'tts_settings.dart';

/// Phiên bản thuật toán trộn. Prefs ghi phiên bản này để lần mở app sau
/// không lặp lại bước di trú (xem [kEngineOrderReinsertOnMigration]).
const int kEngineOrderMergeVersion = 2;

/// Khoá prefs ghi phiên bản trộn (dùng trong `TtsService`).
const String kEngineOrderVersionKey = 'tts_engine_order_merge_version';

/// Các engine phải được coi là "mới" một lần duy nhất khi di trú từ phiên
/// bản trộn 1 (thuật toán nối-cuối): bản 1.29.0-Beta đã có thể ghi
/// `vieneu_tts` xuống cuối prefs của người dùng đã sờ vào Cài đặt giọng đọc.
/// Chỉ chèn lại đúng engine này, không xáo trộn engine khác.
const Set<String> kEngineOrderReinsertOnMigration = {'vieneu_tts'};

/// Trộn thứ tự engine đã lưu ([persistedIds]) với danh sách mặc định
/// ([defaults], đã sắp theo `priority` mặc định).
///
/// * Engine **đã có trong prefs**: giữ đúng thứ tự tương đối người dùng đã
///   sắp, giữ trạng thái bật/tắt đã lưu.
/// * Engine **mới** (có trong [defaults] nhưng không có trong prefs, hoặc
///   nằm trong [reinsertAsNew]): chèn ngay TRƯỚC engine đã có đầu tiên mà
///   mức ưu tiên mặc định lớn hơn nó ⇒ `vieneu_tts` (0) đứng trước
///   `piper_tts` (1) và `offline_tts` (2) kể cả với prefs cũ; engine online
///   mới (`edge_tts` 3) vẫn rơi xuống sau các engine offline như thiết kế
///   TTS-EDGE-001.
/// * `priority` của kết quả được đánh lại 0..n-1 theo đúng thứ tự trả về.
List<TtsEngineInfo> mergePersistedEngineOrder({
  required List<TtsEngineInfo> defaults,
  required List<String> persistedIds,
  required Map<String, bool> persistedEnabled,
  Set<String> reinsertAsNew = const <String>{},
}) {
  final defaultById = <String, TtsEngineInfo>{
    for (final engine in defaults) engine.id: engine,
  };
  final defaultRank = <String, int>{
    for (var i = 0; i < defaults.length; i++) defaults[i].id: i,
  };

  // 1) Thứ tự người dùng đã lưu, bỏ id lạ và id trùng.
  final ordered = <String>[];
  for (final id in persistedIds) {
    if (!defaultById.containsKey(id)) continue;
    if (reinsertAsNew.contains(id)) continue; // coi như engine mới
    if (ordered.contains(id)) continue;
    ordered.add(id);
  }

  // 2) Chèn engine mới theo mức ưu tiên mặc định.
  for (final engine in defaults) {
    if (ordered.contains(engine.id)) continue;
    final rank = defaultRank[engine.id]!;
    var insertAt = ordered.length;
    for (var i = 0; i < ordered.length; i++) {
      final existingRank = defaultRank[ordered[i]];
      if (existingRank != null && existingRank > rank) {
        insertAt = i;
        break;
      }
    }
    ordered.insert(insertAt, engine.id);
  }

  // 3) Dựng lại danh sách với priority liên tục.
  return <TtsEngineInfo>[
    for (var i = 0; i < ordered.length; i++)
      defaultById[ordered[i]]!.copyWith(
        isEnabled:
            persistedEnabled[ordered[i]] ?? defaultById[ordered[i]]!.isEnabled,
        priority: i,
      ),
  ];
}
