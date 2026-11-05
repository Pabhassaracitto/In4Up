/// ═══════════════════════════════════════════════════════════════
/// ARCHETYPE CLASSIFIER — level tổng hợp (ADR-0019)
///
/// Level KHÔNG gộp SM-2 (ADR-0001). Không lưu scalar tổng, không dùng
/// diện tích làm level. Dùng 8 archetype với ngưỡng [P0 calibrate].
///
/// Gate: chặn lên level functionalBalanced/fullMastery nếu KHÔNG có
/// bằng chứng output (use/speak/write) — ADR-0019 §1.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:in4up/knowledge/engine/ema_engine.dart' show MasteryVector;
import 'package:in4up/knowledge/models/learning_state.dart' show SkillDimension;

/// 8 archetype — level tổng hợp (ADR-0019 §1).
enum Archetype {
  /// Không có bằng chứng hoặc mọi skill thấp.
  blindSpot,

  /// Chỉ nghe tốt — listening cao, còn lại thấp.
  passiveListener,

  /// Chỉ đọc tốt — reading cao, còn lại thấp.
  textReader,

  /// Thu nhận tốt nhưng không sản xuất — input cao, output thấp/không có.
  receptiveHoarder,

  /// Chỉ nói tốt (giảm nguyơng) — speak cao, input thấp.
  imitativeSpeaker,

  /// Sản xuất tốt nhưng không thu nhận sâu — output cao, input thấp.
  productiveAsymmetric,

  /// Cân bằng vừa phải — cả input + output ở mức trung bình.
  functionalBalanced,

  /// Giỏi cả 6 trục — input + output đều cao.
  fullMastery,
}

extension ArchetypeLabel on Archetype {
  String get label {
    switch (this) {
      case Archetype.blindSpot:
        return 'Chưa vững';
      case Archetype.passiveListener:
        return 'Chỉ nghe được';
      case Archetype.textReader:
        return 'Chỉ đọc được';
      case Archetype.receptiveHoarder:
        return 'Nhận được, chưa dùng';
      case Archetype.imitativeSpeaker:
        return 'Chỉ nói được';
      case Archetype.productiveAsymmetric:
        return 'Dùng được, chưa hiểu sâu';
      case Archetype.functionalBalanced:
        return 'Cân bằng';
      case Archetype.fullMastery:
        return 'Thành thạo';
    }
  }
}

/// Ngưỡng phân loại archetype — [P0 calibrate bằng dữ liệu thật].
/// Giá trị placeholder, không phải ngưỡng "đúng". P4 calibrate.
class ArchetypeThresholds {
  final double low;    // < low → "thấp"
  final double high;   // >= high → "cao"

  const ArchetypeThresholds({
    this.low = 0.3,
    this.high = 0.7,
  });

  static const ArchetypeThresholds placeholder = ArchetypeThresholds();
}

/// Bộ phân loại archetype — thuần chức năng.
class ArchetypeClassifier {
  final ArchetypeThresholds thresholds;

  /// [requireOutputGate] — chặn functionalBalanced/fullMastery nếu
  /// không có bằng chứng output (ADR-0019 §1). Mặc định true.
  final bool requireOutputGate;

  const ArchetypeClassifier({
    this.thresholds = ArchetypeThresholds.placeholder,
    this.requireOutputGate = true,
  });

  /// Phân loại 1 Mastery Vector → archetype.
  Archetype classify(MasteryVector mv) {
    final low = thresholds.low;
    final high = thresholds.high;

    // ── Gate: không output evidence → không lên functional/full ──
    final hasOutput = mv.hasOutputEvidence;

    // ── Phân cấp từng skill ──
    final Map<SkillDimension, bool> highMap = <SkillDimension, bool>{
      SkillDimension.understanding: mv.understanding >= high,
      SkillDimension.listening: mv.listening >= high,
      SkillDimension.reading: mv.reading >= high,
      SkillDimension.speak: mv.hasSpeak && mv.speak >= high,
      SkillDimension.write: mv.hasWrite && mv.write >= high,
      SkillDimension.use: mv.hasUse && mv.useDisplay >= high,
    };

    final inputHighCount =
        [SkillDimension.understanding, SkillDimension.listening, SkillDimension.reading]
            .where((d) => highMap[d]).length;
    final outputHighCount =
        [SkillDimension.use, SkillDimension.speak, SkillDimension.write]
            .where((d) => highMap[d]).length;

    final inputLow = mv.understanding < low &&
        mv.listening < low &&
        mv.reading < low;
    final outputLow = (!mv.hasUse || mv.useDisplay < low) &&
        (!mv.hasSpeak || mv.speak < low) &&
        (!mv.hasWrite || mv.write < low);

    final inputHigh = inputHighCount >= 2;
    // outputHighAny = ít nhất 1 output skill cao (use/speak/write).
    final outputHighAny = outputHighCount >= 1;

    // ── Phân loại theo priority ──
    // 1. blindSpot: không bằng chứng hoặc mọi skill thấp.
    if (!mv.hasInputEvidence && !hasOutput) return Archetype.blindSpot;
    if (inputLow && outputLow) return Archetype.blindSpot;

    // 2. passiveListener: chỉ listening cao, input khác thấp, output thấp.
    if (highMap[SkillDimension.listening] &&
        !highMap[SkillDimension.understanding] &&
        !highMap[SkillDimension.reading] &&
        outputLow) {
      return Archetype.passiveListener;
    }

    // 3. textReader: chỉ reading cao, input khác thấp, output thấp.
    if (highMap[SkillDimension.reading] &&
        !highMap[SkillDimension.understanding] &&
        !highMap[SkillDimension.listening] &&
        outputLow) {
      return Archetype.textReader;
    }

    // 4. imitativeSpeaker: chỉ speak cao (output ĐỘC LẠC), input thấp.
    //    speak + write/use cao → không phải imitativeSpeaker (→ productive).
    if (highMap[SkillDimension.speak] &&
        !highMap[SkillDimension.write] &&
        !highMap[SkillDimension.use] &&
        inputLow) {
      return Archetype.imitativeSpeaker;
    }

    // 5. productiveAsymmetric: output cao (bất kỳ), input thấp.
    //    "only speak" đã bị bước 4 bắt → đây là speak+write, use, …
    if (outputHighAny && inputLow) {
      return Archetype.productiveAsymmetric;
    }

    // 6. receptiveHoarder: input cao, không output cao.
    if (inputHigh && !outputHighAny) {
      return Archetype.receptiveHoarder;
    }

    // 7. fullMastery: input + output đều cao. Gate: cần output evidence.
    if (inputHigh && outputHighAny) {
      if (requireOutputGate && !hasOutput) return Archetype.receptiveHoarder;
      return Archetype.fullMastery;
    }

    // 8. functionalBalanced: còn lại — cả input + output ở mức trung bình.
    // Gate: cần output evidence.
    if (requireOutputGate && !hasOutput) {
      return inputHigh ? Archetype.receptiveHoarder : Archetype.blindSpot;
    }
    return Archetype.functionalBalanced;
  }
}
