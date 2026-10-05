import 'package:in4up/core/language/localized_material.dart';

import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/screens/download_screen.dart';
import 'package:in4up/features/tipitaka/screens/workspace_screen.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_markup.dart';

/// Full-text search across Pāli and every imported translation.
///
/// Results were previously a dead end: they rendered a preview but could not
/// open anything. Every hit now jumps into the reading workspace at exactly
/// the matched paragraph, mirroring OpenTipitaka's paragraph anchors.
class TipitakaSearchScreen extends StatefulWidget {
  const TipitakaSearchScreen({super.key});

  @override
  State<TipitakaSearchScreen> createState() => _TipitakaSearchScreenState();
}

class _TipitakaSearchScreenState extends State<TipitakaSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<TipitakaSegment> results = [];
  bool searching = false;
  String? error;
  String _query = '';
  int? _openingId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        results = [];
        error = null;
        _query = '';
      });
      return;
    }
    setState(() {
      searching = true;
      error = null;
      _query = trimmed;
    });
    try {
      final db = await TipitakaDb.openReady();
      final found = await TipitakaDb.searchSegments(db, trimmed);
      if (mounted) setState(() => results = found);
    } catch (e) {
      if (mounted) {
        setState(() {
          results = [];
          error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  String _tabTitle(TipitakaSegment segment, String language) {
    final candidates = <String>[
      segment.translationFor(language),
      segment.translationVi ?? '',
      segment.translationEn ?? '',
      segment.firstTranslation?.value ?? '',
      segment.paliText,
    ];
    for (final candidate in candidates) {
      final clean = cleanTipitakaText(candidate);
      if (clean.isNotEmpty) {
        return clean.length > 70 ? '${clean.substring(0, 70)}…' : clean;
      }
    }
    return 'Tipiṭaka';
  }

  Future<void> _openResult(TipitakaSegment segment) async {
    if (_openingId != null) return;
    setState(() => _openingId = segment.id);
    try {
      final db = await TipitakaDb.openReady();
      final book = await TipitakaDb.getBookById(db, segment.bookId);
      if (!mounted) return;
      if (book == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.uiText('Không tìm thấy sách chứa đoạn này.'),
            ),
          ),
        );
        return;
      }
      final language = Localizations.localeOf(context).languageCode;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TipitakaWorkspaceScreen(
            initialTab: TipitakaWorkspaceTab(
              book: book,
              title: _tabTitle(segment, language),
              initialSegmentId: segment.id,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText('Không thể mở đoạn: $e')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _openingId = null);
      }
    }
  }

  /// Snippet centred on the first match, preferring the translation columns
  /// that actually contain the query.
  String _snippetFor(TipitakaSegment segment) {
    final candidates = <String>[
      segment.translationVi ?? '',
      segment.translationEn ?? '',
      segment.firstTranslation?.value ?? '',
      segment.paliText,
    ].map(cleanTipitakaText).where((text) => text.isNotEmpty).toList();
    if (candidates.isEmpty) return '';
    final needle = _query.toLowerCase();
    for (final candidate in candidates) {
      if (needle.isNotEmpty &&
          candidate.toLowerCase().contains(needle)) {
        return _excerptAround(candidate, _query);
      }
    }
    final first = candidates.first;
    return first.length > 160 ? '${first.substring(0, 160)}…' : first;
  }

  String _excerptAround(String text, String query, {int radius = 80}) {
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) {
      return text.length > 160 ? '${text.substring(0, 160)}…' : text;
    }
    final start = (index - radius).clamp(0, text.length).toInt();
    final end =
        (index + query.length + radius).clamp(0, text.length).toInt();
    final prefix = start > 0 ? '…' : '';
    final suffix = end < text.length ? '…' : '';
    return '$prefix${text.substring(start, end)}$suffix';
  }

  List<InlineSpan> _highlightSpans(String text) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final highlight = base?.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    );
    final needle = _query.toLowerCase();
    if (needle.isEmpty) {
      return [TextSpan(text: text, style: base)];
    }
    final spans = <InlineSpan>[];
    var remaining = text;
    while (remaining.isNotEmpty) {
      final index = remaining.toLowerCase().indexOf(needle);
      if (index < 0) {
        spans.add(TextSpan(text: remaining, style: base));
        break;
      }
      if (index > 0) {
        spans.add(TextSpan(text: remaining.substring(0, index), style: base));
      }
      spans.add(
        TextSpan(
          text: remaining.substring(index, index + _query.length),
          style: highlight,
        ),
      );
      remaining = remaining.substring(index + _query.length);
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.uiText('Tìm kiếm Tipiṭaka'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: results.isEmpty && error == null,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.uiText('Từ khóa Pāli / bản dịch…'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: context.uiText('Xóa từ khóa'),
                        onPressed: () {
                          _controller.clear();
                          _search('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _search,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    context.uiText('Không thể mở cơ sở dữ liệu Tipiṭaka.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TipitakaDownloadScreen(),
                      ),
                    ),
                    child: Text(context.uiText('Import hoặc tải dữ liệu')),
                  ),
                ],
              ),
            ),
          Expanded(
            child: searching
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty && error == null
                    ? Center(
                        child: Text(
                          context.uiText('Nhập từ khóa để tìm trong Tipiṭaka'),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 6),
                            child: Row(
                              children: [
                                Text(
                                  context.uiText('Kết quả'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge,
                                ),
                                const SizedBox(width: 8),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  label: Text('${results.length}'),
                                ),
                                const Spacer(),
                                Text(
                                  context.uiText(
                                    'Chạm để mở tại đúng đoạn',
                                  ),
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, indent: 16),
                              itemBuilder: (context, index) {
                                final segment = results[index];
                                final snippet = _snippetFor(segment);
                                final opening = _openingId == segment.id;
                                return ListTile(
                                  onTap: opening
                                      ? null
                                      : () => _openResult(segment),
                                  leading:
                                      const Icon(Icons.article_outlined),
                                  title: RichText(
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      children: _highlightSpans(snippet),
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      if (segment.reference
                                          .trim()
                                          .isNotEmpty)
                                        segment.reference.trim(),
                                      '${context.uiText('Đoạn')} ${segment.orderIndex + 1}',
                                    ].join(' · '),
                                  ),
                                  trailing: opening
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.keyboard_arrow_right,
                                        ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
