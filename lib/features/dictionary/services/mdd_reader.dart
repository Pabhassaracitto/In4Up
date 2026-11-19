import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'random_access_source.dart';

/// A deliberately limited MDict 2.0 resource reader. This is not a renderer.
/// The caller owns [source], must serialize operations, and must close it.
/// Index construction reads key metadata, never the complete MDD record stream.
class MddReader {
  static const int maxMetadataBytes = 16 * 1024 * 1024;
  static const int maxBlockBytes = 16 * 1024 * 1024;
  static const int maxAssetBytes = 8 * 1024 * 1024;
  static const int maxEntries = 250000;
  static const int maxBlocks = 65536;

  final RandomAccessSource source;
  final Map<String, _Range> _entries;
  final List<_RecordBlock> _blocks;

  MddReader._(this.source, this._entries, this._blocks);

  /// Only relative MDD keys are accepted; this never resolves filesystem paths.
  /// Percent escapes are rejected rather than decoded (avoids encoded traversal).
  static String? normalizeKey(String key) {
    if (key.length > 1024 || key.contains('%') || key.contains('\u0000')) {
      return null;
    }
    var value = key.replaceAll('\\', '/');
    if (value.startsWith('/')) value = value.substring(1);
    if (value.isEmpty || value.startsWith('/') || value.contains(':') ||
        value.contains('?') || value.contains('#')) return null;
    final parts = value.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    return parts.join('/').toLowerCase();
  }

  /// Opens a v2.0, unencrypted MDD index. Throws [FormatException] for
  /// malformed/unsupported files and propagates source/permission failures.
  static Future<MddReader> open(RandomAccessSource source) async {
    final length = await source.length;
    var position = 0;
    Future<Uint8List> read(int count) async {
      if (count < 0 || count > maxMetadataBytes || position > length - count) {
        throw const FormatException('MDD range exceeds limits or file size');
      }
      final bytes = await source.readAt(position, count);
      if (bytes.length != count) throw const FormatException('Truncated MDD');
      position += count;
      return bytes;
    }

    final headerLength = _Cursor(await read(4)).u32();
    if (headerLength < 2 || headerLength > 65536 || headerLength.isOdd) {
      throw const FormatException('Invalid MDD header');
    }
    final headerBytes = await read(headerLength);
    final checksum = _Cursor(await read(4)).u32le();
    if (_adler(headerBytes) != checksum) throw const FormatException('Bad MDD header checksum');
    final header = _utf16(headerBytes).replaceAll('\u0000', '');
    String? attribute(String name) => RegExp('$name="([^"]*)"').firstMatch(header)?.group(1);
    if (!header.startsWith('<Library_Data') ||
        attribute('GeneratedByEngineVersion') != '2.0' ||
        !const {'0', 'No'}.contains(attribute('Encrypted') ?? 'No')) {
      throw const FormatException('Unsupported MDD format or encryption');
    }
    final numbers = await read(40);
    if (_adler(numbers) != _Cursor(await read(4)).u32()) {
      throw const FormatException('Bad MDD key header checksum');
    }
    final n = _Cursor(numbers);
    final keyBlockCount = n.u64();
    final entryCount = n.u64();
    final indexSize = n.u64();
    final indexStoredSize = n.u64();
    final keysStoredSize = n.u64();
    if (keyBlockCount < 1 || keyBlockCount > maxBlocks || entryCount > maxEntries ||
        indexSize > maxMetadataBytes || indexStoredSize > maxMetadataBytes ||
        keysStoredSize > length - position) {
      throw const FormatException('MDD key index exceeds limits');
    }
    final index = _Cursor(_decodeBlock(await read(indexStoredSize), indexSize));
    final keyBlocks = <_KeyBlock>[];
    var totalKeys = 0;
    var totalStored = 0;
    for (var i = 0; i < keyBlockCount; i++) {
      final count = index.u64();
      index.skipText();
      index.skipText();
      final stored = index.u64();
      final unpacked = index.u64();
      if (stored > maxBlockBytes || unpacked > maxBlockBytes) {
        throw const FormatException('MDD key block exceeds limits');
      }
      totalKeys += count;
      totalStored += stored;
      keyBlocks.add(_KeyBlock(count, stored, unpacked));
    }
    if (!index.done || totalKeys != entryCount || totalStored != keysStoredSize) {
      throw const FormatException('Inconsistent MDD key index');
    }
    final keys = <_Key>[];
    var keyTextBytes = 0;
    var lastOffset = -1;
    for (final block in keyBlocks) {
      final data = _Cursor(_decodeBlock(await read(block.stored), block.unpacked));
      for (var i = 0; i < block.count; i++) {
        final offset = data.u64();
        final raw = data.zeroText();
        keyTextBytes += raw.length;
        if (keyTextBytes > maxMetadataBytes || offset < lastOffset) {
          throw const FormatException('MDD keys exceed limits or are unordered');
        }
        lastOffset = offset;
        final name = normalizeKey(_utf16(raw));
        // Invalid keys must still contribute offsets for adjacent records.
        keys.add(_Key(name, offset));
      }
      if (!data.done) throw const FormatException('Invalid MDD key block');
    }
    final rec = _Cursor(await read(32));
    final recCount = rec.u64();
    final recEntries = rec.u64();
    final infoSize = rec.u64();
    final recStoredSize = rec.u64();
    if (recCount > maxBlocks || recEntries != entryCount || infoSize != recCount * 16 ||
        infoSize > maxMetadataBytes) throw const FormatException('Invalid MDD record index');
    final info = _Cursor(await read(infoSize));
    var disk = position;
    var unpackedOffset = 0;
    final blocks = <_RecordBlock>[];
    for (var i = 0; i < recCount; i++) {
      final stored = info.u64();
      final unpacked = info.u64();
      if (stored < 8 || stored > maxBlockBytes || unpacked > maxBlockBytes ||
          disk > length - stored) throw const FormatException('MDD record block exceeds limits');
      blocks.add(_RecordBlock(disk, stored, unpackedOffset, unpacked));
      disk += stored;
      unpackedOffset += unpacked;
    }
    if (disk - position != recStoredSize || (keys.isNotEmpty && keys.last.offset > unpackedOffset)) {
      throw const FormatException('Inconsistent MDD records');
    }
    final entries = <String, _Range>{};
    var end = unpackedOffset;
    for (var i = keys.length - 1; i >= 0; i--) {
      final key = keys[i];
      if (i < keys.length - 1 && key.offset < keys[i + 1].offset) end = keys[i + 1].offset;
      if (key.name != null) {
        if (entries.containsKey(key.name)) throw const FormatException('Duplicate MDD key');
        entries[key.name!] = _Range(key.offset, end);
      }
    }
    return MddReader._(source, entries, blocks);
  }

