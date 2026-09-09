import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/dict_entry.dart';

/// MDX file parser — extract entries từ file .mdx
class MdxParser {
  /// Parse file MDX → Stream<DictEntry>
  static Stream<DictEntry> parse(String filePath, {required String dictId}) async* {
    final file = File(filePath);
    if (!file.existsSync()) return;

    final bytes = await file.readAsBytes();
    final reader = _MdxReader(bytes);

    // Đọc header
    final header = reader.readHeader();
    final encoding = header['encoding'] as String? ?? 'UTF-8';
    final keyType = header['key_type'] as int? ?? 0;

    // Đọc index blocks
    final entries = reader.readEntries(encoding: encoding, dictId: dictId);

    for (final entry in entries) {
      yield entry;
    }
  }

  /// Detect ngôn ngữ từ header MDX
  static Future<Map<String, String?>> detectLanguage(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return {};

      final bytes = await file.readAsBytes();
      final reader = _MdxReader(bytes);
      final header = reader.readHeader();

      final name = header['name'] as String? ?? '';
      final description = header['description'] as String? ?? '';

      // Parse language từ name hoặc description
      String? sourceLang;
      String? targetLang;

      // Thử parse từ tên file: "en_vi_bdict.mdx" → en, vi
      final fileName = filePath.split(Platform.pathSeparator).last;
      final langMatch = RegExp(r'^(\w{2})_(\w{2})').firstMatch(fileName);
      if (langMatch != null) {
        sourceLang = langMatch.group(1);
        targetLang = langMatch.group(2);
      }

      return {
        'name': name.isNotEmpty ? name : null,
        'source_lang': sourceLang,
        'target_lang': targetLang,
      };
    } catch (e) {
      return {};
    }
  }
}

/// Helper đọc binary MDX
class _MdxReader {
  final Uint8List _bytes;
  int _offset = 0;

  _MdxReader(this._bytes);

  Map<String, dynamic> readHeader() {
    final result = <String, dynamic>{};

    try {
      // MDX header format:
      // 4 bytes: number of header bytes
      // Header text (UTF-16LE encoded)

      if (_bytes.length < 8) return result;

      // Số bytes header
      final headerSize = _readUint32();
      if (headerSize <= 0 || headerSize > _bytes.length - 4) return result;

      // Đọc header text
      final headerBytes = _bytes.sublist(4, 4 + headerSize);
      final headerText = utf8.decode(headerBytes, allowMalformed: true);

      // Parse key-value pairs
      for (final line in headerText.split('\n')) {
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim().toLowerCase();
          final value = parts.sublist(1).join('=').trim();
          result[key] = value;
        }
      }

      _offset = 4 + headerSize;
    } catch (e) {
      // Header parse error
    }

    return result;
  }

  List<DictEntry> readEntries({
    required String encoding,
    required String dictId,
  }) {
    final entries = <DictEntry>[];

    try {
      // Đơn giản hóa: scan cho text patterns
      // MDX thực tế phức tạp hơn, đây là basic parser
      final text = utf8.decode(_bytes, allowMalformed: true);

      // Tìm HTML definitions
      final htmlPattern = RegExp(r'<div[^>]*>.*?</div>', dotAll: true);
      final matches = htmlPattern.allMatches(text);

      for (final match in matches.take(10000)) {
        final html = match.group(0) ?? '';
        if (html.length > 10) {
          entries.add(DictEntry(
            headword: 'entry_${entries.length}',
            definition: html,
            dictId: dictId,
          ));
        }
      }
    } catch (e) {
      // Parse error
    }

    return entries;
  }

  int _readUint32() {
    if (_offset + 4 > _bytes.length) return 0;
    final value = _bytes[_offset] |
        (_bytes[_offset + 1] << 8) |
        (_bytes[_offset + 2] << 16) |
        (_bytes[_offset + 3] << 24);
    _offset += 4;
    return value;
  }
}
