/// Shared Tipiṭaka markup utilities used by the reader, search results and
/// library outlines.
///
/// Two database shapes reach the UI:
///
///  * raw/demo rows that still carry Chaṭṭha Saṅgāyana `rend` attributes
///    (`<p rend="chapter">`, `<hi rend="paranum">`…);
///  * normalised rows where the importer already stripped tags and recorded
///    its own `block_type` column (`book`, `chapter`, `heading`, `center`).
///
/// These helpers give both shapes one consistent, book-like presentation.
library;

import '../models/segment.dart';

/// Semantic block kinds the layout pipeline understands.
enum TipitakaBlockKind {
  /// `rend="book"` — tên tập/bộ kinh.
  book,

  /// `rend="chapter"` — tên chương/phẩm.
  chapter,

  /// `rend="subhead"` / `rend="heading"` — tiểu mục.
  heading,

  /// `rend="centre"` — dòng canh giữa, vd "Namo tassa…".
  center,

  /// `rend="hangnum"` — số đoạn trôi nổi (1. 2. 3.) của ấn bản CSCD.
  hangnum,

  /// `rend="gatha*"` — kệ; dòng thơ được thụt dòng.
  gatha,

  /// Đoạn văn thường.
  paragraph,
}

/// Cross-platform serif stack for canonical text. Android ships Noto Serif;
/// Apple/Windows machines resolve Georgia/Times. No bundled font required.
const tipitakaSerifFamily = 'NotoSerifTipitaka';

const tipitakaSerifFallback = <String>[
  'Noto Serif',
  'Source Serif 4',
  'Source Serif Pro',
  'Charis SIL',
  'Gentium Plus',
  'Georgia',
  'Times New Roman',
  'Times',
  'serif',
];

/// Human label for a content language code (`vi` → `Tiếng Việt`).
String tipitakaLanguageLabel(String code) {
  switch (code.toLowerCase()) {
    case 'pi':
      return 'Pāḷi';
    case 'vi':
      return 'Tiếng Việt';
    case 'en':
      return 'English';
    case 'my':
      return 'Myanmar (မြန်မာ)';
    case 'th':
      return 'Thai (ไทย)';
    case 'zh':
      return '中文';
    case 'si':
      return 'සිංහල';
    case 'hi':
      return 'हिन्दी';
    default:
      return code.toUpperCase();
  }
}

/// Classifies a segment into a [TipitakaBlockKind], honouring both the stored
/// `block_type` column and the raw CSCD `rend` attributes.
TipitakaBlockKind tipitakaBlockKind(TipitakaSegment segment) {
  switch (segment.blockType) {
    case 'book':
      return TipitakaBlockKind.book;
    case 'chapter':
      return TipitakaBlockKind.chapter;
    case 'heading':
      return TipitakaBlockKind.heading;
    case 'center':
      return TipitakaBlockKind.center;
    case 'gatha':
      return TipitakaBlockKind.gatha;
    case 'hangnum':
      return TipitakaBlockKind.hangnum;
  }
  final raw = segment.paliText.toLowerCase();
  if (raw.contains('rend="book"') || raw.contains("rend='book'")) {
    return TipitakaBlockKind.book;
  }
  if (raw.contains('rend="chapter"') || raw.contains("rend='chapter'")) {
    return TipitakaBlockKind.chapter;
  }
  if (raw.contains('rend="subhead"') ||
      raw.contains('rend="heading"') ||
      raw.contains("rend='subhead'") ||
      raw.contains("rend='heading'")) {
    return TipitakaBlockKind.heading;
  }
  if (raw.contains('rend="centre"') ||
      raw.contains('rend="center"') ||
      raw.contains("rend='centre'") ||
      raw.contains("rend='center'")) {
    return TipitakaBlockKind.center;
  }
  if (raw.contains('rend="hangnum"') || raw.contains("rend='hangnum'")) {
    return TipitakaBlockKind.hangnum;
  }
  if (raw.contains('rend="gatha') || raw.contains("rend='gatha")) {
    return TipitakaBlockKind.gatha;
  }
  // Imported databases strip tags, so a "hangnum" row survives only as its
  // bare number (e.g. `1 .`) with no translation attached.
  if (segment.blockType == 'paragraph') {
    final plain = cleanTipitakaText(segment.paliText);
    final hasTranslation = segment.firstTranslation != null;
    if (!hasTranslation && RegExp(r'^\d{1,5}\s*[.)]?$').hasMatch(plain)) {
      return TipitakaBlockKind.hangnum;
    }
  }
  return TipitakaBlockKind.paragraph;
}

/// Plain canonical text separated from compact CSCD apparatus notes.
class TipitakaParsedText {
  final String text;
  final List<String> apparatus;

  const TipitakaParsedText(this.text, this.apparatus);
}

/// Extracts apparatus such as `[(syā.) (sī.)]` in one shared parser.
/// The source string is never mutated in the database.
TipitakaParsedText parseTipitakaText(String value, {bool apparatusInline = false}) {
  final notes = <String>[];
  final apparatusPattern = RegExp(r'\[\((.*?)\)\]', dotAll: true);
  final withoutApparatus = value.replaceAllMapped(apparatusPattern, (match) {
    final note = (match.group(1) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (note.isNotEmpty) notes.add(note);
    return apparatusInline ? match.group(0)! : ' ';
  });
  return TipitakaParsedText(_cleanTipitakaMarkup(withoutApparatus), notes);
}

/// Strips CSCD/HTML markup into displayable plain text, keeping intentional
/// line breaks (paragraph and verse boundaries).
String cleanTipitakaText(String value) => parseTipitakaText(value).text;

String _cleanTipitakaMarkup(String value) {
  return value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();
}

/// Extracts page-break markers such as `<pb ed="M" n="1.0001"/>` into short
/// labels like `M 1.0001`, mirroring how OpenTipitaka surfaces edition page
/// anchors (`M 1`, `M 2`…).
List<String> tipitakaPageMarkers(String raw) {
  if (raw.isEmpty || !raw.contains('<pb')) return const [];
  final pattern = RegExp(
    r'''<pb\s+[^>]*?ed=["']?([A-Za-z]+)["']?[^>]*?n=["']?([0-9]+(?:\.[0-9]+)?)["']?[^>]*?/?>''',
    caseSensitive: false,
  );
  final markers = <String>[];
  for (final match in pattern.allMatches(raw)) {
    final edition = (match.group(1) ?? '').trim();
    final page = (match.group(2) ?? '').trim();
    if (edition.isEmpty || page.isEmpty) continue;
    markers.add('$edition $page');
  }
  return List.unmodifiable(markers);
}

/// Label for a `hangnum` paragraph-number row (`<hi rend="paranum">1</hi>`).
/// Falls back to the bare digits left after tag stripping in imported DBs.
String tipitakaParagraphNumber(TipitakaSegment segment) {
  final raw = segment.paliText;
  final match = RegExp(r'paranum[^>]*>\s*([^<]+)', caseSensitive: false)
      .firstMatch(raw);
  final fromMarkup = match?.group(1)?.trim() ?? '';
  if (fromMarkup.isNotEmpty) {
    return fromMarkup.endsWith('.') ? fromMarkup : '$fromMarkup.';
  }
  final plain = cleanTipitakaText(raw);
  final digits = RegExp(r'^\d{1,5}').firstMatch(plain)?.group(0) ?? '';
  if (digits.isNotEmpty) return '$digits.';
  return plain.length <= 4 ? plain : '';
}
