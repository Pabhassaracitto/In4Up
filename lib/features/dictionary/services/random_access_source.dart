import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'dict_device_channel.dart';

/// Seekable byte source used by the MDX reader.
///
/// Reads are asynchronous because Android SAF documents are exposed through a
/// native descriptor rather than a Dart [File]. Implementations may return
/// fewer than [count] bytes at EOF; callers that need an exact range should
/// validate the returned length.
abstract interface class RandomAccessSource {
  Future<int> get length;

  Future<void> seek(int offset);

  Future<Uint8List> read(int count);

  Future<void> close();
}

/// A readable source became unavailable (for example, a revoked SAF grant or
/// removed SD card). Keep this distinct from malformed MDX so the UI can offer
/// a reselect action without deleting its already-built SQLite index.
class RandomAccessSourceException implements Exception {
  final String code;
  final String message;

  const RandomAccessSourceException(this.code, this.message);

  bool get needsReselect =>
      code == 'PERMISSION_LOST' || code == 'SOURCE_UNAVAILABLE';

  @override
  String toString() => message;
}

/// Random-access reader for ordinary filesystem files (desktop/iOS and staged
/// imports). The open handle is seekable and only the requested range is read.
class FileRandomAccessSource implements RandomAccessSource {
  final RandomAccessFile _file;
  final int _length;
  int _position = 0;
  bool _closed = false;

  FileRandomAccessSource._(this._file, this._length);

  static Future<FileRandomAccessSource> open(String path) async {
    try {
      final file = await File(path).open(mode: FileMode.read);
      return FileRandomAccessSource._(file, await file.length());
    } on FileSystemException catch (error) {
      throw RandomAccessSourceException('SOURCE_UNAVAILABLE', error.message);
    }
  }

  @override
  Future<int> get length async => _length;

  @override
  Future<void> seek(int offset) async {
    _ensureOpen();
    if (offset < 0 || offset > _length) {
      throw RangeError.range(offset, 0, _length, 'offset');
    }
    await _file.setPosition(offset);
    _position = offset;
  }

  @override
  Future<Uint8List> read(int count) async {
    _ensureOpen();
    if (count < 0) throw RangeError.value(count, 'count');
    if (count == 0 || _position >= _length) return Uint8List(0);
    final available = _length - _position;
    final bytes = await _file.read(count < available ? count : available);
    _position += bytes.length;
    return bytes;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _file.close();
  }

  void _ensureOpen() {
    if (_closed) {
      throw const RandomAccessSourceException(
        'SOURCE_CLOSED',
        'Random-access source is already closed.',
      );
    }
  }
}

/// Android SAF-backed seekable source.
///
/// Native reads are capped at 64 KiB. A four-page LRU cache avoids repeated
/// MethodChannel calls for nearby parser reads without retaining large MDD
/// documents in Dart memory.
class SafRandomAccessSource implements RandomAccessSource {
  static const int pageSize = 64 * 1024;
  static const int defaultCachePages = 4;

  final String _handle;
  final int _length;
  final int _cachePages;
  final LinkedHashMap<int, Uint8List> _pages = LinkedHashMap();
  int _position = 0;
  bool _closed = false;

  SafRandomAccessSource._(this._handle, this._length, this._cachePages);

  static Future<SafRandomAccessSource> open(
    String documentUri, {
    int cachePages = defaultCachePages,
  }) async {
    if (cachePages < 1) {
      throw ArgumentError.value(cachePages, 'cachePages', 'Must be positive.');
    }
    try {
      final opened = await DictDeviceChannel.openRandomAccess(documentUri);
      return SafRandomAccessSource._(
        opened.id,
        opened.length,
        cachePages,
      );
    } on DictDeviceChannelException catch (error) {
      throw RandomAccessSourceException(error.code, error.message ?? '$error');
    }
  }

  @override
  Future<int> get length async => _length;

  @override
  Future<void> seek(int offset) async {
    _ensureOpen();
    if (offset < 0 || offset > _length) {
      throw RangeError.range(offset, 0, _length, 'offset');
    }
    _position = offset;
  }

  @override
  Future<Uint8List> read(int count) async {
    _ensureOpen();
    if (count < 0) throw RangeError.value(count, 'count');
    if (count == 0 || _position >= _length) return Uint8List(0);

    final wanted = count < _length - _position ? count : _length - _position;
    final output = Uint8List(wanted);
    var written = 0;
    while (written < wanted) {
      final pageStart = (_position ~/ pageSize) * pageSize;
      final page = await _loadPage(pageStart);
      final withinPage = _position - pageStart;
      final available = page.length - withinPage;
      if (available <= 0) break;
      final amount = available < wanted - written ? available : wanted - written;
      output.setRange(written, written + amount, page, withinPage);
      written += amount;
      _position += amount;
    }
    if (written == wanted) return output;
    return Uint8List.sublistView(output, 0, written);
  }

  Future<Uint8List> _loadPage(int offset) async {
    final cached = _pages.remove(offset);
    if (cached != null) {
      _pages[offset] = cached;
      return cached;
    }
    final count = (_length - offset) < pageSize ? _length - offset : pageSize;
    late final Uint8List bytes;
    try {
      bytes = await DictDeviceChannel.readRandomAccess(
        _handle,
        offset: offset,
        count: count,
      );
    } on DictDeviceChannelException catch (error) {
      throw RandomAccessSourceException(error.code, error.message ?? '$error');
    }
    if (bytes.length != count) {
      throw const RandomAccessSourceException(
        'SOURCE_UNAVAILABLE',
        'The selected dictionary file was shortened or is no longer readable.',
      );
    }
    _pages[offset] = bytes;
    while (_pages.length > _cachePages) {
      _pages.remove(_pages.keys.first);
    }
    return bytes;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pages.clear();
    await DictDeviceChannel.closeRandomAccess(_handle);
  }

  void _ensureOpen() {
    if (_closed) {
      throw const RandomAccessSourceException(
        'SOURCE_CLOSED',
        'Random-access source is already closed.',
      );
    }
  }
}

/// Read a fixed range from [offset], allowing a short result only when the
/// source itself reaches EOF. This helper is deliberately generic so parser
/// tests can supply an in-memory source without platform plugins.
extension RandomAccessSourceRange on RandomAccessSource {
  Future<Uint8List> readAt(int offset, int count) async {
    await seek(offset);
    return read(count);
  }
}
