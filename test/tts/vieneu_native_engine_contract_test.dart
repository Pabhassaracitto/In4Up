// test/tts/vieneu_native_engine_contract_test.dart — BETA-1.29.0 · lane L6
//
// "Máy bắt" cho HỢP ĐỒNG của engine native VieNeu-TTS (audio.cpp + wrapper C):
// engine chỉ thật sự chạy được khi 3 mảnh cùng có mặt — `libvieneu_tts.so`
// (submodule audio.cpp), `libsea_g2p_rs.so` (Rust, jniLibs) và `sea_g2p.bin`
// (từ điển, cạnh model). Test này khoá các bất biến dễ bị merge làm hỏng lại:
//
//   1. VieNeu phát 48 kHz STEREO; hợp đồng FFI của app là MONO float32 ⇒
//      wrapper phải TRỘN KÊNH, không được memcpy thô (mất nửa dữ liệu + phát
//      nhanh gấp đôi).
//   2. Từ điển SEA-G2P phải được truyền khi có mặt; đường dẫn thư viện chỉ
//      override khi người dùng đặt .so cạnh model — mặc định để audio.cpp
//      `dlopen` theo tên (lib nằm trong jniLibs của APK).
//   3. Hai submodule engine phải được khai báo trong `.gitmodules` (gitlink là
//      thứ duy nhất khiến CI tải được mã nguồn audio.cpp / sea-g2p).
//   4. Workflow build engine phải kiểm đủ 3 `.so` trong APK — nếu không, "build
//      xanh" vẫn có thể là APK thiếu engine.
//
// Thuần đọc file — không plugin, không isolate, chạy được trên CI.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// Bỏ dòng comment để source-scan không bắt nhầm chữ nằm trong giải thích.
String _codeOnly(String src) => src
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('VieNeu native engine — hợp đồng build/âm thanh', () {
    final wrapper = _codeOnly(_read('native/tts_vieneu/vieneu_tts.cpp'));

    test('stereo 48 kHz của VieNeu được trộn về mono', () {
      expect(
        wrapper.contains('if (channels > 1)'),
        isTrue,
        reason: 'Thiếu nhánh trộn kênh — PCM stereo sẽ bị cắt nửa và phát 2×',
      );
      expect(
        wrapper.contains('out[i] = acc / static_cast<float>(channels);'),
        isTrue,
        reason: 'Không trộn trung bình các kênh',
      );
      // memcpy thô chỉ còn được phép ở nhánh mono.
      expect(
        wrapper.contains('std::memcpy(out, samples, frames * sizeof(float));'),
        isTrue,
        reason: 'Nhánh mono vẫn phải copy trực tiếp',
      );
      expect(
        RegExp(r'channels\s*>\s*1').hasMatch(wrapper),
        isTrue,
      );
    });

    test('SEA-G2P: truyền từ điển khi có, thư viện chỉ override khi có file', () {
      expect(
        wrapper.contains('const fs::path g2p_dict_path = folder / kG2pDictName;'),
        isTrue,
      );
      expect(
        wrapper.contains('if (file_exists(g2p_dict_path.u8string().c_str()))'),
        isTrue,
        reason: 'Thiếu từ điển thì audio.cpp ném lỗi cần sea_g2p.bin',
      );
      expect(
        wrapper.contains('"vieneu_v3_turbo.g2p_dict_file"'),
        isTrue,
      );
      expect(
        wrapper.contains('if (const char * g2p_lib = find_g2p_library(folder))'),
        isTrue,
        reason:
            'Phải chỉ set g2p_library khi .so nằm cạnh model; còn lại để audio.cpp dlopen theo tên',
      );
    });

    test('hai submodule engine được khai báo trong .gitmodules', () {
      final modules = _read('.gitmodules');
      expect(modules.contains('path = third_party/audio.cpp'), isTrue);
      expect(modules.contains('https://github.com/0xShug0/audio.cpp'), isTrue);
      expect(modules.contains('path = third_party/sea-g2p'), isTrue);
      expect(modules.contains('https://github.com/pnnbao97/sea-g2p'), isTrue);
    });

    test('CMake Android build engine; workflow kiểm đủ 3 .so trong APK', () {
      final cmake = _read('android/app/src/main/cpp/ai/CMakeLists.txt');
      expect(cmake.contains('add_library(vieneu_tts SHARED'), isTrue);
      expect(cmake.contains('native/tts_vieneu/vieneu_tts.cpp'), isTrue);
      expect(cmake.contains('third_party/audio.cpp'), isTrue);
      expect(cmake.contains('AUDIOCPP_MODELS'), isTrue);

      final workflow = _read('.github/workflows/vieneu_engine_build.yml');
      for (final lib in <String>[
        'libvieneu_tts.so',
        'libaudiocpp.so',
        'libsea_g2p_rs.so',
      ]) {
        expect(workflow.contains(lib), isTrue,
            reason: 'Workflow phải xác minh $lib có trong APK');
      }
      expect(workflow.contains('--features capi'), isTrue,
          reason: 'SEA-G2P phải build bằng C ABI (không kéo PyO3)');
      expect(workflow.contains('third_party/sea-g2p/Cargo.toml'), isTrue);
    });
  });
}
