// ═══════════════════════════════════════════════════════════════
// WORD LIST SCREEN — v4 Complete Merge
// Old: TTS, sort, selection, YouGlish, folders, import, settings
// New: Hierarchy, type filter, contexts, relationships, decompose
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../features/tts/tts_service.dart';
import '../../../models/vocab_context.dart';
import '../../../models/vocabulary_type.dart';
import '../../../models/word_entry.dart';
import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../services/vocab_classifier.dart';
import '../../../widgets/sync_status_badge.dart';
import '../../memory_mode/controllers/memory_controller.dart';
import 'knowledge_graph_screen.dart';
import 'single_word_review_screen.dart';
import 'word_import_sheet.dart';
import 'word_list_models.dart' hide WordEntry;
import 'youglish_mini_sheet.dart';
import 'package:in4up/core/language/tr_extension.dart';

// ══════════════════════════════════════════════════════════
// MAIN SCREEN
// ══════════════════════════════════════════════════════════
class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});
  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  static const double _kWordListSpeakSpeed = 0.82;

  // ── Services ──
  final _tts = TtsService();

  // ── UI state ──
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  bool _filterExpanded = false;
  String? _expandedId;
  WordListSortMode _sortMode = WordListSortMode.addTime;
  WordListSettings _settings = const WordListSettings();

  // ── Playback state ──
  bool _isPlaying = false;
  int _playingIndex = -1;
  int _playingRepeatCurrent = 0;
  bool _stopRequested = false;
  int _listRepeatCount = 1;
  int _listRepeatCurrent = 0;
  final Map<String, int> _repeatOverrides = {};

  // ── Selection state ──
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _stopRequested = true;
    _tts.stop();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Sorted + filtered display list ──
  List<WordEntry> _getDisplayList(VocabularyProvider p) {
    final list = List<WordEntry>.from(p.displayedWords);
    _applySortMode(list);
    return list;
  }

  void _applySortMode(List<WordEntry> list) {
    switch (_sortMode) {
      case WordListSortMode.addTime:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case WordListSortMode.alphabetical:
        list.sort(
            (a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      case WordListSortMode.alphabeticalDesc:
        list.sort(
            (a, b) => b.word.toLowerCase().compareTo(a.word.toLowerCase()));
      case WordListSortMode.rankDescending:
      case WordListSortMode.easyFirst:
        list.sort((a, b) => b.mastery.compareTo(a.mastery));
      case WordListSortMode.familiarity:
      case WordListSortMode.hardFirst:
        list.sort((a, b) => a.mastery.compareTo(b.mastery));
      case WordListSortMode.random:
        list.shuffle();
      case WordListSortMode.sm2Due:
        list.sort((a, b) {
          if (a.isDue && !b.isDue) return -1;
          if (!a.isDue && b.isDue) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    }
  }

  int _getRepeatCount(String id) => (_repeatOverrides[id] ?? 1).clamp(1, 999);

  @override
  Widget build(BuildContext context) {
    // Watch MemoryController một lần tại đây để tránh lỗi assertion do quá nhiều dependents trong ListView
    final memoryController = context.watch<MemoryController>();
    final sownWords = memoryController.allItems
        .map((e) => e.word.trim().toLowerCase())
        .toSet();

    return Consumer<VocabularyProvider>(
      builder: (_, provider, __) {
        final items = _getDisplayList(provider);
        return Scaffold(
          backgroundColor: const Color(0xFF080B1A),
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(provider),
                _buildTypeFilterBar(provider),
                _buildSubBar(provider, items),
                Expanded(child: _buildCompactList(provider, items, sownWords)),
                _buildPlayBar(items),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF6C63FF),
            onPressed: () => _showAddMenu(provider),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildAppBar(VocabularyProvider p) {
    final sm2Due = p.dueCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 4),
              if (!_showSearch) ...[
                Expanded(
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Wordlist',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _CountBadge(count: p.total, color: const Color(0xFF6C63FF)),
                                if (sm2Due > 0)
                                  _CountBadge(
                                    count: sm2Due,
                                    color: const Color(0xFFFF5722),
                                    icon: Icons.alarm,
                                    label: context.tr('ôn'),
                                    onTap: () => setState(() => _sortMode = WordListSortMode.sm2Due),
                                  ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Flexible(
                              child: Text('Wordlist',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            _CountBadge(count: p.total, color: const Color(0xFF6C63FF)),
                            if (sm2Due > 0) ...[
                              const SizedBox(width: 8),
                              _CountBadge(
                                count: sm2Due,
                                color: const Color(0xFFFF5722),
                                icon: Icons.alarm,
                                label: context.tr('ôn'),
                                onTap: () => setState(() => _sortMode = WordListSortMode.sm2Due),
                              ),
                            ],
                          ],
                        ),
                ),
              ] else ...[
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: context.l10n.wordListSearchHint,
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey[600], size: 16),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onChanged: p.setSearch,
                    ),
                  ),
                ),
              ],
              if (!compact && !_showSearch) const SyncStatusBadge(),
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search,
                    color: Colors.grey[400], size: 20),
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  if (!_showSearch) {
                    _searchCtrl.clear();
                    p.clearSearch();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.view_sidebar_outlined,
                    color: Colors.grey[400], size: 20),
                onPressed: () => _showSmartGroupsSheet(p),
              ),
              IconButton(
                icon: Icon(Icons.hub_outlined, color: Colors.grey[400], size: 20),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KnowledgeGraphScreen(),
                  ),
                ),
                tooltip: 'Knowledge Graph',
              ),
              _buildOverflowMenu(p),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverflowMenu(VocabularyProvider p) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
      color: const Color(0xFF1A2235),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        switch (val) {
          case 'select':
            setState(() {
              _isSelecting = !_isSelecting;
              if (!_isSelecting) _selectedIds.clear();
            });
          case 'expand':
            setState(() => _settings = _settings.copyWith(
                definitionsExpanded: !_settings.definitionsExpanded));
          case 'toggle_def':
            final any =
                _settings.showShortDefinition || _settings.showFullDefinition;
            setState(() => _settings = _settings.copyWith(
                showShortDefinition: !any, showFullDefinition: false));
          case 'settings':
            _showSettingsSheet();
        }
      },
      itemBuilder: (_) => [
        _menuItem('select', Icons.checklist, 'Content'),
        _menuItem('expand', Icons.unfold_more, 'Content'),
        const PopupMenuDivider(height: 1),
        _menuItem(
            'toggle_def',
            _settings.showShortDefinition
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            _settings.showShortDefinition ? 'Content' : 'Content'),
        const PopupMenuDivider(height: 1),
        _menuItem('settings', Icons.tune, 'Options'),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String v, IconData icon, String label) =>
      PopupMenuItem(
          value: v,
          child: Row(children: [
            Icon(icon, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]));

  // ═══════════════════════════════════════════════════════
  // TYPE FILTER BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildTypeFilterBar(VocabularyProvider p) {
    final hasActiveFilter = p.filterType != null ||
        p.filterLearningStatus != null ||
        p.filterLanguage != null ||
        p.filterTopic != null;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1A),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Column(
          children: [
            // ── COLLAPSED SUMMARY ROW ──
            GestureDetector(
              onTap: () => setState(() => _filterExpanded = !_filterExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 14,
                      color: hasActiveFilter
                          ? const Color(0xFF6C63FF)
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    // Active filter summary chips
                    Expanded(
                      child: hasActiveFilter
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (p.filterType != null)
                                    _ActiveFilterBadge(
                                      label: p.filterType!.label(context),
                                      color: p.filterType!.color,
                                      onRemove: () => p.setFilterType(null),
                                    ),
                                  if (p.filterLearningStatus != null)
                                    _ActiveFilterBadge(
                                      label: _statusLabel(p.filterLearningStatus!),
                                      color: _statusColor(p.filterLearningStatus!),
                                      onRemove: () =>
                                          p.setFilterLearningStatus(null),
                                    ),
                                  if (p.filterLanguage != null)
                                    _ActiveFilterBadge(
                                      label: _langLabel(p.filterLanguage!),
                                      color: const Color(0xFF42A5F5),
                                      onRemove: () => p.setFilterLanguage(null),
                                    ),
                                  if (p.filterTopic != null)
                                    _ActiveFilterBadge(
                                      label: p.filterTopic!,
                                      color: const Color(0xFF9C27B0),
                                      onRemove: () => p.setFilterTopic(null),
                                    ),
                                ],
                              ),
                            )
                          : TrText('Lọc theo thực thể, trạng thái, ngôn ngữ...', style: TextStyle(
                                  color: Colors.grey[700], fontSize: 11),
                            ),
                    ),
                    const SizedBox(width: 6),
                    // Clear all button
                    if (hasActiveFilter)
                      GestureDetector(
                        onTap: () {
                          p.setFilterType(null);
                          p.setFilterLearningStatus(null);
                          p.setFilterLanguage(null);
                          p.setFilterTopic(null);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(Icons.close,
                              size: 12, color: Colors.grey[500]),
                        ),
                      ),
                    const SizedBox(width: 4),
                    // Expand toggle
                    AnimatedRotation(
                      turns: _filterExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            // ── EXPANDED FILTER ROWS ──
            if (_filterExpanded) ...[
              Divider(
                color: Colors.white.withValues(alpha: 0.04),
                height: 1,
              ),
              _buildFilterRow(
                label: context.tr('Thực thể'),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _FilterSegmentChip(
                      label: context.tr('Tất cả'),
                      isSelected: p.filterType == null,
                      onTap: () {
                        p.setFilterType(null);
                      },
                    ),
                    const SizedBox(width: 6),
                    ...VocabularyType.values.map((type) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterSegmentChip(
                            label: type.label(context),
                            color: type.color,
                            isSelected: p.filterType == type,
                            onTap: () {
                              p.setFilterType(type);
                            },
                          ),
                        )),
                  ]),
                ),
              ),
              _buildFilterRow(
                label: context.tr('Trạng thái'),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _FilterSegmentChip(
                      label: context.tr('Tất cả'),
                      isSelected: p.filterLearningStatus == null,
                      onTap: () {
                        p.setFilterLearningStatus(null);
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterSegmentChip(
                      label: context.l10n.wordListDue,
                      color: const Color(0xFFFF5722),
                      isSelected: p.filterLearningStatus == 'due',
                      onTap: () {
                        p.setFilterLearningStatus('due');
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterSegmentChip(
                      label: context.l10n.wordListLearning,
                      color: const Color(0xFF2196F3),
                      isSelected: p.filterLearningStatus == 'learning',
                      onTap: () {
                        p.setFilterLearningStatus('learning');
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterSegmentChip(
                      label: context.l10n.memoryMastered,
                      color: const Color(0xFFFFD54F),
                      isSelected: p.filterLearningStatus == 'mastered',
                      onTap: () {
                        p.setFilterLearningStatus('mastered');
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterSegmentChip(
                      label: context.l10n.wordListBlindSpot,
                      color: const Color(0xFF616161),
                      isSelected: p.filterLearningStatus == 'blindSpot',
                      onTap: () {
                        p.setFilterLearningStatus('blindSpot');
                      },
                    ),
                  ]),
                ),
              ),
              _buildFilterRow(
                label: context.tr('Ngôn ngữ'),
                child: _buildLanguageRow(p),
              ),
              _buildFilterRow(
                label: context.tr('Chủ đề'),
                child: _buildTopicRow(p),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helper label/color converters ──
  String _statusLabel(String s) => switch (s) {
        'due' => 'Content',
        'learning' => 'Content',
        'mastered' => 'Content',
        'blindSpot' => 'Content',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'due' => const Color(0xFFFF5722),
        'learning' => const Color(0xFF2196F3),
        'mastered' => const Color(0xFFFFD54F),
        'blindSpot' => const Color(0xFF616161),
        _ => Colors.grey,
      };

  String _langLabel(String lang) => switch (lang) {
        'en' => 'Anh',
        'vi' => 'Content',
        'pali' => 'Pali',
        'my' => 'Burmese',
        _ => lang,
      };

  // ── Extract language & topic rows ──
  Widget _buildLanguageRow(VocabularyProvider p) {
    final languages = p.allLanguages.toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterSegmentChip(
          label: context.tr('Tất cả'),
          isSelected: p.filterLanguage == null,
          onTap: () {
            p.setFilterLanguage(null);
          },
        ),
        const SizedBox(width: 6),
        for (final lang in ['en', 'vi', 'pali', 'my'])
          if (!languages.contains(lang))
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterSegmentChip(
                label: _langLabel(lang),
                isSelected: p.filterLanguage == lang,
                onTap: () {
                  p.setFilterLanguage(lang);
                },
              ),
            ),
        for (final lang in languages)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _FilterSegmentChip(
              label: _langLabel(lang),
              isSelected: p.filterLanguage == lang,
              onTap: () {
                p.setFilterLanguage(lang);
              },
              onDelete: p.isCustomLanguage(lang)
                  ? () => p.removeCustomLanguage(lang)
                  : null,
            ),
          ),
        _AddChip(onTap: () => _promptAddLanguage(p)),
      ]),
    );
  }

  Widget _buildTopicRow(VocabularyProvider p) {
    final topics = p.allTopics.toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _FilterSegmentChip(
          label: context.tr('Tất cả'),
          isSelected: p.filterTopic == null,
          onTap: () {
            p.setFilterTopic(null);
          },
        ),
        const SizedBox(width: 6),
        for (final topic in topics)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _FilterSegmentChip(
              label: topic,
              isSelected: p.filterTopic == topic,
              onTap: () {
                p.setFilterTopic(topic);
              },
              onDelete: p.isCustomTopic(topic)
                  ? () => p.removeCustomTopic(topic)
                  : null,
            ),
          ),
        _AddChip(onTap: () => _promptAddTopic(p)),
      ]),
    );
  }

  Widget _buildFilterRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  void _promptAddLanguage(VocabularyProvider p) {
    final textC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2A),
        title: const TrText('Thêm ngôn ngữ mới', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textC,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: context.tr('Nhập mã/tên ngôn ngữ (VD: Pali, Sanskrit...)'),
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF42A5F5))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(context.l10n.commonCancel, style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = textC.text.trim();
              if (val.isNotEmpty) {
                await p.addCustomLanguage(val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5)),
            child: const TrTrText('Tạo & lọc'),
          ),
        ],
      ),
    );
  }

  void _promptAddTopic(VocabularyProvider p) {
    final textC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2A),
        title: const TrText('Thêm chủ đề mới', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textC,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: context.tr('Nhập chủ đề (VD: Phật Pháp/Kinh Đoạn, Đời Sống...)'),
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[800]!)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF42A5F5))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(context.l10n.commonCancel, style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = textC.text.trim();
              if (val.isNotEmpty) {
                await p.addCustomTopic(val);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF42A5F5)),
            child: const TrTrText('Tạo & lọc'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // SUB BAR (Sort + Play All + Repeat)
  // ═══════════════════════════════════════════════════════
  Widget _buildSubBar(VocabularyProvider p, List<WordEntry> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1A),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          // Sort
          _DropdownChip(
            icon: _sortMode.icon,
            label: _sortMode.label,
            color: _sortMode == WordListSortMode.sm2Due
                ? const Color(0xFFFF5722)
                : _sortMode == WordListSortMode.hardFirst
                    ? const Color(0xFFEF5350)
                    : const Color(0xFF6C63FF),
            onTap: () => _showSortSheet(),
          ),
          const Spacer(),
          // List repeat
          _ListRepeatButton(
            count: _listRepeatCount,
            current: _listRepeatCurrent,
            onChanged: (v) => setState(() => _listRepeatCount = v),
          ),
          const SizedBox(width: 8),
          // Play All
          _PlayAllButton(
            isPlaying: _isPlaying,
            onTap: () => _isPlaying ? _stopPlayback() : _playAll(items),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // COMPACT LIST
  // ═══════════════════════════════════════════════════════
  Widget _buildCompactList(
      VocabularyProvider p, List<WordEntry> items, Set<String> sownWords) {
    if (items.isEmpty) return _buildEmptyState(p);

    return Column(
      children: [
        // Selection action bar
        if (_isSelecting && _selectedIds.isNotEmpty) _buildSelectionBar(),
        // Stats strip
        _buildStatsStrip(p),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final entry = items[i];
              final isPlaying = _isPlaying && _playingIndex == i;
              final isSelected = _selectedIds.contains(entry.id);
              final isExpanded =
                  _expandedId == entry.id || _settings.definitionsExpanded;

              return _CompactListItem(
                entry: entry,
                index: i,
                isExpanded: isExpanded,
                isPlaying: isPlaying,
                isSelected: isSelected,
                isSelecting: _isSelecting,
                settings: _settings,
                isAlreadySown:
                    sownWords.contains(entry.word.trim().toLowerCase()),
                provider: p,
                repeatCount: _getRepeatCount(entry.id),
                playingRepeat: isPlaying ? _playingRepeatCurrent : 0,
                onTap: _isSelecting
                    ? () => setState(() {
                          _selectedIds.contains(entry.id)
                              ? _selectedIds.remove(entry.id)
                              : _selectedIds.add(entry.id);
                        })
                    : () => setState(() {
                          _expandedId =
                              _expandedId == entry.id ? null : entry.id;
                        }),
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  if (!_isSelecting) setState(() => _isSelecting = true);
                  setState(() => _selectedIds.add(entry.id));
                },
                onRepeatChanged: (v) =>
                    setState(() => _repeatOverrides[entry.id] = v),
                onEdit: () => _showEditSheet(entry, p),
                onSpeak: () => _speakWord(entry.word),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStrip(VocabularyProvider p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: p.progress,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(p.progress * 100).toInt()}%',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          Text('Content',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() {
              _selectedIds.addAll(
                  _getDisplayList(context.read<VocabularyProvider>())
                      .map((e) => e.id));
            }),
            child: const TrText('Tất cả', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
          ),
          TextButton(
            onPressed: () => setState(() {
              _isSelecting = false;
              _selectedIds.clear();
            }),
            child: const Text('Xong',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(VocabularyProvider p) {
    final isSearching = p.searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSearching ? Icons.search_off : Icons.library_books_outlined,
              size: 52, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text(
              isSearching
                  ? 'Không tìm thấy "${p.searchQuery}"'
                  : 'No Vocabulary',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
              isSearching
                  ? 'Save'
                  : 'Add',
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          if (isSearching) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _addAndSaveNow(p, p.searchQuery),
              icon: const Icon(Icons.add),
              label: const TrTrText('Lưu ngay từ này'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addAndSaveNow(VocabularyProvider p, String text) {
    VocabContext? context;
    try {
      final textProvider = this.context.read<TextProvider>();
      if (textProvider.currentDocument != null &&
          textProvider.currentLineIndex >= 0) {
        final line = textProvider.lines[textProvider.currentLineIndex].content;
        context = VocabContext.fromStory(
          storyTitle: textProvider.currentDocument!.title,
          lineIndex: textProvider.currentLineIndex,
          surroundingText: line,
          sourceRef: textProvider.currentContextSourceRef,
          sourceRefType: textProvider.currentContextSourceRefType,
        );
      }
    } catch (_) {}

    final entry = p.addWithAutoClassify(
      text: text,
      context: context,
    );

    HapticFeedback.mediumImpact();
    // Clear search after saving
    setState(() {
      _showSearch = false;
      _searchCtrl.clear();
      p.clearSearch();
    });

    final typeLabel = entry.vocabType == VocabularyType.word
        ? 'Content'
        : entry.vocabType == VocabularyType.phrase
            ? 'Content'
            : 'Content';

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Saved $typeLabel: $text',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'SỬA',
          textColor: Colors.white,
          onPressed: () => _showEditSheet(entry, p),
        ),
      ),
    );
  }

  Future<void> _speakWord(String text) async {
    final previousSpeed = _tts.speed;
    _tts.configure(speed: _kWordListSpeakSpeed);
    try {
      await _tts.speak(text);
    } finally {
      _tts.configure(speed: previousSpeed);
    }
  }

  void _showAddMenu(VocabularyProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(2)),
            ),
            _addMenuItem(
              icon: Icons.add_circle_outline,
              title: context.l10n.wordListAddManual,
              subtitle: context.tr('Nhập từ vựng, nghĩa và ví dụ bằng tay'),
              color: const Color(0xFF6C63FF),
              onTap: () {
                Navigator.pop(ctx);
                _showAddSheet(provider);
              },
            ),
            const SizedBox(height: 12),
            _addMenuItem(
              icon: Icons.download_outlined,
              title: context.l10n.wordListImport,
              subtitle: context.tr('Import từ Clipboard, Text Provider hoặc File'),
              color: const Color(0xFF4CAF50),
              onTap: () {
                Navigator.pop(ctx);
                WordImportSheet.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _addMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PLAY BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildPlayBar(List<WordEntry> items) {
    if (!_isPlaying && !(_isSelecting && _selectedIds.isNotEmpty))
      return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child:
          _isPlaying ? _buildPlayingBar(items) : _buildSelectingPlayBar(items),
    );
  }

  Widget _buildPlayingBar(List<WordEntry> items) {
    final current = _playingIndex >= 0 && _playingIndex < items.length
        ? items[_playingIndex]
        : null;
    final listInfo = _listRepeatCount == 0
        ? 'Content'
        : _listRepeatCount > 1
            ? 'Content'
            : '';
    return Row(
      children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.volume_up,
                color: Color(0xFF9C8FFF), size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Text(current?.word ?? '...',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(
                  '${_playingIndex + 1}/${items.length}'
                  '${_playingRepeatCurrent > 1 ? ' · lần $_playingRepeatCurrent' : ''}'
                  '${listInfo.isNotEmpty ? '  $listInfo' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            ])),
        GestureDetector(
          onTap: _stopPlayback,
          child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.stop, color: Colors.red, size: 18)),
        ),
      ],
    );
  }

  Widget _buildSelectingPlayBar(List<WordEntry> items) {
    return Row(
      children: [
        Text('Content',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const Spacer(),
        GestureDetector(
          onTap: () {
            final selected =
                items.where((e) => _selectedIds.contains(e.id)).toList();
            if (selected.isNotEmpty) _playAll(selected);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)]),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow, color: Colors.white, size: 16),
              SizedBox(width: 4),
              Text(context.l10n.listenPlay, style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ]),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // TTS PLAYBACK
  // ═══════════════════════════════════════════════════════

  Future<void> _playAll(List<WordEntry> items) async {
    if (_isPlaying) {
      _stopPlayback();
      return;
    }
    if (items.isEmpty) return;
    HapticFeedback.mediumImpact();
    _stopRequested = false;
    final previousSpeed = _tts.speed;
    _tts.configure(speed: _kWordListSpeakSpeed);
    setState(() {
      _isPlaying = true;
      _listRepeatCurrent = 0;
    });

    try {
      int listPass = 0;
      while (!_stopRequested && mounted) {
        listPass++;
        setState(() => _listRepeatCurrent = listPass);

        for (int i = 0; i < items.length; i++) {
          if (_stopRequested || !mounted) break;
          setState(() => _playingIndex = i);
          final entry = items[i];
          final repeat = _getRepeatCount(entry.id);
          for (int r = 0; r < repeat; r++) {
            if (_stopRequested || !mounted) break;
            setState(() => _playingRepeatCurrent = r + 1);
            await _tts.speak(entry.word);
            if (r < repeat - 1 && !_stopRequested && mounted) {
              await Future.delayed(const Duration(milliseconds: 700));
            }
          }
          if (!_stopRequested && mounted && i < items.length - 1) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        if (_stopRequested || !mounted) break;
        if (_listRepeatCount != 0 && listPass >= _listRepeatCount) break;
        if (!_stopRequested && mounted) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }
    } finally {
      _tts.configure(speed: previousSpeed);
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingIndex = -1;
          _playingRepeatCurrent = 0;
          _listRepeatCurrent = 0;
          _stopRequested = false;
        });
      }
    }
  }

  void _stopPlayback() {
    _stopRequested = true;
    _tts.stop();
    if (mounted)
      setState(() {
        _isPlaying = false;
        _playingIndex = -1;
        _playingRepeatCurrent = 0;
        _listRepeatCurrent = 0;
      });
  }

  // ═══════════════════════════════════════════════════════
  // SHEETS & DIALOGS
  // ═══════════════════════════════════════════════════════

  void _showSmartGroupsSheet(VocabularyProvider p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SmartGroupsSheet(provider: p),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SortSheet(
        current: _sortMode,
        onSelected: (mode) {
          setState(() => _sortMode = mode);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1520),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SettingsSheet(
        settings: _settings,
        onChanged: (s) => setState(() => _settings = s),
      ),
    );
  }

  void _showAddSheet(VocabularyProvider p) {
    final textCtrl = TextEditingController();
    final meaningCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    VocabularyType? detectedType;
    String selectedLang = 'en';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setS) {
          final pad = MediaQuery.of(sheetCtx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + pad),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.add_circle,
                          color: Color(0xFF42A5F5), size: 20),
                      const SizedBox(width: 10),
                      const TrText('Thêm từ vựng', style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (detectedType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: detectedType!.bgColor,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(detectedType!.label(context),
                              style: TextStyle(
                                  color: detectedType!.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: _inputDeco('Content',
                          'VD: breakthrough or Pali text', const Color(0xFF42A5F5)),
                      onChanged: (t) => setS(() => detectedType =
                          t.trim().isEmpty ? null : VocabClassifier.classify(t)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: meaningCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDeco('Content', 'Content',
                            const Color(0xFFFFB300))),
                    const SizedBox(height: 10),
                    TextField(
                        controller: topicCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDeco('Content', 'Content',
                            const Color(0xFF9C27B0))),
                    const SizedBox(height: 12),
                    const TrText('Ngôn ngữ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final lang in ['en', 'vi', 'pali', 'my'])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  lang == 'en' ? 'Content' : lang == 'vi' ? 'Content' : lang == 'pali' ? 'Pali' : 'Burmese',
                                  style: TextStyle(color: selectedLang == lang ? Colors.white : Colors.grey, fontSize: 11),
                                ),
                                selected: selectedLang == lang,
                                selectedColor: const Color(0xFF42A5F5),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                onSelected: (val) {
                                  if (val) setS(() => selectedLang = lang);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final text = textCtrl.text.trim(),
                                meaning = meaningCtrl.text.trim();
                            if (text.isEmpty || meaning.isEmpty) return;
                            final entry = p.addWithAutoClassify(
                              text: text,
                              meaning: meaning,
                              language: selectedLang,
                              topic: topicCtrl.text.trim().isEmpty ? null : topicCtrl.text.trim(),
                            );
                            Navigator.pop(sheetCtx);
                            if (entry.vocabType != VocabularyType.word) {
                              _showDecomposeDialog(entry, p);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: const Text(context.l10n.commonSave, style: TextStyle(fontWeight: FontWeight.bold)),
                        )),
                  ]),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDeco(String label, String hint, Color color) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        labelStyle: TextStyle(color: color, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: 1.5)),
      );

  void _showDecomposeDialog(WordEntry parent, VocabularyProvider p) {
    final result = p.autoDecompose(parent.word, parent.vocabType);
    if (result.isEmpty) return;
    final selWords = <String>{};
    final selPhrases = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFFFB300), size: 20),
                  SizedBox(width: 10),
                  TrText('Gợi ý tách thành phần', style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                Text('Chọn từ/cụm muốn lưu riêng từ "${parent.word}"',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 16),
                if (result.words.isNotEmpty) ...[
                  TrText('Từ đơn:', style: TextStyle(
                          color: VocabularyType.word.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.words.map((w) {
                        final sel = selWords.contains(w);
                        final exists = p.hasWord(w);
                        return _DecomposeChip(
                            word: w,
                            selected: sel,
                            exists: exists,
                            color: VocabularyType.word.color,
                            onTap: exists
                                ? null
                                : () => setS(() {
                                      sel
                                          ? selWords.remove(w)
                                          : selWords.add(w);
                                    }));
                      }).toList()),
                  const SizedBox(height: 12),
                ],
                if (result.phrases.isNotEmpty) ...[
                  TrText('Cụm từ:', style: TextStyle(
                          color: VocabularyType.phrase.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.phrases.take(8).map((ph) {
                        final sel = selPhrases.contains(ph);
                        final exists = p.hasWord(ph);
                        return _DecomposeChip(
                            word: ph,
                            selected: sel,
                            exists: exists,
                            color: VocabularyType.phrase.color,
                            onTap: exists
                                ? null
                                : () => setS(() {
                                      sel
                                          ? selPhrases.remove(ph)
                                          : selPhrases.add(ph);
                                    }));
                      }).toList()),
                  const SizedBox(height: 16),
                ],
                Row(children: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: TrText('Bỏ qua', style: TextStyle(color: Colors.grey[500]))),
                  const Spacer(),
                  if (selWords.isNotEmpty || selPhrases.isNotEmpty)
                    ElevatedButton(
                      onPressed: () {
                        p.saveDecomposeResults(
                            parentId: parent.id,
                            selectedWords: selWords.toList(),
                            selectedPhrases: selPhrases.toList(),
                            meanings: {});
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '✅ Created ${selWords.length + selPhrases.length} entry con'),
                            backgroundColor: const Color(0xFF4CAF50),
                            behavior: SnackBarBehavior.floating));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF)),
                      child: Text(
                          'Lưu ${selWords.length + selPhrases.length} mục'),
                    ),
                ]),
              ]),
        ),
      ),
    );
  }

  void _showEditSheet(WordEntry entry, VocabularyProvider p) {
    final wordC = TextEditingController(text: entry.word);
    final meanC = TextEditingController(text: entry.meaning);
    final ipaC = TextEditingController(text: entry.phonetic ?? '');
    final noteC = TextEditingController(text: entry.personalNotes ?? '');
    final topicC = TextEditingController(text: entry.topic ?? '');
    String selectedLang = entry.language;
    VocabularyType selectedType = entry.vocabType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A2235),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setS) {
            final pad = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + pad),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.edit, color: Color(0xFF42A5F5), size: 20),
                      const SizedBox(width: 10),
                      const TrText('Sửa chi tiết', style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFEF5350), size: 20),
                          onPressed: () {
                            p.removeWord(entry.id);
                            Navigator.pop(ctx);
                          }),
                    ]),
                    const SizedBox(height: 16),
                    _editField(wordC, 'Content', Icons.text_fields),
                    const SizedBox(height: 10),
                    _editField(meanC, 'Content', Icons.translate),
                    const SizedBox(height: 10),
                    _editField(ipaC, 'Content', Icons.record_voice_over_outlined),
                    const SizedBox(height: 10),
                    _editField(noteC, 'Note', Icons.note_alt_outlined, maxLines: 2),
                    const SizedBox(height: 10),
                    _editField(topicC, 'Content', Icons.folder_outlined),
                    
                    const SizedBox(height: 12),
                    const TrText('Phân loại Thực thể', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final type in VocabularyType.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  type.label(context),
                                  style: TextStyle(color: selectedType == type ? Colors.white : Colors.grey, fontSize: 11),
                                ),
                                selected: selectedType == type,
                                selectedColor: type.color,
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                onSelected: (val) {
                                  if (val) setS(() => selectedType = type);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const TrText('Ngôn ngữ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final lang in ['en', 'vi', 'pali', 'my'])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  lang == 'en' ? 'Content' : lang == 'vi' ? 'Content' : lang == 'pali' ? 'Pali' : 'Burmese',
                                  style: TextStyle(color: selectedLang == lang ? Colors.white : Colors.grey, fontSize: 11),
                                ),
                                selected: selectedLang == lang,
                                selectedColor: const Color(0xFF42A5F5),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                onSelected: (val) {
                                  if (val) setS(() => selectedLang = lang);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            p.updateWord(
                              entry.id,
                              word: wordC.text.trim(),
                              meaning: meanC.text.trim(),
                              phonetic: ipaC.text.trim(),
                              language: selectedLang,
                              topic: topicC.text.trim(),
                              vocabType: selectedType,
                            );
                            if (noteC.text.trim().isNotEmpty) {
                              p.updateNotes(entry.id, noteC.text.trim());
                            }
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF42A5F5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: const Text(context.l10n.commonSave, style: TextStyle(fontWeight: FontWeight.bold)),
                        )),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _editField(TextEditingController c, String label, IconData icon,
          {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 16),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none)),
      );
}

