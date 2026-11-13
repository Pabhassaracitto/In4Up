import 'package:in4up/core/language/localized_material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../models/dict_entry.dart';
import '../services/dictionary_service.dart';

/// Separate source entries, without the lossy sense limits of the quick view.
/// This is intentionally a text-only HTML subset, not an MDict renderer: no
/// scripts, links, stylesheets, network, file access or media are executed.
class DictSourceEntries extends StatelessWidget {
  final List<DictEntry> entries;
  final bool initiallyExpanded;

  const DictSourceEntries({
    super.key,
    required this.entries,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final names = <String, String>{
      for (final info in DictionaryService.instance.dictionaries)
        info.id: info.name,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          context.uiText('Nội dung theo từng từ điển'),
          style: const TextStyle(
            color: Color(0xFF90CAF9),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.uiText('Bản văn bản từ dữ liệu đã nhập; chưa hỗ trợ CSS, ảnh, âm thanh và liên kết.'),
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        for (final entry in entries)
          ExpansionTile(
            key: ObjectKey(entry),
            initiallyExpanded: initiallyExpanded,
            tilePadding: EdgeInsets.zero,
            collapsedIconColor: Colors.white70,
            iconColor: const Color(0xFF90CAF9),
            title: Text(
              names[entry.dictId] ?? entry.dictId,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText.rich(
                  dictionaryTextSpans(entry.definition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
      ],
    );
  }
}

/// Render a safe, non-executable HTML subset as selectable text. No HTML
/// attributes are interpreted; resource requests and JavaScript are impossible.
/// Whitespace inside preformatted blocks is retained; normal HTML whitespace
/// is collapsed. No sense/example truncation or cross-dictionary deduplication.
TextSpan dictionaryTextSpans(String definition) {
  if (!RegExp(r'<[a-zA-Z!/][^>]*>').hasMatch(definition)) {
    return TextSpan(text: definition);
  }
  final fragment = html.parseFragment(definition);
  final spans = <InlineSpan>[];
  const blocked = <String>{
    'script', 'style', 'head', 'iframe', 'object', 'embed', 'svg',
    'audio', 'video', 'template', 'form', 'noscript',
  };
  const blocks = <String>{
    'p', 'div', 'section', 'article', 'li', 'tr', 'blockquote', 'pre',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'table', 'dt', 'dd',
  };
  var lastEndsWithNewline = true;
  void lineBreak() {
    if (!lastEndsWithNewline) {
      spans.add(const TextSpan(text: '\n'));
      lastEndsWithNewline = true;
    }
  }

  void visit(dom.Node node, TextStyle style, bool pre, int depth) {
    if (depth > 100) return;
    if (node is dom.Text) {
      final text = pre ? node.data : node.data.replaceAll(RegExp(r'\s+'), ' ');
      if (text.isNotEmpty && !(lastEndsWithNewline && text.trim().isEmpty)) {
        spans.add(TextSpan(text: text, style: style));
        lastEndsWithNewline = text.endsWith('\n');
      }
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName?.toLowerCase() ?? '';
    if (blocked.contains(tag)) return;
    if (tag == 'br' || tag == 'hr') {
      lineBreak();
      return;
    }
    if (blocks.contains(tag)) lineBreak();
    if (tag == 'li') {
      spans.add(TextSpan(text: '• ', style: style));
      lastEndsWithNewline = false;
    }
    final nextStyle = style.merge(TextStyle(
      fontWeight: <String>{'b', 'strong', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(tag)
          ? FontWeight.bold : null,
      fontStyle: <String>{'i', 'em'}.contains(tag) ? FontStyle.italic : null,
    ));
    for (final child in node.nodes) {
      visit(child, nextStyle, pre || tag == 'pre', depth + 1);
    }
    if (blocks.contains(tag)) lineBreak();
  }

  for (final node in fragment.nodes) {
    visit(node, const TextStyle(), false, 0);
  }
  return TextSpan(children: spans);
}
