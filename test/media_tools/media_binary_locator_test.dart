// test/media_tools/media_binary_locator_test.dart
//
// AVTOOL-001 (PLAN-046 P0) — máy bắt cho việc TÌM BINARY FFmpeg.
//
// Đây là chỗ dễ gây "app không làm gì cả" trên desktop: người dùng đã tải
// FFmpeg nhưng locator vẫn trả `ffmpeg.exe` trần ⇒ Process ném lỗi ⇒ màn hình
// báo "Xuất thất bại". Thứ tự ưu tiên vì thế phải được kiểm bằng file THẬT
// trong thư mục tạm, không phải bằng niềm tin.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/src/ffmpeg_binary_locator.dart';

void main() {
  late Directory temp;
  late String exeName;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('in4up_locator_test');
    exeName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
  });

  tearDown(() async {
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } catch (_) {}
  });

  test('binary đã đăng ký (app tự tải) thắng mọi nguồn khác', () async {
    final registered = File('${temp.path}/$exeName');
    await registered.writeAsBytes(const [1, 2, 3]);
    final hint = Directory('${temp.path}/khac')..createSync();
    expect(
      resolveFfmpegBinaryPath(
        registeredPath: registered.path,
        hintPath: hint.path,
      ),
      registered.path,
    );
  });

  test('đăng ký trỏ file không tồn tại ⇒ bỏ qua, dùng gợi ý', () async {
    final hintDir = Directory('${temp.path}/bin')..createSync();
    final hinted = File('${hintDir.path}${Platform.pathSeparator}$exeName');
    await hinted.writeAsBytes(const [1]);

    expect(
      resolveFfmpegBinaryPath(
        registeredPath: '${temp.path}/khong-ton-tai.exe',
        hintPath: hintDir.path,
      ),
      hinted.path,
    );
  });

  test('gợi ý là ĐƯỜNG DẪN FILE cũng được nhận', () async {
    final file = File('${temp.path}/$exeName');
    await file.writeAsBytes(const [1]);
    expect(
      resolveFfmpegBinaryPath(hintPath: file.path),
      file.path,
    );
  });

  test('không có gì ⇒ trả tên trần để PATH phân giải (không ném)', () {
    final resolved = resolveFfmpegBinaryPath();
    expect(
      resolved,
      anyOf(equals('ffmpeg'), equals('ffmpeg.exe'), contains('ffmpeg')),
      reason: 'không được trả chuỗi rỗng hay ném lỗi',
    );
    expect(resolved, isNotEmpty);
  });

  test('đường dẫn rỗng được coi như không có', () {
    final resolved = resolveFfmpegBinaryPath(
      registeredPath: '',
      hintPath: '',
    );
    expect(resolved, isNotEmpty);
  });

  test('FfmpegBinaryRegistry: đăng ký rồi đọc lại qua resolve()', () async {
    final file = File('${temp.path}/$exeName');
    await file.writeAsBytes(const [1]);
    FfmpegBinaryRegistry.registeredPath = file.path;
    FfmpegBinaryRegistry.hintProvider = null;
    try {
      expect(FfmpegBinaryRegistry.resolve(), file.path);
    } finally {
      FfmpegBinaryRegistry.registeredPath = null;
    }
  });

  test('hintProvider ném lỗi ⇒ locator vẫn chạy (không làm sập app)', () {
    FfmpegBinaryRegistry.hintProvider = () => throw StateError('boom');
    try {
      expect(FfmpegBinaryRegistry.hint(), isNull);
      expect(FfmpegBinaryRegistry.resolve(), isNotEmpty);
    } finally {
      FfmpegBinaryRegistry.hintProvider = null;
    }
  });
}
