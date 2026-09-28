import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/dict_entry.dart';

/// Parser MDX v2 (định dạng phổ biến của MDict).
///
/// MDX không phải là file text: header, key blocks và definition blocks đều
/// có thể được nén. Parser cũ chỉ scan chuỗi UTF-8 nên gần như luôn trả về
/// danh sách rỗng (và tự sinh headword entry_0). Ở đây đọc index thật để
/// headword và definition khớp nhau.
class MdxParser {
  static Stream<DictEntry> parse(String filePath, {required String dictId}) async* {
    final file = File(filePath);
    if (!file.existsSync()) return;
    final reader = _MdxReader(await file.readAsBytes());
    final header = reader.readHeader();
    for (final entry in reader.readEntries(
      encoding: header['encoding'] ?? 'UTF-8',
      dictId: dictId,
    )) {
      yield entry;
    }
  }

  static Future<Map<String, String?>> detectLanguage(String filePath) async {
    try {
      final reader = _MdxReader(await File(filePath).readAsBytes());
      final header = reader.readHeader();
      final name = header['name'] ?? '';
      final match = RegExp(r'^(\w{2})_(\w{2})', caseSensitive: false)
          .firstMatch(filePath.split(Platform.pathSeparator).last);
      return {
        'name': name.isEmpty ? null : name,
        'source_lang': match?.group(1),
        'target_lang': match?.group(2),
      };
    } catch (_) {
      return {};
    }
  }
}

class _MdxReader {
  final Uint8List bytes;
  int offset = 0;
  _MdxReader(this.bytes);

