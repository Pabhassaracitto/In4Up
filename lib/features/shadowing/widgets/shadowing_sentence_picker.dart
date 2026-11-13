import 'package:in4up/core/language/localized_material.dart';

import '../services/lrc_ab_suggestions.dart';

/// Existing lyric hints shared by Speaking Studio and Understand shadowing.
/// This widget never generates text; it only displays timed source lines.
class ShadowingSentencePicker extends StatelessWidget {
  const ShadowingSentencePicker({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelected,
    required this.onUseCurrent,
  });

  final List<AbSuggestion> suggestions;
  final int selectedIndex;
  final ValueChanged<AbSuggestion> onSelected;
  final VoidCallback onUseCurrent;

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    final ms = d.inMilliseconds % 1000 ~/ 10;
    return '$mins:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('shadowing-sentence-picker'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lyrics_outlined, size: 15, color: Color(0xFF64B5F6)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.uiText('Gợi ý theo câu (lời bài)'),
                  style: const TextStyle(
                    color: Color(0xFF64B5F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onUseCurrent,
                child: Text(
                  context.uiText('Dùng câu đang phát'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: Scrollbar(
              child: ListView.builder(
                itemCount: suggestions.length,
                itemBuilder: (context, i) {
                  final s = suggestions[i];
                  final selected = i == selectedIndex;
                  return InkWell(
                    key: ValueKey('shadowing-sentence-$i'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2196F3).withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(
                              _formatDuration(s.start),
                              style: TextStyle(
                                color: selected ? const Color(0xFF64B5F6) : Colors.grey[500],
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Lyric text is user content, not translated chrome.
                          Expanded(
                            child: Text(
                              s.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(
                            selected ? Icons.check_circle : Icons.chevron_right,
                            size: 14,
                            color: selected ? const Color(0xFF64B5F6) : Colors.grey[700],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
