import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../utils/text_parser.dart';

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

  List<_ImportCandidate> _parseStructuredContent(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return const [];

    final mapped = WordTableParser.mapHeader(lines.first);
    if (!mapped.contains('word')) return const [];
    if (mapped.whereType<String>().toSet().length < 2) return const [];
    final delimiter = WordTableParser.detectDelimiter(lines.first);

    final candidates = <_ImportCandidate>[];
    for (final line in lines.skip(1)) {
      final parts = WordTableParser.splitCsvLine(line, delimiter);
      if (parts.isEmpty) continue;
      final data = WordTableParser.alignRow(parts, mapped);

      final word = (data['word'] ?? '').trim().toLowerCase();
      // Hàng cấu trúc = người dùng liệt kê ĐÚNG Ý → không áp _minLength
      // (từ 1-2 ký tự vẫn là entry hợp lệ cho từ điển/trò chơi).
      if (word.isEmpty) continue;
      final existed = _provider.hasWord(word);
      // Hàng đã có trong WordList vẫn HIỆN để user xem/cập nhật meaning
      // (smart-fill khi import: chỉ điền chỗ trống, không ghi đè).

      final exampleParts = <String>[];
      if ((data['example'] ?? '').trim().isNotEmpty) {
        exampleParts.add(data['example']!.trim());
      }
      if ((data['exampleSimple'] ?? '').trim().isNotEmpty) {
        exampleParts.add('Ví dụ đơn: ${data['exampleSimple']!.trim()}');
      }
      if ((data['exampleComplex'] ?? '').trim().isNotEmpty) {
        exampleParts.add('Ví dụ phức: ${data['exampleComplex']!.trim()}');
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
          existed: existed,
          selected: true,
          frequency: 1,
        ),
      );
    }

    return candidates;
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
          SnackBar(content: Text(context.uiText('Lỗi đọc file: $e'))),
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

  // ★ UPDATED: Dùng VocabularyProvider.addWithAutoClassify (smart-fill) —
  // entry MỚI: tạo đầy đủ meaning/phonetic/topic/language/example.
  // entry ĐÃ CÓ: chỉ BỔ SUNG chỗ trống (meaning/IPA/example) + tag
  // topic/language — không ghi đè dữ liệu cũ, không mất ngữ cảnh.
  void _doImport(List<_ImportCandidate> candidates) {
    final selected = candidates.where((c) => c.selected).toList();
    if (selected.isEmpty) return;

    final provider = _provider;
    int added = 0;
    int updated = 0;
    for (final c in selected) {
      final existed = provider.hasWord(c.word);
      final entry = provider.addWithAutoClassify(
        text: c.word,
        meaning: c.meaning ?? '',
        phonetic: c.phonetic,
        language: c.language,
        topic: c.topic,
      );
      // example: chỉ điền khi còn trống (không đè ví dụ user đã có)
      if ((c.example ?? '').trim().isNotEmpty &&
          (entry.example ?? '').trim().isEmpty) {
        provider.updateWord(entry.id, example: c.example);
      }
      if (existed) {
        updated++;
      } else {
        added++;
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated > 0
              ? '✅ Đã import: +$added mới, cập nhật $updated đã có'
              : '✅ Đã import $added từ',
        ),
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
              label: '$value ký tự',
              selected: _minLength == value,
            ),
          ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<int>(
          value: -1,
          child: _MinLengthMenuItem(label: 'Tùy chỉnh...'),
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
          title: const Text('Tối thiểu bao nhiêu ký tự?',
              style: TextStyle(color: Colors.white)),
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
              child: const Text('Hủy'),
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
                  const Text(
                    'Import từ vựng',
                    style: TextStyle(
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
                tabs: [
                  const Tab(
                      icon: Icon(Icons.content_paste, size: 15),
                      text: 'Clipboard'),
                  Tab(
                      icon: const Icon(Icons.article_outlined, size: 15),
                      text: context.uiText('Văn bản')),
                  const Tab(
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
              label: 'Tối thiểu $_minLength ký tự',
              icon: Icons.text_fields,
              onTap: () => _pickMinLength(context),
            ),
            const SizedBox(width: 8),
            _OptionChip(
              label: 'Bỏ stop words',
              icon: Icons.filter_list,
              isActive: _excludeStopWords,
              onTap: () {
                setState(() => _excludeStopWords = !_excludeStopWords);
                _reparseAllSources();
              },
            ),
            const SizedBox(width: 8),
            _OptionChip(
              label: 'Chỉ từ mới',
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
                  hintText: context.uiText(
                      'Dán bảng có header: word, meaning, ipa, topic, example, language\n(tab hoặc dấu phẩy; meaning có dấu phẩy thì bọc "nét nháy")\nHoặc text thường / một từ mỗi dòng...'),
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
                    label: const Text('Paste từ clipboard',
                        style:
                            TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
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
                    label: Text('Xóa',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
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
            child: Text(
              'Không tìm thấy từ nào phù hợp\n(thử giảm độ dài tối thiểu)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                Text('Chưa có văn bản nào được mở',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text('Mở văn bản trong tab "Đọc" trước',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
            ),
          );
        }

        _refreshProviderWords(tp);
        final words = _providerWords;
        final documentTitle = tp.currentDocument?.title ??
            context.uiText('Văn bản hiện tại');

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
                      context.uiText('"$documentTitle" — ${tp.lines.length} dòng'),
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
                child: Text('Tất cả từ đã có trong danh sách',
                    style: TextStyle(color: Colors.grey[500])),
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
                Text('Định dạng hỗ trợ',
                    style: TextStyle(
                        color: Colors.grey[300],
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Text(
                '.txt: Mỗi dòng 1 từ, hoặc văn bản thường\n'
                '.csv/.txt bảng cột (cần dòng header): word, meaning, ipa, topic, example, example_simple, example_complex, language\n'
                'Ngăn cột: tab, phẩy, chấm phẩy hoặc | — ý nghĩa có dấu phẩy thì bọc "nét nháy"\n'
                'Từ/cụm ĐÃ CÓ trong WordList vẫn hiện (badge "đã có") — import chỉ bổ sung nghĩa/IPA/ví dụ CHỖ TRỐNG + tag, không ghi đè',
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
                      : 'Chọn file .txt hoặc .csv',
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
                context.uiText('${words.length} từ tìm thấy · $selectedCount được chọn'),
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
              child: const Text('Chọn tất',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6C63FF))),
            ),
            TextButton(
              onPressed: () => setState(() {
                for (final w in words) {
                  w.selected = false;
                }
              }),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text('Bỏ chọn',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          w.selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 13,
                          color: w.selected
                              ? const Color(0xFF9C8FFF)
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            w.word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  w.selected ? Colors.white : Colors.grey[500],
                              fontSize: 12,
                              fontWeight: w.selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (w.existed) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'đã có',
                              style: TextStyle(
                                  color: Colors.orange[300], fontSize: 8.5),
                            ),
                          ),
                        ],
                        if (w.frequency > 1) ...[
                          const SizedBox(width: 4),
                          Text(
                            '×${w.frequency}',
                            style:
                                TextStyle(color: Colors.grey[600], fontSize: 9),
                          ),
                        ],
                      ],
                    ),
                    // meaning / IPA / topic — thuộc tính giải thích cho từ,
                    // quan trọng cho merge từ điển + trò chơi "nhìn chữ,
                    // nghe âm, viết nghĩa" (AI chấm)
                    if ((w.meaning ?? '').trim().isNotEmpty ||
                        (w.phonetic ?? '').trim().isNotEmpty ||
                        (w.topic ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 19, top: 1),
                        child: Text(
                          [
                            if ((w.phonetic ?? '').trim().isNotEmpty)
                              w.phonetic!.trim(),
                            if ((w.meaning ?? '').trim().isNotEmpty)
                              w.meaning!.trim(),
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10.5,
                          ),
                        ),
                      ),
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
                context.uiText(expanded
                    ? 'Thu gọn danh sách'
                    : 'Mở rộng thêm ${words.length - _previewLimit} từ'),
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
          context.uiText('Import $count từ vào danh sách'),
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
  /// true = từ/cụm này đã có trong WordList (import sẽ smart-fill,
  /// không tạo entry trùng).
  final bool existed;
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
    this.existed = false,
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
          context.uiText(label),
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
              context.uiText(label),
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

// ═══════════════════════════════════════════════════════════
// PURE PARSER — bảng có header (test được, không phụ thuộc widget)
//
// Định dạng chuẩn (như hướng dẫn trong UI):
//   word, meaning, ipa, topic, example, example_simple, example_complex, language
//
// Robust 3 điểm:
//  - Header alias được chuẩn hóa (bỏ gạch dưới/dấu) nên `example_simple`
//    /`example_complex` KHÔNG còn bị bỏ sót (bug cũ: key alias có `_`
//    nhưng key đã normalize không có `_` → tra không thấy).
//  - Hỗ trợ nháy kép ("...") cho cột chứa delimiter.
//  - Khi một HÀNG có NHIỀU ô hơn header (meaning/example chứa dấu phẩy
//    KHÔNG bọc nháy — rất hay gặp với danh sách Gemini sinh ra) → căn lại
//    bằng mỏ neo (word = ô đầu, ipa = ô /.../, language = ô cuối) để cột
//    không bị lệch phải.
// ═══════════════════════════════════════════════════════════

class WordTableParser {
  WordTableParser._();

  static const Map<String, String> fieldAliases = {
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
    'phienam': 'phonetic',
    'topic': 'topic',
    'category': 'topic',
    'chude': 'topic',
    'folder': 'topic',
    'example': 'example',
    'vidu': 'example',
    'example_simple': 'exampleSimple',
    'simpleexample': 'exampleSimple',
    'vidudon': 'exampleSimple',
    'example_complex': 'exampleComplex',
    'complexexample': 'exampleComplex',
    'viduphuc': 'exampleComplex',
    'language': 'language',
    'lang': 'language',
    'ngonngu': 'language',
    'tiengviet': 'language',
    'tienganh': 'language',
  };

  /// Cột tự do — có thể chứa dấu phẩy nội bộ (hấp thụ ô dư khi hàng dài
  /// hơn header).
  static const Set<String> _wideFields = {
    'meaning',
    'example',
    'exampleSimple',
    'exampleComplex',
  };

  /// Alias đã normalize key (tra nhanh, tránh lệch do gạch dưới/dấu).
  static final Map<String, String> _normAliases =
      fieldAliases.map((k, v) => MapEntry(normKey(k), v));

  /// Bảng bỏ dấu tiếng Việt ĐẦY ĐỦ (cả khối Latin Extended Additional
  /// U+1E00+ — nếu strip TRƯỚC khi map thì 'từ' mất cả chữ 'u' → 't').
  static const Map<String, String> _viBase = {
    // a
    '\u00E1': 'a', '\u00E0': 'a', '\u1EA3': 'a', '\u00E3': 'a', '\u1EA1': 'a', '\u0103': 'a', '\u1EAF': 'a', '\u1EB1': 'a', '\u1EB3': 'a', '\u1EB5': 'a', '\u1EA4': 'a', '\u00E2': 'a', '\u1EA5': 'a', '\u1EA7': 'a', '\u1EA9': 'a', '\u1EAB': 'a', '\u1EAD': 'a',
    // e
    '\u00E9': 'e', '\u00E8': 'e', '\u1EBB': 'e', '\u1EBD': 'e', '\u00EA': 'e', '\u1EBF': 'e', '\u1EC1': 'e', '\u1EC3': 'e', '\u1EC5': 'e', '\u1EC7': 'e',
    // i
    '\u00ED': 'i', '\u00EC': 'i', '\u1EC9': 'i', '\u0129': 'i', '\u1ECB': 'i',
    // o
    '\u00F3': 'o', '\u00F2': 'o', '\u1ECF': 'o', '\u00F5': 'o', '\u1ECD': 'o', '\u01A1': 'o', '\u1EDB': 'o', '\u1EDD': 'o', '\u1EE3': 'o', '\u00F4': 'o', '\u1ED1': 'o', '\u1ED3': 'o', '\u1ED5': 'o', '\u1ED7': 'o', '\u1ED9': 'o',
    // u
    '\u00FA': 'u', '\u00F9': 'u', '\u1EE7': 'u', '\u0169': 'u', '\u1EE5': 'u', '\u01B0': 'u', '\u1EE9': 'u', '\u1EEB': 'u', '\u1EED': 'u', '\u1EEF': 'u', '\u1EF1': 'u',
    // y
    '\u00FD': 'y', '\u1EF3': 'y', '\u1EF7': 'y', '\u1EF9': 'y', '\u1EF5': 'y',
    // d
    '\u0111': 'd',
  };

  /// Chuẩn hóa tên cột header: hạ chữ thường → bỏ dấu tiếng Việt →
  /// bỏ ký tự đặc biệt (để "Từ vựng" ≡ "tu" ≡ "tu_vung" ≡ "tuvung").
  static String normKey(String input) {
    var s = input.toLowerCase();
    for (final e in _viBase.entries) {
      s = s.replaceAll(e.key, e.value);
    }
    return s.replaceAll(RegExp(r'[^a-zA-Z]'), '');
  }

  /// Map dòng header → danh sách tên trường (null = cột không nhận ra).
  static List<String?> mapHeader(String headerLine) {
    final parts = splitHeaderLine(headerLine);
    return parts.map((e) => _normAliases[normKey(e)]).toList();
  }

  /// Chọn delimiter từ dòng header: tab > | > ; > ,
  static String detectDelimiter(String line) {
    if (line.contains('\t')) return '\t';
    if (line.contains('|')) return '|';
    if (line.contains(';')) return ';';
    return ',';
  }

  /// Tách dòng header (không cần hiểu nháy — header không chứa nháy).
  static List<String> splitHeaderLine(String line) {
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

  /// Tách hàng dữ liệu theo delimiter, hiểu NHÁY KÉP (`"..."`) + escape
  /// `""` — meaning như `Chuyển tiếp, thay đổi trạng thái` bọc nháy
  /// không bị xé giữa chừng (CSV đúng chuẩn).
  static List<String> splitCsvLine(String line, String delimiter) {
    final parts = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buf.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == delimiter) {
        parts.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    parts.add(buf.toString().trim());
    return parts;
  }

  /// Cell có dạng IPA: `/əˈbʌndəns/`.
  static bool looksLikeIpa(String s) {
    final t = s.trim();
    return t.length >= 3 && t.startsWith('/') && t.endsWith('/');
  }

  /// Căn ô của hàng dữ liệu ([parts]) với cột header ([fields]).
  ///
  /// - Ô < cột → khớp 1-1 theo vị trí, đệm '' (như trước).
  /// - Ô = cột → thường là hàng sạch → 1-1. NGOẠI LỆ (Gemini hay gặp):
  ///     + ô ở cột ipa KHÔNG phải IPA nhưng 1 ô khác DẠNG IPA
  ///       (vd meaning lọt 1 dấu phẩy làm IPA chạy sang ô khác)
  ///       → căn lại bằng mỏ neo.
  ///     + ô ở cột ipa không phải IPA và CHỨA DẤU CÁCH (IPA không bao
  ///       giờ có khoảng trắng) → coi IPA bị bỏ trống, ô đó là phần
  ///       meaning bị tách → gộp vào meaning.
  /// - Ô > cột (dấu phẩy không bọc nháy) → căn lại bằng mỏ neo:
  ///     word = ô đầu · language = ô cuối · ipa = ô /.../ đầu tiên.
  ///   Ô TRƯỚC ipa → gộp vào meaning (", "); ô SAU ipa →
  ///   topic/example/exampleSimple/exampleComplex (cột tự do đứng đầu
  ///   hấp thụ ô dư).
  ///
  /// Chỉ áp căn neo khi đủ mỏ neo của định dạng chuẩn; header lạ →
  /// giữ hành vi vị trí cũ (best-effort).
  static Map<String, String> alignRow(
    List<String> parts,
    List<String?> fields,
  ) {
    if (parts.isEmpty || fields.isEmpty) return const {};

    // Số ô ≤ số cột.
    if (parts.length <= fields.length) {
      final n = parts.length;
      final p = fields.indexOf('phonetic');
      if (p > 0 && p < n) {
        final cell = parts[p].trim();
        if (!looksLikeIpa(cell)) {
          final alt = _firstIpaIndex(parts, 1, n - 2);
          if (alt >= 0) {
            // IPA đang ở ô khác → hàng đã lệch → căn neo.
            return _anchorAlign(parts, fields);
          }
          if (n == fields.length) {
            // IPA trống + ô chứa khoảng trắng không phải IPA (IPA không
            // bao giờ có khoảng trắng) → là phần meaning bị tách → gộp.
            if (cell.contains(' ')) {
              return _mergeIntoMeaningNoIpa(parts, fields);
            }
          } else if (fields.last == 'language' &&
              _looksLikeLangCode(parts.last) &&
              // Ô kề cuối phải "giống ví dụ" (có khoảng trắng hoặc
              // ≥5 ký tự) → xác nhận hàng đủ các cột text, chỉ thiếu
              // giá trị IPA → các ô sau ô ipa TRƯỢT TRÁI.
              (parts[n - 2].contains(' ') || parts[n - 2].length >= 5)) {
            final noIpa = <String?>[...fields]..removeAt(p);
            return _zip(parts, noIpa);
          }
        }
      }
      final data = _zip(parts, fields);
      // Hàng thiếu CỘT CUỐI: ô cuối giống mã ngôn ngữ nhưng zip đẩy nó
      // vào cột text (vd language bị đẩy sang exampleSimple) → chuyển
      // ô cuối về cột language.
      if (fields.last == 'language' &&
          _looksLikeLangCode(parts.last) &&
          !_looksLikeLangCode(data['language'] ?? '')) {
        final stolen = fields[n - 1];
        if (stolen != null) data[stolen] = '';
        data['language'] = parts.last.trim();
      }
      return data;
    }

    // Nhiều ô hơn cột — chỉ căn neo với định dạng chuẩn.
    final present = <String>{};
    for (final f in fields) {
      if (f != null) present.add(f);
    }
    final hasAnchors = present.containsAll(
      const {'word', 'meaning', 'phonetic', 'topic', 'example'},
    );
    final wordFirst = fields.first == 'word';
    final langLast =
        !present.contains('language') || fields.last == 'language';

    if (!hasAnchors || !wordFirst || !langLast) {
      // Header lạ — best-effort vị trí (lấy đủ số ô bằng số cột).
      return _zip(parts, fields);
    }
    return _anchorAlign(parts, fields);
  }

  /// Khớp 1-1 theo vị trí (đệm '' nếu thiếu ô).
  static Map<String, String> _zip(List<String> parts, List<String?> fields) {
    final data = <String, String>{};
    for (int i = 0; i < fields.length; i++) {
      final key = fields[i];
      if (key == null) continue;
      data[key] = i < parts.length ? parts[i].trim() : '';
    }
    return data;
  }

  /// Giá trị "giống mã ngôn ngữ": en / vi / zh / pali... (2-4 chữ cái).
  static bool _looksLikeLangCode(String s) =>
      RegExp(r'^[a-z]{2,4}$').hasMatch(s.trim().toLowerCase());

  /// Index ô đầu tiên (trong [from]..[toInclusive]) có dạng IPA.
  static int _firstIpaIndex(List<String> parts, int from, int toInclusive) {
    final hi = toInclusive.clamp(0, parts.length - 1);
    for (int i = from; i <= hi; i++) {
      if (looksLikeIpa(parts[i])) return i;
    }
    return -1;
  }

  /// Căn bằng mỏ neo: word = ô đầu · language = ô cuối · ipa = ô /.../.
  /// Ô TRƯỚC ipa → meaning (gộp); ô SAU ipa → các cột còn lại
  /// (cột tự do đứng đầu hấp thụ ô dư).
  static Map<String, String> _anchorAlign(
    List<String> parts,
    List<String?> fields,
  ) {
    final data = <String, String>{};
    final n = parts.length;
    final hasLang = fields.last == 'language';
    final lastIdx = hasLang ? n - 2 : n - 1; // biên phải của vùng giữa

    data['word'] = parts[0].trim();
    if (hasLang) data['language'] = parts[n - 1].trim();

    final ipaIdx = _firstIpaIndex(parts, 1, lastIdx);

    if (ipaIdx >= 0) {
      data['phonetic'] = parts[ipaIdx].trim();
      // Ô TRƯỚC ipa → meaning (gộp ", ").
      final pre = [for (int i = 1; i < ipaIdx; i++) parts[i]];
      data['meaning'] = pre
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      // Ô SAU ipa → topic / example / exampleSimple / exampleComplex.
      final post = [for (int i = ipaIdx + 1; i <= lastIdx; i++) parts[i]];
      final postFields = <String>[];
      for (final f in fields) {
        if (f == null) continue;
        if (const {'word', 'language', 'phonetic', 'meaning'}.contains(f)) {
          continue;
        }
        postFields.add(f);
      }
      _distribute(post, postFields, data);
    } else {
      // Hàng không có ô IPA → 1 nhóm giữa word và language.
      data['phonetic'] = '';
      final group = [for (int i = 1; i <= lastIdx; i++) parts[i]];
      final groupFields = <String>[];
      for (final f in fields) {
        if (f == null) continue;
        if (const {'word', 'language', 'phonetic'}.contains(f)) continue;
        groupFields.add(f);
      }
      _distribute(group, groupFields, data);
    }

    return data;
  }

  /// Ô = cột, cột ipa chứa giá trị KHÔNG phải IPA (có khoảng trắng) →
  /// coi IPA bị bỏ trống, ô đó là phần meaning bị tách → gộp vào
  /// meaning; các ô sau khớp 1-1 với cột tương ứng.
  static Map<String, String> _mergeIntoMeaningNoIpa(
    List<String> parts,
    List<String?> fields,
  ) {
    final data = <String, String>{};
    final n = parts.length;
    final p = fields.indexOf('phonetic');
    final hasLang = fields.last == 'language';

    data['word'] = parts[0].trim();
    if (hasLang) data['language'] = parts[n - 1].trim();
    // Ô 1..p (kể cả ô "ipa rác") → meaning.
    data['meaning'] = parts
        .sublist(1, p + 1)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(', ');
    data['phonetic'] = '';
    for (int i = p + 1; i < n; i++) {
      final key = fields[i];
      if (key == null || key == 'language') continue;
      data[key] = parts[i].trim();
    }
    return data;
  }

  /// Chia [cells] vào [fields] (theo thứ tự header).
  ///  - cell == field → 1-1.
  ///  - cell > field → cột tự do (wide) ĐẦU TIÊN hấp thụ ô dư (gộp ", ");
  ///    các cột hẹp đứng trước nó (vd topic) vẫn lấy đúng 1 ô.
  ///  - cell < field → 1-1 rồi đệm ''.
  static void _distribute(
    List<String> cells,
    List<String> fields,
    Map<String, String> out,
  ) {
    if (fields.isEmpty) return;
    if (cells.isEmpty) {
      for (final f in fields) {
        out[f] = '';
      }
      return;
    }
    if (cells.length == fields.length) {
      for (int i = 0; i < fields.length; i++) {
        out[fields[i]] = cells[i].trim();
      }
      return;
    }
    if (cells.length > fields.length) {
      // Cột HẤP THỤ ô dư: mặc định = cột tự do đầu tiên, nhưng chọn
      // cột khiến ÍT cột tự do nào đó bị "cụt" thành ô 1 từ nhất
      // (vd ví dụ đơn 'A simple, one' thay vì ví dụ chính nuốt luôn
      // 'A simple' và để ví dụ đơn chỉ còn 'one').
      final wideIdxs = [
        for (int i = 0; i < fields.length; i++)
          if (_wideFields.contains(fields[i])) i,
      ];
      int absorb = wideIdxs.isNotEmpty ? wideIdxs.first : 0;
      final take = cells.length - (fields.length - 1);
      if (wideIdxs.length > 1) {
        int bestScore = -1;
        for (final c in wideIdxs) {
          // Chấm điểm: số cột TỰ DO (không phải cột hấp thụ) nhận ô
          // KHÔNG có khoảng trắng (nghi là mảnh bị xé).
          var cursor = 0;
          var score = 0;
          for (int i = 0; i < fields.length; i++) {
            final cell = (i == c)
                ? cells.sublist(cursor, cursor + take)
                : [cells[cursor]];
            final isWide = _wideFields.contains(fields[i]);
            if (isWide && i != c && !cell.first.contains(' ')) score++;
            cursor += cell.length;
          }
          if (bestScore < 0 || score < bestScore) {
            bestScore = score;
            absorb = c;
          }
          if (score == 0) break; // tốt nhất có thể — dừng sớm
        }
      }
      for (int i = 0; i < absorb; i++) {
        out[fields[i]] = cells[i].trim();
      }
      out[fields[absorb]] = cells
          .sublist(absorb, absorb + take)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      for (int i = absorb + 1; i < fields.length; i++) {
        out[fields[i]] = cells[absorb + take + (i - absorb - 1)].trim();
      }
      return;
    }
    // Ít ô hơn cột: 1-1 rồi đệm ''.
    for (int i = 0; i < fields.length; i++) {
      out[fields[i]] = i < cells.length ? cells[i].trim() : '';
    }
  }
}
