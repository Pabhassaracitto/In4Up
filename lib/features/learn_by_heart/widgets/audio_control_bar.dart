// lib/features/learn_by_heart/widgets/audio_control_bar.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import '../models/learn_by_heart_item.dart';
import '../services/multilingual_audio_service.dart';

class AudioControlBar extends StatelessWidget {
  final MultilingualAudioService audioService;
  final VoidCallback onPlayPause;
  final LearnByHeartItem? item;

  const AudioControlBar({
    super.key,
    required this.audioService,
    required this.onPlayPause,
    this.item,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: audioService,
      builder: (context, _) {
        final isPlaying = audioService.isPlaying;
        final speed = audioService.speed;
        final isLooping = audioService.isLoopingChunk;
        final langMode = audioService.langMode;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Play / Pause main button
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPlayPause();
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C63FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Speed selector
              _ActionButton(
                label: '${speed}x',
                icon: Icons.speed_rounded,
                isActive: speed != 1.0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (speed == 0.75) {
                    audioService.setSpeed(1.0);
                  } else if (speed == 1.0) {
                    audioService.setSpeed(1.25);
                  } else {
                    audioService.setSpeed(0.75);
                  }
                },
              ),
              const SizedBox(width: 8),

              // Loop chunk button
              _ActionButton(
                label: 'Lặp đoạn',
                icon: Icons.repeat_rounded,
                isActive: isLooping,
                onTap: () {
                  HapticFeedback.selectionClick();
                  audioService.toggleLoopChunk();
                },
              ),
              const Spacer(),

              // Language selector popup
              PopupMenuButton<PlaybackLanguageMode>(
                initialValue: langMode,
                onSelected: (mode) {
                  HapticFeedback.selectionClick();
                  audioService.setLanguageMode(mode);
                },
                color: const Color(0xFF1E293B),
                itemBuilder: (context) {
                  final source = item?.sourceLanguage.displayName(
                        Localizations.localeOf(context).languageCode,
                      ) ??
                      'Pali';
                  final target = item?.targetLanguage.displayName(
                        Localizations.localeOf(context).languageCode,
                      ) ??
                      'Tiếng Việt';
                  return [
                    PopupMenuItem(
                      value: PlaybackLanguageMode.bilingual,
                      child: Text(
                        'Song ngữ ($source + $target)',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: PlaybackLanguageMode.source,
                      child: Text(
                        'Chỉ $source',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: PlaybackLanguageMode.target,
                      child: Text(
                        'Chỉ $target',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ];
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.language_rounded, size: 16, color: Color(0xFFFFD54F)),
                      const SizedBox(width: 6),
                      Text(
                        _getLangLabel(langMode),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getLangLabel(PlaybackLanguageMode mode) {
    final source = item?.sourceLanguage.labelEn ?? 'Pali';
    final target = item?.targetLanguage.labelVi ?? 'Tiếng Việt';
    switch (mode) {
      case PlaybackLanguageMode.bilingual:
        return 'Song ngữ';
      case PlaybackLanguageMode.source:
        return source;
      case PlaybackLanguageMode.target:
        return target;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF818CF8) : Colors.white70;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF6C63FF).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
