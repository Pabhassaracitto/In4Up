import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// TEXT SOURCE LOADER — đọc nguồn text mở rộng (.md, .json, .docx)
///
/// Thuần Dart, KHÔNG thêm package zip ngoài:
///  * .md/.markdown  → strip markdown syntax → plain text (giữ chữ thật
///    để pipeline Read phân tích từ, không bị nhiễu ký tự đánh dấu)
///  * .json          → jsonDecode → gom string values thành các dòng
///  * .docx          → .docx là ZIP; tự tìm entry `word/document.xml`
///    qua local file header (PK\x03\x04), inflate raw-deflate bằng
///    ZLibCodec chuẩn của dart:io (bù 2 byte zlib header), rồi lấy text
///    trong thẻ <w:t> theo đoạn <w:p>.
///
/// .doc (binary cũ) KHÔNG hỗ trợ — trả null để caller hiện thông báo
/// "vui lòng lưu lại .docx hoặc .txt".
/// ═══════════════════════════════════════════════════════════════
class TextSourceLoader {
  TextSourceLoader._();

  static const List<String> supportedExtensions = [
    'md',
    'markdown',
    'json',
    'docx',
  ];

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
      if (lower.endsWith('.docx')) {
        return docxToPlainText(await File(path).readAsBytes());
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
    final sig = [0x50, 0x4B, 0x03, 0x04]; // PK\x03\x04
    int pos = 0;
    while (pos + 30 <= bytes.length) {
      if (bytes[pos] != sig[0] ||
          bytes[pos + 1] != sig[1] ||
          bytes[pos + 2] != sig[2] ||
          bytes[pos + 3] != sig[3]) {
        pos++;
        continue;
      }
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
        if (name == entryName) {
          final dataEnd = dataStart + compSize;
          if (dataEnd > bytes.length) {
            // compSize không tin cậy (zip streaming) → quét tới header kế
            var next = dataStart;
            while (next + 4 <= bytes.length &&
                !(bytes[next] == 0x50 &&
                    bytes[next + 1] == 0x4B &&
                    (bytes[next + 2] == 0x03 || bytes[next + 2] == 0x01))) {
              next++;
            }
            return _inflate(
              bytes,
              dataStart,
              next < bytes.length ? next : bytes.length,
              method,
            );
          }
          return _inflate(
            bytes,
            dataStart,
            dataEnd,
            method,
          );
        }
      }
      pos = dataStart + (compSize > 0 ? compSize : 1);
      if (pos <= nameStart) pos = nameStart + 1;
    }
    return null;
  }

  /// method 0 = stored (không nén), method 8 = deflate.
  /// Raw deflate của ZIP không có zlib header → bù [0x78, 0x01] trước
  /// khi cho ZLibCodec (đúng chuẩn RFC 1950, trick phổ biến).
  static String? _inflate(
    List<int> bytes,
    int start,
    int end,
    int method,
  ) {
    try {
      final data = Uint8List.fromList(bytes.sublist(start, end));
      final Uint8List raw;
      if (method == 8) {
        raw = Uint8List.fromList([0x78, 0x01, ...data]);
      } else if (method == 0) {
        raw = data;
      } else {
        return null; // compression khác (rar... — không phải docx chuẩn)
      }
      final inflated = method == 8 ? ZLibCodec().decode(raw) : raw;
      return utf8.decode(inflated, allowMalformed: true);
    } catch (e) {
      debugPrint('TextSourceLoader._inflate error: $e');
      return null;
    }
  }

  /// XML của document.xml → text theo đoạn (<w:p>), tab/xuống dòng thật.
  static String docxXmlToPlainText(String xml) {
    String text = xml;
    // Giữ cấu trúc: đoạn, xuống dòng, tab
    text = text.replaceAll('</w:p>', '\n');
    text = text.replaceAll(RegExp(r'<w:br[^>]*/>'), '\n');
    text = text.replaceAll(RegExp(r'<w:tab[^>]*/>'), '\t');
    // Bỏ hết tag còn lại (giữ text trong <w:t>, <w:instrText>...)
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    // XML entities
    text = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
    text = text.replaceAll(RegExp(r'&#x([0-9A-Fa-f]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)));
    text = text.replaceAll(RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)));
    // Dọn whitespace
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
