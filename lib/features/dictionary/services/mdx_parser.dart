// lib/features/dictionary/services/mdx_parser.dart
// Parser MDX thật (Octopus MDict .mdx) — thuần Dart, không thêm dependency.
//
// Cấu trúc file MDX (v1 / v2):
//   [header]  4B độ-dài-header (BE) + header text (UTF-16LE, có NUL cuối)
//             + 4B adler32 của header text (LE)
//   [key]     số-liệu-khối (số khối / tổng entry / kích thước index…)
//             + key block info (v2: zlib; v1: raw) → kích thước từng key block
//             + key block: [4B kiểu nén (LE)][4B adler32 (BE)][dữ liệu]
//               mỗi entry: key_id (offset record) + headword (kết thúc bằng NUL)
//   [record]  số khối / tổng entry / kích thước index + từng block
//             [4B kiểu nén (LE)][4B adler32 (BE)][dữ liệu]
//             record của headword thứ i nằm ở offset key_id[i] trong chuỗi
//             record đã giải nép nối lại.
//
// Hỗ trợ: engine 1.x (số 4 byte) + 2.x (số 8 byte); nén: không nén, LZO1X,
// zlib; encoding UTF-8 / UTF-16LE. Không hỗ trợ (báo lỗi rõ, không crash):
// file mã hóa (Encrypted=Yes/2/3), engine 3.x (zstd + khoá từ UUID), bảng mã
// GB18030/Big5 (chưa có bảng chuyển trong Dart).
//
// Đọc theo vùng (RandomAccessFile) thay vì nạp nguyên file >100MB vào RAM.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/dict_entry.dart';
import 'lzo1x.dart';

/// Lỗi đọc file MDX — message hiện trực tiếp cho người dùng (đã i18n ở tầng UI).
class MdxException implements Exception {
  final String message;
  const MdxException(this.message);

  @override
  String toString() => message;
}

/// Metadata đọc được từ header MDX.
class MdxHeader {
  /// Ví dụ 1.2 / 2.0 / 3.0.
  final double version;

  /// 'UTF-8' hoặc 'UTF-16'.
  final String encoding;

  /// 0 = không mã hóa; bit0 = record block, bit1 = key block info.
  final int encrypted;

  /// 4 (engine < 2.0) hoặc 8 (engine >= 2.0).
  final int numberWidth;

  /// Thuộc tính header: Title, Description, Encoding, Format, Encrypted…
  final Map<String, String> attributes;

  /// Vị trí bắt đầu phần key (ngay sau header).
  final int keyBlockOffset;

  const MdxHeader({
    required this.version,
    required this.encoding,
    required this.encrypted,
    required this.numberWidth,
    required this.attributes,
    required this.keyBlockOffset,
  });

  String? get title => attributes['Title'];
  String? get description => attributes['Description'];
  String? get format => attributes['Format'];

  bool get isUtf16 => encoding == 'UTF-16';
}

/// Parser file .mdx → stream [DictEntry].
class MdxParser {
  MdxParser._();

  /// Đọc header (rẻ) — dùng để đặt tên từ điển + nhận diện ngôn ngữ.
  static Future<MdxHeader> readHeader(String filePath) async {
    final file = await _MdxFile.open(filePath);
    try {
      return await _readHeader(file);
    } finally {
      await file.close();
    }
  }