  /// Returns null for a missing/unsafe key; blocks are decoded on demand.
  /// An asset spanning multiple blocks is assembled with a strict size cap.
  Future<Uint8List?> readResource(String key, {int maxBytes = maxAssetBytes}) async {
    if (maxBytes < 0 || maxBytes > maxAssetBytes) throw ArgumentError.value(maxBytes);
    final name = normalizeKey(key);
    final range = name == null ? null : _entries[name];
    if (range == null) return null;
    final size = range.end - range.start;
    if (size > maxBytes) throw const FormatException('MDD asset exceeds limit');
    final out = BytesBuilder(copy: false);
    for (final block in _blocks) {
      final blockEnd = block.offset + block.unpacked;
      if (blockEnd <= range.start || block.offset >= range.end) continue;
      final bytes = await source.readAt(block.disk, block.stored);
      if (bytes.length != block.stored) throw const FormatException('Truncated MDD record');
      final data = _decodeBlock(bytes, block.unpacked);
      final start = range.start > block.offset ? range.start - block.offset : 0;
      final end = range.end < blockEnd ? range.end - block.offset : block.unpacked;
      out.add(Uint8List.sublistView(data, start, end));
    }
    final result = out.takeBytes();
    if (result.length != size) throw const FormatException('Incomplete MDD record');
    return result;
  }
}

class _KeyBlock {
  final int count, stored, unpacked;
  _KeyBlock(this.count, this.stored, this.unpacked);
}
class _Key {
  final String? name;
  final int offset;
  _Key(this.name, this.offset);
}
class _Range {
  final int start, end;
  _Range(this.start, this.end);
}
class _RecordBlock {
  final int disk, stored, offset, unpacked;
  _RecordBlock(this.disk, this.stored, this.offset, this.unpacked);
}

