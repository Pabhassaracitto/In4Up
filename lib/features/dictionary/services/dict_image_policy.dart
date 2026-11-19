import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import 'mdd_reader.dart';

/// Conservative, non-executable subset: four local PNG/JPEG MDD keys only.
class DictImagePolicy {
  static const int maxImages = 4;
  static const int maxBytes = 2 * 1024 * 1024;
  static const int maxDimension = 2048;
  static const int maxPixels = 2 * 1024 * 1024;

  static List<String> extract(String definition) {
    final fragment = html.parseFragment(definition);
    final found = <String>{};
    const blocked = {'script', 'style', 'head', 'iframe', 'object', 'embed',
      'svg', 'audio', 'video', 'template', 'form', 'noscript'};
    void visit(dom.Node node, int depth) {
      if (depth > 100 || found.length >= maxImages || node is! dom.Element) return;
      final tag = node.localName?.toLowerCase() ?? '';
      if (blocked.contains(tag)) return;
      if (tag == 'img') {
        final key = MddReader.normalizeKey((node.attributes['src'] ?? '').trim());
        if (key != null && (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg'))) {
          found.add(key);
        }
      }
      for (final child in node.nodes) { visit(child, depth + 1); }
    }
    for (final node in fragment.nodes) { visit(node, 0); }
    return found.toList(growable: false);
  }

  /// Validate headers and dimensions before invoking Flutter's image decoder.
  /// Animated PNG and all other formats are rejected. This is not a substitute
  /// for a sandboxed decoder; corrupt bytes can still fail in the image codec.
  static DictImageSize? inspect(Uint8List bytes) {
    if (bytes.length > maxBytes || bytes.length < 12) return null;
    if (_isPng(bytes)) return _png(bytes);
    if (bytes[0] == 0xff && bytes[1] == 0xd8) return _jpeg(bytes);
    return null;
  }

  static bool _isPng(Uint8List b) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i++) { if (b[i] != signature[i]) return false; }
    return true;
  }

  static DictImageSize? _size(int width, int height) =>
      width > 0 && height > 0 && width <= maxDimension && height <= maxDimension &&
      width * height <= maxPixels ? DictImageSize(width, height) : null;

  static DictImageSize? _png(Uint8List b) {
    final data = ByteData.sublistView(b);
    var pos = 8;
    var chunks = 0;
    DictImageSize? size;
    var imageData = false;
    while (pos <= b.length - 12 && ++chunks <= 10000) {
      final length = data.getUint32(pos);
      if (length > b.length - pos - 12) return null;
      final type = String.fromCharCodes(b.sublist(pos + 4, pos + 8));
      if (chunks == 1) {
        if (type != 'IHDR' || length != 13) return null;
        size = _size(data.getUint32(pos + 8), data.getUint32(pos + 12));
        if (size == null) return null;
      } else if (type == 'IHDR' || type == 'acTL' || type == 'fcTL' || type == 'fdAT') {
        return null;
      }
      if (type == 'IDAT') imageData = true;
      pos += 12 + length;
      if (type == 'IEND') return length == 0 && imageData && pos == b.length ? size : null;
    }
    return null;
  }

  static DictImageSize? _jpeg(Uint8List b) {
    var pos = 2;
    DictImageSize? size;
    while (pos < b.length) {
      if (b[pos++] != 0xff) return null;
      while (pos < b.length && b[pos] == 0xff) { pos++; }
      if (pos >= b.length) return null;
      final marker = b[pos++];
      if (marker == 0xd9 || marker == 0x00) return null;
      if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (pos + 2 > b.length) return null;
      final length = b[pos] * 256 + b[pos + 1];
      if (length < 2 || pos + length > b.length) return null;
      if (marker == 0xda) return size; // first scan: frame header already vetted
      final isFrame = marker >= 0xc0 && marker <= 0xcf &&
          marker != 0xc4 && marker != 0xc8 && marker != 0xcc;
      if (isFrame) {
        // Reject unsupported encodings and ambiguous multiple frame headers.
        if (size != null || (marker != 0xc0 && marker != 0xc2) ||
            length < 8 || b[pos + 2] != 8) return null;
        size = _size(b[pos + 5] * 256 + b[pos + 6], b[pos + 3] * 256 + b[pos + 4]);
        if (size == null) return null;
      }
      pos += length;
    }
    return null;
  }

}

class DictImageSize {
  final int width;
  final int height;
  const DictImageSize(this.width, this.height);
}
