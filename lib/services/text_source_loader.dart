import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// TEXT SOURCE LOADER — đọc nguồn text mở rộng (.md, .json, .docx)
///
/// .docx fix raw-deflate: thâu hoạch c301004 từ 01a01580 (2026-08-29).
/// NOTE: packages/in4up_stt (archive 4.x) nằm ngoài paths app_analyze —
/// thay đổi packages/ cần push kèm 1 dòng lib/ để trigger CI root.
///
/// Thuần Dart, KHÔNG thêm package zip ngoài:
///  * .md/.markdown  → strip markdown syntax → plain text (giữ chữ thật
///    để pipeline Read phân tích từ, không bị nhiễu ký tự đánh dấu)
///  * .json          → jsonDecode → gom string values thành các dòng
///  * .docx          → .docx là ZIP; tự tìm entry `word/document.xml`
///    qua local file header (PK\x03\x04), inflate **raw deflate**
///    (`ZLibDecoder(raw: true)` — RFC 1951). Không được bù zlib header
///    0x78 0x01 rồi `ZLibCodec().decode`: thiếu Adler32 → mọi .docx nén
///    (Word/LibreOffice/Google Docs) bung thất bại.
///
/// .doc (OLE Compound, Word 97–2003) KHÔNG hỗ trợ — trả null.
/// ═══════════════════════════════════════════════════════════════
class TextSourceLoader {
  TextSourceLoader._();

  static const List<String> supportedExtensions = [
    'md',
    'markdown',
    'json',
    'docx',
  ];

  /// Snackbar trung thực — đừng gộp mọi lỗi đọc thành ".doc cũ".
  static const String openFailedHint =
      'Không đọc được nội dung. App mở được .docx (Word 2007+), .txt, .md '
      '— không mở .doc cũ (Word 97–2003).';

  /// ZIP local-file header `PK\x03\x04` (mọi .docx chuẩn).
  static bool looksLikeZip(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  /// OLE Compound File magic `D0 CF 11 E0` — Word 97–2003 .doc.
  static bool looksLikeOleDoc(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0xD0 &&
      bytes[1] == 0xCF &&
      bytes[2] == 0x11 &&
      bytes[3] == 0xE0;

  /// Trả về text thuần để nạp vào TextProvider, hoặc null nếu không
  /// đọc được / định dạng không hỗ trợ.
  static Future<String?> extractReadableText(String path) async {
    final lower = path.toLowerCase();
    try {
      if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
        return markdownToPlainText(await File(path).readAsString());
      }
      if (lower.endsWith('.json')) {
        return jsonToPlainText(await File(path).readAsString());
      }
      final bytes = await File(path).readAsBytes();
      if (looksLikeOleDoc(bytes)) {
        debugPrint('TextSourceLoader: OLE .doc không hỗ trợ: $path');
        return null;
      }
      // Đuôi .docx HOẶC magic ZIP (FilePicker Android đôi khi mất đuôi).
      if (lower.endsWith('.docx') || looksLikeZip(bytes)) {
        return docxToPlainText(bytes);
      }
    } catch (e) {
      debugPrint('TextSourceLoader.extractReadableText error: $e');
    }
    return null;
  }

  // ── Markdown → plain text ─────────────────────────────────

  static String markdownToPlainText(String md) {
    String text = md;

    // Code fences: bỏ dòng fence, giữ nội dung
    text = text.replaceAll(RegExp(r'^```.*$', multiLine: true), '');

    // Ảnh: ![alt](url) → alt ; Link: [text](url) → text
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'\1');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'\1');

    // Inline code: `x` → x
    text = text.replaceAll(RegExp(r'`([^`]*)`'), r'\1');

    // Heading: # ... → ...
    text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');

    // Blockquote: > text → text
    text = text.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');

    // List markers: - / * / + / 1. → bỏ marker, giữ nội dung
    text = text.replaceAll(
      RegExp(r'^\s{0,3}([-*+]\s+|\d+[.)]\s+)', multiLine: true),
      '',
    );

