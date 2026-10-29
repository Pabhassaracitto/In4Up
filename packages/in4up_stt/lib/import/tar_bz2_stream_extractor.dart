// Giải nén `.tar.bz2` **theo luồng** — không nạp cả archive vào RAM.
//
// PARAKEET-002 (app bị văng khi import Parakeet): bản cũ trong
// `SherpaModelManager._extractTarBz2` làm
//
//   final raw = await File(path).readAsBytes();      // 487MB  → RAM
//   final tarBytes = BZip2Decoder().decodeBytes(raw); // 670MB  → RAM
//   final archive = TarDecoder().decodeBytes(tarBytes); // + metadata
//
// ⇒ đỉnh bộ nhớ > 1.1GB chỉ để giải nén. Trên máy 4–6GB, Android kill tiến
// trình giữa lúc giải nén (người dùng thấy "app tự văng một chặng sau khi bấm
// Import"). Whisper large (~1GB) cũng đi cùng đường này.
//
// Cách làm ở đây:
// - đọc archive bằng [`InputFileStream`] (buffer ~64KB, đọc lười từ đĩa);
// - bơm từng khối bz2 đã giải nén vào một [`OutputStream`] tự viết, nó phân
//   tích header tar 512 byte rồi **ghi thẳng nội dung file ra đĩa**;
// - bộ nhớ tối đa ≈ kích thước một khối bz2 (≤ ~900KB) + buffer 64KB.
//
// Chạy được trong isolate (xem `SherpaModelManager._extractTarBz2`) để không
// treo UI trong lúc giải nén vài trăm MB.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Lỗi giải nén có thông điệp đọc được (không phải crash native).
class TarBz2ExtractException implements Exception {
  final String message;
  const TarBz2ExtractException(this.message);
  @override
  String toString() => 'TarBz2ExtractException: $message';
}

/// Kết quả một lần giải nén.
class TarBz2ExtractReport {
  /// Số file đã ghi ra đĩa.
  final int files;

  /// Tổng byte đã ghi (chưa tính phần padding của tar).
  final int bytesWritten;

  /// Tên file (đường dẫn tương đối) — dùng cho log/test.
  final List<String> written;

  const TarBz2ExtractReport({
    required this.files,
    required this.bytesWritten,
    required this.written,
  });

  @override
  String toString() =>
      'TarBz2ExtractReport(files: $files, bytes: $bytesWritten)';
}

const int _kTarBlockSize = 512;

/// Giải nén [archivePath] (`.tar.bz2`) vào [destDir] theo luồng.
///
/// Chỉ ghi các entry nằm TRONG [destDir] (chặn `../` và đường dẫn tuyệt đối).
/// Trả về thống kê; ném [TarBz2ExtractException] khi archive hỏng/không phải
/// bz2.
TarBz2ExtractReport extractTarBz2ToDirectorySync(
  String archivePath,
  String destDir,
) {
  final archiveFile = File(archivePath);
  if (!archiveFile.existsSync()) {
    throw const TarBz2ExtractException('Không tìm thấy archive');
  }
  final dest = Directory(destDir);
  if (!dest.existsSync()) dest.createSync(recursive: true);

  // 64KB cache: bộ giải bz2 đọc từng byte, cache nhỏ (mặc định 1KB) sẽ
  // khiến syscall dày đặc trên archive vài trăm MB.
  final input = InputFileStream(archivePath, bufferSize: 1 << 16);
  final sink = _TarExtractingSink(dest.path);
  try {
    final ok = BZip2Decoder().decodeStream(input, sink);
    if (!ok) {
      throw const TarBz2ExtractException(
        'File không phải bzip2 hợp lệ (sai chữ ký "BZh")',
      );
    }
    sink.finish();
    final report = sink.report;
    if (report.files == 0) {
      throw const TarBz2ExtractException(
        'Giải nén xong nhưng không có file nào — archive rỗng hoặc hỏng',
      );
    }
    return report;
  } finally {
    try {
      input.closeSync();
    } catch (_) {}
    sink.dispose();
  }
}

enum _State {
  /// Đang chờ đủ 512 byte header tar.
  header,