  /// Tương thích API cũ: metadata dạng map để đặt tên / cặp ngôn ngữ.
  ///
  /// Trả về map rỗng khi file không đọc được (không ném) vì hàm này chỉ
  /// dùng để đặt tên hiển thị — lỗi thật sẽ bị bắt ở [parse].
  static Future<Map<String, String?>> detectLanguage(String filePath) async {
    try {
      final header = await readHeader(filePath);
      final fileName =
          filePath.split(Platform.pathSeparator).last.toLowerCase();
      String? sourceLang;
      String? targetLang;
      final match = RegExp(r'^([a-z]{2})[_-]([a-z]{2})').firstMatch(fileName);
      if (match != null) {
        sourceLang = match.group(1);
        targetLang = match.group(2);
      }
      if (sourceLang == null) {
        final fromDescription = RegExp(
          r'([a-z]{2})\s*(?:[-→>/]| to|2)\s*([a-z]{2})',
          caseSensitive: false,
        ).firstMatch(header.description ?? '');
        if (fromDescription != null) {
          sourceLang = fromDescription.group(1)?.toLowerCase();
          targetLang = fromDescription.group(2)?.toLowerCase();
        }
      }
      return {
        'name': header.title,
        'description': header.description,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'encoding': header.encoding,
        'version': header.version.toString(),
      };
    } catch (e) {
      return {};
    }
  }

  /// Đọc toàn bộ file → stream entry (headword + định nghĩa).
  ///
  /// Dùng `await for (final entry in MdxParser.parse(...))` để import; stream
  /// đọc từng record block nên không giữ nguyên file trong RAM.
  static Stream<DictEntry> parse(
    String filePath, {
    required String dictId,
  }) async* {
    final file = await _MdxFile.open(filePath);
    try {
      final header = await _readHeader(file);
      if (header.version >= 3.0) {
        throw const MdxException(
          'MDX phiên bản 3.0 (MdxBuilder 4.x) chưa được hỗ trợ. '
          'Hãy dùng file MDX tạo bởi engine 1.x hoặc 2.x.',
        );
      }
      final keys = await _readKeys(file, header);
      yield* _readRecords(file, header, keys.entries, keys.recordOffset, dictId);
    } finally {
      await file.close();
    }
  }

  // ═══ Header ═══════════════════════════════════════════════════════════

  static Future<MdxHeader> _readHeader(_MdxFile file) async {
    if (file.length < 12) {
      throw const MdxException('File quá nhỏ để là MDX.');
    }
    final sizeBytes = await file.readAt(0, 4);
    final size = _readBe32(sizeBytes, 0);
    if (size <= 0 || size + 8 > file.length) {
      throw MdxException('MDX header không hợp lệ ($size byte).');
    }

    final raw = await file.readAt(4, size);
    final checksumBytes = await file.readAt(4 + size, 4);
    if (_adler32(raw, 0, raw.length) != _readLe32(checksumBytes, 0)) {
      throw const MdxException(
        'MDX header bị hỏng (checksum không khớp) — file có thể không '
        'phải .mdx hoặc bị cắt.',
      );
    }

    final text = _decodeHeaderText(raw);
    final attributes = _parseAttributes(text);

    final rawVersion = attributes['GeneratedByEngineVersion'] ?? '';
    final version = double.tryParse(rawVersion.trim());
    if (version == null) {
      throw MdxException(
        'MDX không có GeneratedByEngineVersion hợp lệ ("$rawVersion").',
      );
    }

    final encoding = _normalizeEncoding(attributes['Encoding'] ?? '');
    if (encoding != 'UTF-8' && encoding != 'UTF-16') {
      throw MdxException(
        'MDX dùng bảng mã $encoding — chưa được hỗ trợ. Hãy dùng file '
        'MDX mã hóa UTF-8 hoặc UTF-16.',
      );
    }

    final encryptedFlag = (attributes['Encrypted'] ?? 'No').trim();
    final encrypted = encryptedFlag.isEmpty || encryptedFlag == 'No'
        ? 0
        : (int.tryParse(encryptedFlag) ?? (encryptedFlag == 'Yes' ? 1 : 0));

    return MdxHeader(
      version: version,
      encoding: encoding,
      encrypted: encrypted,
      numberWidth: version < 2.0 ? 4 : 8,
      attributes: attributes,
      keyBlockOffset: 4 + size + 4,
    );
  }

