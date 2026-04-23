import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vipsound/screens/read_mode/models/playback_recipe.dart';
import 'package:vipsound/screens/read_mode/services/playback_controller.dart';

class PresetRadialMenu extends StatelessWidget {
  final PlaybackController controller;
  final VoidCallback onDismiss;

  static const _presets = [
    (icon: '👂', label: 'Thụ động', recipe: PlaybackRecipe.enOnly),
    (icon: '🔊', label: 'Shadowing', recipe: PlaybackRecipe.shadowing),
    (icon: '📖', label: 'Song ngữ', recipe: PlaybackRecipe.bilingual),
    (icon: '⚡', label: 'Luyện nhanh', recipe: PlaybackRecipe.intensive),
    (icon: '🎯', label: 'Tự kiểm tra', recipe: PlaybackRecipe.quiz),
  ];

  const PresetRadialMenu({
    super.key,
    required this.controller,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Center: Cancel
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1F35),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white60, size: 24),
                ),

                // Radial presets
                ..._presets.asMap().entries.map((entry) {
                  final angle = (entry.key * 72 - 90) * (pi / 180);
                  final radius = 100.0;
                  final dx = cos(angle) * radius;
                  final dy = sin(angle) * radius;

                  return Positioned(
                    left: 140 + dx - 36,
                    top: 140 + dy - 36,
                    child: _PresetChip(
                      icon: entry.value.icon,
                      label: entry.value.label,
                      onTap: () async {
                        await controller.updateRecipe(entry.value.recipe);
                        onDismiss();
                        HapticFeedback.mediumImpact();
                      },
                      isActive: controller.recipe == entry.value.recipe,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _PresetChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Chọn chế độ $label',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF1A1F35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF6C63FF)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