  /// Đang ghi nội dung của file hiện tại.
  content,

  /// Bỏ phần padding cho đủ bội số 512.
  padding,

  /// Đã gặp 2 block 0 → hết archive.
  done,
}

/// `OutputStream` nhận dữ liệu tar đã giải nén và ghi file ngay xuống đĩa.
class _TarExtractingSink extends OutputStream {
  static const int _chunkSize = 64 * 1024;

  final String destDir;
  final Uint8List _chunk = Uint8List(_chunkSize);
  final Uint8List _header = Uint8List(_kTarBlockSize);
  int _chunkLen = 0;
  int _headerLen = 0;

  _State _state = _State.header;
  int _remaining = 0;
  int _padRemaining = 0;
  RandomAccessFile? _raf;
  String? _currentRelPath;

  /// Tên file dài (GNU `././@LongLink`, typeflag 'L') hoặc PAX `path=`.
  String? _pendingName;
  BytesBuilder? _metaBuffer;

  int _zeroBlocks = 0;
  int _files = 0;
  int _bytes = 0;
  final List<String> _written = <String>[];

  _TarExtractingSink(this.destDir) : super(byteOrder: ByteOrder.littleEndian);

  TarBz2ExtractReport get report => TarBz2ExtractReport(
        files: _files,
        bytesWritten: _bytes,
        written: List.unmodifiable(_written),
      );

  // ── OutputStream ────────────────────────────────────────────────────────
  @override
  int get length => _bytes;

  @override
  void clear() {
    _chunkLen = 0;
    _headerLen = 0;
    _state = _State.header;
    _remaining = 0;
    _padRemaining = 0;
    _pendingName = null;
    _metaBuffer = null;
    _zeroBlocks = 0;
    _files = 0;
    _bytes = 0;
    _written.clear();
    _closeCurrent();
  }

  @override
  void flush() => _drain();

  @override
  void writeByte(int value) {
    _chunk[_chunkLen++] = value & 0xFF;
    if (_chunkLen == _chunkSize) _drain();
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final total = length ?? bytes.length;
    var offset = 0;
    while (offset < total) {
      final space = _chunkSize - _chunkLen;
      final take = math.min(space, total - offset);
      _chunk.setRange(_chunkLen, _chunkLen + take, bytes, offset);
      _chunkLen += take;
      offset += take;
      if (_chunkLen == _chunkSize) _drain();
    }
  }

  @override
  void writeStream(InputStream stream) {
    const chunk = 1 << 16;
    while (!stream.isEOS) {
      final remaining = stream.length - stream.position;
      if (remaining <= 0) break;
      writeBytes(stream.readBytes(math.min(chunk, remaining)).toUint8List());
    }
  }

  /// Không dùng: sink này ghi thẳng ra đĩa nên không có buffer để trả về.
  /// ([BZip2Decoder.decodeStream] chỉ gọi `writeByte`/`flush`.)
  @override
  Uint8List subset(int start, [int? end]) => throw UnsupportedError(
        '_TarExtractingSink không giữ dữ liệu trong bộ nhớ',
      );

  // ── Vòng xử lý ──────────────────────────────────────────────────────────
  void _drain() {
    if (_chunkLen == 0) return;
    final view = Uint8List.sublistView(_chunk, 0, _chunkLen);
    _chunkLen = 0;
    _consume(view);
  }

  void _consume(Uint8List data) {
    var i = 0;
    while (i < data.length) {
      switch (_state) {
        case _State.done:
          return;
        case _State.header:
          final need = _kTarBlockSize - _headerLen;
          final take = math.min(need, data.length - i);
          _header.setRange(_headerLen, _headerLen + take, data, i);
          _headerLen += take;
          i += take;
          if (_headerLen == _kTarBlockSize) {
            _headerLen = 0;
            _handleHeader(_header);
          }
          break;
        case _State.content:
          final take = math.min(_remaining, data.length - i);
          if (take == 0) return;
          _writeContent(data, i, take);
          i += take;
          _remaining -= take;
          if (_remaining == 0) _finishContent();
          break;
        case _State.padding:
          final take = math.min(_padRemaining, data.length - i);
          _padRemaining -= take;
          i += take;
          if (_padRemaining == 0) _state = _State.header;
          break;
      }
    }
  }