// ══════════════════════════════════════════════════════════
// COMPACT LIST ITEM
// ══════════════════════════════════════════════════════════
class _CompactListItem extends StatelessWidget {
  final WordEntry entry;
  final int index;
  final bool isExpanded, isPlaying, isSelected, isSelecting;
  final bool isAlreadySown;
  final WordListSettings settings;
  final VocabularyProvider provider;
  final int repeatCount, playingRepeat;
  final VoidCallback onTap, onLongPress, onEdit, onSpeak;
  final ValueChanged<int> onRepeatChanged;

  const _CompactListItem({
    required this.entry,
    required this.index,
    required this.isExpanded,
    required this.isPlaying,
    required this.isSelected,
    required this.isAlreadySown,
    required this.isSelecting,
    required this.settings,
    required this.provider,
    required this.repeatCount,
    required this.playingRepeat,
    required this.onTap,
    required this.onLongPress,
    required this.onRepeatChanged,
    required this.onEdit,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = entry.vocabType.color;
    final isDue = entry.isDue;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isPlaying
              ? Color(0xFF6C63FF).withValues(alpha: 0.12)
              : isSelected
                  ? Color(0xFF2196F3).withValues(alpha: 0.10)
                  : isExpanded
                      ? const Color(0xFF111827)
                      : isDue
                          ? Color(0xFFFF5722).withValues(alpha: 0.04)
                          : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPlaying
                ? Color(0xFF6C63FF).withValues(alpha: 0.4)
                : isSelected
                    ? Color(0xFF2196F3).withValues(alpha: 0.35)
                    : isExpanded
                        ? typeColor.withValues(alpha: 0.3)
                        : isDue
                            ? Color(0xFFFF5722).withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
            width: isPlaying ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          // ── Collapsed Row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(children: [
              // Selection checkbox or type badge
              if (isSelecting)
                Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2196F3)
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2196F3)
                                    : Colors.grey),
                            borderRadius: BorderRadius.circular(6)),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 13)
                            : null))
              else ...[
                if (entry.isUnborn)
                  _buildUnbornIndicator()
                else ...[
                  Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.center,
                      child: Text(entry.vocabType.badge,
                          style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))),
                  const SizedBox(width: 10),
                ],
              ],

              // Word + meaning
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      if (settings.showWord)
                        Flexible(
                            child: Text(entry.word,
                                style: TextStyle(
                                    color: isPlaying
                                        ? const Color(0xFF9C8FFF)
                                        : Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      if (settings.showPhonetic && entry.phonetic != null) ...[
                        const SizedBox(width: 6),
                        Text(entry.phonetic!,
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                                fontStyle: FontStyle.italic)),
                      ],
                    ]),
                    if (settings.showShortDefinition)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [
                          Expanded(
                              child: Text(entry.meaning,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 12),
                                  maxLines: isExpanded ? null : 1,
                                  overflow: isExpanded
                                      ? null
                                      : TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 40,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                      value: entry.mastery,
                                      minHeight: 3,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.06),
                                      valueColor: AlwaysStoppedAnimation(entry
                                          .zone.color
                                          .withValues(alpha: 0.7))))),
                          const SizedBox(width: 3),
                          Text('${(entry.mastery * 100).toInt()}%',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 9)),
                        ]),
                      ),
                  ])),

              // Encounter badge
              if (entry.encounterCount > 1)
                Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                        color: Color(0xFFFFB300).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('📌${entry.encounterCount}',
                        style: const TextStyle(fontSize: 9))),

              // Per-word repeat
              _PerWordRepeatBtn(
                  count: repeatCount,
                  isPlaying: isPlaying,
                  currentRepeat: playingRepeat,
                  onChanged: onRepeatChanged),
              const SizedBox(width: 2),

              // Seed Button (Gieo mầm vườn nhớ) - Sau icon lặp từ và trước YouGlish
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  final memoryController = context.read<MemoryController>();
                  if (isAlreadySown) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '🌱 "${entry.word}" đã được gieo trong vườn nhớ rồi!'),
                        backgroundColor: const Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } else {
                    final success = memoryController.addWord(
                      word: entry.word,
                      meaning: entry.meaning.isNotEmpty
                          ? entry.meaning
                          : 'Content',
                      phonetic: entry.phonetic,
                      example: entry.example,
                    );
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '🌱 Đã gieo mầm "${entry.word}" vào vườn trí nhớ!'),
                          backgroundColor: const Color(0xFF4CAF50),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isAlreadySown
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isAlreadySown
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    isAlreadySown ? Icons.spa : Icons.spa_outlined,
                    size: 13,
                    color: isAlreadySown
                        ? const Color(0xFF4CAF50)
                        : Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(width: 2),

              // YouGlish
              GestureDetector(
                onTap: () => YouGlishMiniSheet.show(context, entry.word),
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: Color(0xFF00BCD4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.record_voice_over,
                        size: 13, color: Color(0xFF00BCD4))),
              ),
              const SizedBox(width: 2),

              // TTS
              GestureDetector(
                onTap: onSpeak,
                child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: isPlaying
                            ? Color(0xFF6C63FF).withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.volume_up_outlined,
                        size: 13,
                        color: isPlaying
                            ? const Color(0xFF9C8FFF)
                            : Colors.grey[500])),
              ),

              // Expand indicator
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.grey[700]),
            ]),
          ),

          // ── Expanded Detail ──
          if (isExpanded) _buildExpanded(context),
        ]),
      ),
    );
  }

  Widget _buildUnbornIndicator() {
    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.star, color: Color(0xFFFFB300), size: 14),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .scale(
            duration: 1000.ms,
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.1, 1.1),
            curve: Curves.easeInOut)
        .then()
        .scale(
            duration: 1000.ms,
            begin: const Offset(1.1, 1.1),
            end: const Offset(0.8, 0.8),
            curve: Curves.easeInOut);
  }

  Widget _buildExpanded(BuildContext ctx) {
    final children = provider.getChildren(entry.id);
    final parents = provider.getParents(entry.id);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Divider(color: Colors.white.withValues(alpha: 0.06), height: 4),
        const SizedBox(height: 8),

        // Contexts
        if (entry.contexts.isNotEmpty) ...[
          _SectionHeader(
              icon: Icons.menu_book,
              label: 'Content'),
          const SizedBox(height: 6),
          ...entry.contexts.take(3).map((c) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.surroundingText.isNotEmpty)
                        Text('"${c.surroundingText}"',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                height: 1.4)),
                      if (c.sourceName != null) ...[
                        const SizedBox(height: 4),
                        Text('${c.sourceIcon} ${c.displaySource}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 10))
                      ],
                    ]),
              )),
          const SizedBox(height: 8),
        ],

        // Relationships
        if (parents.isNotEmpty || children.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.link, label: context.tr('Liên kết')),
          const SizedBox(height: 6),
          if (parents.isNotEmpty) ...[
            TrText('Xuất hiện trong:', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            const SizedBox(height: 4),
            Wrap(
                spacing: 6,
                runSpacing: 4,
                children: parents
                    .map((p) => _RelatedChip(entry: p, prefix: '▲'))
                    .toList()),
          ],
          if (children.isNotEmpty) ...[
            const SizedBox(height: 6),
            TrText('Chứa:', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            const SizedBox(height: 4),
            Wrap(
                spacing: 6,
                runSpacing: 4,
                children: children
                    .map((c) => _RelatedChip(entry: c, prefix: '▼'))
                    .toList()),
          ],
          const SizedBox(height: 8),
        ],

        // Notes
        if (entry.personalNotes != null && entry.personalNotes!.isNotEmpty) ...[
          const _SectionHeader(icon: Icons.note_alt_outlined, label: context.l10n.commonNotes),
          const SizedBox(height: 4),
          Text(entry.personalNotes!,
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 12, height: 1.5)),
          const SizedBox(height: 8),
        ],

        // SM-2 Skills
        const _SectionHeader(icon: Icons.bar_chart, label: context.l10n.commonReview),
        const SizedBox(height: 6),
        Row(children: [
          _SkillBar(
              label: context.l10n.commonUnderstanding,
              value: entry.understand,
              color: const Color(0xFF42A5F5)),
          const SizedBox(width: 8),
          _SkillBar(
              label: 'Nghe',
              value: entry.listen,
              color: const Color(0xFF66BB6A)),
          const SizedBox(width: 8),
          _SkillBar(
              label: context.tr('Đọc'), value: entry.read, color: const Color(0xFFEF5350)),
        ]),
        if (entry.nextReview != null) ...[
          const SizedBox(height: 4),
          Text(
              entry.isDue
                  ? 'Content'
                  : 'Content',
              style: TextStyle(
                  color:
                      entry.isDue ? const Color(0xFFFF5722) : Colors.grey[600],
                  fontSize: 11)),
        ],

        // Actions
        const SizedBox(height: 10),
        Row(children: [
          _ActionBtn(
              icon: Icons.edit_outlined,
              label: context.l10n.commonEdit,
              color: const Color(0xFF42A5F5),
              onTap: onEdit),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: Icons.play_arrow,
            label: 'Ôn',
            color: const Color(0xFF4CAF50),
            onTap: () => _navigateToReview(ctx, entry),
          ),
          const Spacer(),
          _ActionBtn(
              icon: Icons.delete_outline,
              label: context.l10n.ttsClear,
              color: const Color(0xFFEF5350),
              onTap: () => provider.removeWord(entry.id)),
        ]),
      ]),
    );
  }

  void _navigateToReview(BuildContext ctx, WordEntry word) {
    // Filter provider để chỉ hiện word này trước
    // Sau đó navigate đến ReviewTab
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => SingleWordReviewScreen(word: word),
      ),
    );
  }
}