  Map<String, String> readHeader() {
    final result = <String, String>{};
    if (bytes.length < 4) return result;
    final size = _u32();
    if (size <= 0 || offset + size > bytes.length) return result;
    final raw = bytes.sublist(offset, offset + size);
    offset += size;
    // Header text is UTF-16LE, although a few old dictionaries use UTF-8.
    var text = _utf16(raw).replaceFirst('\uFEFF', '');
    if (!text.contains('=')) {
      text = utf8.decode(raw, allowMalformed: true);
    }
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final i = line.indexOf('=');
      if (i > 0) result[line.substring(0, i).trim().toLowerCase()] =
          _unescape(line.substring(i + 1).trim());
    }
    // Header checksum (4 bytes) is not part of the index.
    if (offset + 4 <= bytes.length) {
      offset += 4;
    }
    return result;
  }

  List<DictEntry> readEntries({required String encoding, required String dictId}) {
    final out = <DictEntry>[];
    try {
      if (offset + 16 > bytes.length) {
        return out;
      }
      final blockCount = _u32();
      _u32(); // total entry count (kept for format alignment)
      final infoSize = _u32();
      final blockSize = _u32();
      if (blockCount == 0 ||
          blockCount > 100000 ||
          offset + infoSize + blockSize > bytes.length) {
        return out;
      }

      final infoCompressed = bytes.sublist(offset, offset + infoSize);
      offset += infoSize;
      final keyData = bytes.sublist(offset, offset + blockSize);
      offset += blockSize;
      final info = _decompressBlock(infoCompressed);
      final keyBlocks = _parseKeyInfo(info, blockCount);

      // The record index follows the key blocks. It gives the compressed size
      // of every definition block; key offsets refer to the concatenation of
      // the decompressed record blocks.
      if (offset + 12 > bytes.length) {
        return out;
      }
      final recordCount = _at32(bytes, offset);
      final recordInfoSize = _at32(bytes, offset + 4);
      final recordDataSize = _at32(bytes, offset + 8);
      offset += 12;
      if (recordCount == 0 ||
          recordCount > 100000 ||
          offset + recordInfoSize + recordDataSize > bytes.length) {
        return out;
      }
      final recordInfo = _decompressBlock(bytes.sublist(offset, offset + recordInfoSize));
      offset += recordInfoSize;
      final recordSizes = <int>[];
      for (var i = 0; i < recordCount && i * 8 + 8 <= recordInfo.length; i++) {
        recordSizes.add(_at32(recordInfo, i * 8));
      }
      final recordData = bytes.sublist(offset, offset + recordDataSize);
      final definitions = BytesBuilder();
      var recordCursor = 0;
      for (final compressedSize in recordSizes) {
        if (recordCursor + compressedSize > recordData.length) break;
        definitions.add(_decompressBlock(recordData.sublist(
            recordCursor, recordCursor + compressedSize)));
        recordCursor += compressedSize;
      }
      return _readEntriesFromBlocks(keyData, keyBlocks, definitions.takeBytes(),
          encoding, dictId);
    } catch (_) {
      return out;
    }
  }

  List<DictEntry> _readEntriesFromBlocks(Uint8List data, List<_KeySpec> specs,
      Uint8List definitions, String encoding, String dictId) {
    final result = <DictEntry>[];
    var keyCursor = 0;
    final allKeys = <_Key>[];
    for (final spec in specs) {
      if (keyCursor + spec.compressedSize > data.length) break;
      final keys = _decompressBlock(
          data.sublist(keyCursor, keyCursor + spec.compressedSize));
      keyCursor += spec.compressedSize;
      allKeys.addAll(_parseKeys(keys, encoding));
    }
    for (var i = 0; i < allKeys.length; i++) {
      final end = i + 1 < allKeys.length ? allKeys[i + 1].offset : definitions.length;
      if (allKeys[i].offset >= end || end > definitions.length) continue;
      final value = _decode(definitions.sublist(allKeys[i].offset, end), encoding).trim();
      if (value.isNotEmpty) {
        result.add(DictEntry(headword: allKeys[i].word, definition: value, dictId: dictId));
      }
    }
    return result;
  }

  List<_KeySpec> _parseKeyInfo(Uint8List raw, int count) {
    final result = <_KeySpec>[];
    var p = 0;
    for (var i = 0; i < count && p + 8 <= raw.length; i++) {
      // first/last key strings are variable length and are skipped.
      final firstLen = _at16(raw, p); p += 2 + firstLen * 2;
      if (p + 2 > raw.length) break;
      final lastLen = _at16(raw, p); p += 2 + lastLen * 2;
      if (p + 8 > raw.length) break;
      final compressed = _at32(raw, p); final definition = _at32(raw, p + 4); p += 8;
      result.add(_KeySpec(compressed, definition));
    }
    return result;
  }

  List<_Key> _parseKeys(Uint8List raw, String encoding) {
    final out = <_Key>[]; var p = 0;
    while (p + 2 <= raw.length) {
      final len = _at16(raw, p); p += 2;
      if (p + len * 2 + 4 > raw.length) break;
      final word = _utf16(raw.sublist(p, p + len * 2)).replaceAll('\u0000', ''); p += len * 2;
      final pos = _at32(raw, p); p += 4;
      out.add(_Key(word, pos));
    }
    return out;
  }

  Uint8List _decompressBlock(Uint8List block) {
    if (block.length < 8) return block;
    final type = _at32(block, 0);
    final payload = block.sublist(8); // 4-byte type + 4-byte Adler/checksum
    if (type == 0) return payload;
    if (type == 1) return Uint8List.fromList(ZLibCodec().decode(payload));
    return payload; // LZMA is intentionally left untouched rather than crashing import.
  }

  String _decode(List<int> data, String encoding) {
    if (encoding.toLowerCase().contains('utf-16')) return _utf16(data);
    if (encoding.toLowerCase().contains('8859') || encoding.toLowerCase().contains('latin')) {
      return String.fromCharCodes(data);
    }
    return utf8.decode(data, allowMalformed: true);
  }
  String _utf16(List<int> data) {
    final units = <int>[];
    for (var i = 0; i + 1 < data.length; i += 2) {
      units.add(data[i] | data[i + 1] << 8);
    }
    return String.fromCharCodes(units);
  }
  String _unescape(String s) => s.replaceAll('\\n', '\n').replaceAll('\\r', '\r');
  int _u32() { final v = _at32(bytes, offset); offset += 4; return v; }
  int _at16(List<int> b, int p) => b[p] | b[p + 1] << 8;
  int _at32(List<int> b, int p) => b[p] | b[p + 1] << 8 | b[p + 2] << 16 | b[p + 3] << 24;
}

class _KeySpec { final int compressedSize, definitionSize; _KeySpec(this.compressedSize, this.definitionSize); }
class _Key { final String word; final int offset; _Key(this.word, this.offset); }
