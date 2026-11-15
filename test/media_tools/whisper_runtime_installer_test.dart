// test/media_tools/whisper_runtime_installer_test.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — máy bắt cho phần THUẦN của
// installer: chọn đúng file trong archive + chặn zip-slip + URL nguồn.
//
// Vì sao đáng test: bản release `whisper-bin-x64.zip` chứa cả model mẫu,
// `*.pdb`, `whisper-bench.exe`, `whisper-server.exe`, `parakeet-*.exe`. Nếu
// lấy hết thì tốn ổ đĩa và có thể ghi đè nhầm binary; nếu lấy thiếu
// `whisper.dll` thì người dùng lại gặp `exit -1073741515` — đúng lỗi audit.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/services/whisper_runtime_installer.dart';

void main() {
  group('isRuntimeFile — chỉ lấy file bộ chạy', () {
    test('lấy đủ 6 nhóm file của bộ chạy', () {
      for (final name in <String>[
        'whisper-cli.exe',
        'whisper.dll',
        'ggml.dll',
        'ggml-base.dll',
        'ggml-cpu-haswell.dll',
        'ggml-cpu-sse42.dll',
        'ggml-blas.dll',
        'SDL2.dll',
      ]) {
        expect(
          WhisperRuntimeInstaller.isRuntimeFile(name),
          isTrue,
          reason: '$name phải được lấy',
        );
      }
    });

    test('bỏ model, pdb, các exe khác và DLL lạ', () {
      for (final name in <String>[
        'ggml-tiny.bin',
        'ggml-base.en.bin',
        'for-tests-ggml-tiny.bin',
        'whisper-cli.pdb',
        'whisper-bench.exe',
        'whisper-server.exe',
        'parakeet-cli.exe',
        'cudart64_12.dll',
        'ffmpeg.exe',
      ]) {
        expect(
          WhisperRuntimeInstaller.isRuntimeFile(name),
          isFalse,
          reason: '$name KHÔNG được lấy',
        );
      }
    });

    test('nhận theo basename (entry nằm trong thư mục con)', () {
      expect(
        WhisperRuntimeInstaller.isRuntimeFile(
          'whisper-bin-x64/Release/whisper-cli.exe',
        ),
        isTrue,
      );
      // Entry dùng '\' (zipWindows) phải được nhận diện như '/' .
      expect(
        WhisperRuntimeInstaller.isRuntimeFile(
          'whisper-bin-x64\\Release\\whisper.dll',
        ),
        isTrue,
      );
    });
  });

  group('safeRelativePath — chặn zip-slip', () {
    test('đường dẫn thường được chuẩn hóa', () {
      expect(
        WhisperRuntimeInstaller.safeRelativePath('a/b/whisper.dll'),
        'a/b/whisper.dll',
      );
      expect(
        WhisperRuntimeInstaller.safeRelativePath('./whisper.dll'),
        'whisper.dll',
      );
    });

    test('`..`, ổ đĩa, đường dẫn tuyệt đối bị chặn', () {
      expect(WhisperRuntimeInstaller.safeRelativePath('../evil.dll'), isNull);
      expect(
        WhisperRuntimeInstaller.safeRelativePath('a/../../evil.dll'),
        isNull,
      );
      expect(WhisperRuntimeInstaller.safeRelativePath(r'C:\evil.dll'), isNull);
      expect(WhisperRuntimeInstaller.safeRelativePath('/etc/passwd'), isNull);
      expect(WhisperRuntimeInstaller.safeRelativePath(''), isNull);
    });
  });

  group('nguồn tải', () {
    test('URL trỏ đúng release được ghim + asset x64', () {
      final uri = WhisperRuntimeInstaller.assetUri('whisper-bin-x64.zip');
      expect(uri.host, 'github.com');
      expect(uri.path, contains('ggml-org/whisper.cpp/releases/download'));
      expect(uri.path, endsWith('/whisper-bin-x64.zip'));
      expect(uri.path, contains(WhisperRuntimeInstaller.pinnedTag));
    });

    test('trang release dùng cho nút "Cách khác"', () {
      expect(
        WhisperRuntimeInstaller.releasePageUri().toString(),
        contains('ggml-org/whisper.cpp/releases/tag/'),
      );
    });

    test('luôn có asset x64 trong danh sách thử', () {
      expect(
        WhisperRuntimeInstaller.assetCandidates,
        contains('whisper-bin-x64.zip'),
      );
    });
  });
}
