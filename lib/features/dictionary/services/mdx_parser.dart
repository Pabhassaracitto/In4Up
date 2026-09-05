import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/dict_entry.dart';

/// Dart parser cho file MDX (MDict dictionary format)
///
/// Hỗ trợ MDX version 1.x và 2.x
/// Parse trong Stream để xử lý file lớn mà không hết RAM
class MdxParser {
  MdxParser._();

  /// Parse file .mdx → Stream<DictEntry>
  ///
  /// [dictId] gán cho mỗi entry (để biết entry thuộc từ điển nào)
  static Stream<DictEntry> parse(String mdxPath, {required String dictId}) {
    final controller = StreamController<DictEntry>();

    Future<void>(() async {
      try {
        final file = File(mdxPath);
        if (!file.existsSync()) {
          controller.addError('File không tồn tại: $mdxPath');
          await controller.close();
          return;
        }

        final bytes = await file.readAsBytes();
        if (bytes.length < 16) {
          controller.addError('File quá nhỏ để là MDX');
          await controller.close();
          return;
        }

        // Parse header
        final header = _parseHeader(bytes);
        if (header == null) {
          controller.addError('Không đọc được header MDX');
          await controller.close();
          return;
        }

        final encoding = header['encoding'] as String? ?? 'UTF-8';
        final keyFormat = header['key_format'] as int? ?? 0;

        // Parse index + records
        final entries = _parseBody(bytes, header, dictId, encoding, keyFormat);
        for (final entry in entries) {
          controller.add(entry);
        }
      } catch (e) {
        controller.addError('Lỗi parse MDX: $e');
      }

      await controller.close();
    });

    return controller.stream;
  }

  /// Detect ngôn ngữ từ MDX header
  static Future<Map<String, String?>> detectLanguage(String mdxPath) async {
    try {
      final file = File(mdxPath);
      if (!file.existsSync()) return {};
      final bytes = await file.readAsBytes();
      final header = _parseHeader(bytes);
      if (header == null) return {};

      final title = header['title'] as String? ?? '';
      final description = header['description'] as String? ?? '';

      return {
        'name': title.isNotEmpty ? title : null,
        ..._guessLangPair('$title $description'),
      };
    } catch (_) {
      return {};
    }
  }