    // Bold/italic
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
    text = text.replaceAll(RegExp(r'__([^_]+)__'), r'\1');
    text = text.replaceAll(RegExp(r'(?<!\*)\*([^*\s][^*]*)\*(?!\*)'), r'\1');
    text = text.replaceAll(RegExp(r'(?<![A-Za-z0-9])_([^_\s][^_]*)_(?![A-Za-z0-9])'), r'\1');

    // Horizontal rules
    text = text.replaceAll(RegExp(r'^\s{0,3}(-{3,}|\*{3,}|_{3,})\s*$', multiLine: true), '');

    // Table separators: |---|---| → bỏ
    text = text.replaceAll(
        RegExp(r'^\s*\|?[\s:|-]+\|[\s:|-]*$', multiLine: true), '');

    // Gom khoảng trắng dòng đầu, 3+ dòng trống → 2
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }

  // ── JSON → plain text ─────────────────────────────────────

  static String jsonToPlainText(String raw) {
    try {
      final decoded = jsonDecode(raw);
      final lines = <String>[];
      _collectJsonStrings(decoded, lines);
      if (lines.isNotEmpty) {
        return lines.join('\n');
      }
    } catch (_) {
      // JSON không parse được → coi như text thường (vẫn dùng được)
    }
    return raw;
  }

  static void _collectJsonStrings(dynamic node, List<String> out) {
    if (node is String) {
      final trimmed = node.trim();
      // Chỉ giữ chuỗi có chữ (bỏ số/hASH/url thuần không chữ)
      if (trimmed.length >= 2 && RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(trimmed)) {
        out.add(trimmed);
      }
      return;
    }
    if (node is List) {
      for (final item in node) {
        _collectJsonStrings(item, out);
      }
      return;
    }
    if (node is Map) {
      node.forEach((key, value) {
        if (value is String) {
          final v = value.trim();
          if (v.length >= 2 && RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(v)) {
            out.add('$key: $v');
          }
        } else {
          _collectJsonStrings(value, out);
        }
      });
    }
    // num/bool/null → bỏ (không phải nội dung đọc)
  }

  // ── DOCX (ZIP) → plain text ───────────────────────────────

  static String? docxToPlainText(List<int> bytes) {
    final xml = _readZipEntry(bytes, 'word/document.xml');
    if (xml == null) return null;
    return docxXmlToPlainText(xml);
  }

  /// Đọc 1 entry trong ZIP qua local file header (đủ cho .docx chuẩn,
  /// không cần full ZIP parser).
  static String? _readZipEntry(List<int> bytes, String entryName) {
    int pos = 0;
    while (pos + 30 <= bytes.length) {
      if (!_isLocalFileHeader(bytes, pos)) {
        pos++;
        continue;
      }
      final gp = bytes[pos + 6] | (bytes[pos + 7] << 8);
      final hasDataDescriptor = (gp & 0x08) != 0;
      final method = bytes[pos + 8] | (bytes[pos + 9] << 8);
      final compSize = bytes[pos + 18] |
          (bytes[pos + 19] << 8) |
          (bytes[pos + 20] << 16) |
          (bytes[pos + 21] << 24);
      final nameLen = bytes[pos + 26] | (bytes[pos + 27] << 8);
      final extraLen = bytes[pos + 28] | (bytes[pos + 29] << 8);
      final nameStart = pos + 30;
      final dataStart = nameStart + nameLen + extraLen;

      if (nameStart + nameLen <= bytes.length) {
        final name = utf8.decode(
          Uint8List.fromList(bytes.sublist(nameStart, nameStart + nameLen)),
          allowMalformed: true,
        );
        final normalized = name.replaceAll('\\', '/').toLowerCase();
        if (normalized == entryName.toLowerCase()) {
          final dataEnd = _zipDataEnd(
            bytes,
            dataStart: dataStart,
            compSize: compSize,
            hasDataDescriptor: hasDataDescriptor,
          );
          return _inflate(bytes, dataStart, dataEnd, method);
        }
      }
      pos = _zipDataEnd(
        bytes,
        dataStart: dataStart,
        compSize: compSize,
        hasDataDescriptor: hasDataDescriptor,
      );
      if (pos <= nameStart) pos = nameStart + 1;
    }
    return null;
  }

  static bool _isLocalFileHeader(List<int> bytes, int pos) =>
      pos + 4 <= bytes.length &&
      bytes[pos] == 0x50 &&
      bytes[pos + 1] == 0x4B &&
      bytes[pos + 2] == 0x03 &&
      bytes[pos + 3] == 0x04;

  /// PK\x03\x04 local, PK\x01\x02 central, PK\x05\x06 EOCD, PK\x07\x08 data desc.
  static bool _isZipSignature(List<int> bytes, int pos) {
    if (pos + 4 > bytes.length) return false;
    if (bytes[pos] != 0x50 || bytes[pos + 1] != 0x4B) return false;
    final b2 = bytes[pos + 2];
    final b3 = bytes[pos + 3];
    return (b2 == 0x03 && b3 == 0x04) ||
        (b2 == 0x01 && b3 == 0x02) ||
        (b2 == 0x05 && b3 == 0x06) ||
        (b2 == 0x07 && b3 == 0x08);
  }

  static int _zipDataEnd(
    List<int> bytes, {
    required int dataStart,
    required int compSize,
    required bool hasDataDescriptor,
  }) {
    final claimed = dataStart + compSize;
    if (!hasDataDescriptor && compSize > 0 && claimed <= bytes.length) {
      return claimed;
    }
    var next = dataStart;
    while (next + 4 <= bytes.length && !_isZipSignature(bytes, next)) {
      next++;
    }
    return next < bytes.length ? next : bytes.length;
  }

  /// method 0 = stored, method 8 = raw deflate (RFC 1951).
  static String? _inflate(
    List<int> bytes,
    int start,
    int end,
    int method,
  ) {
    try {
      if (end <= start || start < 0 || end > bytes.length) return null;
      final data = Uint8List.fromList(bytes.sublist(start, end));
      if (method == 0) {
        return utf8.decode(data, allowMalformed: true);
      }
      if (method != 8) return null;
      List<int> inflated;
      try {
        inflated = ZLibDecoder(raw: true).convert(data);
      } catch (_) {
        // Một số tool bọc zlib (RFC 1950) thay vì raw deflate.
        inflated = ZLibCodec().decode(data);
      }
      return utf8.decode(inflated, allowMalformed: true);
    } catch (e) {
      debugPrint('TextSourceLoader._inflate error: $e');
      return null;
    }
  }

  /// XML của document.xml → text theo đoạn (`<w:p>`), tab/xuống dòng thật.
  ///
  /// Không được `strip mọi tag rồi giữ khoảng trắng còn lại`: Word pretty-print
  /// XML và hay tách tiếng Việt (proofing / font phức tạp) thành nhiều `<w:t>`
  /// trong cùng một đoạn. Newline giữa thẻ sẽ biến "Việt Nam" thành
  /// từng chữ một dòng. Chỉ lấy nội dung `<w:t>`, nối run trong đoạn,
  /// xuống dòng ở `</w:p>` / `<w:br>` / `<w:cr>`, bỏ `w:instrText`.
  static String docxXmlToPlainText(String xml) {
    final out = StringBuffer();
    final tokenRe = RegExp(
      r'</w:p\s*>|<w:br\b[^>]*/?>|<w:cr\b[^>]*/?>|<w:tab\b[^>]*/?>|'
      r'<w:t(?:\s[^>]*)?>([\s\S]*?)</w:t>',
      caseSensitive: false,
    );

    for (final match in tokenRe.allMatches(xml)) {
      final raw = match.group(0)!;
      final lower = raw.toLowerCase();
      if (lower.startsWith('</w:p') ||
          lower.startsWith('<w:br') ||
          lower.startsWith('<w:cr')) {
        out.write('\n');
      } else if (lower.startsWith('<w:tab')) {
        out.write('\t');
      } else {
        out.write(_decodeXmlEntities(match.group(1) ?? ''));
      }
    }

    var text = out.toString();
    // Word/proofing hay chèn ZWSP / soft-hyphen → chữ Việt trông rời.
    text = text.replaceAll(RegExp(r'[\u00AD\u200B\u200C\u200D\uFEFF]'), '');
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String _decodeXmlEntities(String text) {
    var decoded = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#x([0-9A-Fa-f]+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    return decoded;
  }
}
