// PLAN-041 Pha A (ADR-0021) — UI Nút Khái niệm đa ngữ:
//  * [ConceptsScreen]: danh sách khái niệm + tạo mới + vào duyệt gợi ý.
//  * [ConceptDetailScreen]: ảnh/animation chung ở giữa, các cánh ngôn ngữ
//    (từ · IPA · nghĩa · nghe từng cánh · điểm SM-2 riêng), thêm/tháo cánh.
//  * [ConceptSuggestionsScreen]: duyệt cặp gắn kết máy đề xuất — nối chỉ
//    xảy ra khi người dùng bấm xác nhận (luật AT2, không tự gộp).
//
// SM-2 chỉ HIỂN THỊ từ từng WordEntry; màn này không chấm điểm.

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/language/app_language.dart';
import '../../../features/tts/tts_service.dart';
import '../../../features/vocab_image/vocab_image_picker_sheet.dart';
import '../../../features/vocab_image/vocab_image_thumbnail.dart';
import '../../../features/vocab_image/vocabulary_media_widget.dart';
import '../../../models/concept_node.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';
import 'concept_link_suggestions.dart';

const Color _kBg = Color(0xFF0A0F1A);
const Color _kPanel = Color(0xFF101A2C);
const Color _kBorder = Color(0xFF1D2C49);
const Color _kAccent = Color(0xFF6C63FF);

String _flagOf(String languageCode) =>
    AppLanguageCatalog.maybeFromCode(languageCode)?.flag ?? '🏳️';

Future<void> _speakEntry(WordEntry entry) async {
  HapticFeedback.lightImpact();
  final lang = entry.language.trim();
  await TtsService().speak(
    entry.word,
    language: lang.isEmpty ? null : lang,
  );
}

