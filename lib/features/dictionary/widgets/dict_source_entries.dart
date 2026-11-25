import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/material.dart' as material;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../models/dict_entry.dart';
import '../services/dictionary_service.dart';
import '../services/dict_entry_links.dart';
import 'dict_source_images.dart';

/// Separate source entries, without the lossy sense limits of the quick view.
/// Safe text subset plus optional bounded MDD images, not a full renderer:
/// no scripts, stylesheets, network, arbitrary file access or audio are executed.
class DictSourceEntries extends StatelessWidget {
  final List<DictEntry> entries;
  final bool initiallyExpanded;
  final void Function(String word, String dictId)? onLookupWord;

  const DictSourceEntries({
    super.key,
    required this.entries,
    this.initiallyExpanded = false,
    this.onLookupWord,
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
          context.uiText('Ảnh MDD thử nghiệm; chỉ hỗ trợ một số kiểu chữ, chưa hỗ trợ tệp CSS và âm thanh.'),
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
              DictSourceImages(dictId: entry.dictId, definition: entry.definition),
              if (onLookupWord != null &&
                  DictEntryLinks.extract(entry.definition).isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      for (final target in DictEntryLinks.extract(entry.definition))
                        ActionChip(
                          label: material.Text(target),
                          onPressed: () => onLookupWord!(target, entry.dictId),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
      ],
    );
  }
}

/// Render a safe, non-executable HTML subset as selectable text. No HTML
/// attributes are interpreted except a strict, inert inline typography subset;
/// resource requests and JavaScript are impossible.
/// Whitespace inside preformatted blocks is retained; normal HTML whitespace
/// is collapsed. No sense/example truncation or cross-dictionary deduplication.
TextSpan dictionaryTextSpans(String definition) {
  // MDX record terminators are not visible content; older SQLite imports may
  // still contain them even after newer parsers are deployed.
  definition = definition.replaceFirst(RegExp(r'\x00+$'), '');
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
  final listCounters = <int?>[];
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
    // Preserve cell boundaries without interpreting untrusted CSS or HTML attributes.
    if (tag == 'td' || tag == 'th') {
      final previous = node.previousElementSibling;
      if (previous != null && (previous.localName == 'td' || previous.localName == 'th')) {
        spans.add(TextSpan(text: '  |  ', style: style));
        lastEndsWithNewline = false;
      }
    }
    if (tag == 'ol' || tag == 'ul') {
      listCounters.add(tag == 'ol' ? 0 : null);
    }
    if (tag == 'li') {
      var marker = '• ';
      if (listCounters.isNotEmpty && listCounters.last != null) {
        final next = listCounters.last! + 1;
        listCounters[listCounters.length - 1] = next;
        marker = '$next. ';
      }
      spans.add(TextSpan(text: marker, style: style));
      lastEndsWithNewline = false;
    }
    final tagStyle = TextStyle(
      fontWeight: <String>{'b', 'strong', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'th'}.contains(tag)
          ? FontWeight.bold : null,
      fontStyle: <String>{'i', 'em'}.contains(tag) ? FontStyle.italic : null,
      decoration: tag == 'u' ? TextDecoration.underline : null,
    );
    final inline = safeDictionaryInlineStyle(node.attributes['style']);
    final nextStyle = style.merge(tagStyle).merge(inline);
    for (final child in node.nodes) {
      visit(child, nextStyle, pre || tag == 'pre', depth + 1);
    }
    if (blocks.contains(tag)) lineBreak();
    if (tag == 'ol' || tag == 'ul') listCounters.removeLast();
  }

  for (final node in fragment.nodes) {
    visit(node, const TextStyle(), false, 0);
  }
  return TextSpan(children: spans);
}

/// Only inert typography declarations. Never interpret URLs, escapes, selectors,
/// colors, fonts, sizing, layout, visibility, or external stylesheets.
TextStyle safeDictionaryInlineStyle(String? css) {
  if (css == null || css.length > 1024) return const TextStyle();
  FontWeight? weight;
  FontStyle? fontStyle;
  TextDecoration? decoration;
  for (final declaration in css.split(';').take(32)) {
    final split = declaration.indexOf(':');
    if (split < 1) continue;
    final key = declaration.substring(0, split).trim().toLowerCase();
    final value = declaration.substring(split + 1).trim().toLowerCase();
    switch (key) {
      case 'font-weight':
        if (value == 'bold' || value == '700') weight = FontWeight.bold;
        if (value == 'normal' || value == '400') weight = FontWeight.normal;
        break;
      case 'font-style':
        if (value == 'italic') fontStyle = FontStyle.italic;
        if (value == 'normal') fontStyle = FontStyle.normal;
        break;
      case 'text-decoration':
        if (value == 'underline') decoration = TextDecoration.underline;
        if (value == 'line-through') decoration = TextDecoration.lineThrough;
        if (value == 'none') decoration = TextDecoration.none;
        break;
    }
  }
  return TextStyle(fontWeight: weight, fontStyle: fontStyle, decoration: decoration);
}