class _ActiveFilterBadge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;

  const _ActiveFilterBadge({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 12, color: Colors.grey),
              SizedBox(width: 2),
              Text(context.l10n.commonAdd, style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════
// SMART GROUPS SHEET
// ══════════════════════════════════════════════════════════
class _SmartGroupsSheet extends StatelessWidget {
  final VocabularyProvider provider;
  const _SmartGroupsSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: ListView(controller: sc, children: [
          Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Smart Groups',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _gSection('Content', [
            _gItem(Icons.alarm, 'Content', provider.dueCount,
                const Color(0xFFFF5722), () {}),
            _gItem(Icons.star, 'Content', provider.masteredCount,
                const Color(0xFFFFD54F), () {}),
            _gItem(
                Icons.repeat,
                'Content',
                provider.frequentlyEncountered.length,
                const Color(0xFFFFB300),
                () {}),
            _gItem(Icons.visibility_off, 'Content', provider.blindSpots,
                const Color(0xFF616161), () {}),
          ]),
          const SizedBox(height: 16),
          _gSection(
              'Content',
              VocabularyType.values
                  .map((t) => _gItem(t.icon, t.label(context),
                          provider.wordsByType[t]?.length ?? 0, t.color, () {
                        provider.setFilterType(t);
                        Navigator.pop(context);
                      }))
                  .toList()),
          if (provider.allSources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _gSection(
                'Content',
                provider.allSources
                    .take(10)
                    .map((s) => _gItem(
                            _srcIcon(s),
                            s.length > 25 ? '${s.substring(0, 22)}...' : s,
                            provider.wordsBySource[s]?.length ?? 0,
                            const Color(0xFF2196F3), () {
                          provider.setFilterSource(s);
                          Navigator.pop(context);
                        }))
                    .toList()),
          ],
          if (provider.wordsByDate.isNotEmpty) ...[
            const SizedBox(height: 16),
            _gSection(
                'Content',
                provider.wordsByDate.entries
                    .take(7)
                    .map((e) => _gItem(
                        Icons.calendar_today,
                        e.key,
                        e.value.length,
                        const Color(0xFF9C27B0),
                        () => Navigator.pop(context)))
                    .toList()),
          ],
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  IconData _srcIcon(String s) => s.endsWith('.pdf')
      ? Icons.picture_as_pdf
      : s.startsWith('http')
          ? Icons.language
          : Icons.edit_note;

  Widget _gSection(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children
      ]);

  Widget _gItem(IconData icon, String label, int count, Color color,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('$count',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
            ])),
      );
}

