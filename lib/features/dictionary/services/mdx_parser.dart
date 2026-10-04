import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../models/dict_entry.dart';

/// Lỗi parse MDX có lý do rõ ràng — AT #6 (file .mdx hỏng/lạ → báo lỗi rõ,
/// không crash): import bắt exception này và đưa reason vào outcome error.
class MdxParseException implements Exception {
  final String reason;
  const MdxParseException(this.reason);

  @override
  String toString() => reason;
}

/// Parser MDX/MDD (MDict engine **1.2 & 2.0**) — thuần Dart, compute-bound,
/// chạy trong isolate riêng để không block UI với từ điển lớn (>100MB).
///
/// Layout theo đặc tả writemdict/fileformat.md + tham chiếu đọc đã được
/// kiểm chứng thực chiến (mdict-utils `readmdict.py`):
///
/// - Số của các section: **big-endian**, u32 (engine < 2.0) / u64 (>= 2.0).
/// - Header: [u32 BE length][UTF-16LE text][u32 LE adler32].
/// - Block nén: [u32 LE info][u32 BE adler32][data] với
///   `comp = info & 0xF` (0 = none, 1 = LZO, 2 = zlib),
///   `encrypt = (info >> 4) & 0xF` (≠ 0 → chưa hỗ trợ).
/// - Key section (v2.0): num_blocks, num_entries, key_index_decomp_len,
///   key_index_comp_len, key_blocks_len (số BE) + adler32; v1.2 chỉ có
///   num_blocks, num_entries, key_index_len, key_blocks_len (không adler).
/// - Key index (sau giải nén): mỗi block: num_entries, first/last word
///   (size u16 ở v2.0, u8 ở v1.2; text có null terminator ở v2.0),
///   comp_size, decomp_size. v1.2 index RAW, v2.0 nén zlib.
/// - Key block (sau giải nén): [key_id BE][key text \x00]…
/// - Record section: 4 số header + cặp (comp, decomp) RAW (không nén)
///   + các record block nén; key_id là offset trong stream record đã giải
///   nén và nối tiếp nhau.
///
/// Engine 3.0 dùng layout khác hẳn (typed blocks) → báo "chưa hỗ trợ" rõ
/// ràng thay vì parse rác.
class MdxParser {
  MdxParser._();

  /// Parse file .mdx → stream entry. Parse chạy trong isolate; entry được
  /// gửi về theo batch để giữ UI mượt.
  ///
  /// [onProgress] nhận tiến độ 0..1 của file này + thông điệp locale-trung
  /// lập (dạng "Index 1234/56789").
  ///
  /// Bắn [MdxParseException] qua stream error khi file không đọc được theo
  /// đúng đặc tả (hỏng, mã hoá, bảng mã lạ, engine 3.0…).
  static Stream<DictEntry> parse(
    String filePath, {
    required String dictId,
    void Function(double progress, String message)? onProgress,
  }) {
    final controller = StreamController<DictEntry>();
    Isolate? worker;

    controller.onListen = () {
      final port = ReceivePort();
      port.listen((message) {
        final msg = message as List;
        switch (msg[0] as int) {
          case _kMsgBatch:
            for (final entry in msg[1] as List<DictEntry>) {
              controller.add(entry);
            }
          case _kMsgProgress:
            onProgress?.call(msg[1] as double, msg[2] as String);
          case _kMsgError:
            controller.addError(MdxParseException(msg[1] as String));
            port.close();
            controller.close();
          case _kMsgDone:
            port.close();
            controller.close();
        }
      });

      unawaited(() async {
        try {
          worker = await Isolate.spawn(
            _parseIsolate,
            [port.sendPort, filePath, dictId],
          );
        } catch (_) {
          // Không spawn được isolate (platform giới hạn) → parse thẳng trên
          // isolate hiện tại để hành vi import vẫn xác định.
          _runParser(
            filePath: filePath,
            dictId: dictId,
            emit: (entries) {
              for (final entry in entries) {
                controller.add(entry);
              }
            },
            progress: (p, message) => onProgress?.call(p, message),
            fail: (reason) => controller.addError(MdxParseException(reason)),
            done: () => controller.close(),
          );
        }
      }());
    };

    controller.onCancel = () {
      worker?.kill(priority: Isolate.immediate);
    };

    return controller.stream;
  }