// ═══════════════════════════════════════════════════════
// DANH SÁCH KHÁI NIỆM
// ═══════════════════════════════════════════════════════
class ConceptsScreen extends StatelessWidget {
  const ConceptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: Text(context.uiText('Khái niệm đa ngữ')),
        actions: [
          IconButton(
            tooltip: context.uiText('Gợi ý nối'),
            icon: const Icon(Icons.link_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConceptSuggestionsScreen(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccent,
        onPressed: () => _createConceptDialog(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.uiText('Khái niệm mới'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Consumer<VocabularyProvider>(
        builder: (context, p, _) {
          final concepts = p.concepts;
          if (concepts.isEmpty) {
            return _emptyState(context);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
            itemCount: concepts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final node = concepts[i];
              final members = p.membersOfConcept(node.id);
              final langs = p.languagesOfConcept(node.id);
              final hero = (node.imageRef ?? '').trim().isNotEmpty
                  ? node.imageRef
                  : members
                      .map((e) => (e.imageUrl ?? '').trim())
                      .firstWhere((u) => u.isNotEmpty, orElse: () => '');
              final title = node.gloss.trim().isNotEmpty
                  ? node.gloss.trim()
                  : (members.isNotEmpty ? members.first.word : '—');
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConceptDetailScreen(conceptId: node.id),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kPanel,
                    border: Border.all(color: _kBorder),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if ((hero ?? '').isNotEmpty)
                        VocabImageThumbnail(imageUrl: hero, size: 54)
                      else
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF241F5E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.psychology_alt_outlined,
                              color: Color(0xFF9C8FFF)),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              members.isEmpty
                                  ? context.uiText('Chưa có từ nào')
                                  : members
                                      .take(5)
                                      .map((e) =>
                                          '${_flagOf(e.language)} ${e.word}')
                                      .join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          '${langs.length} 🌐',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: _kBorder),
                        backgroundColor: const Color(0xFF16233C),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_alt_outlined,
                size: 52, color: Color(0xFF9C8FFF)),
            const SizedBox(height: 14),
            Text(
              context.uiText('Chưa có khái niệm nào'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              context.uiText(
                  'Một khái niệm là một Ý NGHĨA dùng chung cho nhiều ngôn ngữ: ảnh/animation ở giữa, mỗi ngôn ngữ gắn âm và chữ của nó xung quanh. Hãy để máy gợi ý các cặp từ có thể nối, hoặc tự tạo khái niệm mới.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConceptSuggestionsScreen(),
                ),
              ),
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(context.uiText('Xem gợi ý nối từ kho từ')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createConceptDialog(BuildContext context) async {
    final glossCtrl = TextEditingController();
    final domainCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        title: Text(context.uiText('Khái niệm mới')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: glossCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.uiText('Định nghĩa ngắn'),
                hintText: context.uiText('vd: con chó'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: domainCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.uiText('Miền nghĩa (không bắt buộc)'),
                hintText: context.uiText('vd: động vật'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.uiText('Huỷ')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.uiText('Tạo')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final provider = context.read<VocabularyProvider>();
    final node = await provider.createConcept(
      gloss: glossCtrl.text.trim(),
      domain: domainCtrl.text.trim().isEmpty ? null : domainCtrl.text.trim(),
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConceptDetailScreen(conceptId: node.id),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// CHI TIẾT KHÁI NIỆM
// ═══════════════════════════════════════════════════════
class ConceptDetailScreen extends StatelessWidget {
  final String conceptId;
  const ConceptDetailScreen({super.key, required this.conceptId});

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, p, _) {
        final node = p.conceptById(conceptId);
        if (node == null) {
          return Scaffold(
            backgroundColor: _kBg,
            appBar: AppBar(backgroundColor: _kBg),
            body: Center(
              child: Text(
                context.uiText('Khái niệm không còn tồn tại'),
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          );
        }
        final members = p.membersOfConcept(node.id);
        final langs = p.languagesOfConcept(node.id);
        final hero = (node.imageRef ?? '').trim().isNotEmpty
            ? node.imageRef!
            : members
                .map((e) => (e.imageUrl ?? '').trim())
                .firstWhere((u) => u.isNotEmpty, orElse: () => '');
        return Scaffold(
          backgroundColor: _kBg,
          appBar: AppBar(
            backgroundColor: _kBg,
            title: Text(context.uiText('Khái niệm')),
            actions: [
              IconButton(
                tooltip: context.uiText('Sửa định nghĩa'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editDialog(context, p, node),
              ),
              IconButton(
                tooltip: context.uiText('Xoá khái niệm'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteDialog(context, p, node),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              if (hero.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: VocabularyMediaWidget(
                    imageUrl: hero,
                    height: 190,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF241F5E),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.psychology_alt_outlined,
                      size: 52, color: Color(0xFF9C8FFF)),
                ),
              const SizedBox(height: 12),
              Text(
                node.gloss.trim().isNotEmpty
                    ? node.gloss.trim()
                    : context.uiText('(chưa có định nghĩa)'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((node.domain ?? '').trim().isNotEmpty)
                Text(
                  node.domain!.trim(),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12.5),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.language, size: 15),
                    label: Text(
                        '${context.uiText('Ngôn ngữ đã phủ:')} ${langs.length}'),
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: _kBorder),
                    backgroundColor: const Color(0xFF16233C),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.image_search_outlined, size: 15),
                    label: Text(context.uiText('Chọn hình cho khái niệm')),
                    onPressed: () => _pickConceptImage(context, p, node),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.uiText('Các cánh ngôn ngữ'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                Text(
                  context.uiText(
                      'Chưa có từ nào. Bấm "Thêm từ" để gắn cánh ngôn ngữ đầu tiên.'),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12.5),
                ),
              for (final e in members) _memberRow(context, p, e),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _addMemberSheet(context, p, node),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(context.uiText('Thêm từ vào khái niệm')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _memberRow(
      BuildContext context, VocabularyProvider p, WordEntry e) {
    final pct = (double v) => '${(v.clamp(0.0, 1.0) * 100).round()}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kPanel,
        border: Border.all(color: _kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Text(_flagOf(e.language), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.word,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    if ((e.phonetic ?? '').trim().isNotEmpty) e.phonetic!.trim(),
                    if (e.meaning.trim().isNotEmpty) e.meaning.trim(),
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11.5),
                ),
                Text(
                  'SM-2 · ${context.uiText('Hiểu')} ${pct(e.understand)} · ${context.uiText('Nghe')} ${pct(e.listen)} · ${context.uiText('Đọc')} ${pct(e.read)}',
                  style: const TextStyle(color: Color(0xFF7286AC), fontSize: 10.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.uiText('Nghe'),
            icon: const Icon(Icons.volume_up_rounded,
                color: Color(0xFF9C8FFF), size: 20),
            onPressed: () => _speakEntry(e),
          ),
          IconButton(
            tooltip: context.uiText('Tháo khỏi khái niệm'),
            icon: Icon(Icons.link_off_rounded,
                color: Colors.grey[500], size: 19),
            onPressed: () => p.unlinkEntryFromConcept(e.id),
          ),
        ],
      ),
    );
  }

  Future<void> _pickConceptImage(
      BuildContext context, VocabularyProvider p, ConceptNode node) async {
    final result = await VocabImagePickerSheet.show(
      context,
      word: node.gloss,
      meaning: node.domain,
      hasExistingImage: (node.imageRef ?? '').trim().isNotEmpty,
    );
    if (result == null) return;
    if (result.removed) {
      node.imageRef = null;
    } else if (result.imagePath != null) {
      node.imageRef = result.imagePath;
    } else {
      return;
    }
    await p.updateConcept(node);
  }

  Future<void> _addMemberSheet(
      BuildContext context, VocabularyProvider p, ConceptNode node) async {
    final picked = await showModalBottomSheet<WordEntry>(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EntryPickerSheet(excludeConceptId: node.id),
    );
    if (picked != null) {
      await p.linkEntryToConcept(picked.id, node.id);
    }
  }

  Future<void> _editDialog(
      BuildContext context, VocabularyProvider p, ConceptNode node) async {
    final glossCtrl = TextEditingController(text: node.gloss);
    final domainCtrl = TextEditingController(text: node.domain ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        title: Text(context.uiText('Sửa định nghĩa')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: glossCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.uiText('Định nghĩa ngắn'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: domainCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.uiText('Miền nghĩa (không bắt buộc)'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.uiText('Huỷ')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.uiText('Lưu')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    node.gloss = glossCtrl.text.trim();
    node.domain =
        domainCtrl.text.trim().isEmpty ? null : domainCtrl.text.trim();
    await p.updateConcept(node);
  }

  Future<void> _deleteDialog(
      BuildContext context, VocabularyProvider p, ConceptNode node) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1520),
        title: Text(context.uiText('Xoá khái niệm?')),
        content: Text(
          context.uiText(
              'Mọi từ thành viên sẽ được tháo nối và GIỮ NGUYÊN. Chỉ nút khái niệm biến mất.'),
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.uiText('Giữ lại')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.uiText('Xoá')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await p.deleteConcept(node.id);
    if (context.mounted) Navigator.pop(context);
  }
}

/// Sheet tìm + chọn một WordEntry chưa thuộc khái niệm đang mở.
class _EntryPickerSheet extends StatefulWidget {
  final String excludeConceptId;
  const _EntryPickerSheet({required this.excludeConceptId});

  @override
  State<_EntryPickerSheet> createState() => _EntryPickerSheetState();
}

class _EntryPickerSheetState extends State<_EntryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VocabularyProvider>();
    final q = _query.trim().toLowerCase();
    final items = p.allWords.where((e) {
      if (e.conceptId == widget.excludeConceptId) return false;
      if (q.isEmpty) return true;
      return e.word.toLowerCase().contains(q) ||
          e.meaning.toLowerCase().contains(q);
    }).take(80).toList();
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: context.uiText('Tìm từ trong kho…'),
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        context.uiText('Không có từ phù hợp'),
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final e = items[i];
                        return ListTile(
                          dense: true,
                          leading: Text(_flagOf(e.language),
                              style: const TextStyle(fontSize: 17)),
                          title: Text(e.word,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            e.meaning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          trailing: e.conceptId != null
                              ? const Icon(Icons.link_rounded,
                                  size: 16, color: Color(0xFF7286AC))
                              : null,
                          onTap: () => Navigator.pop(context, e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// DUYỆT GỢI Ý NỐI
// ═══════════════════════════════════════════════════════
class ConceptSuggestionsScreen extends StatefulWidget {
  const ConceptSuggestionsScreen({super.key});

  @override
  State<ConceptSuggestionsScreen> createState() =>
      _ConceptSuggestionsScreenState();
}

class _ConceptSuggestionsScreenState extends State<ConceptSuggestionsScreen> {
  static const String _kDismissedKey = 'concept_dismissed_pairs_v1';

  bool _loading = true;
  List<ConceptLinkSuggestion> _items = [];
  final Set<String> _dismissed = <String>{};

  @override
  void initState() {
    super.initState();
    // Tính sau frame đầu để màn hình kịp hiện vòng xoay (kho lớn tốn nhịp).
    WidgetsBinding.instance.addPostFrameCallback((_) => _compute());
  }

  Future<void> _compute() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissed
      ..clear()
      ..addAll(prefs.getStringList(_kDismissedKey) ?? const <String>[]);
    if (!mounted) return;
    final p = context.read<VocabularyProvider>();
    final candidates = [
      for (final w in p.allWords)
        ConceptCandidateWord(
          id: w.id,
          word: w.word,
          meaning: w.meaning,
          language: w.language,
          imageUrl: w.imageUrl,
          conceptId: w.conceptId,
        ),
    ];
    final result = buildConceptLinkSuggestions(
      candidates,
      dismissedPairKeys: _dismissed,
    );
    if (!mounted) return;
    setState(() {
      _items = result;
      _loading = false;
    });
  }

  Future<void> _dismiss(ConceptLinkSuggestion s) async {
    _dismissed.add(s.pairKey);
    setState(() => _items.removeWhere((x) => x.pairKey == s.pairKey));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDismissedKey, _dismissed.toList());
  }

  Future<void> _link(
      VocabularyProvider p, ConceptLinkSuggestion s) async {
    final a = p.allWords.firstWhere((w) => w.id == s.wordIds[0]);
    final b = p.allWords.firstWhere((w) => w.id == s.wordIds[1]);
    final aConcept = (a.conceptId ?? '').trim();
    final bConcept = (b.conceptId ?? '').trim();
    if (aConcept.isNotEmpty && bConcept.isEmpty) {
      await p.linkEntryToConcept(b.id, aConcept);
    } else if (bConcept.isNotEmpty && aConcept.isEmpty) {
      await p.linkEntryToConcept(a.id, bConcept);
    } else {
      await p.linkEntriesAsConcept([a.id, b.id]);
    }
    if (!mounted) return;
    setState(() => _items.removeWhere((x) => x.pairKey == s.pairKey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.uiText('Đã nối vào một khái niệm'))),
    );
  }

  String _reasonLabel(ConceptLinkReason r) {
    switch (r) {
      case ConceptLinkReason.translationPair:
        return context.uiText('cặp dịch của nhau');
      case ConceptLinkReason.sameImage:
        return context.uiText('dùng chung một ảnh');
      case ConceptLinkReason.sharedGloss:
        return context.uiText('cùng một nghĩa');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VocabularyProvider>();
    WordEntry? byId(String id) {
      for (final w in p.allWords) {
        if (w.id == id) return w;
      }
      return null;
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: Text(context.uiText('Gợi ý nối khái niệm')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      context.uiText(
                          'Không còn gợi ý nào. Máy chỉ đề xuất khi thấy dấu hiệu rõ (cặp dịch, cùng ảnh, cùng nghĩa) — bạn luôn tự nối tay được trong màn khái niệm.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = _items[i];
                    final a = byId(s.wordIds[0]);
                    final b = byId(s.wordIds[1]);
                    if (a == null || b == null) return const SizedBox.shrink();
                    return Container(
                      decoration: BoxDecoration(
                        color: _kPanel,
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pairLine(a),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '⇕ ${s.reasons.map(_reasonLabel).join(' · ')}',
                              style: const TextStyle(
                                  color: Color(0xFF9C8FFF), fontSize: 11.5),
                            ),
                          ),
                          _pairLine(b),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _link(p, s),
                                  child: Text(
                                      context.uiText('Nối vào 1 khái niệm')),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _dismiss(s),
                                  child: Text(context.uiText('Bỏ qua')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _pairLine(WordEntry e) {
    return Row(
      children: [
        Text(_flagOf(e.language), style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${e.word} — ${e.meaning}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13.5),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.volume_up_rounded,
              size: 18, color: Color(0xFF9C8FFF)),
          onPressed: () => _speakEntry(e),
        ),
      ],
    );
  }
}
