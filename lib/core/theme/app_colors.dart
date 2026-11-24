import 'package:flutter/material.dart';

/// 3-tier Apple HIG Dark Mode color system & semantic workspace tokens.
abstract final class AppColors {
  // ── 3-Tier Elevated Dark Surfaces ──────────────────────────────────────
  /// Level 0: Root Scaffold / canvas background.
  static const Color bgBase = Color(0xFF090D16);

  /// Level 1: Cards, workspace headers, bottom docks, toolbars.
  static const Color surfaceElevated = Color(0xFF121826);

  /// Level 2: Modal bottom sheets, dialogs, floating bubbles & popovers.
  static const Color surfaceModal = Color(0xFF1C2436);

  // ── Semantic Workspace Accents ─────────────────────────────────────────
  static const Color accentPrimary = Color(0xFF6C63FF);
  static const Color accentListen = Color(0xFF6C63FF);
  static const Color accentSpeak = Color(0xFFB388FF);
  static const Color accentRead = Color(0xFF2196F3);
  static const Color accentWrite = Color(0xFF26C6DA);
  static const Color accentUnderstand = Color(0xFFFFB300);
  static const Color accentRemember = Color(0xFF4CAF50);

  // ── Status & Feedback ──────────────────────────────────────────────────
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFEF5350);

  // ── Typography & Hairline Borders ──────────────────────────────────────
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);

  /// 1px hairline border (`rgba(255, 255, 255, 0.07)`).
  static const Color borderSubtle = Color(0x12FFFFFF);
  static const Color borderStrong = Color(0x24FFFFFF);
}