  /// Đọc metadata từ header MDX (không parse toàn bộ file — chỉ đọc vài KB
  /// đầu). Trả map rỗng khi file không đọc được.
  static Future<Map<String, String?>> detectLanguage(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return {};
      final handle = await file.open();
      try {
        final sizeBytes = await handle.read(4);
        if (sizeBytes.length < 4) return {};
        final size = ByteData.sublistView(sizeBytes).getUint32(0, Endian.big);
        // Header có thể chứa Description dài — chỉ đọc tối đa 64KB.
        if (size <= 0 || size > 64 * 1024) return {};
        final raw = await handle.read(size);
        var text = _decodeUtf16Le(raw);
        if (text.contains('\u0000')) {
          text = text.replaceAll('\u0000', '');
        }
        if (!text.contains('=')) {
          text = utf8.decode(raw, allowMalformed: true);
        }
        final attrs = _parseHeaderAttrs(text);
        final name = attrs['title'];
        final match = RegExp(r'^(\w{2})_(\w{2})', caseSensitive: false)
            .firstMatch(filePath.split(Platform.pathSeparator).last);
        return {
          'name': (name == null || name.isEmpty) ? null : name,
          'source_lang': match?.group(1),
          'target_lang': match?.group(2),
        };
      } finally {
        await handle.close();
      }
    } catch (_) {
      return {};
    }
  }

  // ── Isolate protocol ──────────────────────────────────────────────────

  static const int _kMsgBatch = 0;
  static const int _kMsgProgress = 1;
  static const int _kMsgError = 2;
  static const int _kMsgDone = 3;

  static void _parseIsolate(List args) {
    _runParser(
      filePath: args[1] as String,
      dictId: args[2] as String,
      emit: (entries) => (args[0] as SendPort).send([_kMsgBatch, entries]),
      progress: (p, message) =>
          (args[0] as SendPort).send([_kMsgProgress, p, message]),
      fail: (reason) => (args[0] as SendPort).send([_kMsgError, reason]),
      done: () => (args[0] as SendPort).send([_kMsgDone]),
    );
  }

  /// Thân parser dùng chung cho isolate và fallback sync.
  static void _runParser({
    required String filePath,
    required String dictId,
    required void Function(List<DictEntry>) emit,
    required void Function(double, String) progress,
    required void Function(String) fail,
    required void Function() done,
  }) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw const MdxParseException(
            'File .mdx không tồn tại hoặc không đọc được');
      }
      final bytes = file.readAsBytesSync();
      final core = _MdxCore(bytes, dictId);
      core.parse(emit: emit, progress: progress);
      progress(1.0, 'Index done');
      done();
    } on MdxParseException catch (e) {
      fail(e.reason);
    } catch (e) {
      fail('Lỗi đọc MDX: $e');
    }
  }
}

// ── Core reader ──────────────────────────────────────────────────────────

class _MdxHeader {
  /// Engine >= 2.0 → số 8 byte (u64 BE).
  final bool wide;

  /// Encoding = UTF-16 → key/record là chuỗi UTF-16LE, terminator 2 byte.
  final bool utf16;
  const _MdxHeader({required this.wide, required this.utf16});

  int get numWidth => wide ? 8 : 4;
}

class _KeySpec {
  final int compressedSize;
  final int decompressedSize;
  const _KeySpec(this.compressedSize, this.decompressedSize);
}

class _Key {
  final String word;
  final int offset;
  const _Key(this.word, this.offset);
}

class _RecordBlock {
  /// Offset của block này trong stream record đã giải nén + nối tiếp.
  final int base;
  final Uint8List data;
  const _RecordBlock(this.base, this.data);
}