  void _handleHeader(Uint8List block) {
    // Hai block 0 liên tiếp = hết archive.
    var allZero = true;
    for (var i = 0; i < block.length; i++) {
      if (block[i] != 0) {
        allZero = false;
        break;
      }
    }
    if (allZero) {
      if (++_zeroBlocks >= 2) {
        _state = _State.done;
        return;
      }
      return;
    }
    _zeroBlocks = 0;

    final typeFlag = block[156];
    final size = _parseOctal(block, 124, 12);
    var name = _readName(block);

    // Entry metadata (không phải file thật): gom nội dung vào RAM (nhỏ) rồi
    // dùng làm tên/đường dẫn cho entry kế tiếp.
    if (typeFlag == 0x4C /* 'L' GNU long name */ ||
        typeFlag == 0x78 /* 'x' PAX header */ ||
        typeFlag == 0x4B /* 'K' GNU long link */) {
      // Metadata tar thật chỉ vài trăm byte; archive dựng để phá sẽ khai
      // size khổng lồ — chặn để không nạp vào RAM.
      if (size > 1 << 20) {
        _skipContent(size);
        return;
      }
      _metaBuffer = BytesBuilder(copy: true);
      _metaIsPax = typeFlag == 0x78;
      // 'K' là tên đích của symlink — không dùng, nhưng vẫn phải tiêu thụ
      // đúng size byte để không lệch con trỏ tar.
      _metaIsName = typeFlag == 0x4C;
      _currentRelPath = null;
      _remaining = size;
      _padRemaining = _paddingFor(size);
      _state = size > 0 ? _State.content : _State.padding;
      if (size == 0) {
        _metaBuffer = null;
        _state = _State.padding;
      }
      return;
    }

    final pending = _pendingName;
    if (pending != null && pending.isNotEmpty) {
      name = pending;
      _pendingName = null;
    }

    // Thư mục.
    if (typeFlag == 0x35 /* '5' */ || name.endsWith('/')) {
      final dir = _resolve(name);
      if (dir != null) Directory(dir).createSync(recursive: true);
      _skipContent(size);
      return;
    }

    // Link (symbolic/hard) — không cần cho model, chỉ bỏ nội dung.
    if (typeFlag == 0x32 /* '2' */ || typeFlag == 0x31 /* '1' */) {
      _skipContent(size);
      return;
    }

    // File thường ('0' hoặc NUL).
    final relPath = _resolve(name);
    if (relPath == null) {
      _skipContent(size);
      return;
    }
    if (size == 0) {
      final f = File(relPath);
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(const <int>[]);
      _files++;
      _written.add(relPath);
      _state = _State.padding;
      _padRemaining = 0;
      return;
    }

    final out = File(relPath);
    out.parent.createSync(recursive: true);
    if (out.existsSync()) {
      try {
        out.deleteSync();
      } catch (_) {}
    }
    _currentRelPath = relPath;
    _raf = out.openSync(mode: FileMode.writeOnly);
    _remaining = size;
    // Padding sau nội dung phải tính Ở ĐÂY: nếu quên, con trỏ tar lệch
    // (size % 512) byte và mọi header sau đó bị đọc sai — đúng lỗi mà mô
    // phỏng phát hiện (file sau bị đặt tên rác).
    _padRemaining = _paddingFor(size);
    _state = _State.content;
  }

  bool _metaIsName = true;
  bool _metaIsPax = false;

  int _paddingFor(int size) => (size % _kTarBlockSize == 0)
      ? 0
      : _kTarBlockSize - (size % _kTarBlockSize);

  void _skipContent(int size) {
    _remaining = size;
    _padRemaining = _paddingFor(size);
    _state = size > 0 ? _State.content : _State.padding;
    _currentRelPath = null;
    _metaBuffer = null;
    if (size == 0) _state = _State.padding;
  }

