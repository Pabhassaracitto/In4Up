// lib/features/canon/widgets/canon_search_sheet.dart
//
// Demo UI cho Canon FTS — search sheet + reader.
// Dùng để test PoC: mở sheet, gõ "niem xu", "chanh niem", "kho", "dhammapada", "trung dao"
// Thấy kết quả highlight + snippet + thời gian search.

import 'package:flutter/material.dart';

import '../../../data/repositories/interfaces/canon_repository.dart';
import '../models/canon_search_result.dart';

class CanonSearchSheet extends StatefulWidget {
  final CanonRepository repository;
  final void Function(String canonId)? onOpenCanon;

  const CanonSearchSheet({
    super.key,
    required this.repository,
    this.onOpenCanon,
  });

  static Future<void> show(BuildContext context, CanonRepository repo) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => CanonSearchSheet(
          repository: repo,
          onOpenCanon: (id) {
            Navigator.pop(ctx);
            Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => CanonReaderScreen(repository: repo, canonId: id)),
            );
          },
        ),
      ),
    );
  }

  @override
  State<CanonSearchSheet> createState() => _CanonSearchSheetState();
}

class _CanonSearchSheetState extends State<CanonSearchSheet> {
  final _ctrl = TextEditingController();
  CanonSearchResult? _result;
  bool _isSearching = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // initial search empty -> show all
    _doSearch('');
  }

  Future<void> _doSearch(String q) async {
    setState(() => _isSearching = true);
    final r = await widget.repository.search(q, limit: 20);
    if (!mounted) return;
    setState(() {
      _result = r;
      _isSearching = false;
      _suggestions = q.trim().isNotEmpty ? widget.repository.suggest(q, limit: 5) : [];
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = _result?.hits ?? [];
    return Column(
      children: [
        // handle
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kho Kinh Chuẩn — Tìm kiếm FTS',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${widget.repository.count} bài • offline 100% • FTS Hive (sẵn sàng Drift FTS5)',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Thử: niệm xứ, chánh niệm, khổ, trung đạo, dhammapada...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _ctrl.clear();
                            _doSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => _doSearch(v),
                onSubmitted: (v) => _doSearch(v),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _suggestions
                      .map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            backgroundColor: const Color(0xFF252540),
                            onPressed: () {
                              _ctrl.text = s;
                              _doSearch(s);
                            },
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              if (_result != null)
                Text(
                  _isSearching
                      ? 'Đang tìm...'
                      : _result!.isEmpty
                          ? 'Không tìm thấy cho "${_result!.query}"'
                          : 'Tìm thấy ${_result!.total} kết quả • ${ _result!.elapsed.inMilliseconds}ms • query: "${_result!.query}"',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: _isSearching && _result == null
              ? const Center(child: CircularProgressIndicator())
              : hits.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: hits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final hit = hits[i];
                        return _CanonHitCard(
                          hit: hit,
                          query: _result?.query ?? '',
                          onTap: () => widget.onOpenCanon?.call(hit.entry.id),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 40, color: Colors.white24),
            const SizedBox(height: 12),
            const Text('Gõ từ khóa để tìm trong kho Kinh',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final q in ['niệm xứ', 'chánh niệm', 'khổ', 'trung đạo', 'ý dẫn đầu', 'satipatthana'])
                  ActionChip(
                    label: Text(q, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    backgroundColor: const Color(0xFF252540),
                    onPressed: () {
                      _ctrl.text = q;
                      _doSearch(q);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CanonHitCard extends StatelessWidget {
  final CanonSearchHit hit;
  final String query;
  final VoidCallback onTap;

  const _CanonHitCard({required this.hit, required this.query, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = hit.entry;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: Text(e.paliRef.isNotEmpty ? e.paliRef : e.category,
                      style: const TextStyle(color: Color(0xFF9B8EFF), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(e.collection,
                      style: const TextStyle(color: Colors.white38, fontSize: 10), overflow: TextOverflow.ellipsis),
                ),
                Text('score ${hit.score.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white24, fontSize: 9)),
              ],
            ),
            const SizedBox(height: 6),
            Text(e.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            if (e.titlePali.isNotEmpty)
              Text(e.titlePali, style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            Text(hit.snippet,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: e.tags.take(4).map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text('#$t', style: const TextStyle(color: Colors.white54, fontSize: 9)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reader ───────────────────────────────────────────────

class CanonReaderScreen extends StatefulWidget {
  final CanonRepository repository;
  final String canonId;

  const CanonReaderScreen({super.key, required this.repository, required this.canonId});

  @override
  State<CanonReaderScreen> createState() => _CanonReaderScreenState();
}

class _CanonReaderScreenState extends State<CanonReaderScreen> {
  final _noteCtrl = TextEditingController();
  bool _showNoteEditor = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.repository.getById(widget.canonId);
    _noteCtrl.text = entry?.personalNote ?? '';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.repository.getById(widget.canonId);
    if (entry == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080B1A),
        appBar: AppBar(title: const Text('Không tìm thấy')),
        body: const Center(child: Text('Bài kinh không tồn tại', style: TextStyle(color: Colors.white54))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1E),
        title: Text(entry.title, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            icon: Icon(_showNoteEditor ? Icons.close : Icons.edit_note, color: Colors.white70),
            onPressed: () => setState(() => _showNoteEditor = !_showNoteEditor),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header meta
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.titlePali.isNotEmpty)
                    Text(entry.titlePali, style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      _metaChip(entry.paliRef),
                      _metaChip(entry.collection),
                      _metaChip(entry.translator),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: entry.tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text('#$t', style: const TextStyle(color: Color(0xFF9B8EFF), fontSize: 10)),
                    )).toList(),
                  ),
                ],
              ),
            ),

            // note editor
            if (_showNoteEditor) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit, size: 14, color: Color(0xFF66BB6A)),
                        SizedBox(width: 6),
                        Text('Ghi chú cá nhân (lưu local, sẽ sync riêng)',
                            style: TextStyle(color: Color(0xFF66BB6A), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ghi lại cảm nhận, bản dịch cá nhân, câu hỏi...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F1A0F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                        onPressed: () async {
                          await widget.repository.savePersonalNote(entry.id, _noteCtrl.text.trim());
                          if (!mounted) return;
                          setState(() => _showNoteEditor = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã lưu ghi chú cục bộ'), backgroundColor: Color(0xFF2E7D32)),
                          );
                        },
                        child: const Text('Lưu ghi chú', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if ((entry.personalNote ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A1A).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 14, color: Color(0xFF66BB6A)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.personalNote!, style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            // markdown content — đơn giản, không cần package markdown
            // hiển thị plain với selectableText + giữ heading
            SelectableText(
              entry.markdownContent,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.6),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text('Nguồn: ${entry.sourcePath} • ${entry.wordCount} từ • offline 100%',
                  style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    );
  }
}
