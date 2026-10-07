// lib/features/iconize/data/iconize_binary.dart
//
// ICONIZE-001b — reader thuần Dart cho 3 file nhị phân sinh bởi
// tool/iconize/build_icon_assets.py. HỢP ĐỒNG FORMAT: tool/iconize/README.md
// (magic "ICNB0001", little-endian, header 16 byte, offset table + blob).
//
// Lỗi format (magic sai / file cụt) ném [IconizeBinaryFormatException] —
// tầng trên (lane 001d) bắt để disable Iconize cả session + badge cảnh báo
// (blueprint mục 3.8), KHÔNG để crash app.

import 'dart:convert';
import 'dart:typed_data';

import '../models/iconize_span.dart';

/// Magic header 8 byte ASCII mở đầu mọi file .bin của Iconize.
const String iconizeBinaryMagic = 'ICNB0001';

/// Version format mà reader này hiểu.
const int iconizeBinaryVersion = 1;

class IconizeBinaryFormatException implements Exception {
  final String message;
  const IconizeBinaryFormatException(this.message);

  @override
  String toString() => 'IconizeBinaryFormatException: $message';
}

/// Đọc + kiểm header 16 byte, trả về count. Ném exception nếu sai format.
int readIconizeHeader(Uint8List bytes, String label) {
  if (bytes.length < 16) {
    throw IconizeBinaryFormatException('$label: file cụt (${bytes.length}B)');
  }
  final magic = ascii.decode(bytes.sublist(0, 8), allowInvalid: true);
  if (magic != iconizeBinaryMagic) {
    throw IconizeBinaryFormatException('$label: magic "$magic" ≠ ICNB0001');
  }
  final bd = ByteData.sublistView(bytes);
  final version = bd.getUint32(8, Endian.little);
  if (version != iconizeBinaryVersion) {
    throw IconizeBinaryFormatException('$label: version $version chưa hỗ trợ');
  }
  return bd.getUint32(12, Endian.little);
}

/// So sánh byte-order hai chuỗi UTF-8 (khớp sort của build tool Python).
int _compareBytes(Uint8List a, Uint8List b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final d = a[i] - b[i];
    if (d != 0) return d;
  }
  return a.length - b.length;
}

/// Base chung cho 2 bảng dạng `offsets[count] + blob record (u16 len + key)`.
abstract class _SortedKeyTable {
  final Uint8List _bytes;
  final ByteData _bd;
  final int count;
  final int _blobStart;

  _SortedKeyTable(this._bytes, String label)
      : _bd = ByteData.sublistView(_bytes),
        count = readIconizeHeader(_bytes, label),
        _blobStart = 16 + 4 * readIconizeHeader(_bytes, label);

  /// Binary search theo key UTF-8; trả offset tuyệt đối của payload
  /// (ngay sau key) hoặc -1 nếu không có.
  int _find(String key) {
    final target = Uint8List.fromList(utf8.encode(key));
    var lo = 0;
    var hi = count - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final rec = _blobStart + _bd.getUint32(16 + 4 * mid, Endian.little);
      final klen = _bd.getUint16(rec, Endian.little);
      final k = Uint8List.sublistView(_bytes, rec + 2, rec + 2 + klen);
      final cmp = _compareBytes(k, target);
      if (cmp == 0) return rec + 2 + klen;
      if (cmp < 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -1;
  }
}

/// Một dòng tra cứu concreteness: điểm + từ loại trội.
class ConcretenessEntry {
  /// Thang 1.0–5.0 (lưu u8 = điểm × 10).
  final double concreteness;
  final IconizePos pos;
  const ConcretenessEntry(this.concreteness, this.pos);
}

/// concreteness.bin — word → (Conc.M, Dom_Pos). Chỉ chứa từ ≥ 3.5.
class ConcretenessTable extends _SortedKeyTable {
  ConcretenessTable(Uint8List bytes) : super(bytes, 'concreteness.bin');

  ConcretenessEntry? lookup(String wordLower) {
    final at = _find(wordLower);
    if (at < 0) return null;
    final conc10 = _bd.getUint8(at);
    final posCode = _bd.getUint8(at + 1);
    final pos = posCode < IconizePos.values.length
        ? IconizePos.values[posCode]
        : IconizePos.other;
    return ConcretenessEntry(conc10 / 10.0, pos);
  }

  bool contains(String wordLower) => _find(wordLower) >= 0;
}

/// icon_index.bin — "lemma|POS" → iconId (chỉ số TOC trong icons_bundle.bin).
class IconIndexTable extends _SortedKeyTable {
  IconIndexTable(Uint8List bytes) : super(bytes, 'icon_index.bin');

  int? lookup(String lemmaPosKey) {
    final at = _find(lemmaPosKey);
    if (at < 0) return null;
    return _bd.getUint16(at, Endian.little);
  }
}

/// icons_bundle.bin — TOC cố định 14 byte/entry + name blob + data blob.
class IconsBundle {
  final Uint8List _bytes;
  final ByteData _bd;
  final int count;
  final int _nameBlobStart;
  final int _dataBlobStart;

  IconsBundle._(this._bytes, this._bd, this.count, this._nameBlobStart,
      this._dataBlobStart);

  factory IconsBundle(Uint8List bytes) {
    final count = readIconizeHeader(bytes, 'icons_bundle.bin');
    final bd = ByteData.sublistView(bytes);
    final nameBlobStart = 16 + 14 * count;
    var totalNames = 0;
    for (var i = 0; i < count; i++) {
      totalNames += bd.getUint16(16 + 14 * i + 12, Endian.little);
    }
    return IconsBundle._(
        bytes, bd, count, nameBlobStart, nameBlobStart + totalNames);
  }

  /// Tên icon (chuỗi codepoint Twemoji, vd "1f408") theo iconId.
  String name(int iconId) {
    _checkId(iconId);
    final base = 16 + 14 * iconId;
    final nameOff = _bd.getUint32(base + 8, Endian.little);
    final nameLen = _bd.getUint16(base + 12, Endian.little);
    final at = _nameBlobStart + nameOff;
    return ascii.decode(_bytes.sublist(at, at + nameLen));
  }

  /// Bytes SVG thô theo iconId (view, không copy).
  Uint8List svgBytes(int iconId) {
    _checkId(iconId);
    final base = 16 + 14 * iconId;
    final dataOff = _bd.getUint32(base, Endian.little);
    final dataLen = _bd.getUint32(base + 4, Endian.little);
    final at = _dataBlobStart + dataOff;
    if (at + dataLen > _bytes.length) {
      throw const IconizeBinaryFormatException(
          'icons_bundle.bin: TOC trỏ ra ngoài file');
    }
    return Uint8List.sublistView(_bytes, at, at + dataLen);
  }

  void _checkId(int iconId) {
    if (iconId < 0 || iconId >= count) {
      throw IconizeBinaryFormatException(
          'icons_bundle.bin: iconId $iconId ngoài [0,$count)');
    }
  }
}