class _Cursor {
  final Uint8List data;
  int pos = 0;
  _Cursor(this.data);
  bool get done => pos == data.length;
  Uint8List take(int count) {
    if (count < 0 || pos > data.length - count) throw const FormatException('Truncated MDD metadata');
    final result = Uint8List.sublistView(data, pos, pos + count);
    pos += count;
    return result;
  }
  int u16() { final b = take(2); return b[0] * 256 + b[1]; }
  int u32() { final b = take(4); return ByteData.sublistView(b).getUint32(0); }
  int u32le() { final b = take(4); return ByteData.sublistView(b).getUint32(0, Endian.little); }
  int u64() {
    final hi = u32(); final lo = u32();
    // Dart VM integers are signed; all practical file sizes are smaller.
    if (hi > 0x7fffffff) throw const FormatException('MDD integer too large');
    return hi * 0x100000000 + lo;
  }
  void skipText() {
    final length = u16();
    take(length * 2);
    final terminator = take(2);
    if (terminator[0] != 0 || terminator[1] != 0) throw const FormatException('Invalid MDD key index');
  }
  Uint8List zeroText() {
    final start = pos;
    while (true) {
      final unit = take(2);
      if (unit[0] == 0 && unit[1] == 0) break;
      if (pos - start > 2048) throw const FormatException('MDD key too long');
    }
    return Uint8List.sublistView(data, start, pos - 2);
  }
}

String _utf16(Uint8List bytes) {
  if (bytes.length.isOdd) throw const FormatException('Invalid UTF-16');
  final units = <int>[];
  for (var i = 0; i < bytes.length; i += 2) { units.add(bytes[i] | bytes[i + 1] << 8); }
  return String.fromCharCodes(units);
}

int _adler(List<int> bytes) {
  var a = 1, b = 0;
  for (final byte in bytes) { a = (a + byte) % 65521; b = (b + a) % 65521; }
  return (b << 16) | a;
}

class _LimitedSink implements Sink<List<int>> {
  final int limit;
  final BytesBuilder output = BytesBuilder(copy: false);
  int length = 0;
  _LimitedSink(this.limit);
  @override
  void add(List<int> chunk) {
    length += chunk.length;
    if (length > limit) throw const FormatException('MDD decompression exceeds limit');
    output.add(chunk);
  }
  @override
  void close() {}
}

Uint8List _decodeBlock(Uint8List bytes, int expected) {
  if (expected > MddReader.maxBlockBytes || bytes.length < 8) throw const FormatException('Invalid MDD block');
  final cursor = _Cursor(bytes);
  final type = cursor.u32le();
  final checksum = cursor.u32();
  final payload = cursor.take(bytes.length - 8);
  Uint8List result;
  if (type == 0) {
    result = payload;
  } else if (type == 2) {
    final sink = _LimitedSink(expected);
    final decoder = ZLibDecoder().startChunkedConversion(sink);
    for (var i = 0; i < payload.length; i += 1024) {
      decoder.add(Uint8List.sublistView(payload, i, i + 1024 < payload.length ? i + 1024 : payload.length));
    }
    decoder.close();
    result = sink.output.takeBytes();
  } else {
    throw const FormatException('Unsupported MDD compression or encryption');
  }
  if (result.length != expected || _adler(result) != checksum) throw const FormatException('Bad MDD block checksum or length');
  return result;
}

/// Searches explicitly selected parts in caller-provided order, closing each
/// handle even on failure. A broken part is not silently treated as missing.
/// Part discovery, caching and UI integration belong to the future resolver.
class MddParts {
  static const int maxParts = 64;
  final List<Future<RandomAccessSource> Function()> _openers;

  MddParts(List<Future<RandomAccessSource> Function()> openers)
      : _openers = List.unmodifiable(openers) {
    if (_openers.length > maxParts) throw ArgumentError('Too many MDD parts');
  }

  /// Resolve a small batch in one pass. Each part is indexed at most once for
  /// this operation; no index survives a source close/relink/revocation.
  Future<List<Uint8List?>> readResources(List<String> keys, {
    int maxItemBytes = MddReader.maxAssetBytes,
    int maxTotalBytes = MddReader.maxAssetBytes,
  }) async {
    if (keys.length > 4 || maxItemBytes < 0 || maxItemBytes > MddReader.maxAssetBytes ||
        maxTotalBytes < 0 || maxTotalBytes > MddReader.maxAssetBytes) {
      throw ArgumentError('Invalid MDD batch limits');
    }
    final names = keys.map(MddReader.normalizeKey).toList();
    final pending = names.whereType<String>().toSet();
    final found = <String, Uint8List>{};
    var total = 0;
    for (final open in _openers) {
      if (pending.isEmpty) break;
      final source = await open();
      try {
        final reader = await MddReader.open(source);
        for (final name in pending.toList()) {
          final bytes = await reader.readResource(name, maxBytes: maxItemBytes);
          if (bytes == null) continue;
          total += bytes.length;
          if (total > maxTotalBytes) throw const FormatException('MDD batch exceeds limit');
          found[name] = bytes;
          pending.remove(name);
        }
      } finally {
        await source.close();
      }
    }
    return [for (final name in names) name == null ? null : found[name]];
  }

  Future<Uint8List?> readResource(String key) async =>
      (await readResources([key])).single;
}
