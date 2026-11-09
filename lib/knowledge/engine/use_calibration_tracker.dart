/// ═══════════════════════════════════════════════════════════════
/// USE CALIBRATION TRACKER — theo dõi calibration Dùng 2 tuần (P4)
///
/// Theo dõi 2 EMA con (useForm, useSentence) qua thời gian để
/// calibrate ngưỡng archetype + alpha EMA bằng dữ liệu thật.
///
/// Rủi ro HIGH-2: lạm phát mastery ở Dùng (sub-test dễ).
/// Hồi phục: nhãn "một phần", không bù 0, calibration 2 tuần,
/// không công bố level khi dữ liệu mỏng (SPEC §5.2).
///
/// Thuần chức năng — không I/O, deterministic, test đơn giản.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/engine/ema_engine.dart' show MasteryVector;
import 'package:in4up/knowledge/models/evidence_metadata.dart';

/// 1 ghi nhận calibration: timestamp + useForm + useSentence EMA.
class CalibrationSample {
  final DateTime timestamp;
  final double useForm;
  final double useSentence;
  final double useDisplay;

  const CalibrationSample({
    required this.timestamp,
    required this.useForm,
    required this.useSentence,
    required this.useDisplay,
  });

  @override
  String toString() =>
      'CalibrationSample(${timestamp.toIso8601String()}, form: ${useForm.toStringAsFixed(3)}, sentence: ${useSentence.toStringAsFixed(3)})';
}

/// Theo dõi calibration Dùng — thuần chức năng.
class UseCalibrationTracker {
  final List<CalibrationSample> samples = [];

  /// Ghi nhận 1 sample từ MasteryVector.
  void record(MasteryVector mv, DateTime at) {
    samples.add(CalibrationSample(
      timestamp: at,
      useForm: mv.useForm,
      useSentence: mv.useSentence,
      useDisplay: mv.useDisplay,
    ));
  }

  /// Số sample đã ghi nhận.
  int get count => samples.length;

  /// Đã đủ 2 tuần (14 ngày) calibration?
  ///
  /// [since] mốc bắt đầu calibration.
  bool hasTwoWeeksCalibration(DateTime since) {
    if (samples.isEmpty) return false;
    final latest = samples.last.timestamp;
    return latest.difference(since) >= const Duration(days: 14);
  }

  /// Đề xuất alpha mới dựa trên dữ liệu calibration.
  ///
  /// Logic placeholder (P4 calibrate thật):
  ///   - Nếu dữ liệu mỏng (< 10 sample) → giữ alpha default.
  ///   - Nếu variance cao → giảm alpha (ổn định hơn).
  ///   - Nếu variance thấp → tăng alpha (nhạy hơn).
  ///
  /// [defaultAlpha] alpha mặc định (kDefaultEmaAlpha = 0.2).
  double suggestAlpha({required double defaultAlpha}) {
    if (samples.isEmpty) return defaultAlpha;
    if (samples.length < 10) {
      return defaultAlpha; // dữ liệu mỏng → không thay đổi
    }

    // Tính variance của useDisplay.
    final mean = samples
        .map((s) => s.useDisplay)
        .fold<double>(0, (a, b) => a + b) / samples.length;
    final variance = samples
        .map((s) => (s.useDisplay - mean) * (s.useDisplay - mean))
        .fold<double>(0, (a, b) => a + b) / samples.length;

    if (variance > 0.1) {
      // Variance cao → mastery dao động nhiều → giảm alpha.
      return (defaultAlpha * 0.7).clamp(0.05, 0.2);
    } else if (variance < 0.02) {
      // Variance thấp → mastery ổn định → tăng alpha.
      return (defaultAlpha * 1.3).clamp(0.1, 0.3);
    }
    return defaultAlpha;
  }

  /// Rõ ràng dữ liệu đủ để công bố level?
  ///
  /// Không công bố level khi dữ liệu mỏng (SPEC §5.2).
  bool isReadyForLevelAnnouncement({required DateTime since}) {
    return hasTwoWeeksCalibration(since) && count >= 20;
  }

  /// Xóa tất cả sample (reset calibration).
  void reset() {
    samples.clear();
  }
}

/// ═══════════════════════════════════════════════════════════════
/// ROLLBACK FLAG — hexagon_v1 (ADR-0020 §3)
///
/// Flag có thể tắt → Venn/Triangle cũ chạy song song.
/// Rollback sẵn sàng: chỉ cần tắt flag, không cần rollback code.
/// ═══════════════════════════════════════════════════════════════

/// Trạng thái flag — on/off.
enum HexagonFlagState { on, off }

/// Helper cho rollback flag — thuần chức năng.
class HexagonRollbackFlag {
  HexagonRollbackFlag._();

  /// Bật flag (hexagon view).
  static HexagonFlagState on() => HexagonFlagState.on;

  /// Tắt flag (Venn/Triangle cũ).
  static HexagonFlagState off() => HexagonFlagState.off;

  /// Đảo trạng thái (toggle).
  static HexagonFlagState toggle(HexagonFlagState current) =>
      current == HexagonFlagState.on
          ? HexagonFlagState.off
          : HexagonFlagState.on;

  /// Có đang rollback? (flag tắt = rollback về Venn/Triangle).
  static bool isRollback(HexagonFlagState state) =>
      state == HexagonFlagState.off;
}
