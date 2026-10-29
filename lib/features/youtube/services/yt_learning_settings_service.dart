// YT-LR-002 / IN4-88 — Lưu/đọc cài đặt học tập của chế độ YouTube.
//
// Local-first: Hive trên máy, không gọi mạng. Cùng pattern với `YtHistory`
// (`lib/features/youtube/models/yt_video.dart`) để không thêm cơ chế mới.

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/yt_learning_settings.dart';

class YtLearningSettingsService {
  static const String _boxName = 'yt_learning_settings';
  static const String _key = 'settings';

  static Future<void> ensureOpen() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  /// Đọc cài đặt; trả về mặc định nếu chưa lưu hoặc dữ liệu hỏng.
  static YtLearningSettings load() {
    try {
      if (!Hive.isBoxOpen(_boxName)) return const YtLearningSettings();
      final raw = Hive.box<String>(_boxName).get(_key);
      if (raw == null || raw.isEmpty) return const YtLearningSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const YtLearningSettings();
      return YtLearningSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return const YtLearningSettings();
    }
  }

  static Future<void> save(YtLearningSettings settings) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      await Hive.box<String>(_boxName)
          .put(_key, jsonEncode(settings.toJson()));
    } catch (_) {
      // Cài đặt không sống còn: chấp nhận mất, không được làm crash màn học.
    }
  }
}
