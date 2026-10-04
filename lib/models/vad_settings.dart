// ignore_for_file: constant_identifier_names

// lib/models/vad_settings.dart
// Soundlist – Cài đặt tách đoạn (VAD) có thể tinh chỉnh trong app.
//
// Giúp người dùng chỉnh ngay trên giao diện (không cần sửa code):
//   • preset  – Tách nhiều / Bình thường / Tách ít
//   • silence – khoảng lặng tối thiểu để coi là ranh giới (giây)
//   • segment – đoạn tối thiểu giữa hai ranh giới (giây)

class VadSettings {
  final double minSilenceSec;
  final double minSegmentSec;
  final double thresholdFactor;

  const VadSettings({
    this.minSilenceSec = 0.9,
    this.minSegmentSec = 6.0,
    this.thresholdFactor = 0.28,
  });

  static const normal = VadSettings();
  static const many = VadSettings(
    minSilenceSec: 0.5,
    minSegmentSec: 3.0,
    thresholdFactor: 0.22,
  );
  static const few = VadSettings(
    minSilenceSec: 1.6,
    minSegmentSec: 10.0,
    thresholdFactor: 0.38,
  );

  String get presetLabel {
    if (minSilenceSec <= 0.55 && minSegmentSec <= 3.5) return 'Tách nhiều';
    if (minSilenceSec >= 1.5 && minSegmentSec >= 9) return 'Tách ít';
    return 'Bình thường';
  }

  VadSettings copyWith({
    double? minSilenceSec,
    double? minSegmentSec,
    double? thresholdFactor,
  }) {
    return VadSettings(
      minSilenceSec: minSilenceSec ?? this.minSilenceSec,
      minSegmentSec: minSegmentSec ?? this.minSegmentSec,
      thresholdFactor: thresholdFactor ?? this.thresholdFactor,
    );
  }

  Map<String, dynamic> toJson() => {
        'minSilenceSec': minSilenceSec,
        'minSegmentSec': minSegmentSec,
        'thresholdFactor': thresholdFactor,
      };

  factory VadSettings.fromJson(Map<String, dynamic> j) => VadSettings(
        minSilenceSec: (j['minSilenceSec'] as num?)?.toDouble() ?? 0.9,
        minSegmentSec: (j['minSegmentSec'] as num?)?.toDouble() ?? 6.0,
        thresholdFactor: (j['thresholdFactor'] as num?)?.toDouble() ?? 0.28,
      );
}
