import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../models/dict_entry.dart';
import '../services/dict_text_cleaner.dart';
import '../services/dictionary_service.dart';
import 'dict_definition_view.dart';

/// "Trang từ điển" đầy đủ (DICT-CLEAN-001).
///
/// Khác với bản cô đọng nhúng trong sheet PDF/Read: ở đây hiển thị ĐẦY ĐỦ —
/// headword lớn, IPA + nguồn, nhóm loại từ, nghĩa đánh số, ví dụ, nhãn bộ từ
/// điển. Nội dung đã qua [DictTextCleaner] nên không còn CSS/script/entity
/// và nghĩa trùng giữa nhiều bộ từ điển.
class DictEntryDetailSheet extends StatelessWidget {
  final String word;
  final List<DictEntry> entries;

  /// IPA dự phòng khi nguồn MDX không có (ví dụ lấy từ mạng).
  final String? fallbackIpa;

  /// Nghĩa dự phòng khi không có entry MDX nào.
  final String? fallbackMeaning;

  final String? partOfSpeech;

  /// Nhãn nguồn đã tra ("Mạng" / "Từ điển" / "Ngoại tuyến") — đã dịch ở caller.
  final String? originLabel;

  final VoidCallback? onSpeak;

  const DictEntryDetailSheet({
    super.key,
    required this.word,
    this.entries = const <DictEntry>[],
    this.fallbackIpa,
    this.fallbackMeaning,
    this.partOfSpeech,
    this.originLabel,
    this.onSpeak,
  });

  static void show(
    BuildContext context, {
    required String word,
    List<DictEntry> entries = const <DictEntry>[],
    String? ipa,
    String? meaning,
    String? partOfSpeech,
    String? originLabel,
    VoidCallback? onSpeak,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141A28),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: DictEntryDetailSheet(
          word: word,
          entries: entries,
          fallbackIpa: ipa,
          fallbackMeaning: meaning,
          partOfSpeech: partOfSpeech,
          originLabel: originLabel,
          onSpeak: onSpeak,
        ),
      ),
    );
  }

  Map<String, String> _dictionaryNames() {
    try {
      final names = <String, String>{};
      for (final info in DictionaryService.instance.dictionaries) {
        names[info.id] = info.name;
      }
      return names;
    } catch (_) {
      return const <String, String>{};
    }
  }

  DictMergedEntry get _merged {
    final names = _dictionaryNames();
    return DictTextCleaner.merge(<DictSourceText>[
      for (final entry in entries)
        DictSourceText(
          headword: entry.headword,
          definition: entry.definition,
          phonetic: entry.phonetic,
          sourceLabel: names[entry.dictId] ?? entry.dictId,
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final merged = _merged;
    final ipa = merged.ipa ?? fallbackIpa;
    final meaning = (fallbackMeaning ?? '').trim();
    final sources = merged.sourceLabel;

    return Column(
      children: <Widget>[
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      word,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if ((ipa ?? '').trim().isNotEmpty ||
                        (partOfSpeech ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            if ((ipa ?? '').trim().isNotEmpty)
                              Text(
                                ipa!.trim(),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            if ((partOfSpeech ?? '').trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9C27B0)
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  context.uiText(
                                    DictTextCleaner.posDisplaySource(
                                          partOfSpeech,
                                        ) ??
                                        partOfSpeech!.trim(),
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFCE93D8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if ((originLabel ?? '').trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  originLabel!.trim(),
                                  style: const TextStyle(
                                    color: Color(0xFF81C784),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (onSpeak != null)
                IconButton(
                  onPressed: onSpeak,
                  tooltip: context.uiText('Phát âm'),
                  icon: const Icon(Icons.volume_up_rounded,
                      color: Color(0xFF2196F3)),
                ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: word));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(context.uiText('Đã sao chép')),
                    ),
                  );
                },
                tooltip: context.uiText('Sao chép'),
                icon: const Icon(Icons.copy, color: Colors.white54, size: 20),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1E2A3A), height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: <Widget>[
              if (merged.isEmpty && meaning.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      context.uiText('Chưa có nội dung cho từ này'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ),
                ),
              if (!merged.isEmpty)
                DictDefinitionView(
                  groups: merged.groups,
                  compact: false,
                  accentColor: const Color(0xFF64B5F6),
                ),
              if (merged.isEmpty && meaning.isNotEmpty)
                Text(
                  meaning,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              if (sources.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    context.uiText('Nguồn: $sources'),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
