// lib/features/dictionary/services/lzo1x.dart
// Giải nén LZO1X thuần Dart — port của `lzo1x_decompress` trong miniLZO
// (Markus Oberhumer, http://www.oberhumer.com/opensource/lzo/).
//
// Tại sao cần: file MDX tạo bởi engine < 2.0 (vd OALD7, Collins Cobuild,
// American Heritage) nén key block / record block bằng LZO (compression
// type = 1). Không có LZO ⇒ những từ điển đó import ra 0 entry và UI chỉ
// hiện "Chưa có từ điển nào" mà không báo lỗi.
//
// An toàn: output buffer được cấp đúng [expectedSize] (MDX luôn ghi kèm
// decompressed size) + mọi lần ghi/đọc đều kiểm tra biên → dữ liệu hỏng
// ném [LzoException] thay vì tràn bộ nhớ. Sau khi giải nén, MDX parser
// đối chiếu tiếp adler32 ⇒ lỗi giải nén sai sẽ bị bắt chứ không sinh
// dữ liệu rác.

import 'dart:typed_data';

/// Lỗi giải nén LZO (dữ liệu hỏng / sai định dạng).
class LzoException implements Exception {
  final String message;
  const LzoException(this.message);

  @override
  String toString() => message;
}

/// Bộ giải nén LZO1X (dùng 1 lần cho mỗi block).
class Lzo1x {
  static const int _eofFound = -999;

  final Uint8List _buf;
  final Uint8List _out;
  int _ip = 0;
  int _op = 0;
  int _t = 0;
  int _mPos = 0;

  Lzo1x._(this._buf, int expectedSize) : _out = Uint8List(expectedSize);

  /// Giải nén [input] (đã bỏ 8 byte header block của MDX) thành đúng
  /// [expectedSize] byte.
  static Uint8List decompress(Uint8List input, int expectedSize) {
    if (input.isEmpty || expectedSize <= 0) {
      throw const LzoException('LZO: dữ liệu rỗng.');
    }
    return Lzo1x._(input, expectedSize)._run();
  }

  // ═══ primitives (có kiểm tra biên) ═══════════════════════════════════

  int _byte() {
    if (_ip >= _buf.length) {
      throw const LzoException('LZO: dữ liệu đầu vào bị thiếu.');
    }
    return _buf[_ip++];
  }

  int _peek(int offset) {
    if (offset >= _buf.length) {
      throw const LzoException('LZO: dữ liệu đầu vào bị thiếu.');
    }
    return _buf[offset];
  }

  void _put(int value) {
    if (_op >= _out.length) {
      throw const LzoException('LZO: kết quả vượt quá kích thước công bố.');
    }
    _out[_op++] = value;
  }

  void _putFromOut() {
    if (_mPos < 0 || _mPos >= _out.length || _op >= _out.length) {
      throw const LzoException('LZO: con trỏ lùi sau không hợp lệ.');
    }
    _out[_op++] = _out[_mPos++];
  }

  // ═══ state machine ═══════════════════════════════════════════════════

  void _copyFromBuf() {
    do {
      _put(_byte());
    } while (--_t > 0);
  }

  void _copyMatch() {
    _t += 2;
    do {
      _putFromOut();
    } while (--_t > 0);
  }

  void _matchNext() {
    _put(_byte());
    if (_t > 1) {
      _put(_byte());
      if (_t > 2) {
        _put(_byte());
      }
    }
    _t = _byte();
  }

  int _matchDone() {
    _t = _peek(_ip - 2) & 3;
    return _t;
  }

  int _match() {
    for (;;) {
      if (_t >= 64) {
        _mPos = (_op - 1) - ((_t >> 2) & 7) - (_byte() << 3);
        _t = (_t >> 5) - 1;
        _copyMatch();
      } else if (_t >= 32) {
        _t &= 31;
        if (_t == 0) {
          while (_peek(_ip) == 0) {
            _t += 255;
            _ip++;
          }
          _t += 31 + _byte();
        }
        _mPos = (_op - 1) - (_peek(_ip) >> 2) - (_peek(_ip + 1) << 6);
        _ip += 2;
        _copyMatch();
      } else if (_t >= 16) {
        _mPos = _op - ((_t & 8) << 11);
        _t &= 7;
        if (_t == 0) {
          while (_peek(_ip) == 0) {
            _t += 255;
            _ip++;
          }
          _t += 7 + _byte();
        }
        _mPos -= (_peek(_ip) >> 2) + (_peek(_ip + 1) << 6);
        _ip += 2;
        if (_mPos == _op) {
          return _eofFound;
        }
        _mPos -= 0x4000;
        _copyMatch();
      } else {
        _mPos = (_op - 1) - (_t >> 2) - (_byte() << 2);
        _putFromOut();
        _putFromOut();
      }

      if (_matchDone() == 0) {
        return 0;
      }
      _matchNext();
    }
  }

  Uint8List _run() {
    var skipToFirstLiteral = false;

    if (_peek(_ip) > 17) {
      _t = _byte() - 17;
      if (_t < 4) {
        _matchNext();
        final ret = _match();
        if (ret != 0) {
          return _finish(ret);
        }
      } else {
        _copyFromBuf();
        skipToFirstLiteral = true;
      }
    }

    for (;;) {
      if (!skipToFirstLiteral) {
        _t = _byte();
        if (_t >= 16) {
          final ret = _match();
          if (ret != 0) {
            return _finish(ret);
          }
          continue;
        } else if (_t == 0) {
          while (_peek(_ip) == 0) {
            _t += 255;
            _ip++;
          }
          _t += 15 + _byte();
        }
        _t += 3;
        _copyFromBuf();
      } else {
        skipToFirstLiteral = false;
      }

      _t = _byte();
      if (_t < 16) {
        _mPos = _op - (1 + 0x0800);
        _mPos -= _t >> 2;
        _mPos -= _byte() << 2;
        _putFromOut();
        _putFromOut();
        _putFromOut();
        if (_matchDone() == 0) {
          continue;
        }
        _matchNext();
      }

      final ret = _match();
      if (ret != 0) {
        return _finish(ret);
      }
    }
  }

  Uint8List _finish(int ret) {
    if (ret != _eofFound) {
      throw const LzoException('LZO: dữ liệu nén không hợp lệ.');
    }
    if (_op == _out.length) {
      return _out;
    }
    return Uint8List.fromList(_out.sublist(0, _op));
  }
}
