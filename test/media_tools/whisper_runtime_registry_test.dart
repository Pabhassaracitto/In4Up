// test/media_tools/whisper_runtime_registry_test.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — máy bắt cho phần THUẦN của
// `WhisperRuntimeRegistry`: đăng ký bộ chạy app tự cài rồi kiểm tra
// `WhisperCliLocator.resolve()` dùng đúng đường dẫn đó.
//
// Vì sao đáng test: đây là sợi dây duy nhất nối "người dùng bấm Cài" với
// "engine tìm thấy binary". Đứt dây ⇒ người dùng cài xong vẫn nhận
// `Bad state: Khong tim thay whisper binary: whisper-cli.exe` (đúng lỗi audit).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/src/whisper_cli_locator.dart';

/// PE giả tối thiểu: đủ để locator coi là file thật (`lengthSync() > 50 KB`).
/// Nội dung không phải PE hợp lệ ⇒ `probe.scanned == false`, đúng thứ cần cho
/// các ca "file rỗng/hỏng".
File _fakeBinary(String path, {required bool posix}) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(List<int>.filled(60000, 0x4D));
  return file;
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('whisper_registry_test_');
    WhisperRuntimeRegistry.reset();
    WhisperCliLocator.invalidateCache();
  });

  tearDown(() {
    WhisperRuntimeRegistry.reset();
    WhisperCliLocator.invalidateCache();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  final exeName = Platform.isWindows ? 'whisper-cli.exe' : 'whisper-cli';

  group('WhisperRuntimeRegistry', () {
    test('register(binaryPath:) đặt đúng đường dẫn', () {
      WhisperRuntimeRegistry.register(binaryPath: '/tmp/x/whisper-cli');
      expect(WhisperRuntimeRegistry.registeredBinaryPath, '/tmp/x/whisper-cli');
    });

    test('register(binaryPath: "") = xoá đăng ký', () {
      WhisperRuntimeRegistry.register(binaryPath: '/tmp/x/whisper-cli');
      WhisperRuntimeRegistry.register(binaryPath: '');
      expect(WhisperRuntimeRegistry.registeredBinaryPath, isNull);
    });

    test('dllDirs rỗng KHÔNG xoá danh sách đã đăng ký', () {
      WhisperRuntimeRegistry.register(dllDirs: <String>['/tmp/a']);
      expect(WhisperRuntimeRegistry.extraDllDirs, <String>['/tmp/a']);

      // Bootstrap gọi register(dllDirs: const []) trong init() — không được
      // làm mất thư mục DLL vừa đăng ký (nếu mất: 0xC0000135).
      WhisperRuntimeRegistry.register(dllDirs: const <String>[]);
      expect(WhisperRuntimeRegistry.extraDllDirs, <String>['/tmp/a']);
    });

    test('directoryHint lỗi ⇒ hintedDirectory null, không ném', () {
      WhisperRuntimeRegistry.register(
        directoryHint: () => throw StateError('boom'),
      );
      expect(WhisperRuntimeRegistry.hintedDirectory, isNull);
    });

    test('reset() xoá sạch', () {
      WhisperRuntimeRegistry.register(
        binaryPath: '/tmp/x',
        dllDirs: <String>['/tmp/y'],
        directoryHint: () => '/tmp/z',
      );
      WhisperRuntimeRegistry.reset();
      expect(WhisperRuntimeRegistry.registeredBinaryPath, isNull);
      expect(WhisperRuntimeRegistry.extraDllDirs, isEmpty);
      expect(WhisperRuntimeRegistry.hintedDirectory, isNull);
    });
  });

  group('WhisperCliLocator.resolve', () {
    test('dùng binary đã đăng ký và coi là found', () {
      final binary = _fakeBinary('${tmp.path}/runtime/$exeName', posix: true);
      WhisperRuntimeRegistry.register(
        binaryPath: binary.path,
        dllDirs: <String>[binary.parent.path],
      );

      final location = WhisperCliLocator.resolve(forceRefresh: true);
      expect(location.found, isTrue);
      expect(location.binaryPath, binary.path);
      expect(location.binaryDir, binary.parent.path);
      // Đăng ký rỗng lúc trước không được làm mất thư mục DLL.
      expect(location.dllDirs, contains(binary.parent.path));
    });

    test('thư mục gợi ý (app-runtime) được quét', () {
      final dir = Directory('${tmp.path}/whisper_runtime')..createSync();
      final binary = _fakeBinary('${dir.path}/$exeName', posix: true);
      WhisperRuntimeRegistry.register(directoryHint: () => dir.path);

      final location = WhisperCliLocator.resolve(forceRefresh: true);
      expect(location.found, isTrue);
      expect(location.binaryPath, binary.path);
    });

    test('thư mục gợi ý có binary nhưng THIẾU DLL ⇒ vẫn found (probe báo thiếu)',
        () {
      final dir = Directory('${tmp.path}/whisper_runtime')..createSync();
      _fakeBinary('${dir.path}/$exeName', posix: true);
      WhisperRuntimeRegistry.register(directoryHint: () => dir.path);

      final location = WhisperCliLocator.resolve(forceRefresh: true);
      expect(location.found, isTrue);
      // File giả không phải PE ⇒ probe.scanned false, KHÔNG được bịa "đủ file".
      expect(location.probe, isNotNull);
      expect(location.probe!.scanned, isFalse);
      expect(location.probe!.isRunnable, isFalse);
    });

    test('file nhỏ hơn ngưỡng (shim/rỗng) bị bỏ qua', () {
      final dir = Directory('${tmp.path}/tiny')..createSync();
      File('${dir.path}/$exeName').writeAsBytesSync(<int>[0x4D, 0x5A]);
      WhisperRuntimeRegistry.register(directoryHint: () => dir.path);

      final location = WhisperCliLocator.resolve(forceRefresh: true);
      // Không được nhận file 2 byte; nếu máy có whisper-cli thật trong PATH thì
      // vẫn có thể found — nên chỉ khẳng định "không trả về file 2 byte này".
      expect(location.binaryPath, isNot('${dir.path}/$exeName'));
    });

    test('childEnvironment gộp thư mục binary vào PATH', () {
      final binary = _fakeBinary('${tmp.path}/rt/$exeName', posix: true);
      WhisperRuntimeRegistry.register(
        binaryPath: binary.path,
        dllDirs: <String>[binary.parent.path],
      );
      final location = WhisperCliLocator.resolve(forceRefresh: true);
      final pathValue = location.childEnvironment['PATH'] ?? '';
      expect(pathValue, contains(binary.parent.path));
    });

    test('searched liệt kê nơi đã tìm khi không thấy', () {
      final emptyDir = Directory('${tmp.path}/empty')..createSync();
      WhisperRuntimeRegistry.register(
        binaryPath: '${emptyDir.path}/${exeName}_nope',
        directoryHint: () => emptyDir.path,
      );
      final location = WhisperCliLocator.resolve(forceRefresh: true);
      // Không khẳng định found==false: máy chạy test có thể có whisper-cli thật.
      expect(location.searched, isNotEmpty);
    });
  });

  group('probeWhisperBinaryOnDisk', () {
    test('file không tồn tại ⇒ không ném, scanned false', () {
      final probe = probeWhisperBinaryOnDisk('${tmp.path}/khong-co.exe');
      expect(probe.scanned, isFalse);
      expect(probe.isRunnable, isFalse);
    });

    test('file rỗng 0 byte ⇒ scanned false (không được coi là đủ file)', () {
      final empty = File('${tmp.path}/empty/whisper-cli.exe')
        ..parent.createSync(recursive: true);
      empty.writeAsBytesSync(<int>[]);
      final probe = probeWhisperBinaryOnDisk(empty.path);
      expect(probe.scanned, isFalse);
    });
  });
}
