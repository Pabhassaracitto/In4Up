import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  late TabController _tabCtrl;

  final _pasteCtrl = TextEditingController();
  List<_ImportCandidate> _parsedWords = [];
  int _minLength = 3;
  bool _excludeStopWords = true;
  bool _onlyNewWords = true;

  String? _filePath;
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
    if (text.isEmpty) return;
    setState(() {
      _parsedWords = _parseText(text);
    });
  }

  List<_ImportCandidate> _parseFromProvider(TextProvider tp) {
    final text = tp.fullText;
    if (text.isEmpty) return [];
    return _parseText(text);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
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
        _fileWords = words;
        _isLoadingFile = false;
      });
    } catch (e) {
      setState(() => _isLoadingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đọc file: $e')),
        );
      }
    }
  }

  List<_ImportCandidate> _parseFileContent(String content) {
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

      if (word.isEmpty || word.length < 2) continue;
      if (_onlyNewWords && _provider.hasWord(word)) continue;

      candidates.add(_ImportCandidate(
        word: word,
        meaning: meaning,
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
        provider.addWithAutoClassify(
          text: c.word,
          meaning: c.meaning ?? '',
        );
        count++;
      }
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Đã import $count từ'),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
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
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.5)),
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
                      text: 'Văn bản'),
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
      child: Row(
        children: [
          _OptionChip(
            label: 'Tối thiểu $_minLength ký tự',
            icon: Icons.text_fields,
            onTap: () {
              setState(() =>
                  _minLength = _minLength == 3 ? 4 : (_minLength == 4 ? 5 : 3));
              _parsePasted();
            },
          ),
          const SizedBox(width: 8),
          _OptionChip(
            label: 'Bỏ stop words',
            icon: Icons.filter_list,
            isActive: _excludeStopWords,
            onTap: () {
              setState(() => _excludeStopWords = !_excludeStopWords);
              _parsePasted();
            },
          ),
          const SizedBox(width: 8),
          _OptionChip(
            label: 'Chỉ từ mới',
            icon: Icons.new_releases_outlined,
            isActive: _onlyNewWords,
            onTap: () {
              setState(() => _onlyNewWords = !_onlyNewWords);
              _parsePasted();
            },
          ),
        ],
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
                      'Dán văn bản hoặc danh sách từ vào đây...\nHỗ trợ: text thường, một từ mỗi dòng, CSV (word,meaning)',
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
          }),
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

        final words = _parseFromProvider(tp);

        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: Color(0xFF2196F3), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${tp.currentDocument?.title ?? 'Văn bản hiện tại'}" — ${tp.lines.length} dòng',
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
              _buildWordList(words, (_) => setState(() {})),
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
                '.txt: Mỗi dòng 1 từ (hoặc văn bản thường)\n'
                '.csv: word,meaning (mỗi dòng 1 cặp)',
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
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.35)),
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
          }),
          const SizedBox(height: 12),
          _buildImportButton(_fileWords),
        ],
      ],
    );
  }

  Widget _buildWordList(
      List<_ImportCandidate> words, void Function(int) onToggle) {
    final selectedCount = words.where((w) => w.selected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${words.length} từ tìm thấy · $selectedCount được chọn',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const Spacer(),
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
          children: words.take(80).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final w = entry.value;
            return GestureDetector(
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
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (words.length > 80)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '... và ${words.length - 80} từ nữa (tất cả sẽ được import)',
              style: TextStyle(color: Colors.grey[700], fontSize: 11),
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
          'Import $count từ vào danh sách',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          disabledBackgroundColor:
              const Color(0xFF6C63FF).withValues(alpha: 0.3),
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
  final int frequency;
  bool selected;

  _ImportCandidate({
    required this.word,
    this.meaning,
    this.frequency = 1,
    this.selected = true,
  });
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
              ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF6C63FF).withValues(alpha: 0.4)
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