// ══════════════════════════════════════════════════════════
// SORT SHEET
// ══════════════════════════════════════════════════════════
class _SortSheet extends StatelessWidget {
  final WordListSortMode current;
  final ValueChanged<WordListSortMode> onSelected;
  const _SortSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text(context.l10n.wordListSort, style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...WordListSortMode.values.map((mode) {
              final sel = current == mode;
              return GestureDetector(
                onTap: () => onSelected(mode),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                      color: sel
                          ? Color(0xFF6C63FF).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: sel
                          ? Border.all(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.4))
                          : null),
                  child: Row(children: [
                    Icon(mode.icon,
                        size: 16,
                        color:
                            sel ? const Color(0xFF9C8FFF) : Colors.grey[500]),
                    const SizedBox(width: 12),
                    Text(mode.label,
                        style: TextStyle(
                            color: sel ? Colors.white : Colors.grey[400],
                            fontWeight:
                                sel ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13)),
                    if (sel) ...[
                      const Spacer(),
                      const Icon(Icons.check,
                          color: Color(0xFF9C8FFF), size: 16)
                    ],
                  ]),
                ),
              );
            }),
          ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
// SETTINGS SHEET
// ══════════════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  final WordListSettings settings;
  final ValueChanged<WordListSettings> onChanged;
  const _SettingsSheet({required this.settings, required this.onChanged});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late WordListSettings _s;
  @override
  void initState() {
    super.initState();
    _s = widget.settings;
  }

  void _update(WordListSettings s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text(context.l10n.grammarDisplay, style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _toggle('Content', Icons.text_fields, _s.showWord,
                (v) => _update(_s.copyWith(showWord: v))),
            _toggle('Content', Icons.record_voice_over_outlined,
                _s.showPhonetic, (v) => _update(_s.copyWith(showPhonetic: v))),
            _toggle('Content', Icons.format_list_numbered, _s.showNumber,
                (v) => _update(_s.copyWith(showNumber: v))),
            const Divider(color: Color(0xFF1E2A3A), height: 20),
            _toggle('Content', Icons.short_text, _s.showShortDefinition,
                (v) => _update(_s.copyWith(showShortDefinition: v))),
            _toggle(
                'Content',
                Icons.article_outlined,
                _s.showFullDefinition,
                (v) => _update(_s.copyWith(showFullDefinition: v))),
            _toggle('Example', Icons.format_quote_outlined, _s.showExample,
                (v) => _update(_s.copyWith(showExample: v))),
            const Divider(color: Color(0xFF1E2A3A), height: 32),
            const TrText('Đồng bộ dữ liệu', style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const SyncStatusBadge(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<VocabularyProvider>().syncNow(forceAll: true);
                },
                icon: const Icon(Icons.sync, size: 18),
                label: const TrText('Đồng bộ ngay bây giờ', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                  side: const BorderSide(color: Color(0xFF6C63FF), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
    );
  }

  Widget _toggle(
          String label, IconData icon, bool value, ValueChanged<bool> cb) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 13))),
          Switch(
              value: value,
              onChanged: cb,
              activeThumbColor: const Color(0xFF6C63FF),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
      );
}

