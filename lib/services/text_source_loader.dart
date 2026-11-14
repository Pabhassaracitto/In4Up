import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// TEXT SOURCE LOADER — đọc nguồn text mở rộng (.md, .json, .docx)
///
/// .docx fix raw-deflate + Central Directory (PSRC-207):
///  * .md/.markdown  → strip markdown syntax → plain text (giữ chữ thật
///    để pipeline Read phân tích từ, không bị nhiễu ký tự đánh dấu)
///  * .json          → jsonDecode → gom string values thành các dòng
///  * .docx          → .docx là ZIP; ưu tiên đọc Central Directory
///    (`PK\x05\x06` → `PK\x01\x02`) để biết chính xác `compressedSize`
///    kể cả khi Google Docs / Java / LibreOffice bật bit 3
///    (`hasDataDescriptor`, `compSize == 0` ở local header), và tự dò
///    main part qua `[Content_Types].xml` / `_rels/.rels` khi không tên
///    `word/document.xml`. Fallback sang local file header cho ZIP tối giản.
///
/// .doc (OLE Compound, Word 97–2003) và .docx đặt mật khẩu (OLE
/// EncryptedPackage) KHÔNG hỗ trợ — trả thông báo chẩn đoán chính xác.
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

  static const String legacyDocHint =
      'Định dạng .doc cũ (Word 97–2003) chưa hỗ trợ — vui lòng lưu lại '
      'thành .docx hoặc .txt.';

  static const String encryptedDocxHint =
      'Tài liệu .docx đang đặt mật khẩu bảo vệ — hãy gỡ mật khẩu rồi mở lại.';

  static const String imageOnlyDocxHint =
      'Tài liệu .docx chỉ chứa ảnh, không có văn bản để đọc.';

  /// ZIP local-file header `PK\x03\x04` (mọi .docx chuẩn) hoặc archive rỗng `PK\x05\x06`.
  static bool looksLikeZip(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      ((bytes[2] == 0x03 && bytes[3] == 0x04) ||
          (bytes[2] == 0x05 && bytes[3] == 0x06));

  /// OLE Compound File magic `D0 CF 11 E0` — Word 97–2003 .doc hoặc .docx mã hóa mật khẩu.
  static bool looksLikeOleDoc(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0xD0 &&
      bytes[1] == 0xCF &&
      bytes[2] == 0x11 &&
      bytes[3] == 0xE0;

  /// Phát hiện file Office đặt mật khẩu (OLE container chứa `EncryptedPackage` / `EncryptionInfo`).
  static bool looksLikeEncryptedOffice(List<int> bytes) {
    if (!looksLikeOleDoc(bytes)) return false;
    return _containsAsciiOrUtf16Le(bytes, 'EncryptedPackage') ||
        _containsAsciiOrUtf16Le(bytes, 'EncryptionInfo');
  }

  static bool _containsAsciiOrUtf16Le(List<int> haystack, String needle) {
    final ascii = needle.codeUnits;
    if (_indexOfBytes(haystack, ascii) >= 0) return true;
    final utf16le = <int>[
      for (final unit in ascii) ...[unit & 0xff, (unit >> 8) & 0xff],
    ];
    return _indexOfBytes(haystack, utf16le) >= 0;
  }

  static int _indexOfBytes(List<int> haystack, List<int> needle) {
    if (needle.isEmpty || haystack.length < needle.length) return -1;
    final first = needle[0];
    final maxStart = haystack.length - needle.length;
    for (var i = 0; i <= maxStart; i++) {
      if (haystack[i] != first) continue;
      var matched = true;
      for (var j = 1; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i;
    }
    return -1;
  }

  /// Giải mã chuỗi văn bản thuần an toàn (UTF-8 / UTF-8 BOM / UTF-16LE / UTF-16BE).
  static String decodePlainTextBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add(bytes[i] | (bytes[i + 1] << 8));
      }
      return String.fromCharCodes(units);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Trả về thông báo lỗi cụ thể cho người dùng khi mở file thất bại.
  static String diagnoseOpenFailureBytes(List<int> bytes, {String path = ''}) {
    final lower = path.toLowerCase();
    if (bytes.isEmpty) return openFailedHint;
    if (looksLikeEncryptedOffice(bytes)) return encryptedDocxHint;
    if (looksLikeOleDoc(bytes) ||
        (lower.endsWith('.doc') && !lower.endsWith('.docx'))) {
      return legacyDocHint;
    }
    if (looksLikeZip(bytes)) {
      final mainXml = _extractMainDocxXml(bytes);
      if (mainXml != null && docxXmlToPlainText(mainXml).trim().isEmpty) {
        return imageOnlyDocxHint;
      }
    }
    return openFailedHint;
  }

  /// Trả về text thuần để nạp vào TextProvider, hoặc null nếu không
  /// đọc được / định dạng không hỗ trợ.
  static Future<String?> extractReadableText(String path) async {
    final lower = path.toLowerCase();
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) return null;
      if (looksLikeOleDoc(bytes)) {
        debugPrint('TextSourceLoader: OLE/encrypted Office không hỗ trợ: $path');
        return null;
      }
      // Đuôi .docx HOẶC magic ZIP (FilePicker Android đôi khi mất đuôi).
      if (lower.endsWith('.docx') || looksLikeZip(bytes)) {
        return docxToPlainText(bytes);
      }
      if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
        return markdownToPlainText(decodePlainTextBytes(bytes));
      }
      if (lower.endsWith('.json')) {
        return jsonToPlainText(decodePlainTextBytes(bytes));
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

    // List markers: - / * + / 1. → bỏ marker, giữ nội dung
    text = text.replaceAll(
      RegExp(r'^\s{0,3}([-*+]\s+|\d+[.)]\s+)', multiLine: true),
      '',
    );

    // Bold/italic
    text = text.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1');
    text = text.replaceAll(RegExp(r'__([^_]+)__'), r'\1');
    text = text.replaceAll(RegExp(r'(?<!\*)\*([^*\s][^*]*)\*(?!\*)'), r'\1');
    text = text.replaceAll(
      RegExp(r'(?<![A-Za-z0-9])_([^_\s][^_]*)_(?![A-Za-z0-9])'),
      r'\1',
    );

    // Horizontal rules
    text = text.replaceAll(
      RegExp(r'^\s{0,3}(-{3,}|\*{3,}|_{3,})\s*$', multiLine: true),
      '',
    );

    // Table separators: |---|---| → bỏ
    text = text.replaceAll(
      RegExp(r'^\s*\|?[\s:|-]+\|[\s:|-]*$', multiLine: true),
      '',
    );

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
  }

  // ── DOCX (ZIP) → plain text ───────────────────────────────

  static String? docxToPlainText(List<int> bytes) {
    final xml = _extractMainDocxXml(bytes);
    if (xml == null) return null;
    return docxXmlToPlainText(xml);
  }

  static String? _extractMainDocxXml(List<int> bytes) {
    // 1. Đường chuẩn phổ biến nhất: word/document.xml
    final standard = _readZipEntry(bytes, 'word/document.xml');
    if (standard != null) return standard;

    // 2. Dò qua [Content_Types].xml (vd Strict OOXML / Google Docs / Pandoc
    //    đặt tên word/document2.xml hoặc main.xml).
    final contentTypes = _readZipEntry(bytes, '[Content_Types].xml');
    if (contentTypes != null) {
      final overrideRe = RegExp(
        r'<Override\b[^>]*\bPartName\s*=\s*["\x27]([^"\x27]+)["\x27][^>]*'
        r'\bContentType\s*=\s*["\x27][^"\x27]*wordprocessingml\.document\.main\+xml["\x27]',
        caseSensitive: false,
      );
      final reverseRe = RegExp(
        r'<Override\b[^>]*\bContentType\s*=\s*["\x27][^"\x27]*wordprocessingml\.document\.main\+xml["\x27][^>]*'
        r'\bPartName\s*=\s*["\x27]([^"\x27]+)["\x27]',
        caseSensitive: false,
      );
      final match =
          overrideRe.firstMatch(contentTypes) ?? reverseRe.firstMatch(contentTypes);
      final partName = match?.group(1);
      if (partName != null && partName.isNotEmpty) {
        final byType = _readZipEntry(bytes, _normalizeZipPath(partName));
        if (byType != null) return byType;
      }
    }

    // 3. Dò qua _rels/.rels (Type=".../officeDocument").
    final rels = _readZipEntry(bytes, '_rels/.rels');
    if (rels != null) {
      final relRe = RegExp(
        r'<Relationship\b[^>]*\bType\s*=\s*["\x27][^"\x27]*/officeDocument["\x27][^>]*'
        r'\bTarget\s*=\s*["\x27]([^"\x27]+)["\x27]',
        caseSensitive: false,
      );
      final revRelRe = RegExp(
        r'<Relationship\b[^>]*\bTarget\s*=\s*["\x27]([^"\x27]+)["\x27][^>]*'
        r'\bType\s*=\s*["\x27][^"\x27]*/officeDocument["\x27]',
        caseSensitive: false,
      );
      final match = relRe.firstMatch(rels) ?? revRelRe.firstMatch(rels);
      final target = match?.group(1);
      if (target != null && target.isNotEmpty) {
        final byRel = _readZipEntry(bytes, _normalizeZipPath(target));
        if (byRel != null) return byRel;
      }
    }
    return null;
  }

  static String _normalizeZipPath(String raw) {
    var s = raw.trim().replaceAll('\\', '/');
    while (s.startsWith('/')) {
      s = s.substring(1);
    }
    while (s.startsWith('./')) {
      s = s.substring(2);
    }
    return s;
  }

  static int _u16(List<int> b, int o) => b[o] | (b[o + 1] << 8);

  static int _u32(List<int> b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  /// Đọc 1 entry trong ZIP:
  ///  1) Ưu tiên Central Directory (`PK\x05\x06` → `PK\x01\x02`): luôn có
  ///     `compressedSize` chính xác kể cả khi trình xuất bật bit 3
  ///     (`hasDataDescriptor`, `compSize == 0` ở local header).
  ///  2) Fallback sang duyệt local file header (`PK\x03\x04`) cho ZIP tối giản
  ///     không có Central Directory.
  static String? _readZipEntry(List<int> bytes, String entryName) {
    final target = _normalizeZipPath(entryName).toLowerCase();
    final fromCentralDir = _readZipEntryViaCentralDirectory(bytes, target);
    if (fromCentralDir != null) return fromCentralDir;
    return _readZipEntryViaLocalHeaders(bytes, target);
  }

  static String? _readZipEntryViaCentralDirectory(
    List<int> bytes,
    String targetLower,
  ) {
    final eocd = _findEocdOffset(bytes);
    if (eocd < 0 || eocd + 22 > bytes.length) return null;

    final cdSize = _u32(bytes, eocd + 12);
    final cdOffset = _u32(bytes, eocd + 16);
    if (cdOffset < 0 || cdSize <= 0 || cdOffset + cdSize > bytes.length) {
      return null;
    }

    var pos = cdOffset;
    final cdEnd = cdOffset + cdSize;
    while (pos + 46 <= cdEnd) {
      if (bytes[pos] != 0x50 ||
          bytes[pos + 1] != 0x4B ||
          bytes[pos + 2] != 0x01 ||
          bytes[pos + 3] != 0x02) {
        break;
      }
      final method = _u16(bytes, pos + 10);
      final compSize = _u32(bytes, pos + 20);
      final nameLen = _u16(bytes, pos + 28);
      final extraLen = _u16(bytes, pos + 30);
      final commentLen = _u16(bytes, pos + 32);
      final localHeaderOffset = _u32(bytes, pos + 42);
      final nameStart = pos + 46;
      if (nameStart + nameLen > cdEnd) break;

      final name = utf8.decode(
        Uint8List.fromList(bytes.sublist(nameStart, nameStart + nameLen)),
        allowMalformed: true,
      );
      if (_normalizeZipPath(name).toLowerCase() == targetLower) {
        if (localHeaderOffset >= 0 &&
            localHeaderOffset + 30 <= bytes.length &&
            _isLocalFileHeader(bytes, localHeaderOffset)) {
          final localNameLen = _u16(bytes, localHeaderOffset + 26);
          final localExtraLen = _u16(bytes, localHeaderOffset + 28);
          final dataStart =
              localHeaderOffset + 30 + localNameLen + localExtraLen;
          final dataEnd = dataStart + compSize;
          if (compSize >= 0 && dataEnd <= bytes.length) {
            final inflated = _inflate(bytes, dataStart, dataEnd, method);
            if (inflated != null) return inflated;
          }
        }
      }

      pos = nameStart + nameLen + extraLen + commentLen;
    }
    return null;
  }

  /// Tìm End of Central Directory (`PK\x05\x06`) từ cuối file lùi lại tối đa ~65KB.
  static int _findEocdOffset(List<int> bytes) {
    if (bytes.length < 22) return -1;
    final minOffset =
        bytes.length > (65535 + 22) ? bytes.length - (65535 + 22) : 0;
    for (var i = bytes.length - 22; i >= minOffset; i--) {
      if (bytes[i] == 0x50 &&
          bytes[i + 1] == 0x4B &&
          bytes[i + 2] == 0x05 &&
          bytes[i + 3] == 0x06) {
        final commentLen = _u16(bytes, i + 20);
        if (i + 22 + commentLen <= bytes.length) {
          return i;
        }
      }
    }
    return -1;
  }

  static String? _readZipEntryViaLocalHeaders(
    List<int> bytes,
    String targetLower,
  ) {
    int pos = 0;
    while (pos + 30 <= bytes.length) {
      if (!_isLocalFileHeader(bytes, pos)) {
        pos++;
        continue;
      }
      final gp = _u16(bytes, pos + 6);
      final hasDataDescriptor = (gp & 0x08) != 0;
      final method = _u16(bytes, pos + 8);
      final compSize = _u32(bytes, pos + 18);
      final nameLen = _u16(bytes, pos + 26);
      final extraLen = _u16(bytes, pos + 28);
      final nameStart = pos + 30;
      final dataStart = nameStart + nameLen + extraLen;

      if (nameStart + nameLen <= bytes.length) {
        final name = utf8.decode(
          Uint8List.fromList(bytes.sublist(nameStart, nameStart + nameLen)),
          allowMalformed: true,
        );
        if (_normalizeZipPath(name).toLowerCase() == targetLower) {
          final dataEnd = _zipDataEnd(
            bytes,
            dataStart: dataStart,
            compSize: compSize,
            hasDataDescriptor: hasDataDescriptor,
          );
          final direct = _inflate(bytes, dataStart, dataEnd, method);
          if (direct != null) return direct;
          // Nếu data descriptor 12 byte (không có chữ ký PK\x07\x08) nằm ngay
          // trước header tiếp theo, thử cắt bớt 12 hoặc 16 byte cuối.
          if (hasDataDescriptor) {
            for (final trim in const [12, 16]) {
              if (dataEnd - trim > dataStart) {
                final trimmed =
                    _inflate(bytes, dataStart, dataEnd - trim, method);
                if (trimmed != null) return trimmed;
              }
            }
          }
          return null;
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
    if (!hasDataDescriptor && compSize == 0 && dataStart <= bytes.length) {
      return dataStart;
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
      if (end < start || start < 0 || end > bytes.length) return null;
      if (end == start) return '';
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
  /// xuống dòng ở `</w:p>` / `<w:br>` / `<w:cr>`, bỏ `w:instrText`,
  /// bỏ nhánh dự phòng `<mc:Fallback>` (tránh nhân đôi chữ trong TextBox)
  /// và bỏ chữ đã xoá `<w:del>`.
  ///
  /// I4U18-READ-IPA-001 — CHẾ ĐỘ DÒNG: ranh giới `</w:p>`, `<w:br>`, `<w:cr>`
  /// xuất ra **dòng trống** (`\n\n`) chứ không phải một `\n`.
  static String docxXmlToPlainText(String xml) {
    // 1. Bỏ nhánh <mc:Fallback> (Word ghi trùng nội dung shape/textbox cả ở
    //    mc:Choice lẫn mc:Fallback) và chữ đã xóa trong Track Changes (<w:del>).
    var cleanedXml = xml.replaceAll(
      RegExp(
        r'<(?:[A-Za-z0-9_-]+:)?Fallback\b[^>]*>[\s\S]*?</(?:[A-Za-z0-9_-]+:)?Fallback\s*>',
        caseSensitive: false,
      ),
      '',
    );
    cleanedXml = cleanedXml.replaceAll(
      RegExp(
        r'<(?:[A-Za-z0-9_-]+:)?del\b[^>]*>[\s\S]*?</(?:[A-Za-z0-9_-]+:)?del\s*>',
        caseSensitive: false,
      ),
      '',
    );

    final out = StringBuffer();
    final tokenRe = RegExp(
      r'</(?:[A-Za-z0-9_-]+:)?(?:p|tr)\s*>|'
      r'<(?:[A-Za-z0-9_-]+:)?(?:br|cr)\b[^>]*/?>|'
      r'<(?:[A-Za-z0-9_-]+:)?tab\b[^>]*/?>|'
      r'<((?:[A-Za-z0-9_-]+:)?t)(?:\s[^>]*)?>([\s\S]*?)</\1\s*>',
      caseSensitive: false,
    );

    for (final match in tokenRe.allMatches(cleanedXml)) {
      final raw = match.group(0)!;
      final lower = raw.toLowerCase();
      if (lower.startsWith('</')) {
        // </w:p>, </p>, </w:tr>: dòng trống = ranh giới cứng cho bộ tách dòng.
        out.write('\n\n');
      } else if (match.group(1) != null) {
        out.write(_decodeXmlEntities(match.group(2) ?? ''));
      } else if (RegExp(r'^<(?:[a-z0-9_-]+:)?tab\b').hasMatch(lower)) {
        out.write('\t');
      } else {
        out.write('\n\n');
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
        .replaceAll('&apos;', "'");
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#x([0-9A-Fa-f]+);'),
      (m) {
        final cp = int.tryParse(m.group(1)!, radix: 16);
        if (cp == null || cp < 0 || cp > 0x10FFFF) return m.group(0)!;
        return String.fromCharCodes([cp]);
      },
    );
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        final cp = int.tryParse(m.group(1)!);
        if (cp == null || cp < 0 || cp > 0x10FFFF) return m.group(0)!;
        return String.fromCharCodes([cp]);
      },
    );
    return decoded.replaceAll('&amp;', '&');
  }
}
