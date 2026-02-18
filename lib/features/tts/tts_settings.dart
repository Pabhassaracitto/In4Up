// lib/features/tts/tts_settings.dart

import 'package:flutter/material.dart';

/// Chế độ ưu tiên TTS
enum TtsPriority {
  /// Offline first → phát ngay, không delay
  offlineFirst,

  /// Online first → chất lượng cao hơn, có delay
  onlineFirst,

  /// Chỉ offline
  offlineOnly,

  /// Chỉ online (fallback offline nếu mất mạng)
  onlineOnly,
}

extension TtsPriorityExt on TtsPriority {
  String get label {
    switch (this) {
      case TtsPriority.offlineFirst:
        return 'Offline trước (nhanh)';
      case TtsPriority.onlineFirst:
        return 'Online trước (tự nhiên)';
      case TtsPriority.offlineOnly:
        return 'Chỉ Offline';
      case TtsPriority.onlineOnly:
        return 'Chỉ Online';
    }
  }

  String get description {
    switch (this) {
      case TtsPriority.offlineFirst:
        return 'Phát ngay bằng giọng máy, tải giọng đẹp nền';
      case TtsPriority.onlineFirst:
        return 'Chờ tải giọng tự nhiên, chậm hơn 1-2s';
      case TtsPriority.offlineOnly:
        return 'Không dùng mạng, phát ngay';
      case TtsPriority.onlineOnly:
        return 'Luôn dùng giọng online, cần mạng';
    }
  }

  IconData get icon {
    switch (this) {
      case TtsPriority.offlineFirst:
        return Icons.flash_on;
      case TtsPriority.onlineFirst:
        return Icons.cloud;
      case TtsPriority.offlineOnly:
        return Icons.cloud_off;
      case TtsPriority.onlineOnly:
        return Icons.cloud_done;
    }
  }
}

/// Thông tin 1 TTS engine cho UI
class TtsEngineInfo {
  final String id;
  final String name;
  final String description;
  final bool needsApiKey;
  final bool isOnline;
  final bool isEnabled;
  final int priority; // Thứ tự ưu tiên (nhỏ = ưu tiên hơn)

  const TtsEngineInfo({
    required this.id,
    required this.name,
    required this.description,
    this.needsApiKey = false,
    this.isOnline = true,
    this.isEnabled = true,
    this.priority = 99,
  });

  TtsEngineInfo copyWith({bool? isEnabled, int? priority}) {
    return TtsEngineInfo(
      id: id,
      name: name,
      description: description,
      needsApiKey: needsApiKey,
      isOnline: isOnline,
      isEnabled: isEnabled ?? this.isEnabled,
      priority: priority ?? this.priority,
    );
  }
}
