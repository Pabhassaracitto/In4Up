// lib/features/dharma/services/dharma_store.dart
//
// PLAN-042 / ADR-0022 — lưu trữ pháp thoại.
//
// BA BOX, BA MỤC ĐÍCH KHÁC NHAU (không gộp — xem ADR-0022 quyết định #2):
//   dharma_catalog   : metadata series/buổi. Được QUÉT LẠI ghi đè mỗi lần.
//   dharma_progress  : tiến độ nghe, khoá theo `episodeKey`. CHỈ app ghi.
//   dharma_overrides : sửa tay của người dùng (tên vị Thầy, tên series).
//                      Thắng mọi suy luận của parser.
//
// Tất cả đọc/ghi dạng JSON string để không phải đăng ký Hive TypeAdapter
// (giống `audio_library`, `audio_playlists` đang làm). Hive được khởi tạo trong
// `StorageService.initialize()` và `main.dart`; store này mở box theo nhu cầu
// nên test thuần không cần khởi tạo Hive.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/dharma_talk.dart';

class DharmaStore {
  DharmaStore._();

  /// Dành cho test: tạo instance KHÔNG dùng chung singleton, để bản fake trong
  /// test có thể `extends DharmaStore` mà không chạm Hive của app thật.
  @visibleForTesting
  DharmaStore.forTest();

  static final DharmaStore instance = DharmaStore._();

  static const String catalogBox = 'dharma_catalog';
  static const String progressBox = 'dharma_progress';
  static const String overridesBox = 'dharma_overrides';

  bool _opened = false;

  Future<void> _ensureBoxes() async {
    if (_opened) return;
    await Future.wait([
      Hive.openBox<String>(catalogBox),
      Hive.openBox<String>(progressBox),
      Hive.openBox<String>(overridesBox),
    ]);
    _opened = true;
  }

  // ── Catalog ──────────────────────────────────────────────────
  Future<List<DharmaSeries>> loadSeries() async {
    try {
      await _ensureBoxes();
      final box = Hive.box<String>(catalogBox);
      final out = <DharmaSeries>[];
      for (final raw in box.values) {
        try {
          out.add(DharmaSeries.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          ));
        } catch (e) {
          debugPrint('[Dharma] Bỏ qua series hỏng: $e');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[Dharma] loadSeries lỗi: $e');
      return const [];
    }
  }

  /// Ghi đè toàn bộ catalog (kết quả quét mới). Không chạm progress.
  Future<void> saveSeries(List<DharmaSeries> series) async {
    try {
      await _ensureBoxes();
      final box = Hive.box<String>(catalogBox);
      final payload = <String, String>{
        for (final s in series) s.seriesKey: jsonEncode(s.toJson()),
      };
      // Xoá series đã biến mất khỏi thư mục nguồn, nhưng KHÔNG xoá progress.
      final stale = box.keys
          .where((key) => !payload.containsKey(key))
          .toList(growable: false);
      await box.deleteAll(stale);
      await box.putAll(payload);
    } catch (e) {
      debugPrint('[Dharma] saveSeries lỗi: $e');
    }
  }

  // ── Progress ─────────────────────────────────────────────────
  Future<Map<String, DharmaProgress>> loadProgress() async {
    try {
      await _ensureBoxes();
      final box = Hive.box<String>(progressBox);
      final out = <String, DharmaProgress>{};
      for (final entry in box.toMap().entries) {
        try {
          out[entry.key] = DharmaProgress.fromJson(
            jsonDecode(entry.value) as Map<String, dynamic>,
          );
        } catch (e) {
          debugPrint('[Dharma] Bỏ qua progress hỏng (${entry.key}): $e');
        }
      }
      return out;
    } catch (e) {
      debugPrint('[Dharma] loadProgress lỗi: $e');
      return const {};
    }
  }

  Future<void> putProgress(DharmaProgress progress) async {
    if (progress.episodeKey.isEmpty) return;
    try {
      await _ensureBoxes();
      await Hive.box<String>(progressBox)
          .put(progress.episodeKey, jsonEncode(progress.toJson()));
    } catch (e) {
      debugPrint('[Dharma] putProgress lỗi: $e');
    }
  }

  Future<void> clearProgress(String episodeKey) async {
    try {
      await _ensureBoxes();
      await Hive.box<String>(progressBox).delete(episodeKey);
    } catch (e) {
      debugPrint('[Dharma] clearProgress lỗi: $e');
    }
  }

  // ── Overrides (sửa tay) ──────────────────────────────────────
  /// `speaker:<seriesKey>` → tên vị Thầy do người dùng đặt.
  static String speakerOverrideKey(String seriesKey) => 'speaker:$seriesKey';

  Future<Map<String, String>> loadOverrides() async {
    try {
      await _ensureBoxes();
      final box = Hive.box<String>(overridesBox);
      return {for (final e in box.toMap().entries) e.key: e.value};
    } catch (e) {
      debugPrint('[Dharma] loadOverrides lỗi: $e');
      return const {};
    }
  }

  Future<void> putOverride(String key, String value) async {
    try {
      await _ensureBoxes();
      final box = Hive.box<String>(overridesBox);
      if (value.trim().isEmpty) {
        await box.delete(key);
      } else {
        await box.put(key, value.trim());
      }
    } catch (e) {
      debugPrint('[Dharma] putOverride lỗi: $e');
    }
  }
}
