// PARAKEET-002 — giải nén `.tar.bz2` theo luồng (không nạp cả archive vào RAM).
//
// Bối cảnh: import Parakeet (`sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8`,
// ~487MB nén / ~670MB sau giải nén) làm app bị Android kill "một chặng" sau
// khi import. Nguyên nhân: `_extractTarBz2` cũ làm
//
//   readAsBytes()              // 487MB vào RAM
//   BZip2Decoder().decodeBytes // +670MB
//   TarDecoder().decodeBytes   // + metadata
//
// ⇒ đỉnh > 1.1GB. Bản mới (`extractTarBz2ToDirectorySync`) đọc archive bằng
// `InputFileStream`, bơm từng khối đã giải nén vào một `OutputStream` tự viết,
// sink này ghi file ngay xuống đĩa.
//
// Test khoá lại ĐÚNG những chỗ dễ sai của bộ phân tích tar tự viết:
// - padding 512 byte sau mỗi file (lệch 1 lần là mọi header sau đó thành rác);
// - file size 0, file đúng bội số 512, file đi qua ranh giới buffer 64KB;
// - tên dài > 100 ký tự: GNU `././@LongLink` (typeflag 'L') và PAX 'x';
// - chặn `../` (path traversal) và đường dẫn tuyệt đối;
// - archive không phải bz2 / rỗng → ném lỗi có thông điệp, không crash.
//
// Fixture dựng tại chỗ (header tar viết tay + `BZip2Encoder` của package
// `archive`) nên test offline, không cần file mẫu và không phụ thuộc việc
// `TarEncoder` có hỗ trợ longname hay không (nó không — nó chỉ ghi
// `././@LongLink` như một file thường).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/import/tar_bz2_stream_extractor.dart';

const int _blk = 512;

/// Header tar 512 byte (USTAR) với checksum tính đúng chuẩn.
Uint8List tarHeader(
  String name,
  int size, {
  String type = '0',
  String linkName = '',
}) {
  final header = Uint8List(_blk);
  void put(int offset, String value, int width) {
    final bytes = utf8.encode(value);
    final count = bytes.length < width ? bytes.length : width;
    header.setRange(offset, offset + count, bytes);
  }

  put(0, name, 100); // name
  put(100, '0000644\x00', 8); // mode
  put(108, '0000000\x00', 8); // uid
  put(116, '0000000\x00', 8); // gid
  put(124, '${size.toRadixString(8).padLeft(11, '0')}\x00', 12); // size
  put(136, '00000000000\x00', 12); // mtime
  header.fillRange(148, 156, 0x20); // checksum placeholder = spaces
  put(156, type, 1);
  put(157, linkName, 100);
  put(257, 'ustar\x00', 6); // magic
  put(263, '00', 2); // version

  var sum = 0;
  for (final b in header) {
    sum += b;
  }
  final checksum = sum.toRadixString(8).padLeft(6, '0');
  put(148, checksum, 6);
  header[154] = 0; // NUL
  header[155] = 0x20; // space
  return header;
}

/// Ghi 1 entry (header + nội dung + padding) vào [out].
void addEntry(
  BytesBuilder out,
  String name,
  List<int> data,
  String type, {
  String linkName = '',
}) {
  out.add(tarHeader(name, data.length, type: type, linkName: linkName));
  if (data.isNotEmpty) out.add(data);
  final pad = data.length % _blk == 0 ? 0 : _blk - (data.length % _blk);
  if (pad > 0) out.add(Uint8List(pad));
}

/// Bọc tar bytes thành file `.tar.bz2` thật.
File writeTarBz2(String path, Uint8List tarBytes) {
  final bz2 = BZip2Encoder().encodeBytes(tarBytes);
  return File(path)..writeAsBytesSync(bz2);
}

/// Record PAX đúng chuẩn: `"<len> key=value\n"`, trong đó `len` là độ dài
/// TOÀN BỘ record (tự quy chiếu) nên phải tính lặp cho tới khi ổn định.
String paxRecord(String key, String value) {
  final body = '$key=$value\n';
  var len = body.length + 2;
  while (true) {
    final candidate = '$len $body';
    if (candidate.length == len) return candidate;
    len = candidate.length;
  }
}