const String _kMalformed = 'File .mdx rỗng hoặc sai định dạng';

class _MdxCore {
  final Uint8List bytes;
  final String dictId;
  int offset = 0;

  _MdxCore(this.bytes, this.dictId);

  static const int _kBatchSize = 1000;

  // ── Primitives (big-endian cho số section) ────────────────────────────

  int _be16(List<int> b, int p) => (b[p] << 8) | b[p + 1];

  int _be32(List<int> b, int p) =>
      (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];

  int _beNum(List<int> b, int p, bool wide) {
    if (p < 0) throw const MdxParseException(_kMalformed);
    if (wide) {
      if (p + 8 > b.length) throw const MdxParseException(_kMalformed);
      // Size thực tế không vượt quá vài GB — chặn sớm để số rác không tràn.
      final hi = _be32(b, p);
      if (hi > 0xFFFF) throw const MdxParseException(_kMalformed);
      return hi * 0x100000000 + _be32(b, p + 4);
    }
    if (p + 4 > b.length) throw const MdxParseException(_kMalformed);
    return _be32(b, p);
  }

  void _skip(int n) {
    if (n < 0 || offset + n < 0 || offset + n > bytes.length) {
      throw const MdxParseException(_kMalformed);
    }
    offset += n;
  }

  Uint8List _take(int n) {
    if (n < 0 || offset + n > bytes.length) {
      throw const MdxParseException(_kMalformed);
    }
    final out = Uint8List.sublistView(bytes, offset, offset + n);
    offset += n;
    return out;
  }

  // ── Header ────────────────────────────────────────────────────────────

  _MdxHeader readHeader() {
    if (bytes.length < 12) throw const MdxParseException(_kMalformed);
    final size = _be32(bytes, 0);
    if (size <= 0 || 4 + size + 4 > bytes.length) {
      throw const MdxParseException(_kMalformed);
    }
    final raw = Uint8List.sublistView(bytes, 4, 4 + size);
    offset = 4 + size + 4; // + header adler32 (LE) — không verify

    var text = _decodeUtf16Le(raw);
    if (text.contains('\u0000')) text = text.replaceAll('\u0000', '');
    if (!text.contains('=')) {
      text = utf8.decode(raw, allowMalformed: true);
    }
    final attrs = _parseHeaderAttrs(text);

    final version =
        double.tryParse(attrs['generatedbyengineversion'] ?? '') ?? 0;
    if (version <= 0) throw const MdxParseException(_kMalformed);
    if (version >= 3.0) {
      throw const MdxParseException(
          'MDX engine 3.0 chưa hỗ trợ — hãy dùng bản build engine 2.0');
    }

    final encryptedRaw = (attrs['encrypted'] ?? '0').toLowerCase();
    final encryptedFlag =
        int.tryParse(encryptedRaw) ?? (encryptedRaw == 'yes' ? 1 : 0);
    if (encryptedFlag != 0) {
      throw const MdxParseException(
          'Từ điển có mã hoá (Encrypted) — chưa hỗ trợ');
    }

    final encoding = (attrs['encoding'] ?? 'UTF-8').toUpperCase();
    if (encoding.contains('UTF-16')) {
      return _MdxHeader(wide: version >= 2.0, utf16: true);
    }
    if (encoding.contains('UTF-8') || encoding.contains('UTF8')) {
      return _MdxHeader(wide: version >= 2.0, utf16: false);
    }
    // GBK / GB18030 / Big5…
    throw MdxParseException('Bảng mã không hỗ trợ: $encoding');
  }

  // ── Parse chính ───────────────────────────────────────────────────────

