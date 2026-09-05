// lib/features/learn_by_heart/widgets/bilingual_verse_view.dart

import 'package:in4up/core/language/localized_material.dart';
import '../models/line_timestamp.dart';
import '../models/recitation_repeat.dart';
import '../services/multilingual_audio_service.dart';
import 'repeat_count_menu.dart';

class BilingualVerseView extends StatelessWidget {
  final List<LineTimestamp> lineTimestamps;
  final int? activeLine;
  final PlaybackLanguageMode languageMode;
  final double fontSize;
  final void Function(LineTimestamp line)? onLineTap;
  final MultilingualAudioService? audioService;

  const BilingualVerseView({
    super.key,
    required this.lineTimestamps,
    this.activeLine,
    this.languageMode = PlaybackLanguageMode.bilingual,
    this.fontSize = 17.0,
    this.onLineTap,
    this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      itemCount: lineTimestamps.length,
      itemBuilder: (context, index) {
        final ts = lineTimestamps[index];
        final isActive = activeLine == ts.line;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF6C63FF).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.06),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: InkWell(
            onTap: onLineTap != null ? () => onLineTap!(ts) : null,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF6C63FF)
                        : Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${ts.line}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pali Text
                      if (languageMode != PlaybackLanguageMode.target &&
                          ts.paliText != null &&
                          ts.paliText!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            ts.paliText!,
                            style: TextStyle(
                              fontSize: fontSize * 0.95,
                              fontStyle: FontStyle.italic,
                              color: isActive
                                  ? const Color(0xFFFFD54F)
                                  : const Color(0xFFFFE082).withValues(alpha: 0.85),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Vietnamese Text
                      if (languageMode != PlaybackLanguageMode.source &&
                          ts.text != null &&
                          ts.text!.isNotEmpty)
                        Text(
                          ts.text!,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.88),
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            height: 1.45,
                          ),
                        ),
                    ],
                  ),
                ),
                if (audioService != null) ...[
                  const SizedBox(width: 6),
                  _LineRepeatChip(
                    count: audioService!.lineRepeatFor(ts.line),
                    playingCurrent: isActive ? audioService!.lineRepeatCurrent : 0,
                    onTap: () => showRepeatCountMenu(
                      context,
                      current: audioService!.lineRepeatFor(ts.line),
                      allowInfinite: false,
                      title: 'Số lần phát câu ${ts.line}',
                      onChanged: (value) =>
                          audioService!.setLineRepeatOverride(ts.line, value),
                    ),
                  ),
                ],
                if (isActive)
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 2),
                    child: Icon(
                      Icons.volume_up_rounded,
                      color: Color(0xFF6C63FF),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LineRepeatChip extends StatelessWidget {
  final int count;
  final int playingCurrent;
  final VoidCallback onTap;

  const _LineRepeatChip({
    required this.count,
    required this.playingCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = count > 1 || playingCurrent > 0;
    final color = active ? const Color(0xFFFFB300) : Colors.grey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFFB300).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? const Color(0xFFFFB300).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.repeat, size: 11, color: color),
            const SizedBox(width: 2),
            Text(
              RecitationRepeat.lineLabel(count, current: playingCurrent),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
