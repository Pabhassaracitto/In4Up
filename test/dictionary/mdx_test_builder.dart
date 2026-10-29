import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Builder file MDX tổng hợp cho test DICT-001 §8 ("Unit test: MdxParser —
/// mock binary data").
///
/// Layout đối chiếu đặc tả writemdict/fileformat.md + tham chiếu đọc
/// mdict-utils (readmdict.py):
/// - Số section big-endian: u32 (engine 1.2) / u64 (engine 2.0).
/// - Header text luôn UTF-16LE; adler32 header little-endian.
/// - v2.0: 5 số + adler32; key index nén zlib; head/tail size u16 + terminator.
/// - v1.2: 4 số; key index RAW; head/tail size u8, không terminator.
/// - Block: [u32 LE comp][u32 BE adler32][data]; comp 2 = zlib.
class MdxTestBuilder {
  /// 1.2 hoặc 2.0.
  final double version;

  /// Encoding của key/record (UTF-8 hoặc UTF-16LE). Header luôn UTF-16LE.
  final bool utf16;

  /// word → definition (HTML). Key blocks được sort alphabet như file thật.
  final Map<String, String> entries;

  /// Ghi đè header attr (vd 'Encrypted': '2', 'Encoding': 'GBK').
  final Map<String, String> headerOverrides;

  /// comp type ghi vào block (2 = zlib mặc định; 1 = giả LZO để test lỗi).
  final int compressType;

  /// v1.2: ghi key index DƯỚI DẠNG NÉN (biến thể ngoài đặc tả) để test
  /// graceful fallback của parser.
  final bool forceCompressedKeyIndexV12;

  MdxTestBuilder({
    this.version = 2.0,
    this.utf16 = false,
    required this.entries,
    this.headerOverrides = const {},
    this.compressType = 2,
    this.forceCompressedKeyIndexV12 = false,
  });

  bool get wide => version >= 2.0;
  int get numWidth => wide ? 8 : 4;

  /// Ghi file .mdx vào [path] (đè nếu có) và trả về path.
  String writeToFile(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    file.createSync(recursive: true);
    file.writeAsBytesSync(build());
    return path;
  }

  Uint8List build() {
    final words = entries.keys.toList()..sort();
    final defs = [for (final w in words) encodeText(entries[w]!)];
    final offsets = <int>[];
    var running = 0;
    for (final d in defs) {
      offsets.add(running);
      running += d.length;
    }

    // Chia key blocks: >= 6 entry → 2 block (test multi-block).
    final blockSplit = <List<int>>[];
    if (words.length >= 6) {
      final mid = words.length ~/ 2;
      blockSplit.add([for (var i = 0; i < mid; i++) i]);
      blockSplit.add([for (var i = mid; i < words.length; i++) i]);
    } else {
      blockSplit.add([for (var i = 0; i < words.length; i++) i]);
    }

    // ── Key blocks ──
    final keyBlockCompressed = <Uint8List>[];
    final keyBlockDecompLengths = <int>[];
    for (final idx in blockSplit) {
      final content = BytesBuilder();
      for (final i in idx) {
        content.add(num_(offsets[i]));
        content.add(encodeText(words[i]));
        content.add(utf16 ? Uint8List.fromList([0, 0]) : Uint8List(1));
      }
      final decomp = content.toBytes();
      keyBlockCompressed.add(compressBlock(decomp));
      keyBlockDecompLengths.add(decomp.length);
    }

    // ── Key index ──
    final indexContent = BytesBuilder();
    for (var bi = 0; bi < blockSplit.length; bi++) {
      final idx = blockSplit[bi];
      indexContent.add(num_(idx.length));
      final head = encodeText(words[idx.first]);
      final tail = encodeText(words[idx.last]);
      indexContent.add(sizeBytes(unitLength(head)));
      indexContent.add(head);
      if (wide) indexContent.add(utf16 ? [0, 0] : [0]); // terminator v2.0
      indexContent.add(sizeBytes(unitLength(tail)));
      indexContent.add(tail);
      if (wide) indexContent.add(utf16 ? [0, 0] : [0]);
      indexContent.add(num_(keyBlockCompressed[bi].length));
      indexContent.add(num_(keyBlockDecompLengths[bi]));
    }
    final indexDecomp = indexContent.toBytes();
    final Uint8List indexStored;
    if (wide || forceCompressedKeyIndexV12) {
      indexStored = compressBlock(indexDecomp);
    } else {
      indexStored = indexDecomp; // v1.2: RAW
    }

    final keyBlocksBytes = BytesBuilder();
    for (final b in keyBlockCompressed) {
      keyBlocksBytes.add(b);
    }

    // ── Record blocks: >= 6 entry → 2 block ──
    final recGroups = <List<int>>[];
    if (defs.length >= 6) {
      final mid = defs.length ~/ 2;
      recGroups.add([for (var i = 0; i < mid; i++) i]);
      recGroups.add([for (var i = mid; i < defs.length; i++) i]);
    } else {
      recGroups.add([for (var i = 0; i < defs.length; i++) i]);
    }
    final recCompressed = <Uint8List>[];
    final recDecompLengths = <int>[];
    for (final group in recGroups) {
      final content = BytesBuilder();
      for (final i in group) {
        content.add(defs[i]);
      }
      final decomp = content.toBytes();
      recCompressed.add(compressBlock(decomp));
      recDecompLengths.add(decomp.length);
    }
    final recInfo = BytesBuilder();
    for (var i = 0; i < recCompressed.length; i++) {
      recInfo.add(num_(recCompressed[i].length));
      recInfo.add(num_(recDecompLengths[i]));
    }
    final recBlocks = BytesBuilder();
    for (final b in recCompressed) {
      recBlocks.add(b);
    }

    // ── Header ──
    final out = BytesBuilder();
    final attrs = <String, String>{
      'GeneratedByEngineVersion': version == 2.0 ? '2.0' : '1.2',
      'Encoding': utf16 ? 'UTF-16' : 'UTF-8',
      'Encrypted': '0',
      'Title': 'Test Dictionary',
      ...headerOverrides,
    };
    final headerText =
        '<Dictionary ${attrs.entries.map((e) => '${e.key}="${e.value}"').join(' ')}/>';
    final headerBytes = encodeUtf16Le('$headerText\u0000');
    out.add(be32(headerBytes.length));
    out.add(headerBytes);
    out.add(le32(adler32(headerBytes)));

    // ── Key section ──
    final numbers = BytesBuilder();
    numbers.add(num_(blockSplit.length));
    numbers.add(num_(words.length));
    if (wide) numbers.add(num_(indexDecomp.length));
    numbers.add(num_(indexStored.length));
    numbers.add(num_(keyBlocksBytes.length));
    final numbersBytes = numbers.toBytes();
    out.add(numbersBytes);
    if (wide) out.add(be32(adler32(numbersBytes)));
    out.add(indexStored);
    out.add(keyBlocksBytes.toBytes());

    // ── Record section ──
    out.add(num_(recCompressed.length));
    out.add(num_(words.length));
    out.add(num_(recInfo.length));
    out.add(num_(recBlocks.length));
    out.add(recInfo.toBytes());
    out.add(recBlocks.toBytes());

    return out.toBytes();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Uint8List num_(int v) {
    if (!wide) return be32(v);
    return be64(v);
  }

  static Uint8List be32(int v) => Uint8List.fromList([
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
        v & 0xFF,
      ]);

  static Uint8List be64(int v) {
    final hi = v ~/ 0x100000000;
    final lo = v % 0x100000000;
    final out = BytesBuilder();
    out.add(be32(hi));
    out.add(be32(lo));
    return out.toBytes();
  }

  static Uint8List le32(int v) =>
      Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

  Uint8List sizeBytes(int units) {
    if (wide) return u16be(units);
    return Uint8List.fromList([units & 0xFF]);
  }

  static Uint8List u16be(int v) =>
      Uint8List.fromList([(v >> 8) & 0xFF, v & 0xFF]);

  int unitLength(Uint8List bytes) => utf16 ? bytes.length ~/ 2 : bytes.length;

  Uint8List encodeText(String s) => utf16 ? encodeUtf16Le(s) : Uint8List.fromList(utf8.encode(s));

  static Uint8List encodeUtf16Le(String s) {
    final units = s.codeUnits;
    final out = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      out[i * 2] = units[i] & 0xFF;
      out[i * 2 + 1] = units[i] >> 8;
    }
    return out;
  }

  Uint8List compressBlock(Uint8List data) {
    final out = BytesBuilder();
    out.add(le32(compressType));
    out.add(be32(adler32(data)));
    if (compressType == 2) {
      out.add(ZLibCodec().encode(data));
    } else if (compressType == 0) {
      out.add(data);
    } else {
      // Giả LZO — payload rác, parser phải báo lỗi rõ.
      out.add(Uint8List.fromList(List.filled(data.length + 1, 0x42)));
    }
    return out.toBytes();
  }

  static int adler32(List<int> data) {
    var a = 1;
    var b = 0;
    for (final byte in data) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }
    return ((b << 16) | a) & 0xFFFFFFFF;
  }
}