// ══════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  const _CountBadge(
      {required this.count,
      required this.color,
      this.icon,
      this.label,
      this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 3)
              ],
              Text('$count${label != null ? ' $label' : ''}',
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
      );
}

class _DropdownChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DropdownChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Icon(Icons.arrow_drop_down, size: 14, color: color),
            ])),
      );
}

class _PlayAllButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  const _PlayAllButton({required this.isPlaying, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                gradient: isPlaying
                    ? const LinearGradient(
                        colors: [Color(0xFFB71C1C), Color(0xFFE53935)])
                    : const LinearGradient(
                        colors: [Color(0xFF4527A0), Color(0xFF6C63FF)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: (isPlaying
                              ? const Color(0xFFE53935)
                              : const Color(0xFF6C63FF))
                          .withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                  color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(isPlaying ? 'Content' : 'Content',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ])),
      );
}

Future<void> _showRepeatCountMenu(
  BuildContext context, {
  required int current,
  required ValueChanged<int> onChanged,
  bool allowInfinite = false,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return;

  final rect = RelativeRect.fromRect(
    Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );

  final selected = await showMenu<int>(
    context: context,
    position: rect,
    color: const Color(0xFF141D2E),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: [
      if (allowInfinite)
        PopupMenuItem<int>(
          value: 0,
          child: _RepeatMenuItem(label: '∞', subtitle: context.tr('Lặp mãi'), selected: current == 0),
        ),
      for (final value in [1, 2, 3, 4, 5, 7, 10])
        PopupMenuItem<int>(
          value: value,
          child: _RepeatMenuItem(
            label: '$value×',
            subtitle: value == 1 ? 'Content' : 'Content',
            selected: current == value,
          ),
        ),
      const PopupMenuDivider(height: 1),
      const PopupMenuItem<int>(
        value: -1,
        child: _RepeatMenuItem(label: context.tr('Tùy chỉnh...'), subtitle: context.tr('Nhập số khác')),
      ),
    ],
  );

  if (selected == null) return;
  if (selected == -1) {
    final ctrl = TextEditingController(text: current > 0 ? '$current' : '');
    final custom = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2235),
        title: const TrText('Nhập số lần lặp', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'VD: 12',
            hintStyle: TextStyle(color: Colors.grey[600]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TrText(context.l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, value);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (custom != null && custom >= 0) {
      HapticFeedback.selectionClick();
      onChanged(custom);
    }
    return;
  }

  HapticFeedback.selectionClick();
  onChanged(selected);
}

class _RepeatMenuItem extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;

  const _RepeatMenuItem({
    required this.label,
    required this.subtitle,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (selected)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.check, size: 14, color: Color(0xFFFFB300)),
          )
        else
          const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListRepeatButton extends StatelessWidget {
  final int count, current;
  final ValueChanged<int> onChanged;
  const _ListRepeatButton(
      {required this.count, required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final label = count == 0 ? '∞' : '$count×';
    return GestureDetector(
      onTap: () => _showRepeatCountMenu(
        context,
        current: count,
        allowInfinite: true,
        onChanged: onChanged,
      ),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: count != 1
                  ? Color(0xFFFFB300).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: count != 1
                      ? Color(0xFFFFB300).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.repeat,
                size: 13,
                color: count != 1 ? const Color(0xFFFFB300) : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(current > 0 ? '$current/$label' : label,
                style: TextStyle(
                    color:
                        count != 1 ? const Color(0xFFFFB300) : Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ])),
    );
  }
}

class _PerWordRepeatBtn extends StatelessWidget {
  final int count;
  final bool isPlaying;
  final int currentRepeat;
  final ValueChanged<int> onChanged;
  const _PerWordRepeatBtn(
      {required this.count,
      required this.isPlaying,
      required this.currentRepeat,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _showRepeatCountMenu(
          context,
          current: count,
          onChanged: (v) => onChanged(v.clamp(1, 999)),
        ),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
                color: count > 1
                    ? Color(0xFFFFB300).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: count > 1
                        ? Color(0xFFFFB300).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.repeat,
                  size: 10,
                  color:
                      count > 1 ? const Color(0xFFFFB300) : Colors.grey[600]),
              const SizedBox(width: 2),
              Text(
                  isPlaying && currentRepeat > 0
                      ? '$currentRepeat/$count'
                      : '$count×',
                  style: TextStyle(
                      color: count > 1
                          ? const Color(0xFFFFB300)
                          : Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ])),
      );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]);
}