  void parse({
    required void Function(List<DictEntry>) emit,
    required void Function(double, String) progress,
  }) {
    final header = readHeader();
    final keys = _readKeys(header);
    if (keys.isEmpty) {
      return;
    }
    // Record offset không theo thứ tự alphabet → sort để slice tuần tự.
    final sorted = List<_Key>.from(keys)
      ..sort((a, b) => a.offset.compareTo(b.offset));

    final entries = <DictEntry>[];
    var keyIndex = 0;
    final blocks = _readRecordBlocks(header);
    for (var blockIndex = 0; blockIndex < blocks.length; blockIndex++) {
      final block = blocks[blockIndex];
      while (keyIndex < sorted.length &&
          sorted[keyIndex].offset - block.base < block.data.length) {
        final start = sorted[keyIndex].offset - block.base;
        final nextOffset = keyIndex + 1 < sorted.length
            ? sorted[keyIndex + 1].offset
            : block.base + block.data.length;
        var end = nextOffset - block.base;
        if (end > block.data.length) end = block.data.length;
        if (end < start) end = start;
        if (end > start) {
          final definition = _decodeText(block.data, start, end, header).trim();
          if (definition.isNotEmpty) {
            entries.add(DictEntry(
              headword: sorted[keyIndex].word,
              definition: definition,
              dictId: dictId,
            ));
          }
        }
        keyIndex++;
      }
      if (blockIndex % 4 == 3 || blockIndex == blocks.length - 1) {
        progress(
          ((blockIndex + 1) / blocks.length).clamp(0.0, 0.99),
          'Index $keyIndex/${sorted.length}',
        );
      }
      if (entries.length >= _kBatchSize) {
        emit(List<DictEntry>.from(entries));
        entries.clear();
      }
    }
    if (entries.isNotEmpty) {
      emit(entries);
    }
  }

  // ── Key section ───────────────────────────────────────────────────────

  List<_Key> _readKeys(_MdxHeader header) {
    final wide = header.wide;
    final w = header.numWidth;

    final numKeyBlocks = _beNum(bytes, offset, wide);
    _skip(w);
    final numEntries = _beNum(bytes, offset, wide);
    _skip(w);
    if (wide) {
      _skip(w); // key_index_decomp_len — không cần dùng
    }
    final keyBlockInfoSize = _beNum(bytes, offset, wide);
    _skip(w);
    final keyBlockSize = _beNum(bytes, offset, wide);
    _skip(w);
    if (wide) {
      _skip(4); // adler32 (BE) của 40 byte số phía trước — không verify
    }

    if (numKeyBlocks <= 0 ||
        numKeyBlocks > 1000000 ||
        numEntries < 0 ||
        numEntries > 100000000 ||
        keyBlockInfoSize < 0 ||
        keyBlockSize < 0 ||
        offset + keyBlockInfoSize + keyBlockSize > bytes.length) {
      throw const MdxParseException(_kMalformed);
    }

    final infoRaw = _take(keyBlockInfoSize);
    final keyBlockData = _take(keyBlockSize);

    final specs = _decodeKeyBlockInfo(
      infoRaw,
      header,
      keyBlockSize,
      numKeyBlocks,
    );

    // Giải nén từng key block rồi tách [key_id BE][word \x00]…
    final keys = <_Key>[];
    var cursor = 0;
    for (final spec in specs) {
      if (cursor + spec.compressedSize > keyBlockData.length) {
        throw const MdxParseException(_kMalformed);
      }
      final block = _decodeBlock(Uint8List.sublistView(
        keyBlockData,
        cursor,
        cursor + spec.compressedSize,
      ));
      cursor += spec.compressedSize;
      _splitKeyBlock(block, header, keys);
    }
    return keys;
  }

