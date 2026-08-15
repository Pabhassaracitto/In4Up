import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../utils/text_parser.dart';
import 'package:in4up/core/language/tr_extension.dart';

class WordImportSheet extends StatefulWidget {
  const WordImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<TextProvider>()),
          ChangeNotifierProvider.value(
              value: context.read<VocabularyProvider>()),
        ],
        child: const WordImportSheet(),
      ),
    );
  }

  @override
  State<WordImportSheet> createState() => _WordImportSheetState();
}

class _WordImportSheetState extends State<WordImportSheet>
    with SingleTickerProviderStateMixin {
  static const int _previewLimit = 80;

  late TabController _tabCtrl;

  final _pasteCtrl = TextEditingController();
  List<_ImportCandidate> _parsedWords = [];
  List<_ImportCandidate> _providerWords = [];
  int _minLength = 3;
  bool _excludeStopWords = true;
  bool _onlyNewWords = true;
  bool _showAllClipboard = false;
  bool _showAllProvider = false;
  bool _showAllFile = false;
  String _providerSourceKey = '';

  String? _filePath;
  String _fileContent = '';
  List<_ImportCandidate> _fileWords = [];
  bool _isLoadingFile = false;

  VocabularyProvider get _provider => context.read<VocabularyProvider>();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _pasteCtrl.dispose();
    super.dispose();
  }

  List<_ImportCandidate> _parseText(String text) {
    final structured = _parseStructuredContent(text);
    if (structured.isNotEmpty) {
      return structured;
    }

    final freq =
        TextParser.wordFrequency(text, excludeStopWords: _excludeStopWords);

    return freq.entries
        .where((e) => e.key.length >= _minLength)
        .where((e) => !_onlyNewWords || !_provider.hasWord(e.key))
        .map((e) => _ImportCandidate(
              word: e.key,
              frequency: e.value,
              selected: true,
            ))
        .toList()
      ..sort((a, b) => b.frequency.compareTo(a.frequency));
  }

  void _parsePasted() {
    final text = _pasteCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _parsedWords = []);
      return;
    }
    setState(() {
      _parsedWords = _parseText(text);
    });
  }

  void _refreshProviderWords(TextProvider tp) {
    final nextKey = [
      tp.fullText.hashCode,
      _minLength,
      _excludeStopWords,
      _onlyNewWords,
    ].join('|');
    if (_providerSourceKey == nextKey) return;
    _providerSourceKey = nextKey;
    _providerWords = _parseFromProvider(tp);
  }

  List<_ImportCandidate> _parseFromProvider(TextProvider tp) {
    final text = tp.fullText;
    if (text.isEmpty) return [];
    return _parseText(text);
  }

  static const Map<String, String> _fieldAliases = {
    'word': 'word',
    'vocab': 'word',
    'tu': 'word',
    'tuvung': 'word',
    'term': 'word',
    'meaning': 'meaning',
    'nghia': 'meaning',
    'definition': 'meaning',
    'ipa': 'phonetic',
    'phonetic': 'phonetic',
    'pronunciation': 'phonetic',
    'topic': 'topic',
    'category': 'topic',
    'chude': 'topic',
    'folder': 'topic',
    'example': 'example',
    'example_simple': 'exampleSimple',
    'simpleexample': 'exampleSimple',
    'vidu': 'example',
    'vidudon': 'exampleSimple',
    'example_complex': 'exampleComplex',
    'complexexample': 'exampleComplex',
    'viduphuc': 'exampleComplex',
    'language': 'language',
    'lang': 'language',
    'ngonngu': 'language',
  };

  List<_ImportCandidate> _parseStructuredContent(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];

    final headerParts = _splitStructuredLine(lines.first);
    final normalizedHeader = headerParts.map(_normalizeHeaderKey).toList();
    final mapped = normalizedHeader.map((e) => _fieldAliases[e]).toList();
    if (!mapped.contains('word')) return const [];
    if (mapped.whereType<String>().toSet().length < 2) return const [];

    final candidates = <_ImportCandidate>[];
    for (final line in lines.skip(1)) {
      final parts = _splitStructuredLine(line);
      if (parts.isEmpty) continue;
      final data = <String, String>{};
      for (int i = 0; i < mapped.length && i < parts.length; i++) {
        final key = mapped[i];
        if (key == null) continue;
        data[key] = parts[i].trim();
      }

      final word = (data['word'] ?? '').trim().toLowerCase();
      if (word.isEmpty || word.length < _minLength) continue;
      if (_onlyNewWords && _provider.hasWord(word)) continue;

      final exampleParts = <String>[];
      if ((data['example'] ?? '').trim().isNotEmpty) {
        exampleParts.add(data['example']!.trim());
      }
      if ((data['exampleSimple'] ?? '').trim().isNotEmpty) {
        exampleParts.add('Content'exampleSimple']!.trim()}');
      }
      if ((data['exampleComplex'] ?? '').trim().isNotEmpty) {
        exampleParts.add('Content'exampleComplex']!.trim()}');
      }

      candidates.add(
        _ImportCandidate(
          word: word,
          meaning: _nullIfEmpty(data['meaning']),
          phonetic: _nullIfEmpty(data['phonetic']),
          topic: _nullIfEmpty(data['topic']),
          language: _nullIfEmpty(data['language']) ?? 'en',
          example: exampleParts.isEmpty ? null : exampleParts.join('\n'),
          rawLine: line,
          selected: true,
          frequency: 1,
        ),
      );
    }

    return candidates;
  }

  List<String> _splitStructuredLine(String line) {
    if (line.contains('\t')) {
      return line.split('\t').map((e) => e.trim()).toList();
    }
    if (line.contains('|')) {
      return line.split('|').map((e) => e.trim()).toList();
    }
    if (line.contains(';')) {
      return line.split(';').map((e) => e.trim()).toList();
    }
    if (line.contains(',')) {
      return line.split(',').map((e) => e.trim()).toList();
    }
    return const [];
  }

  String _normalizeHeaderKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zA-Z\u00C0-\u024F]'), '')
        .replaceAll('ừ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('í', 'i')
        .replaceAll('ị', 'i')
        .replaceAll('ý', 'y')
        .replaceAll('ỳ', 'y')
        .replaceAll('đ', 'd')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ă', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ơ', 'o');
  }

  String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _filePath = result.files.single.path;
      _isLoadingFile = true;
    });

    try {
      final content = await File(_filePath!).readAsString();
      final words = _parseFileContent(content);
      setState(() {
        _fileContent = content;
        _fileWords = words;
        _isLoadingFile = false;
      });
    } catch (e) {
      setState(() => _isLoadingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Content')),
        );
      }
    }
  }

  List<_ImportCandidate> _parseFileContent(String content) {
    final structured = _parseStructuredContent(content);
    if (structured.isNotEmpty) return structured;

    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final candidates = <_ImportCandidate>[];

    for (final line in lines) {
      final parts = line.split(RegExp(r'[,;]'));
      final word = parts.first.trim().toLowerCase();
      final meaning =
          parts.length > 1 ? parts.sublist(1).join(',').trim() : null;

      if (word.isEmpty || word.length < _minLength) continue;
      if (_onlyNewWords && _provider.hasWord(word)) continue;

      candidates.add(_ImportCandidate(
        word: word,
        meaning: _nullIfEmpty(meaning),
        rawLine: line,
        selected: true,
      ));
    }
    return candidates;
  }

  // ★ UPDATED: Dùng VocabularyProvider.addWithAutoClassify thay vì WordEntry.manual
  void _doImport(List<_ImportCandidate> candidates) {
    final selected = candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    final provider = _provider;
    int count = 0;
    for (final c in selected) {
      if (!provider.hasWord(c.word)) {
        final entry = provider.addWithAutoClassify(
          text: c.word,
          meaning: c.meaning ?? '',
          phonetic: c.phonetic,
          language: c.language,
          topic: c.topic,
        );
        if ((c.example ?? '').trim().isNotEmpty) {
          provider.updateWord(entry.id, example: c.example);
        }
        count++;
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Content'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _reparseAllSources() {
    if (_pasteCtrl.text.trim().isNotEmpty) {
      _parsedWords = _parseText(_pasteCtrl.text.trim());
    }
    if (_filePath != null && _fileContent.isNotEmpty) {
      _fileWords = _parseFileContent(_fileContent);
    }
    _providerSourceKey = '';
  }

  Future<void> _pickMinLength(BuildContext context) async {
    final selected = await showMenu<int>(
      context: context,
      position: const RelativeRect.fromLTRB(20, 150, 20, 0),
      color: const Color(0xFF141D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        for (final value in [1, 2, 3, 4, 5, 6, 8])
          PopupMenuItem<int>(
            value: value,
            child: _MinLengthMenuItem(
              label: 'Content',
              selected: _minLength == value,
            ),
          ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<int>(
          value: -1,
          child: _MinLengthMenuItem(label: context.tr('Tùy chỉnh...')),
        ),
      ],
    );

    if (selected == null) return;
    if (selected == -1) {
      final ctrl = TextEditingController(text: '$_minLength');
      final custom = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: const TrText('Tối thiểu bao nhiêu ký tự?', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const TrText(context.l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (custom != null && custom >= 1) {
        setState(() {
          _minLength = custom;
          _reparseAllSources();
        });
      }
      return;
    }

    setState(() {
      _minLength = selected;
      _reparseAllSources();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF6C63FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.download_outlined,
                        color: Color(0xFF6C63FF), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const TrText('Import từ vựng', style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: Color(0xFF6C63FF).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Color(0xFF6C63FF).withValues(alpha: 0.5)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(
                      icon: Icon(Icons.content_paste, size: 15),
                      text: 'Clipboard'),
                  Tab(
                      icon: Icon(Icons.article_outlined, size: 15),
                      text: context.tr('Văn bản')),
                  Tab(
                      icon: Icon(Icons.folder_outlined, size: 15),
                      text: 'File'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildOptionsBar(),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildClipboardTab(scroll),
                  _buildTextProviderTab(scroll),
                  _buildFileTab(scroll),
                ],
              ),
            ),
            SizedBox(height: bottomPad + 4),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _OptionChip(
              label: 'Content',
              icon: Icons.text_fields,
              onTap: () => _pickMinLength(context),
            ),
            const SizedBox(width: 8),
            _OptionChip(
              label: context.tr('Bỏ stop words'),
              icon: Icons.filter_list,
              isActive: _excludeStopWords,
              onTap: () {
                setState(() => _excludeStopWords = !_excludeStopWords);
                _reparseAllSources();
              },
            ),
            const SizedBox(width: 8),
            _OptionChip(
              label: context.tr('Chỉ từ mới'),
              icon: Icons.new_releases_outlined,
              isActive: _onlyNewWords,
              onTap: () {
                setState(() => _onlyNewWords = !_onlyNewWords);
                _reparseAllSources();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClipboardTab(ScrollController scroll) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _pasteCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Dán văn bản hoặc danh sách từ vào đây...\nHỗ trợ: text thường, một từ mỗi dòng, hoặc bảng có cột như word, meaning, ipa, topic, example, language',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
                onChanged: (_) {
                  if (_pasteCtrl.text.length > 20) _parsePasted();
                },
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.content_paste,
                        size: 14, color: Color(0xFF6C63FF)),
                    label: const TrText('Paste từ clipboard', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        _pasteCtrl.text = data!.text!;
                        _parsePasted();
                      }
                    },
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: Icon(Icons.clear, size: 14, color: Colors.grey[600]),
                    label: Text(context.l10n.ttsClear, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    onPressed: () {
                      _pasteCtrl.clear();
                      setState(() => _parsedWords = []);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_parsedWords.isNotEmpty) ...[
          _buildWordList(_parsedWords, (idx) {
            setState(
                () => _parsedWords[idx].selected = !_parsedWords[idx].selected);
          },
              expanded: _showAllClipboard,
              onToggleExpanded: () => setState(() => _showAllClipboard = !_showAllClipboard)),
          const SizedBox(height: 12),
          _buildImportButton(_parsedWords),
        ] else if (_pasteCtrl.text.isNotEmpty) ...[
          Center(
            child: TrText('Không tìm thấy từ nào phù hợp\n(thử giảm độ dài tối thiểu)', style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextProviderTab(ScrollController scroll) {
    return Consumer<TextProvider>(
      builder: (_, tp, __) {
        final hasText = tp.fullText.isNotEmpty;

        if (!hasText) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.article_outlined, size: 48, color: Colors.grey[700]),
                const SizedBox(height: 12),
                TrText('Chưa có văn bản nào được mở', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 4),
                TrText('Mở văn bản trong tab "Đọc" trước', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
            ),
          );
        }

        _refreshProviderWords(tp);
        final words = _providerWords;

        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF2196F3).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Color(0xFF2196F3).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF2196F3), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${tp.currentDocument?.title ?? 'Content'}" — ${tp.lines.length} dòng',
                      style: const TextStyle(
                          color: Color(0xFF2196F3), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (words.isEmpty)
              Center(
                child: TrText('Tất cả từ đã có trong danh sách', style: TextStyle(color: Colors.grey[500])),
              )
            else ...[
              _buildWordList(words, (idx) {
                setState(() => words[idx].selected = !words[idx].selected);
              },
                  expanded: _showAllProvider,
                  onToggleExpanded: () => setState(() => _showAllProvider = !_showAllProvider)),
              const SizedBox(height: 12),
              _buildImportButton(words),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFileTab(ScrollController scroll) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.help_outline,
                    color: Color(0xFFFFB300), size: 15),
                const SizedBox(width: 6),
                TrText('Định dạng hỗ trợ', style: TextStyle(
                        color: Colors.grey[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Text(
                '.txt: Mỗi dòng 1 từ, hoặc văn bản thường\n'
                '.csv/.txt bảng cột: word, meaning, ipa, topic, example, example_simple, example_complex, language\n'
                'Content',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Color(0xFF4CAF50).withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.file_open_outlined,
                    color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 10),
                Text(
                  _filePath != null
                      ? _filePath!.split('/').last
                      : 'Content',
                  style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingFile)
          const Center(child: CircularProgressIndicator(strokeWidth: 2))
        else if (_fileWords.isNotEmpty) ...[
          _buildWordList(_fileWords, (idx) {
            setState(
                () => _fileWords[idx].selected = !_fileWords[idx].selected);
          },
              expanded: _showAllFile,
              onToggleExpanded: () => setState(() => _showAllFile = !_showAllFile)),
          const SizedBox(height: 12),
          _buildImportButton(_fileWords),
        ],
      ],
    );
  }

  Widget _buildWordList(
    List<_ImportCandidate> words,
    void Function(int) onToggle, {
    required bool expanded,
    required VoidCallback onToggleExpanded,
  }) {
    final selectedCount = words.where((w) => w.selected).length;
    final visibleWords = expanded ? words : words.take(_previewLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${words.length} từ tìm thấy · $selectedCount được chọn',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                for (final w in words) {
                  w.selected = true;
                }
              }),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const TrText('Chọn tất', style: TextStyle(fontSize: 11, color: Color(0xFF6C63FF))),
            ),
            TextButton(
              onPressed: () => setState(() {
                for (final w in words) {
                  w.selected = false;
                }
              }),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(context.l10n.commonDeselect, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: visibleWords.asMap().entries.map((entry) {
            final i = entry.key;
            final w = entry.value;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: w.selected
                      ? const Color(0xFF6C63FF).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: w.selected
                        ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      w.selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 13,
                      color: w.selected
                          ? const Color(0xFF9C8FFF)
                          : Colors.grey[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      w.word,
                      style: TextStyle(
                        color: w.selected ? Colors.white : Colors.grey[500],
                        fontSize: 12,
                        fontWeight:
                            w.selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (w.frequency > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '×${w.frequency}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 9),
                      ),
                    ],
                    if ((w.meaning ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.info_outline, size: 11, color: Colors.grey[600]),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (words.length > _previewLimit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: onToggleExpanded,
              icon: Icon(
                expanded ? Icons.unfold_less : Icons.unfold_more,
                size: 16,
                color: const Color(0xFF6C63FF),
              ),
              label: Text(
                expanded
                    ? 'Content'
                    : 'Mở rộng thêm ${words.length - _previewLimit} từ',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImportButton(List<_ImportCandidate> candidates) {
    final count = candidates.where((c) => c.selected).length;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: count > 0 ? () => _doImport(candidates) : null,
        icon: const Icon(Icons.download_done, size: 18),
        label: Text(
          'Content',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          disabledBackgroundColor: Color(0xFF6C63FF).withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _ImportCandidate {
  final String word;
  final String? meaning;
  final String? phonetic;
  final String? topic;
  final String? example;
  final String language;
  final String? rawLine;
  final int frequency;
  bool selected;

  _ImportCandidate({
    required this.word,
    this.meaning,
    this.phonetic,
    this.topic,
    this.example,
    this.language = 'en',
    this.rawLine,
    this.frequency = 1,
    this.selected = true,
  });
}

class _MinLengthMenuItem extends StatelessWidget {
  final String label;
  final bool selected;

  const _MinLengthMenuItem({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (selected)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.check, size: 14, color: Color(0xFF6C63FF)),
          )
        else
          const SizedBox(width: 22),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.icon,
    this.isActive = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? Color(0xFF6C63FF).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? Color(0xFF6C63FF).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: isActive ? const Color(0xFF9C8FFF) : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF9C8FFF) : Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}