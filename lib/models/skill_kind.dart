/// ═══════════════════════════════════════════════════════════════
/// SKILL KIND — 6 trục / 2 nhóm (ADR-0015)
///
/// Enum chính cho toàn bộ hệ thống đánh giá từ vựng. Append-only:
/// chỉ thêm vào cuối, KHÔNG chèn giữa (ReviewEvent lưu theo name →
/// dữ liệu cũ parse bình thường).
///
/// Mapping với 2 enum cũ (audit fix MED-5):
///   SkillKind.understand  ↔ WordEntry.Skill.understand  ↔ SkillDimension.understanding
///   SkillKind.listen      ↔ WordEntry.Skill.listen      ↔ SkillDimension.listening
///   SkillKind.read        ↔ WordEntry.Skill.read        ↔ SkillDimension.reading
///   SkillKind.use/speak/write — trục output mới (không có trong 2 enum cũ).
///
/// Mirror (ADR-0015): mỗi input có 1 output đối đỉnh trên đường kính:
///   understand ↔ use, listen ↔ speak, read ↔ write.
/// ═══════════════════════════════════════════════════════════════
library;

enum SkillKind {
  // ── Nhóm Input (receptive) ──
  understand,
  listen,
  read,

  // ── Nhóm Output (productive) ──
  use, // Dùng nghĩa (form + sentence)
  speak, // Nói (phát âm từ đơn)
  write, // Viết (chính tả từ đơn)
}

extension SkillKindInfo on SkillKind {
  /// Nhóm: Input (receptive) hay Output (productive).
  bool get isInput =>
      this == SkillKind.understand ||
      this == SkillKind.listen ||
      this == SkillKind.read;

  bool get isOutput => !isInput;

  /// Label nhóm (UI).
  String get groupLabel => isInput ? 'Input' : 'Output';

  /// Trục đối đỉnh trên đường kính (production gap).
  SkillKind get mirror {
    switch (this) {
      case SkillKind.understand:
        return SkillKind.use;
      case SkillKind.use:
        return SkillKind.understand;
      case SkillKind.listen:
        return SkillKind.speak;
      case SkillKind.speak:
        return SkillKind.listen;
      case SkillKind.read:
        return SkillKind.write;
      case SkillKind.write:
        return SkillKind.read;
    }
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Mapping SkillKind ↔ WordEntry.Skill (input only)
/// ═══════════════════════════════════════════════════════════════

/// Chuyển SkillKind → WordEntry.Skill. Chỉ áp dụng cho input
/// (understand/listen/read). Output trả null (không có trong enum cũ).
SkillKind? wordEntrySkillToSkillKind(String skillName) {
  switch (skillName) {
    case 'understand':
      return SkillKind.understand;
    case 'listen':
      return SkillKind.listen;
    case 'read':
      return SkillKind.read;
    default:
      return null;
  }
}

/// Chuyển SkillKind → SkillDimension (knowledge). Chỉ input.
/// (import knowledge/models/learning_state.dart ở nơi dùng)
SkillKind? skillDimensionToSkillKind(String dimensionName) {
  switch (dimensionName) {
    case 'understanding':
      return SkillKind.understand;
    case 'listening':
      return SkillKind.listen;
    case 'reading':
      return SkillKind.read;
    default:
      return null;
  }
}

/// SkillKind → SkillDimension (input only; output trả null).
String? skillKindToDimensionName(SkillKind kind) {
  switch (kind) {
    case SkillKind.understand:
      return 'understanding';
    case SkillKind.listen:
      return 'listening';
    case SkillKind.read:
      return 'reading';
    default:
      return null;
  }
}

/// SkillKind → WordEntry.Skill name (input only; output trả null).
String? skillKindToWordEntrySkillName(SkillKind kind) {
  switch (kind) {
    case SkillKind.understand:
      return 'understand';
    case SkillKind.listen:
      return 'listen';
    case SkillKind.read:
      return 'read';
    default:
      return null;
  }
}