  List<_KeySpec> _decodeKeyBlockInfo(
    Uint8List infoRaw,
    _MdxHeader header,
    int keyBlockSize,
    int numKeyBlocks,
  ) {
    if (header.wide) {
      // v2.0: index luôn là block nén (thường zlib).
      final info = _decodeBlock(infoRaw);
      final specs = _parseKeyBlockInfo(info, header, numKeyBlocks);
      if (!_specsSumTo(specs, keyBlockSize)) {
        throw const MdxParseException(_kMalformed);
      }
      return specs;
    }
    // v1.2: theo tham chiếu là dữ liệu RAW; một số file cũ vẫn nén →
    // parse raw trước + validate; hỏng thì thử bản giải nén (graceful
    // fallback cho biến thể ngoài đặc tả).
    final rawSpecs = _tryParseKeyBlockInfo(infoRaw, header, numKeyBlocks);
    if (rawSpecs != null && _specsSumTo(rawSpecs, keyBlockSize)) {
      return rawSpecs;
    }
    try {
      final alt = _decodeBlock(infoRaw);
      final altSpecs = _tryParseKeyBlockInfo(alt, header, numKeyBlocks);
      if (altSpecs != null && _specsSumTo(altSpecs, keyBlockSize)) {
        return altSpecs;
      }
    } on MdxParseException {
      // fallthrough → malformed
    }
    throw const MdxParseException(_kMalformed);
  }

  List<_KeySpec>? _tryParseKeyBlockInfo(
      Uint8List info, _MdxHeader header, int numBlocks) {
    try {
      return _parseKeyBlockInfo(info, header, numBlocks);
    } catch (_) {
      return null;
    }
  }

  /// Key index sau giải nén: mỗi block gồm num_entries, first/last word
  /// (size u16 ở v2.0, u8 ở v1.2), comp_size, decomp_size — BE.
  List<_KeySpec> _parseKeyBlockInfo(
      Uint8List info, _MdxHeader header, int numBlocks) {
    final specs = <_KeySpec>[];
    var p = 0;
    final unit = header.utf16 ? 2 : 1;
    final sizeWidth = header.wide ? 2 : 1;
    final terminatorUnits = header.wide ? 1 : 0;
    for (var i = 0; i < numBlocks; i++) {
      if (p + header.numWidth > info.length) {
        throw const MdxParseException(_kMalformed);
      }
      p += header.numWidth; // num_entries của block — chỉ cần skip
      if (p + sizeWidth > info.length) {
        throw const MdxParseException(_kMalformed);
      }
      final headSize = sizeWidth == 2 ? _be16(info, p) : info[p];
      p += sizeWidth + (headSize + terminatorUnits) * unit;
      if (p + sizeWidth > info.length) {
        throw const MdxParseException(_kMalformed);
      }
      final tailSize = sizeWidth == 2 ? _be16(info, p) : info[p];
      p += sizeWidth + (tailSize + terminatorUnits) * unit;
      if (p + header.numWidth * 2 > info.length) {
        throw const MdxParseException(_kMalformed);
      }
      final comp = _beNum(info, p, header.wide);
      final decomp = _beNum(info, p + header.numWidth, header.wide);
      p += header.numWidth * 2;
      if (comp < 0 || decomp < 0) {
        throw const MdxParseException(_kMalformed);
      }
      specs.add(_KeySpec(comp, decomp));
    }
    return specs;
  }

  bool _specsSumTo(List<_KeySpec> specs, int keyBlockSize) {
    var sum = 0;
    for (final spec in specs) {
      sum += spec.compressedSize;
    }
    return sum == keyBlockSize;
  }

  void _splitKeyBlock(Uint8List block, _MdxHeader header, List<_Key> out) {
    if (header.utf16) {
      var p = 0;
      while (p + header.numWidth + 1 < block.length) {
        final keyId = _beNum(block, p, header.wide);
        p += header.numWidth;
        var end = p;
        var found = false;
        while (end + 1 < block.length) {
          if (block[end] == 0 && block[end + 1] == 0) {
            found = true;
            break;
          }
          end += 2;
        }
        final stop = found ? end : block.length;
        if (stop <= p) break;
        final word = _decodeUtf16Le(
          Uint8List.sublistView(block, p, stop),
        );
        out.add(_Key(word, keyId));
        if (!found) break;
        p = end + 2;
      }
      return;
    }
    var p = 0;
    while (p + header.numWidth < block.length) {
      final keyId = _beNum(block, p, header.wide);
      p += header.numWidth;
      var end = p;
      while (end < block.length && block[end] != 0) {
        end++;
      }
      final word = utf8.decode(
        Uint8List.sublistView(block, p, end),
        allowMalformed: true,
      );
      out.add(_Key(word, keyId));
      p = end + 1;
    }
  }

