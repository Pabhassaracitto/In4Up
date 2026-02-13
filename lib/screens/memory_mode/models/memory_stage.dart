// lib/screens/memory_mode/models/memory_stage.dart

import 'package:flutter/material.dart';

enum MemoryStage {
  seed,
  sprout,
  tree,
  branch,
  bud,
  bloom,
}

extension MemoryStageExtension on MemoryStage {
  // ==================== LABELS ====================
  String get label {
    switch (this) {
      case MemoryStage.seed:
        return 'Hột giống';
      case MemoryStage.sprout:
        return 'Cây non';
      case MemoryStage.tree:
        return 'Cây lớn';
      case MemoryStage.branch:
        return 'Nhánh';
      case MemoryStage.bud:
        return 'Nụ';
      case MemoryStage.bloom:
        return 'Hoa';
    }
  }

  String get emoji {
    switch (this) {
      case MemoryStage.seed:
        return '🌰';
      case MemoryStage.sprout:
        return '🌱';
      case MemoryStage.tree:
        return '🌳';
      case MemoryStage.branch:
        return '🌿';
      case MemoryStage.bud:
        return '🌸';
      case MemoryStage.bloom:
        return '🌺';
    }
  }

  String get description {
    switch (this) {
      case MemoryStage.seed:
        return 'Vừa học, cần ôn ngay';
      case MemoryStage.sprout:
        return 'Bắt đầu nhớ, dễ quên';
      case MemoryStage.tree:
        return 'Đang củng cố';
      case MemoryStage.branch:
        return 'Mở rộng liên kết';
      case MemoryStage.bud:
        return 'Gần thuộc';
      case MemoryStage.bloom:
        return 'Đã thuộc!';
    }
  }

  // ==================== VISUAL PROPERTIES ====================
  double get fontScale {
    switch (this) {
      case MemoryStage.seed:
        return 1.6;
      case MemoryStage.sprout:
        return 1.35;
      case MemoryStage.tree:
        return 1.15;
      case MemoryStage.branch:
        return 1.0;
      case MemoryStage.bud:
        return 0.85;
      case MemoryStage.bloom:
        return 0.75;
    }
  }

  double get cardMinHeight {
    switch (this) {
      case MemoryStage.seed:
        return 100;
      case MemoryStage.sprout:
        return 85;
      case MemoryStage.tree:
        return 72;
      case MemoryStage.branch:
        return 60;
      case MemoryStage.bud:
        return 52;
      case MemoryStage.bloom:
        return 44;
    }
  }

  Color get primaryColor {
    switch (this) {
      case MemoryStage.seed:
        return const Color(0xFFFF5252);
      case MemoryStage.sprout:
        return const Color(0xFFFF9800);
      case MemoryStage.tree:
        return const Color(0xFFFFEB3B);
      case MemoryStage.branch:
        return const Color(0xFF4CAF50);
      case MemoryStage.bud:
        return const Color(0xFF2196F3);
      case MemoryStage.bloom:
        return const Color(0xFF9C27B0);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case MemoryStage.seed:
        return const Color(0xFFFF5252).withValues(alpha: 0.20);
      case MemoryStage.sprout:
        return const Color(0xFFFF9800).withValues(alpha: 0.15);
      case MemoryStage.tree:
        return const Color(0xFFFFEB3B).withValues(alpha: 0.10);
      case MemoryStage.branch:
        return const Color(0xFF4CAF50).withValues(alpha: 0.08);
      case MemoryStage.bud:
        return const Color(0xFF2196F3).withValues(alpha: 0.06);
      case MemoryStage.bloom:
        return const Color(0xFF9C27B0).withValues(alpha: 0.04);
    }
  }

  double get textOpacity {
    switch (this) {
      case MemoryStage.seed:
        return 1.0;
      case MemoryStage.sprout:
        return 0.92;
      case MemoryStage.tree:
        return 0.80;
      case MemoryStage.branch:
        return 0.68;
      case MemoryStage.bud:
        return 0.55;
      case MemoryStage.bloom:
        return 0.45;
    }
  }

  double get borderWidth {
    switch (this) {
      case MemoryStage.seed:
        return 2.5;
      case MemoryStage.sprout:
        return 2.0;
      case MemoryStage.tree:
        return 1.5;
      case MemoryStage.branch:
        return 1.0;
      case MemoryStage.bud:
        return 0.5;
      case MemoryStage.bloom:
        return 0.0;
    }
  }

  double get elevation {
    switch (this) {
      case MemoryStage.seed:
        return 8.0;
      case MemoryStage.sprout:
        return 5.0;
      case MemoryStage.tree:
        return 3.0;
      case MemoryStage.branch:
        return 1.5;
      case MemoryStage.bud:
        return 0.5;
      case MemoryStage.bloom:
        return 0.0;
    }
  }

  // ==================== SRS INTERVALS ====================
  int get reviewIntervalHours {
    switch (this) {
      case MemoryStage.seed:
        return 1;
      case MemoryStage.sprout:
        return 8;
      case MemoryStage.tree:
        return 24;
      case MemoryStage.branch:
        return 72;
      case MemoryStage.bud:
        return 168;
      case MemoryStage.bloom:
        return 720;
    }
  }

  int get requiredCorrectReviews {
    switch (this) {
      case MemoryStage.seed:
        return 1;
      case MemoryStage.sprout:
        return 2;
      case MemoryStage.tree:
        return 3;
      case MemoryStage.branch:
        return 3;
      case MemoryStage.bud:
        return 2;
      case MemoryStage.bloom:
        return 1;
    }
  }

  MemoryStage? get next {
    final values = MemoryStage.values;
    final idx = values.indexOf(this);
    if (idx >= values.length - 1) return null;
    return values[idx + 1];
  }

  MemoryStage get demoted {
    switch (this) {
      case MemoryStage.seed:
        return MemoryStage.seed;
      case MemoryStage.sprout:
        return MemoryStage.seed;
      case MemoryStage.tree:
        return MemoryStage.sprout;
      case MemoryStage.branch:
        return MemoryStage.tree;
      case MemoryStage.bud:
        return MemoryStage.branch;
      case MemoryStage.bloom:
        return MemoryStage.bud;
    }
  }

  IconData get icon {
    switch (this) {
      case MemoryStage.seed:
        return Icons.grass;
      case MemoryStage.sprout:
        return Icons.eco;
      case MemoryStage.tree:
        return Icons.park;
      case MemoryStage.branch:
        return Icons.nature;
      case MemoryStage.bud:
        return Icons.local_florist;
      case MemoryStage.bloom:
        return Icons.filter_vintage;
    }
  }

  double get progressRatio {
    return index / (MemoryStage.values.length - 1);
  }
}
