import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';

import '../../tts/tts_service.dart';

import '../models/dict_entry.dart';
import '../services/dict_text_cleaner.dart';
import '../services/dictionary_service.dart';
import 'dict_definition_view.dart';

/// Bottom sheet hiển thị kết quả tra từ điển — "trang từ điển" đầy đủ.
///
/// DICT-CLEAN-001: trước đây mỗi entry MDX được in thành một khối
/// `plainDefinition` (dài, lặp giữa các bộ từ điển, không IPA/loại từ). Nay:
/// - nội dung được [DictTextCleaner] làm sạch + cấu trúc;
/// - nhiều bộ từ điển cho cùng một từ được GỘP và KHỬ nghĩa trùng;
/// - trình bày như từ điển thật: headword, IPA, nhóm loại từ, nghĩa đánh số,
///   ví dụ, nhãn nguồn.
class DictResultSheet extends StatelessWidget {
  final String word;
  final List<DictEntry> entries;

  const DictResultSheet({
    super.key,
    required this.word,
    required this.entries,
  });

  static void show(BuildContext context, String word, List<DictEntry> entries) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: DictResultSheet(word: word, entries: entries),
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

  DictMergedEntry _merged() {
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
    final merged = _merged();
    final headword = merged.headword.trim().isEmpty ? word : merged.headword;
    final sources = merged.sourceLabel;
    // Loại từ có thể nằm ở cột riêng của entry (không nằm trong HTML) — vẫn
    // hiển thị để trang từ điển đủ thông tin như từ điển thật.
    //
    // DICT-VIEW-002: KHÔNG lặp nhãn đã có trong nội dung — bản cũ vừa hiện
    // chip loại từ ở đầu trang, vừa hiện nhãn nhóm loại từ trong phần nghĩa
    // ⇒ đúng kiểu "nhiều phần dư" owner phàn nàn.
    final groupPoses = <String>{
      for (final group in merged.groups)
        if ((group.pos ?? '').trim().isNotEmpty) group.pos!.trim(),
    };
    final entryPoses = <String>{
      for (final entry in entries)
        if ((entry.partOfSpeech ?? '').trim().isNotEmpty)
          entry.partOfSpeech!.trim(),
    }.where((pos) => !groupPoses.contains(pos)).toList();

    return Column(
      children: <Widget>[
        // Handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(Icons.menu_book,
                  color: Color(0xFF2196F3), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.uiText('Từ điển: $word'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.uiText('${entries.length} kết quả'),
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              // DICT-VIEW-003: trang từ điển phải ĐỌC ĐƯỢC từ. Trước đây
              // sheet này chỉ hiện IPA mà không có nút phát âm, dù app đã có
              // sẵn TtsService cho PDF/Read.
              IconButton(
                tooltip: context.uiText('Phát âm'),
                icon: const Icon(Icons.volume_up_rounded,
                    color: Color(0xFF2196F3), size: 20),
                onPressed: () async {
                  try {
                    await TtsService().speak(headword);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          context.uiText('Không phát âm được từ này.'),
                        ),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: context.uiText('Sao chép'),
                icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: headword));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(context.uiText('Đã sao chép')),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF1E2A3A), height: 1),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.uiText('Không tìm thấy "$word"'),
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: <Widget>[
                    Text(
                      headword,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    if ((merged.ipa ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          merged.ipa!.trim(),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (entryPoses.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: <Widget>[
                            for (final pos in entryPoses)
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
                                    DictTextCleaner.posDisplaySource(pos) ??
                                        pos,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFCE93D8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    DictDefinitionView(
                      groups: merged.groups,
                      compact: false,
                      accentColor: const Color(0xFF64B5F6),
                    ),
                    if (merged.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          context.uiText('Chưa có nội dung cho từ này'),
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                      ),
                    if (sources.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          context.uiText('Nguồn: $sources'),
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 11),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