  // ── Record section ────────────────────────────────────────────────────

  List<_RecordBlock> _readRecordBlocks(_MdxHeader header) {
    final wide = header.wide;
    final w = header.numWidth;

    final numBlocks = _beNum(bytes, offset, wide);
    _skip(w);
    _skip(w); // num_entries (record) — không dùng
    final infoSize = _beNum(bytes, offset, wide);
    _skip(w);
    final blocksSize = _beNum(bytes, offset, wide);
    _skip(w);

    if (numBlocks <= 0 ||
        numBlocks > 1000000 ||
        infoSize < 0 ||
        blocksSize < 0 ||
        offset + infoSize + blocksSize > bytes.length) {
      throw const MdxParseException(_kMalformed);
    }

    // Cặp (comp, decomp) lưu RAW — không nén.
    final info = _take(infoSize);
    final blockData = _take(blocksSize);

    final out = <_RecordBlock>[];
    var cursor = 0;
    var base = 0;
    var p = 0;
    for (var i = 0; i < numBlocks; i++) {
      if (p + w * 2 > info.length) {
        throw const MdxParseException(_kMalformed);
      }
      final comp = _beNum(info, p, wide);
      final decomp = _beNum(info, p + w, wide);
      p += w * 2;
      if (comp < 0 || cursor + comp > blockData.length) {
        throw const MdxParseException(_kMalformed);
      }
      final decoded = _decodeBlock(
        Uint8List.sublistView(blockData, cursor, cursor + comp),
      );
      cursor += comp;
      out.add(_RecordBlock(base, decoded));
      base += decoded.length;
    }
    return out;
  }

  // ── Block nén ─────────────────────────────────────────────────────────

  Uint8List _decodeBlock(Uint8List block) {
    if (block.length < 8) throw const MdxParseException(_kMalformed);
    final info = ByteData.sublistView(block).getUint32(0, Endian.little);
    final comp = info & 0xF;
    final encrypt = (info >> 4) & 0xF;
    if (encrypt != 0) {
      throw const MdxParseException(
          'Từ điển có mã hoá (Encrypted) — chưa hỗ trợ');
    }
    final payload = Uint8List.sublistView(block, 8);
    switch (comp) {
      case 0:
        return payload;
      case 2:
        try {
          return Uint8List.fromList(ZLibCodec().decode(payload));
        } on FormatException {
          throw const MdxParseException(_kMalformed);
        }
      default:
        // 1 = LZO (engine 1.x) — không có codec Dart thuần.
        throw MdxParseException('Kiểu nén không hỗ trợ (comp=$comp)');
    }
  }

  // ── Text decode ───────────────────────────────────────────────────────

  String _decodeText(Uint8List block, int start, int end, _MdxHeader header) {
    final raw = Uint8List.sublistView(block, start, end);
    if (header.utf16) return _decodeUtf16Le(raw);
    return utf8.decode(raw, allowMalformed: true);
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

String _decodeUtf16Le(List<int> data) {
  final units = <int>[];
  for (var i = 0; i + 1 < data.length; i += 2) {
    units.add(data[i] | data[i + 1] << 8);
  }
  return String.fromCharCodes(units);
}

Map<String, String> _parseHeaderAttrs(String text) {
  final attrs = <String, String>{};
  for (final match
      in RegExp(r'([\w-]+)="([^"]*)"', dotAll: true).allMatches(text)) {
    final key = match.group(1)!.toLowerCase();
    final value = match.group(2)!
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
    attrs[key] = value;
  }
  return attrs;
}