  void _writeContent(Uint8List data, int offset, int take) {
    final meta = _metaBuffer;
    if (meta != null) {
      meta.add(Uint8List.sublistView(data, offset, offset + take));
      return;
    }
    final raf = _raf;
    if (raf == null) return;
    raf.writeFromSync(data, offset, offset + take);
    _bytes += take;
  }

  void _finishContent() {
    final meta = _metaBuffer;
    if (meta != null) {
      final bytes = meta.takeBytes();
      _metaBuffer = null;
      if (_metaIsPax) {
        final paxName = _paxPath(bytes);
        if (paxName != null) _pendingName = paxName;
      } else if (_metaIsName) {
        // GNU longname là chuỗi kết thúc bằng NUL — phải cắt tại NUL đầu
        // tiên, không thì `File()` ném "embedded null byte" và cả lần
        // import hỏng (tar mặc định của GNU tar dùng kiểu này).
        _pendingName = _cstringFrom(bytes);
      }
      _state = _paddingEndState();
      return;
    }
    _closeCurrent();
    _state = _paddingEndState();
  }

  _State _paddingEndState() =>
      _padRemaining > 0 ? _State.padding : _State.header;

  void _closeCurrent() {
    final raf = _raf;
    _raf = null;
    if (raf != null) {
      try {
        raf.closeSync();
      } catch (_) {}
      final path = _currentRelPath;
      if (path != null) {
        _files++;
        _written.add(path);
      }
    }
    _currentRelPath = null;
  }

  /// Kết thúc archive: đóng file, giữ phần còn lại (không nạp thêm).
  void finish() {
    _drain();
    _closeCurrent();
  }

  void dispose() {
    _closeCurrent();
    _chunkLen = 0;
    _state = _State.done;
  }

  // ── Tiện ích tar ────────────────────────────────────────────────────────
  static int _parseOctal(Uint8List b, int offset, int length) {
    var value = 0;
    for (var i = offset; i < offset + length; i++) {
      final c = b[i];
      if (c == 0 || c == 0x20) continue;
      if (c < 0x30 || c > 0x37) continue;
      value = (value << 3) + (c - 0x30);
    }
    return value;
  }

  static String _readName(Uint8List block) {
    var name = _readCString(block, 0, 100);
    // USTAR: prefix (345..500) đứng trước tên.
    final prefix = _readCString(block, 345, 155);
    if (prefix.isNotEmpty) name = '$prefix/$name';
    return name;
  }

  static String _readCString(Uint8List b, int offset, int length) {
    final end = offset + length;
    var stop = offset;
    while (stop < end && b[stop] != 0) {
      stop++;
    }
    if (stop == offset) return '';
    return utf8.decode(
      Uint8List.sublistView(b, offset, stop),
      allowMalformed: true,
    );
  }

  /// Giải mã chuỗi UTF-8 kết thúc bằng NUL (bỏ cả NUL và khoảng trắng cuối).
  static String _cstringFrom(Uint8List bytes) {
    var end = bytes.length;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        end = i;
        break;
      }
    }
    if (end <= 0) return '';
    return utf8.decode(
      Uint8List.sublistView(bytes, 0, end),
      allowMalformed: true,
    ).trim();
  }

  static String? _paxPath(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    for (final line in text.split('\n')) {
      if (line.startsWith('path=')) return line.substring(5);
      final match = RegExp(r'^\d+ path=(.*)$').firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Đổi tên trong archive thành đường dẫn tuyệt đối AN TOÀN bên trong
  /// [destDir]; trả `null` khi tên rỗng hoặc cố thoát ra ngoài (`../`, `/…`).
  String? _resolve(String rawName) {
    var name = rawName.replaceAll('\\', '/').trim();
    while (name.startsWith('./')) {
      name = name.substring(2);
    }
    if (name.isEmpty) return null;
    if (name.startsWith('/')) return null;
    final parts = name.split('/');
    if (parts.any((seg) => seg == '..')) return null;
    final sanitized = parts.where((seg) => seg.isNotEmpty && seg != '.').join('/');
    if (sanitized.isEmpty) return null;
    return '$destDir${Platform.pathSeparator}'
        '${sanitized.replaceAll('/', Platform.pathSeparator)}';
  }
}