class _RelatedChip extends StatelessWidget {
  final WordEntry entry;
  final String prefix;
  const _RelatedChip({required this.entry, required this.prefix});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4, right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: entry.vocabType.bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: entry.vocabType.color.withValues(alpha: 0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$prefix ',
              style: TextStyle(
                  color: entry.vocabType.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          Text(entry.word,
              style: TextStyle(
                  color: entry.vocabType.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SkillBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _SkillBar(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
          const Spacer(),
          Text('${(value * 100).toInt()}%',
              style: TextStyle(color: Colors.grey[600], fontSize: 9)),
        ]),
        const SizedBox(height: 2),
        ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(color))),
      ]));
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
      );
}

class _DecomposeChip extends StatelessWidget {
  final String word;
  final bool selected, exists;
  final Color color;
  final VoidCallback? onTap;
  const _DecomposeChip(
      {required this.word,
      required this.selected,
      required this.exists,
      required this.color,
      this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: exists
                    ? Colors.grey.withValues(alpha: 0.1)
                    : selected
                        ? color.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: exists
                        ? Colors.grey.withValues(alpha: 0.2)
                        : selected
                            ? color
                            : Colors.white.withValues(alpha: 0.1))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (exists)
                const Icon(Icons.check, size: 12, color: Colors.grey)
              else if (selected)
                Icon(Icons.check_circle, size: 12, color: color),
              if (exists || selected) const SizedBox(width: 4),
              Text(word,
                  style: TextStyle(
                      color: exists
                          ? Colors.grey
                          : selected
                              ? Colors.white
                              : Colors.grey[300],
                      fontSize: 13)),
            ])),
      );
}

class _FilterSegmentChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FilterSegmentChip({
    required this.label,
    this.color,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? const Color(0xFF42A5F5);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? chipColor.withValues(alpha: 0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? chipColor : Colors.grey[400],
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close, size: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}