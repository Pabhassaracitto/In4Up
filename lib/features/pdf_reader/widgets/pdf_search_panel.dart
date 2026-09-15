// Thanh + danh sách kết quả tìm kiếm trong file PDF.
//
// Phần tìm KHÔNG tự viết: dùng `PdfTextSearcher` của pdfrx (quét dần theo từng
// trang, có cache `loadStructuredText`, có paint callback tô sáng kết quả, và
// tự restart khi trang vừa tải xong). Panel này chỉ là mặt nạ: nghe
// `PdfTextSearcher` như một Listenable, dựng danh sách, và nhảy tới kết quả.
import 'package:in4up/core/language/localized_material.dart';
import 'package:pdfrx/pdfrx.dart' hide PdfAnnotation;

import '../services/pdf_search_query.dart';

class PdfSearchPanel extends StatefulWidget {
  const PdfSearchPanel({
    super.key,
    required this.searcher,
    required this.onSearch,
    required this.onClose,
    required this.initialQuery,
    required this.initialIgnoreTones,
  });

  /// `null` khi document chưa sẵn sàng — panel vẫn nhập được, tìm sẽ bắt đầu
  /// sau khi searcher tồn tại.
  final PdfTextSearcher? searcher;

  /// Screen chịu trách nhiệm dựng RegExp (chính sách bỏ dấu nằm ở service) rồi
  /// gọi `startTextSearch`, vì pattern là thứ duy nhất panel không tự quyết được.
  final void Function(String query, bool ignoreTones) onSearch;
  final VoidCallback onClose;
  final String initialQuery;
  final bool initialIgnoreTones;

  @override
  State<PdfSearchPanel> createState() => _PdfSearchPanelState();
}

class _PdfSearchPanelState extends State<PdfSearchPanel> {
  late final TextEditingController _field =
      TextEditingController(text: widget.initialQuery);
  late bool _ignoreTones = widget.initialIgnoreTones;
  VoidCallback? _removeSearcherListener;
  PdfTextSearcher? _listened;

  @override
  void initState() {
    super.initState();
    _listenToSearcher();
  }

  @override
  void didUpdateWidget(covariant PdfSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searcher != widget.searcher) _listenToSearcher();
  }

  void _listenToSearcher() {
    if (identical(_listened, widget.searcher)) return;
    _removeSearcherListener?.call();
    _removeSearcherListener = null;
    _listened = widget.searcher;
    // Searcher bắn thông báo mỗi khi tìm xong một trang → kết quả lớn dần
    // thay vì chờ cả cuốn. Không listener nào khác trong app cần biết.
    _removeSearcherListener = widget.searcher?.addListener(_onSearcherUpdate);
  }

  void _onSearcherUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _removeSearcherListener?.call();
    _field.dispose();
    super.dispose();
  }

  void _submit(String value) {
    widget.onSearch(value, _ignoreTones);
  }

  /// `goToMatch*` tính layout của trang đích; nếu trang chưa được viewer dựng
  /// (mới search xong, đang ở trang khác) thì pdfrx có thể ném. Bắt lấy: mất
  /// một cú nhảy còn hơn văng khỏi màn đọc.
  Future<void> _jump(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final searcher = widget.searcher;
    final matches = searcher?.matches ?? const <PdfPageTextRange>[];
    final current = searcher?.currentIndex;
    final searching = searcher?.isSearching ?? false;
    final progress = searcher?.searchProgress;
    final hasQuery = isPdfSearchQueryMeaningful(_field.text);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _field,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: context.uiText('Tìm trong tài liệu'),
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.white54,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: _submit,
                  onSubmitted: _submit,
                ),
              ),
              if (searcher != null && matches.isNotEmpty) ...[
                IconButton(
                tooltip: context.uiText('Kết quả trước'),
                onPressed: () => _jump(() async {
                  await searcher.goToPrevMatch();
                }),
                icon: const Icon(
                  Icons.keyboard_arrow_up,
                  size: 20,
                  color: Colors.white70,
                ),
              ),
              IconButton(
                tooltip: context.uiText('Kết quả tiếp theo'),
                onPressed: () => _jump(() async {
                  await searcher.goToNextMatch();
                }),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.white70,
                ),
              ),
              ],
              IconButton(
                tooltip: context.uiText('Đóng'),
                onPressed: () {
                  searcher?.resetTextSearch();
                  widget.onClose();
                },
                icon: const Icon(Icons.close, size: 20, color: Colors.white70),
              ),
            ],
          ),
          Row(
            children: [
              FilterChip(
                selected: _ignoreTones,
                label: Text(
                  context.uiText('Không phân biệt dấu'),
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (value) {
                  setState(() => _ignoreTones = value);
                  _submit(_field.text);
                },
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildStatus(hasQuery, searching, progress, matches, current)),
            ],
          ),
          if (matches.isNotEmpty)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.32,
              child: ListView.builder(
                itemExtent: 52,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  final isCurrent = index == current;
                  return InkWell(
                    onTap: () => _jump(() async {
                      final target = searcher;
                      if (target != null) {
                        await target.goToMatchOfIndex(index);
                      }
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              '${match.pageNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: isCurrent
                                    ? const Color(0xFF64B5F6)
                                    : Colors.white38,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              pdfSearchSnippet(
                                match.pageText.fullText,
                                match.start,
                                match.end,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color: isCurrent
                                    ? Colors.white
                                    : Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildStatus(
    bool hasQuery,
    bool searching,
    double? progress,
    List<PdfPageTextRange> matches,
    int? current,
  ) {
    String label;
    if (!hasQuery) {
      label = context.uiText('Nhập ít nhất 2 ký tự');
    } else if (searching) {
      final pct = progress == null ? null : (progress * 100).round();
      label = pct == null
          ? context.uiText('Đang tìm...')
          : '${context.uiText('Đang tìm...')} $pct%';
    } else if (matches.isEmpty) {
      label = context.uiText('Không có kết quả');
    } else {
      label = current == null
          ? '${matches.length} / ${matches.length}'
          : '${current + 1} / ${matches.length}';
    }
    return Text(
      label,
      style: const TextStyle(color: Colors.white38, fontSize: 11),
    );
  }
}