/// Kết thúc archive bằng 2 block 0 (đúng chuẩn tar).
void finishTar(BytesBuilder out) => out.add(Uint8List(_blk * 2));

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('in4up_tarbz2_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('giải nén đúng nội dung (file 0 byte, bội 512, > 64KB)', () {
    // 300KB → đi qua nhiều lần drain 64KB của sink; 70000 lẻ → kiểm padding;
    // 512/1024 → size % 512 == 0 (padding 0, dễ lệch con trỏ nếu tính sai).
    final mid = List<int>.generate(300000, (i) => (i * 7) % 256);
    final big = List<int>.generate(70000, (i) => i % 251);
    final source = <(String, List<int>)>[
      ('model/tokens.txt', utf8.encode('a 1\nb 2\n')),
      ('model/encoder.int8.onnx', mid),
      ('model/decoder.int8.onnx', big),
      ('model/joiner.int8.onnx', List<int>.filled(512, 9)),
      ('model/bpe.vocab', List<int>.filled(1024, 3)),
      ('model/empty.txt', const <int>[]),
    ];
    final out = BytesBuilder(copy: true);
    for (final (name, data) in source) {
      addEntry(out, name, data, '0');
    }
    finishTar(out);
    final archivePath =
        writeTarBz2('${tmp.path}/model.tar.bz2', out.takeBytes()).path;
    final dest = '${tmp.path}/out';

    final report = extractTarBz2ToDirectorySync(archivePath, dest);

    expect(report.files, source.length);
    expect(report.bytesWritten,
        source.fold<int>(0, (sum, e) => sum + e.$2.length));
    for (final (name, data) in source) {
      final file = File('$dest/${name.replaceAll('/', Platform.pathSeparator)}');
      expect(file.existsSync(), isTrue, reason: 'thiếu $name');
      expect(file.readAsBytesSync(), equals(data), reason: 'sai nội dung $name');
    }
  });

  test('không lệch con trỏ sau file 0 byte (padding)', () {
    // Đúng thứ tự từng làm lệch 507 byte: file size 0 nằm giữa, mọi file sau
    // bị đọc bằng header rác (mô phỏng thuật toán đã bắt được lỗi này).
    final source = <(String, List<int>)>[
      ('a.txt', utf8.encode('hello')),
      ('empty.bin', const <int>[]),
      ('c.txt', utf8.encode('after empty')),
      ('big.bin', List<int>.filled(5000, 1)),
      ('z.txt', utf8.encode('last')),
    ];
    final out = BytesBuilder(copy: true);
    for (final (name, data) in source) {
      addEntry(out, name, data, '0');
    }
    finishTar(out);
    final archivePath =
        writeTarBz2('${tmp.path}/order.tar.bz2', out.takeBytes()).path;
    final dest = '${tmp.path}/out';

    final report = extractTarBz2ToDirectorySync(archivePath, dest);

    expect(report.files, source.length,
        reason: 'sai số file — nhiều khả năng lệch padding tar');
    expect(File('$dest/c.txt').readAsStringSync(), 'after empty');
    expect(File('$dest/z.txt').readAsStringSync(), 'last');
    expect(File('$dest/big.bin').lengthSync(), 5000);
  });

  test('GNU longname (typeflag L) — tên dài được dùng, không còn NUL', () {
    final longName = 'model/${'n' * 120}.onnx';
    final out = BytesBuilder(copy: true);
    // '././@LongLink' mang tên thật (kết thúc NUL như GNU tar), rồi entry thật
    // với tên bị cắt 100 ký tự.
    addEntry(out, '././@LongLink', utf8.encode('$longName\u0000'), 'L');
    addEntry(out, longName.substring(0, 100), List<int>.filled(64, 7), '0');
    finishTar(out);
    final archivePath =
        writeTarBz2('${tmp.path}/gnu.tar.bz2', out.takeBytes()).path;
    final dest = '${tmp.path}/out';

    final report = extractTarBz2ToDirectorySync(archivePath, dest);

    expect(report.files, 1);
    final written =
        File('$dest/${longName.replaceAll('/', Platform.pathSeparator)}');
    expect(written.existsSync(), isTrue);
    expect(written.lengthSync(), 64);
    expect(written.path.contains('\u0000'), isFalse);
  });

  test('PAX header (typeflag x) — path= quyết định tên file', () {
    final longName = 'model/${'p' * 130}.onnx';
    final paxBytes = utf8.encode(paxRecord('path', longName));

    final out = BytesBuilder(copy: true);
    addEntry(out, 'PaxHeaders/model', paxBytes, 'x');
    addEntry(out, longName.substring(0, 100), List<int>.filled(32, 5), '0');
    finishTar(out);
    final archivePath =
        writeTarBz2('${tmp.path}/pax.tar.bz2', out.takeBytes()).path;
    final dest = '${tmp.path}/out';

    final report = extractTarBz2ToDirectorySync(archivePath, dest);

    expect(report.files, 1);
    expect(
      File('$dest/${longName.replaceAll('/', Platform.pathSeparator)}')
          .existsSync(),
      isTrue,
    );
  });

  test('chặn path traversal: không ghi ra ngoài destDir', () {
    final out = BytesBuilder(copy: true);
    addEntry(out, 'model/ok.txt', utf8.encode('safe'), '0');
    addEntry(out, '../escape.txt', utf8.encode('pwned'), '0');
    addEntry(out, '/in4up_traversal_probe.txt', utf8.encode('pwned'), '0');
    finishTar(out);
    final archivePath =
        writeTarBz2('${tmp.path}/evil.tar.bz2', out.takeBytes()).path;
    final dest = '${tmp.path}/out';

    final report = extractTarBz2ToDirectorySync(archivePath, dest);

    expect(report.files, 1);
    expect(report.written.single.endsWith('ok.txt'), isTrue);
    expect(File('${tmp.path}/escape.txt').existsSync(), isFalse);
    expect(File('/in4up_traversal_probe.txt').existsSync(), isFalse);
  });

  test('thư mục (typeflag 5) và symlink không làm hỏng các file sau', () {
    final out = BytesBuilder(copy: true);
    addEntry(out, 'model/', const <int>[], '5');
    addEntry(out, 'model/first.txt', utf8.encode('1'), '0');
    addEntry(out, 'model/link', const <int>[], '2', linkName: 'first.txt');
    addEntry(out, 'model/second.txt', utf8.encode('2'), '0');
    finishTar(out);
    final archivePath =
        writeTarBz2('${tmp.path}/dirs.tar.bz2', out.takeBytes()).path;
    final dest = '${tmp.path}/out';

    final report = extractTarBz2ToDirectorySync(archivePath, dest);

    expect(report.files, 2);
    expect(File('$dest/model/first.txt').readAsStringSync(), '1');
    expect(File('$dest/model/second.txt').readAsStringSync(), '2');
    expect(Directory('$dest/model').existsSync(), isTrue);
  });

  test('archive THẬT (GNU tar --format=pax) giải nén đúng', () {
    // Fixture nhỏ tạo bằng `tar cjf --format=pax` (1140 byte) — khoá lại hành
    // vi trên archive do GNU tar sinh ra, không phụ thuộc encoder của package
    // `archive` như các test dựng tại chỗ ở trên.
    final fixture =
        File('test/fixtures/asr_model_sample.tar.bz2');
    expect(fixture.existsSync(), isTrue,
        reason: 'thiếu fixture — test phải chạy từ thư mục gốc repo');
    final dest = '${tmp.path}/out';

    final report = extractTarBz2ToDirectorySync(fixture.path, dest);

    expect(report.files, 3); // tokens.txt + encoder + file tên dài
    expect(File('$dest/model/tokens.txt').readAsStringSync(), 'a 1\nb 2\n');
    expect(
      File('$dest/model/encoder.int8.onnx').readAsBytesSync(),
      equals(List<int>.generate(1500, (i) => (i * 7) % 256)),
    );
    final longFile = File('$dest/model/${'l' * 140}.onnx');
    expect(longFile.existsSync(), isTrue);
    expect(longFile.readAsBytesSync(), equals(List<int>.generate(100, (i) => i)));
  });

  test('archive không phải bz2 → ném TarBz2ExtractException', () {
    final notBz2 = File('${tmp.path}/fake.tar.bz2')
      ..writeAsBytesSync(List<int>.filled(1024, 65)); // 'A' * 1024

    expect(
      () => extractTarBz2ToDirectorySync(notBz2.path, '${tmp.path}/out'),
      throwsA(isA<TarBz2ExtractException>()),
    );
  });

  test('archive thiếu → ném TarBz2ExtractException', () {
    expect(
      () => extractTarBz2ToDirectorySync(
          '${tmp.path}/missing.tar.bz2', '${tmp.path}/out'),
      throwsA(isA<TarBz2ExtractException>()),
    );
  });

  test('archive rỗng (0 entry) → ném lỗi, không im lặng', () {
    final out = BytesBuilder(copy: true);
    finishTar(out);
    final archivePath =
        writeTarBz2('${tmp.path}/empty.tar.bz2', out.takeBytes()).path;

    expect(
      () => extractTarBz2ToDirectorySync(archivePath, '${tmp.path}/out'),
      throwsA(isA<TarBz2ExtractException>()),
    );
  });
}
