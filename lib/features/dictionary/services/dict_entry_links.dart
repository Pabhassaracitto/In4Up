import 'package:html/parser.dart' as html;

/// The only externally supplied targets accepted here are dictionary headwords.
/// They are never used as a filesystem path, network URL, or executable code.
class DictEntryLinks {
  DictEntryLinks._();

  static const int maxTargetLength = 256;
  static const int maxLinks = 30;

  static String? _safeTarget(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.runes.length > maxTargetLength) return null;
    if (value.runes.any((r) => r < 0x20 || r == 0x7f)) return null;
    // Reject embedded protocols and path-like links. Only words are looked up.
    if (value.contains('://') || value.contains('/') || value.contains('\\')) {
      return null;
    }
    return value;
  }

  /// MDict redirects are whole records, not occurrences inside HTML/text.
  static String? redirectTarget(String definition) {
    final text = definition.replaceFirst(RegExp(r'\x00+$'), '').trim();
    const prefix = '@@@LINK=';
    if (!text.startsWith(prefix)) return null;
    return _safeTarget(text.substring(prefix.length));
  }

  /// MDict lookup schemes only: arbitrary web, file, audio and script URLs
  /// deliberately remain inert. Percent decoding never turns '+' into space.
  static String? internalHref(String href) {
    final trimmed = href.trim();
    final lower = trimmed.toLowerCase();
    String raw;
    if (lower.startsWith('entry://')) {
      raw = trimmed.substring('entry://'.length);
    } else if (lower.startsWith('bword://')) {
      raw = trimmed.substring('bword://'.length);
    } else {
      return null;
    }
    if (raw.contains('?') || raw.contains('#')) return null;
    try {
      return _safeTarget(Uri.decodeComponent(raw));
    } on FormatException {
      return null;
    }
  }

  /// Distinct safe targets in source order. Bounds UI work on untrusted files.
  static List<String> extract(String definition) {
    final redirect = redirectTarget(definition);
    if (redirect != null) return <String>[redirect];
    final fragment = html.parseFragment(definition);
    final seen = <String>{};
    const blockedAncestors = <String>{
      'script', 'style', 'head', 'iframe', 'object', 'embed', 'svg',
      'audio', 'video', 'template', 'form', 'noscript',
    };
    for (final anchor in fragment.querySelectorAll('a[href]')) {
      var ancestor = anchor.parent;
      var blocked = false;
      while (ancestor != null) {
        if (blockedAncestors.contains(ancestor.localName?.toLowerCase())) {
          blocked = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      if (blocked) continue;
      final target = internalHref(anchor.attributes['href'] ?? '');
      if (target != null) seen.add(target);
      if (seen.length >= maxLinks) break;
    }
    return seen.toList(growable: false);
  }
}