  static String _decodeHeaderText(Uint8List raw) {
    final n = raw.length;
    // Header MDX là UTF-16LE kết thúc bằng 1 ký tự NUL (2 byte 0x00).
    if (n >= 2 && raw[n - 2] == 0 && raw[n - 1] == 0) {
      return _decodeUtf16Le(raw, 0, n - 2);
    }
    final end = n > 0 ? n - 1 : 0;
    return utf8.decode(Uint8List.sublistView(raw, 0, end),
        allowMalformed: true);
  }

  static final RegExp _attributePattern =
      RegExp(r'(\w+)="(.*?)"', dotAll: true);

  static Map<String, String> _parseAttributes(String headerText) {
    final result = <String, String>{};
    for (final match in _attributePattern.allMatches(headerText)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key == null || value == null) continue;
      result[key] = _unescapeEntities(value);
    }
    return result;
  }

  static String _unescapeEntities(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&');

  static String _normalizeEncoding(String raw) {
    final value = raw.toUpperCase().replaceAll(RegExp(r'[-_ ]'), '');
    switch (value) {
      case '':
      case 'UTF8':
        return 'UTF-8';
      case 'UTF16':
      case 'UTF16LE':
      case 'UNICODE':
        return 'UTF-16';
      case 'GBK':
      case 'GB2312':
      case 'GB18030':
        return 'GB18030';
      case 'BIG5':
        return 'BIG5';
      default:
        return raw.isEmpty ? 'UTF-8' : raw.toUpperCase();
    }
  }

  // ═══ Key section ══════════════════════════════════════════════════════

  static Future<_KeySection> _readKeys(
      _MdxFile file, MdxHeader header) async {
    final width = header.numberWidth;
    final headSize = header.version >= 2.0 ? 8 * 5 : 4 * 4;
    final head = await file.readAt(header.keyBlockOffset, headSize);

    if (header.encrypted & 0x01 != 0) {
      throw const MdxException(
        'MDX này được mã hóa (Encrypted) — không thể đọc. Hãy dùng file '
        'MDX không mã hóa.',
      );
    }

    var pos = 0;
    final numKeyBlocks = _readNumber(head, pos, width);
    pos += width;
    // tổng số entry — chỉ để đối chiếu, không bắt buộc.
    // ignore: unused_local_variable
    final numEntries = _readNumber(head, pos, width);
    pos += width;

    late final int infoSize;
    late final int keyBlocksSize;
    late final int readPos;

    if (header.version >= 2.0) {
      pos += width; // kích thước key block info SAU khi giải nén
      infoSize = _readNumber(head, pos, width);
      pos += width;
      keyBlocksSize = _readNumber(head, pos, width);
      pos += width;
      readPos = header.keyBlockOffset + headSize + 4; // bỏ 4B checksum
    } else {
      infoSize = _readNumber(head, pos, width);
      pos += width;
      keyBlocksSize = _readNumber(head, pos, width);
      pos += width;
      readPos = header.keyBlockOffset + headSize;
    }

    if (numKeyBlocks <= 0 || infoSize <= 0 || keyBlocksSize <= 0) {
      throw const MdxException('MDX không có key block (file rỗng hoặc hỏng).');
    }

    final infoRaw = await file.readAt(readPos, infoSize);
    final blockSizes = _decodeKeyBlockInfo(infoRaw, header);
    final blocksRaw = await file.readAt(readPos + infoSize, keyBlocksSize);

    final keys = <_MdxKey>[];
    var cursor = 0;
    for (final size in blockSizes) {
      if (cursor + size.compSize > blocksRaw.length) {
        throw const MdxException(
          'MDX key block thiếu dữ liệu (file hỏng hoặc bị cắt).',
        );
      }
      final block = _decodeBlock(
        blocksRaw,
        cursor,
        size.compSize,
        size.decompSize,
        header,
      );
      cursor += size.compSize;
      keys.addAll(_splitKeyBlock(block, header));
    }

    return _KeySection(keys, readPos + infoSize + keyBlocksSize);
  }

  static List<_BlockSize> _decodeKeyBlockInfo(
      Uint8List raw, MdxHeader header) {
    final width = header.numberWidth;
    final charWidth = header.isUtf16 ? 2 : 1;

    late final Uint8List data;
    late final int sizeWidth;
    late final int textTerm;

    if (header.version >= 2.0) {
      if (raw.length < 8 ||
          raw[0] != 0x02 ||
          raw[1] != 0x00 ||
          raw[2] != 0x00 ||
          raw[3] != 0x00) {
        throw const MdxException(
          'MDX key block info không hợp lệ (thiếu header zlib).',
        );
      }
      if (header.encrypted & 0x02 != 0) {
        throw const MdxException(
          'MDX này mã hóa cả key block (Encrypted=2) — không thể đọc.',
        );
      }
      final checksum = _readBe32(raw, 4);
      data = _zlibDecode(Uint8List.sublistView(raw, 8));
      if (_adler32(data, 0, data.length) != checksum) {
        throw const MdxException(
          'MDX key block info bị hỏng (checksum không khớp).',
        );
      }
      sizeWidth = 2;
      textTerm = 1;
    } else {
      data = raw;
      sizeWidth = 1;
      textTerm = 0;
    }

    final result = <_BlockSize>[];
    var i = 0;
    while (i + width + sizeWidth <= data.length) {
      i += width; // số entry trong block — không dùng đến
      final headSize = sizeWidth == 2 ? _readBe16(data, i) : data[i];
      i += sizeWidth;
      i += (headSize + textTerm) * charWidth;
      if (i + sizeWidth > data.length) break;
      final tailSize = sizeWidth == 2 ? _readBe16(data, i) : data[i];
      i += sizeWidth;
      i += (tailSize + textTerm) * charWidth;
      if (i + 2 * width > data.length) break;
      final compSize = _readNumber(data, i, width);
      i += width;
      final decompSize = _readNumber(data, i, width);
      i += width;
      result.add(_BlockSize(compSize, decompSize));
    }

    if (result.isEmpty) {
      throw const MdxException('MDX không đọc được danh sách key block.');
    }
    return result;
  }

  static List<_MdxKey> _splitKeyBlock(Uint8List block, MdxHeader header) {
    final width = header.numberWidth;
    final delimWidth = header.isUtf16 ? 2 : 1;
    final keys = <_MdxKey>[];
    var pos = 0;

    while (pos + width <= block.length) {
      final recordOffset = _readNumber(block, pos, width);
      pos += width;
      var end = pos;
      while (end + delimWidth <= block.length) {
        final isDelimiter = delimWidth == 1
            ? block[end] == 0
            : (block[end] == 0 && block[end + 1] == 0);
        if (isDelimiter) break;
        end += delimWidth;
      }
      final headword = _decodeText(block, pos, end, header.encoding);
      pos = end + delimWidth;
      keys.add(_MdxKey(recordOffset, headword));
    }
    return keys;
  }

  // ═══ Record section ═══════════════════════════════════════════════════

  static Stream<DictEntry> _readRecords(
    _MdxFile file,
    MdxHeader header,
    List<_MdxKey> keys,
    int offset,
    String dictId,
  ) async* {
    if (keys.isEmpty) return;

    final width = header.numberWidth;
    final headSize = 4 * width;
    final head = await file.readAt(offset, headSize);

    if (header.encrypted & 0x01 != 0) {
      throw const MdxException(
        'MDX này mã hóa record block — không thể đọc nội dung.',
      );
    }

    var pos = 0;
    final numBlocks = _readNumber(head, pos, width);
    pos += width * 2; // bỏ tổng số entry
    final infoSize = _readNumber(head, pos, width);
    pos += width * 2; // bỏ tổng kích thước vùng block

    final infoRaw = await file.readAt(offset + headSize, infoSize);
    final blocks = <_BlockSize>[];
    var p = 0;
    while (p + 2 * width <= infoRaw.length && blocks.length < numBlocks) {
      final compSize = _readNumber(infoRaw, p, width);
      p += width;
      final decompSize = _readNumber(infoRaw, p, width);
      p += width;
      blocks.add(_BlockSize(compSize, decompSize));
    }
    if (blocks.isEmpty) {
      throw const MdxException('MDX không có record block (không có nghĩa).');
    }

    var dataPos = offset + headSize + infoSize;
    var keyIndex = 0;
    var streamOffset = 0;

    for (final block in blocks) {
      if (block.compSize <= 0) continue;
      final chunk = await file.readAt(dataPos, block.compSize);
      dataPos += block.compSize;
      final data = _decodeBlock(
        chunk,
        0,
        chunk.length,
        block.decompSize,
        header,
      );

      while (keyIndex < keys.length) {
        final key = keys[keyIndex];
        if (key.recordOffset - streamOffset >= data.length) break;
        final nextOffset = keyIndex + 1 < keys.length
            ? keys[keyIndex + 1].recordOffset
            : data.length + streamOffset;
        final from = _clamp(key.recordOffset - streamOffset, 0, data.length);
        final to = _clamp(nextOffset - streamOffset, from, data.length);
        final definition =
            _cleanRecord(_decodeText(data, from, to, header.encoding));
        yield DictEntry(
          headword: key.headword,
          definition: definition,
          dictId: dictId,
        );
        keyIndex++;
      }
      streamOffset += data.length;
      if (keyIndex >= keys.length) break;
    }
  }

  // ═══ Giải nén block ═══════════════════════════════════════════════════

  /// [start] = vị trí đầu block, [length] = số byte của block (kể cả 8B header).
  static Uint8List _decodeBlock(
    Uint8List source,
    int start,
    int length,
    int expectedSize,
    MdxHeader header,
  ) {
    if (length < 8) {
      throw const MdxException('MDX block quá nhỏ (file hỏng).');
    }
    final info = _readLe32(source, start);
    final compression = info & 0x0f;
    final encryption = (info >> 4) & 0x0f;
    if (encryption != 0) {
      throw MdxException(
        'MDX này được mã hóa (kiểu $encryption) — không thể đọc. '
        'Hãy dùng file MDX không mã hóa.',
      );
    }
    final checksum = _readBe32(source, start + 4);
    final payload = Uint8List.sublistView(source, start + 8, start + length);

    late final Uint8List data;
    switch (compression) {
      case 0:
        data = payload;
        break;
      case 1: // LZO1X (engine < 2.0)
        data = Lzo1x.decompress(payload, expectedSize);
        break;
      case 2: // zlib (engine >= 2.0)
        data = _zlibDecode(payload);
        break;
      default:
        throw MdxException(
          'MDX dùng kiểu nén $compression (zstd?) — chưa được hỗ trợ.',
        );
    }

    // v1/v2: adler32 của dữ liệu SAU khi giải nén ⇒ bắt được mọi lỗi giải nén.
    if (header.version < 3.0 && _adler32(data, 0, data.length) != checksum) {
      throw const MdxException(
        'MDX block giải nén sai (checksum không khớp) — file bị hỏng.',
      );
    }
    return data;
  }

  static Uint8List _zlibDecode(Uint8List payload) {
    try {
      final out = ZLibDecoder().convert(payload);
      return out is Uint8List ? out : Uint8List.fromList(out);
    } catch (e) {
      throw MdxException('MDX giải nén zlib thất bại: $e');
    }
  }

  // ═══ Text / số học ════════════════════════════════════════════════════

  static String _decodeText(Uint8List data, int start, int end, String encoding) {
    if (end <= start) return '';
    final view = Uint8List.sublistView(data, start, end);
    switch (encoding) {
      case 'UTF-16':
        return _decodeUtf16Le(data, start, end);
      case 'UTF-8':
      default:
        return utf8.decode(view, allowMalformed: true);
    }
  }

  static String _decodeUtf16Le(Uint8List data, int start, int end) {
    final count = (end - start) >> 1;
    final units = Uint16List(count);
    for (var i = 0; i < count; i++) {
      units[i] = data[start + (i << 1)] | (data[start + (i << 1) + 1] << 8);
    }
    return String.fromCharCodes(units);
  }

  /// Bỏ ký tự NUL cuối (MDX kết thúc record bằng NUL) + trim.
  static String _cleanRecord(String text) {
    var end = text.length;
    while (end > 0) {
      final unit = text.codeUnitAt(end - 1);
      if (unit != 0 && unit != 32 && unit != 10 && unit != 13 && unit != 9) {
        break;
      }
      end--;
    }
    return end == text.length ? text : text.substring(0, end);
  }

  /// Số nguyên không dấu, big-endian, [width] byte.
  static int _readNumber(Uint8List data, int offset, int width) {
    if (offset < 0 || offset + width > data.length) {
      throw const MdxException('MDX thiếu dữ liệu số (file hỏng).');
    }
    var value = 0;
    for (var i = 0; i < width; i++) {
      value = (value << 8) | data[offset + i];
    }
    return value;
  }

  static int _readBe32(Uint8List data, int offset) {
    if (offset + 4 > data.length) {
      throw const MdxException('MDX thiếu dữ liệu (file hỏng).');
    }
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static int _readLe32(Uint8List data, int offset) {
    if (offset + 4 > data.length) {
      throw const MdxException('MDX thiếu dữ liệu (file hỏng).');
    }
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  static int _readBe16(Uint8List data, int offset) {
    if (offset + 2 > data.length) {
      throw const MdxException('MDX thiếu dữ liệu (file hỏng).');
    }
    return (data[offset] << 8) | data[offset + 1];
  }

  static int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Adler32 (RFC 1950) — tự cài để không phụ thuộc API ngoài.
  static int _adler32(Uint8List data, int start, int end) {
    var a = 1;
    var b = 0;
    for (var i = start; i < end; i++) {
      a = (a + data[i]) % 65521;
      b = (b + a) % 65521;
    }
    return ((b << 16) | a) & 0xFFFFFFFF;
  }
}

// ═══ Helpers ═══════════════════════════════════════════════════════════

/// Đọc theo vùng để không nạp nguyên file MDX (có thể >100MB) vào RAM.
class _MdxFile {
  final RandomAccessFile _raf;
  final int length;

  _MdxFile._(this._raf, this.length);

  static Future<_MdxFile> open(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const MdxException('Không tìm thấy file MDX.');
    }
    final raf = await file.open(mode: FileMode.read);
    return _MdxFile._(raf, await raf.length());
  }

  Future<Uint8List> readAt(int offset, int size) async {
    if (offset < 0 || size < 0 || offset + size > length) {
      throw MdxException(
        'MDX thiếu dữ liệu tại offset $offset ($size byte) — file bị hỏng '
        'hoặc không đúng định dạng.',
      );
    }
    await _raf.setPosition(offset);
    final out = Uint8List(size);
    var filled = 0;
    while (filled < size) {
      final read = await _raf.readInto(out, filled, size);
      if (read <= 0) {
        throw const MdxException('MDX đọc không đủ dữ liệu (file bị cắt).');
      }
      filled += read;
    }
    return out;
  }

  Future<void> close() => _raf.close();
}

class _BlockSize {
  final int compSize;
  final int decompSize;
  const _BlockSize(this.compSize, this.decompSize);
}

class _MdxKey {
  /// Offset tuyệt đối của record trong chuỗi record đã giải nén.
  final int recordOffset;
  final String headword;
  const _MdxKey(this.recordOffset, this.headword);
}

class _KeySection {
  final List<_MdxKey> entries;
  final int recordOffset;
  const _KeySection(this.entries, this.recordOffset);
}