  /// Đoán cặp ngôn ngữ từ tên mô tả
  static Map<String, String?> _guessLangPair(String text) {
    final lower = text.toLowerCase();

    // Patterns phổ biến
    final patterns = <RegExp, List<String>>{
      RegExp(r'\b(en|english)[\s_-]*(vi|vietnamese|viet)\b'): ['en', 'vi'],
      RegExp(r'\b(vi|vietnamese)[\s_-]*(en|english)\b'): ['vi', 'en'],
      RegExp(r'\b(en|english)[\s_-]*(zh|chinese)\b'): ['en', 'zh'],
      RegExp(r'\b(ja|japanese)[\s_-]*(en|english)\b'): ['ja', 'en'],
      RegExp(r'\b(en|english)[\s_-]*(ja|japanese)\b'): ['en', 'ja'],
      RegExp(r'\b(pali)[\s_-]*(vi|vietnamese)\b'): ['pali', 'vi'],
      RegExp(r'\b(pali)[\s_-]*(en|english)\b'): ['pali', 'en'],
      RegExp(r'\b(en|english)[\s_-]*(hi|hindi)\b'): ['en', 'hi'],
      RegExp(r'\b(de|german)[\s_-]*(en|english)\b'): ['de', 'en'],
      RegExp(r'\b(en|english)[\s_-]*(fr|french)\b'): ['en', 'fr'],
    };

    for (final entry in patterns.entries) {
      if (entry.key.hasMatch(lower)) {
        return {
          'source_lang': entry.value[0],
          'target_lang': entry.value[1],
        };
      }
    }

    return {};
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER PARSING
  // ═══════════════════════════════════════════════════════════════

  static Map<String, dynamic>? _parseHeader(Uint8List bytes) {
    try {
      // MDX header: 4 bytes length (LE) + UTF-16LE encoded header string
      final headerLen = _readUint32LE(bytes, 0);

      if (headerLen <= 0 || headerLen > bytes.length - 4) {
        return null;
      }

      // Decode UTF-16LE header (skip 4 bytes length)
      final headerBytes = bytes.sublist(4, 4 + headerLen);
      final headerStr = _decodeUtf16LE(headerBytes);

      // Parse XML-like attributes
      final attrs = <String, dynamic>{};

      // Extract encoding
      final encMatch = RegExp(r'Encoding="([^"]*)"').firstMatch(headerStr);
      if (encMatch != null) {
        attrs['encoding'] = encMatch.group(1);
      }

      // Extract version
      final verMatch = RegExp(r'GeneratedByEngineVersion="([^"]*)"')
          .firstMatch(headerStr);
      if (verMatch != null) {
        attrs['version'] = double.tryParse(verMatch.group(1)!) ?? 2.0;
      }

      // Extract title
      final titleMatch =
          RegExp(r'Title="([^"]*)"').firstMatch(headerStr);
      if (titleMatch != null) {
        attrs['title'] = titleMatch.group(1);
      }

      // Extract description
      final descMatch =
          RegExp(r'Description="([^"]*)"').firstMatch(headerStr);
      if (descMatch != null) {
        attrs['description'] = descMatch.group(1);
      }

      // Key format (0=plain, 1=strip, 2=encryption)
      final kfMatch =
          RegExp(r'KeyCaseSensitive="([^"]*)"').firstMatch(headerStr);
      attrs['key_format'] = 0; // default

      // Header end marker: 4 bytes of 0x00 after header
      attrs['_header_end'] = 4 + headerLen + 4;

      return attrs;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  BODY PARSING (Index + Records)
  // ═══════════════════════════════════════════════════════════════

  static List<DictEntry> _parseBody(
    Uint8List bytes,
    Map<String, dynamic> header,
    String dictId,
    String encoding,
    int keyFormat,
  ) {
    final entries = <DictEntry>[];
    var offset = header['_header_end'] as int;

    if (offset + 8 > bytes.length) return entries;

    try {
      // Number of index entries (8 bytes, LE)
      final numEntries = _readUint64LE(bytes, offset);
      offset += 8;

      if (numEntries <= 0 || numEntries > 10000000) {
        return entries; // sanity check
      }

      // Number of index blocks (8 bytes, LE)
      final numBlocks = _readUint64LE(bytes, offset);
      offset += 8;

      // Number of bytes of key block info (8 bytes, LE)
      final keyBlockInfoLen = _readUint64LE(bytes, offset);
      offset += 8;

      // Skip key block info
      if (keyBlockInfoLen > 0 && offset + keyBlockInfoLen <= bytes.length) {
        offset += keyBlockInfoLen;
      }

      // Number of bytes of key blocks (8 bytes, LE)
      final keyBlockLen = _readUint64LE(bytes, offset);
      offset += 8;

      // Parse key blocks
      final keys = <_KeyEntry>[];
      final keyBlockEnd = offset + keyBlockLen;

      if (keyBlockLen > 0 && keyBlockEnd <= bytes.length) {
        final keyBlockData = bytes.sublist(offset, keyBlockEnd);
        _parseKeyBlocks(keyBlockData, numEntries, encoding, keys);
      }
      offset = keyBlockEnd;

      // Number of record block info len (8 bytes, LE)
      if (offset + 8 > bytes.length) return _buildEntries(keys, [], dictId);
      final recordBlockInfoLen = _readUint64LE(bytes, offset);
      offset += 8;

      // Skip record block info
      if (recordBlockInfoLen > 0 &&
          offset + recordBlockInfoLen <= bytes.length) {
        offset += recordBlockInfoLen;
      }

      // Number of bytes of record blocks (8 bytes, LE)
      if (offset + 8 > bytes.length) return _buildEntries(keys, [], dictId);
      final recordBlockLen = _readUint64LE(bytes, offset);
      offset += 8;

      // Parse record blocks
      final records = <String>[];
      final recordBlockEnd = offset + recordBlockLen;

      if (recordBlockLen > 0 && recordBlockEnd <= bytes.length) {
        final recordBlockData = bytes.sublist(offset, recordBlockEnd);
        _parseRecordBlocks(recordBlockData, keys.length, encoding, records);
      }

      return _buildEntries(keys, records, dictId);
    } catch (_) {
      // Parse lỗi → trả về entries đã parse được
      return entries;
    }
  }

  /// Parse key blocks → danh sách key entries
  static void _parseKeyBlocks(
    Uint8List data,
    int numEntries,
    String encoding,
    List<_KeyEntry> keys,
  ) {
    var pos = 0;

    while (pos + 8 <= data.length && keys.length < numEntries) {
      // Each key block header:
      // 8 bytes: number of entries in this block
      // 8 bytes: compressed size
      // 8 bytes: decompressed size
      // 1 byte: compression type (0=none, 1=zlib, 2=lzo)
      final numInBlock = _readUint64LE(data, pos);
      pos += 8;

      if (pos + 24 > data.length) break;
      final compressedSize = _readUint64LE(data, pos);
      pos += 8;
      final _ = _readUint64LE(data, pos); // decompressed size
      pos += 8;

      if (pos + 1 > data.length) break;
      final compressionType = data[pos];
      pos += 1;

      if (pos + compressedSize > data.length) break;
      final blockData = data.sublist(pos, pos + compressedSize);
      pos += compressedSize;

      // Decompress
      List<int>? decompressed;
      if (compressionType == 0) {
        decompressed = blockData;
      } else if (compressionType == 1) {
        try {
          decompressed = zlib.decode(blockData);
        } catch (_) {
          continue;
        }
      } else {
        continue; // LZO không hỗ trợ trong Dart standard
      }

      // Parse entries trong block
      _parseKeyEntries(
        Uint8List.fromList(decompressed),
        numInBlock,
        encoding,
        keys,
      );
    }
  }

  /// Parse entries từ decompressed key block data
  static void _parseKeyEntries(
    Uint8List data,
    int numEntries,
    String encoding,
    List<_KeyEntry> keys,
  ) {
    var pos = 0;
    for (var i = 0; i < numEntries && pos < data.length; i++) {
      if (pos + 8 > data.length) break;

      // 8 bytes: record offset
      final recordOffset = _readUint64LE(data, pos);
      pos += 8;

      // Key text (null-terminated, encoding-dependent)
      final keyEnd = data.indexOf(0, pos);
      if (keyEnd < 0) break;

      final keyBytes = data.sublist(pos, keyEnd);
      final key = _decodeKey(keyBytes, encoding);
      pos = keyEnd + 1; // skip null terminator

      if (key.isNotEmpty) {
        keys.add(_KeyEntry(key, recordOffset));
      }
    }
  }

  /// Parse record blocks → danh sách definitions
  static void _parseRecordBlocks(
    Uint8List data,
    int numRecords,
    String encoding,
    List<String> records,
  ) {
    var pos = 0;

    while (pos + 24 <= data.length && records.length < numRecords) {
      // Record block header:
      // 8 bytes: number of entries
      // 8 bytes: compressed size
      // 8 bytes: decompressed size
      // 1 byte: compression type
      final _ = _readUint64LE(data, pos);
      pos += 8;

      if (pos + 24 > data.length) break;
      final compressedSize = _readUint64LE(data, pos);
      pos += 8;
      final _ = _readUint64LE(data, pos); // decompressed size
      pos += 8;

      if (pos + 1 > data.length) break;
      final compressionType = data[pos];
      pos += 1;

      if (pos + compressedSize > data.length) break;
      final blockData = data.sublist(pos, pos + compressedSize);
      pos += compressedSize;

      // Decompress
      List<int>? decompressed;
      if (compressionType == 0) {
        decompressed = blockData;
      } else if (compressionType == 1) {
        try {
          decompressed = zlib.decode(blockData);
        } catch (_) {
          continue;
        }
      } else {
        continue;
      }

      // Decode record data
      final recordStr = _decodeRecord(decompressed, encoding);
      records.add(recordStr);
    }
  }

  /// Build DictEntry từ keys + records
  static List<DictEntry> _buildEntries(
    List<_KeyEntry> keys,
    List<String> records,
    String dictId,
  ) {
    final entries = <DictEntry>[];
    for (final key in keys) {
      String definition = '';
      if (key.recordIndex >= 0 && key.recordIndex < records.length) {
        definition = records[key.recordIndex];
      }

      // Tách phonetic và POS từ definition nếu có
      final phonetic = _extractPhonetic(definition);
      final pos = _extractPOS(definition);

      entries.add(DictEntry(
        headword: key.key,
        definition: definition,
        phonetic: phonetic,
        partOfSpeech: pos,
        dictId: dictId,
      ));
    }
    return entries;
  }

  // ═══════════════════════════════════════════════════════════════
  //  HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  static int _readUint32LE(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  static int _readUint64LE(Uint8List data, int offset) {
    final lo = _readUint32LE(data, offset);
    final hi = _readUint32LE(data, offset + 4);
    return lo + (hi * 0x100000000);
  }

  static String _decodeUtf16LE(Uint8List bytes) {
    final buffer = StringBuffer();
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final codeUnit = bytes[i] | (bytes[i + 1] << 8);
      buffer.writeCharCode(codeUnit);
    }
    return buffer.toString();
  }

  static String _decodeKey(Uint8List bytes, String encoding) {
    try {
      final enc = encoding.toUpperCase();
      if (enc.contains('UTF-16')) {
        return _decodeUtf16LE(bytes);
      } else if (enc.contains('UTF-8')) {
        return utf8.decode(bytes, allowMalformed: true);
      } else {
        return latin1.decode(bytes);
      }
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String _decodeRecord(List<int> bytes, String encoding) {
    try {
      final enc = encoding.toUpperCase();
      if (enc.contains('UTF-16')) {
        return _decodeUtf16LE(Uint8List.fromList(bytes));
      } else if (enc.contains('UTF-8')) {
        return utf8.decode(bytes, allowMalformed: true);
      } else {
        return latin1.decode(bytes);
      }
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// Extract phonetic từ HTML definition (pattern: /.../ hoặc [...])
  static String? _extractPhonetic(String definition) {
    // Pattern: /phonetic/ hoặc [phonetic]
    final match = RegExp(r'[/\[][^\]/\[]{2,50}[/\]]').firstMatch(definition);
    return match?.group(0);
  }

  /// Extract part of speech từ HTML definition
  static String? _extractPOS(String definition) {
    final match =
        RegExp(r'\b(n\.|v\.|adj\.|adv\.|prep\.|conj\.|pron\.|int\.)')
            .firstMatch(definition);
    return match?.group(0);
  }
}

/// Internal key entry: key + record offset/index
class _KeyEntry {
  final String key;
  final int recordIndex;

  _KeyEntry(this.key, this.recordIndex);
}
