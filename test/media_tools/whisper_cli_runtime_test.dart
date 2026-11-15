// test/media_tools/whisper_cli_runtime_test.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — MÁY BẮT cho lỗi "Tạo mục lục tự
// động" trên Windows:
//
//   a) `Bad state: Khong tim thay whisper binary: whisper-cli.exe`
//   b) `whisper.exe thất bại (exit -1073741515)` + STDOUT/STDERR RỖNG
//      ⇒ 0xC0000135 STATUS_DLL_NOT_FOUND: người dùng chép "4 file" mà bộ đầy
//        đủ là 6 (`whisper-cli.exe`, `whisper.dll`, `ggml.dll`,
//        `ggml-base.dll`, `ggml-cpu-*.dll`, `SDL2.dll`).
//
// Test chạy trên host VM (không cần Windows):
//   1. Dựng PE 64-bit tối thiểu có import table thật (đúng layout NT) rồi đọc
//      lại — chứng minh parser không "đoán" mà đọc đúng cấu trúc.
//   2. Kiểm đủ bộ DLL ⇒ runnable; thiếu `whisper.dll` ⇒ báo đúng tên file
//      (đây chính là ca người dùng gặp: 4 file có, 2 file thiếu).
//   3. `ggml-cpu-haswell.dll` phải được chấp nhận cho import
//      `ggml-cpu*.dll` (bản release build GGML_CPU_ALL_VARIANTS).
//   4. File DLL 0 byte (bản build CI tạo) phải bị coi là thiếu.
//   5. Câu báo lỗi phải nói "6 file" + tên file thiếu; KHÔNG còn câu cũ
//      "Lay file whisper-cli.exe ... Copy whisper-cli.exe + ggml-*.dll"
//      (chính câu này làm người dùng chép thiếu whisper.dll).
//   6. argv CLI pin `-np`, `-bs 1`, `-osrt`, `-of`.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/src/whisper_cli_runtime.dart';

/// Dựng PE 64-bit tối thiểu với 1 section và import table chứa [dlls].
///
/// Layout theo đúng đặc tả PE (DOS header 0x40, PE sig, COFF 20 byte, optional
/// header PE32+ 112 byte + data directories, section table 40 byte/section,
/// rồi tới raw data của section: import descriptors + tên DLL).
Uint8List buildPe({
  required List<String> dlls,
  int machine = 0x8664,
  bool delay = false,
  List<String> delayDlls = const <String>[],
}) {
  const peOffset = 0x80;
  const optionalSize = 240; // PE32+ (112) + 16 dirs * 8 = 240
  const sectionTableAt = peOffset + 24 + optionalSize; // 0x1A8
  const sectionRawAt = sectionTableAt + 40; // dữ liệu section bắt đầu
  const sectionRva = 0x1000;
  const sectionSize = 0x2000;

  // Bố cục trong section:
  //   +0x000: import descriptors (20 byte/cái) + terminator
  //   +0x100: delay descriptors
  //   +0x1000: tên DLL
  final nameBlob = <int>[];

  List<int> descriptorsFor(List<String> names, {required bool isDelay}) {
    final out = <int>[];
    for (final name in names) {
      final rva = sectionRva + 0x1000 + nameBlob.length;
      nameBlob.addAll(<int>[...name.codeUnits, 0]);
      if (isDelay) {
        // IMAGE_DELAYLOAD_DESCRIPTOR: 32 byte, +0 = attributes (bit 0 =
        // dlattrRva), +4 = DllNameRVA.
        out.addAll(<int>[1, rva, 0, 0, 0, 0, 0, 0]);
      } else {
        out.addAll(<int>[0x2000, 0, 0, rva, 0x2000]);
      }
    }
    if (!isDelay) {
      out.addAll(List<int>.filled(20, 0)); // terminator
    }
    return out;
  }

  final importDesc = descriptorsFor(dlls, isDelay: false);
  final delayDesc = delay ? descriptorsFor(delayDlls, isDelay: true) : const <int>[];

  final data = Uint8List(sectionRawAt + sectionSize);
  final view = ByteData.sublistView(data);

  // DOS header
  data[0] = 0x4D;
  data[1] = 0x5A;
  view.setUint32(0x3C, peOffset, Endian.little);

  // PE signature + COFF
  data[peOffset] = 0x50;
  data[peOffset + 1] = 0x45;
  view.setUint16(peOffset + 4, machine, Endian.little);
  view.setUint16(peOffset + 6, 1, Endian.little); // NumberOfSections
  view.setUint16(peOffset + 20, optionalSize, Endian.little);

  // Optional header
  final opt = peOffset + 24;
  view.setUint16(opt, 0x20B, Endian.little); // PE32+
  view.setUint32(opt + 108, 16, Endian.little); // NumberOfRvaAndSizes
  view.setUint32(opt + 112 + 1 * 8, sectionRva, Endian.little); // import
  view.setUint32(opt + 112 + 1 * 8 + 4, importDesc.length, Endian.little);
  if (delay) {
    view.setUint32(opt + 112 + 13 * 8, sectionRva + 0x100, Endian.little);
    view.setUint32(opt + 112 + 13 * 8 + 4, delayDesc.length, Endian.little);
  }

  // Section table
  final sec = sectionTableAt;
  data.setRange(sec, sec + 6, <int>[0x2E, 0x69, 0x64, 0x61, 0x74, 0x61]);
  view.setUint32(sec + 8, sectionSize, Endian.little); // VirtualSize
  view.setUint32(sec + 12, sectionRva, Endian.little); // VirtualAddress
  view.setUint32(sec + 16, sectionSize, Endian.little); // SizeOfRawData
  view.setUint32(sec + 20, sectionRawAt, Endian.little); // PointerToRawData

  // Raw data: descriptors + tên DLL
  var at = sectionRawAt;
  for (final word in importDesc) {
    view.setUint32(at, word, Endian.little);
    at += 4;
  }
  at = sectionRawAt + 0x100;
  for (final word in delayDesc) {
    view.setUint32(at, word, Endian.little);
    at += 4;
  }
  data.setRange(sectionRawAt + 0x1000, sectionRawAt + 0x1000 + nameBlob.length, nameBlob);
  return data;
}

List<PeDirEntry> siblingsFrom(List<String> names, {Map<String, int>? sizes}) =>
    names
        .map((n) => PeDirEntry(name: n, size: sizes?[n] ?? 2 * 1024 * 1024))
        .toList();

const List<String> _fullRuntime = <String>[
  'whisper-cli.exe',
  'whisper.dll',
  'ggml.dll',
  'ggml-base.dll',
  'ggml-cpu-haswell.dll',
  'SDL2.dll',
];

/// Import table thật của `whisper-cli.exe` bản release x64 (rút gọn: đúng các
/// DLL mà app phải có, bỏ DLL hệ thống).
const List<String> _realImports = <String>[
  'KERNEL32.dll',
  'USER32.dll',
  'SHELL32.dll',
  'ADVAPI32.dll',
  'whisper.dll',
  'ggml.dll',
  'ggml-base.dll',
  'ggml-cpu-haswell.dll',
  'SDL2.dll',
];

void main() {
  group('Đọc import table PE (không cần Windows)', () {
    test('PE 64-bit tối thiểu: đọc đúng danh sách DLL', () {
      final bytes = buildPe(dlls: _realImports);
      final info = parsePeImports(bytes);
      expect(info, isNotNull);
      expect(info!.machine, kPeMachineAmd64);
      expect(
        info.imports.map((i) => i.name),
        containsAll(<String>['whisper.dll', 'ggml.dll', 'sdl2.dll']),
      );
    });

    test('file không phải PE ⇒ null (không được đoán "không cần DLL")', () {
      expect(parsePeImports(Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
      expect(
        parsePeImports(Uint8List.fromList(List<int>.filled(200, 0x41))),
        isNull,
      );
    });

    test('PE 32-bit vẫn đọc được + machine = 0x14C', () {
      final bytes = buildPe(dlls: <String>['whisper.dll'], machine: kPeMachineX86);
      final info = parsePeImports(bytes);
      expect(info, isNotNull);
      expect(info!.machine, kPeMachineX86);
    });

    test('delay-import (không chặn) được tách khỏi import thường', () {
      // Ghi đè bằng một PE có cả hai bảng.
      final bytes = buildPe(dlls: <String>['whisper.dll'], delay: true, delayDlls: <String>['extras.dll']);
      final info = parsePeImports(bytes);
      expect(info, isNotNull);
      expect(info!.imports.map((i) => i.name), contains('whisper.dll'));
      expect(info.delayImports.map((i) => i.name), contains('extras.dll'));
    });
  });

  group('Soi bộ file: 4 file có, 2 file thiếu (đúng ca audit 1.29.0)', () {
    test('đủ 6 file ⇒ chạy được', () {
      final image = parsePeImports(buildPe(dlls: _realImports))!;
      final probe = probeWhisperBinary(
        binaryPath: 'C:/app/whisper-cli.exe',
        image: image,
        siblings: siblingsFrom(_fullRuntime),
      );
      expect(probe.isRunnable, isTrue, reason: probe.summary);
      expect(probe.missing, isEmpty);
    });

    test('chép 4 file (thiếu whisper.dll + SDL2.dll) ⇒ báo ĐÚNG tên file', () {
      final image = parsePeImports(buildPe(dlls: _realImports))!;
      final probe = probeWhisperBinary(
        binaryPath: 'C:/app/whisper-cli.exe',
        image: image,
        siblings: siblingsFrom(<String>[
          'whisper-cli.exe',
          'ggml.dll',
          'ggml-base.dll',
          'ggml-cpu-avx2.dll',
        ]),
      );
      expect(probe.isRunnable, isFalse);
      expect(probe.missing.map((i) => i.name), containsAll(
        <String>['whisper.dll', 'sdl2.dll'],
      ));
      // Không báo nhầm DLL hệ thống là thiếu.
      expect(probe.missing.map((i) => i.name), isNot(contains('kernel32.dll')));
    });

    test('ggml-cpu-<variant> thay cho ggml-cpu khác vẫn OK', () {
      final image = parsePeImports(buildPe(dlls: <String>['ggml-cpu-sse42.dll']))!;
      final probe = probeWhisperBinary(
        binaryPath: 'C:/app/whisper-cli.exe',
        image: image,
        siblings: siblingsFrom(<String>['ggml-cpu-haswell.dll']),
      );
      expect(probe.missing, isEmpty);
    });

    test('DLL 0 byte (bản build CI tạo file rỗng) bị coi là thiếu', () {
      final image = parsePeImports(buildPe(dlls: <String>['whisper.dll']))!;
      final probe = probeWhisperBinary(
        binaryPath: 'C:/app/whisper-cli.exe',
        image: image,
        siblings: siblingsFrom(
          <String>['whisper.dll', 'ggml.dll'],
          sizes: <String, int>{'whisper.dll': 0},
        ),
      );
      expect(probe.isRunnable, isFalse);
      expect(probe.emptyDlls.map((e) => e.name), contains('whisper.dll'));
    });

    test('binary 32-bit trong app 64-bit ⇒ ghi chú 0xC000007B', () {
      final image = parsePeImports(
        buildPe(dlls: <String>['whisper.dll'], machine: kPeMachineX86),
      )!;
      final probe = probeWhisperBinary(
        binaryPath: 'C:/app/whisper-cli.exe',
        image: image,
        siblings: siblingsFrom(<String>['whisper.dll']),
      );
      expect(probe.notes.join(' '), contains('0xC000007B'));
      // Sai bitness là lỗi CHẶN: loader trả 0xC000007B trước main() ⇒ không
      // được coi là chạy được, và phải vào machineMismatch để câu báo lỗi nêu.
      expect(probe.machineMismatch.join(' '), contains('32-bit'));
      expect(probe.isRunnable, isFalse);
    });

    test('không đọc được PE ⇒ scanned=false, KHÔNG kết luận thiếu', () {
      final probe = probeWhisperBinary(
        binaryPath: 'C:/app/whisper-cli.exe',
        image: null,
        siblings: siblingsFrom(<String>['whisper-cli.exe']),
      );
      expect(probe.scanned, isFalse);
      expect(probe.missing, isEmpty);
      // Không đọc được PE ⇒ KHÔNG được coi là chạy được (installer sẽ đăng ký
      // một bộ chạy chết rồi người dùng lại gặp 0xC0000135).
      expect(probe.isRunnable, isFalse);
    });
  });

  group('Mã thoát Windows', () {
    test('-1073741515 ⇔ 0xC0000135 ⇔ thiếu DLL', () {
      expect(kStatusDllNotFound, -1073741515);
      expect(describeWindowsExitCode(-1073741515), contains('0xC0000135'));
      expect(describeWindowsExitCode(-1073741515), contains('DLL'));
      expect(isNativeLoadFailure(-1073741515), isTrue);
      expect(isNativeLoadFailure(1), isFalse);
    });

    test('câu báo lỗi nói rõ "6 file" và tên file thiếu', () {
      final image = parsePeImports(buildPe(dlls: _realImports))!;
      final probe = probeWhisperBinary(
        binaryPath: 'C:/app/whisper-cli.exe',
        image: image,
        siblings: siblingsFrom(<String>['ggml.dll']),
      );
      final msg = describeDllLoadFailure(
        probe: probe,
        binaryDir: r'C:\app',
        exitCode: kStatusDllNotFound,
      );
      expect(msg, contains('whisper.dll'));
      expect(msg, contains('6 file'));
      expect(msg, contains(r'C:\app'));
    });

    test('bộ file chuẩn là ĐÚNG 6 nhóm file (không phải 4)', () {
      // Chốt bằng số: tài liệu cũ ghi 4 file (thiếu whisper.dll + SDL2.dll) và
      // đó chính là nguyên nhân exit -1073741515.
      expect(kWindowsWhisperFileSet.length, 6);
      expect(
        kWindowsWhisperFileSet,
        containsAll(<String>[
          'whisper-cli.exe',
          'whisper.dll',
          'ggml.dll',
          'ggml-base.dll',
          'ggml-cpu-*.dll',
          'SDL2.dll',
        ]),
      );
      expect(
        kWindowsWhisperFileSet.where((f) => f.endsWith('.dll')).length,
        5,
        reason: 'phải có 1 exe + 5 DLL',
      );
    });

    test('câu "không tìm thấy binary" KHÔNG còn hướng dẫn chép 4 file', () {
      final msg = describeMissingBinary(
        searched: <String>[r'C:\app', r'C:\app\whisper'],
        suggestedDir: r'C:\app',
      );
      expect(msg, contains('whisper-cli.exe'));
      expect(msg, isNot(contains('Lay file whisper-cli.exe')));
      // Bộ đầy đủ phải được nêu ngay cả ở nhánh "chưa có gì".
      expect(msg, contains('whisper.dll'));
      expect(msg, contains('SDL2.dll'));
      expect(msg, contains(r'C:\app'));
    });
  });

  group('argv whisper-cli', () {
    test('mặc định: -np, -bs 1, -osrt, -of; ngôn ngữ truyền nguyên', () {
      final args = buildWhisperCliArgs(
        modelPath: r'C:\m\ggml-tiny.en-q5_1.bin',
        wavPath: r'C:\t\Audio_1_converted.wav',
        language: 'auto',
        outBase: r'C:\t\out',
      );
      expect(args, contains('-np'));
      expect(args.sublist(args.indexOf('-bs'), args.indexOf('-bs') + 2),
          <String>['-bs', '1']);
      expect(args, contains('-osrt'));
      expect(args.sublist(args.indexOf('-l'), args.indexOf('-l') + 2),
          <String>['-l', 'auto']);
      expect(args.sublist(args.indexOf('-of'), args.indexOf('-of') + 2),
          <String>['-of', r'C:\t\out']);
    });

    test('threads chỉ thêm khi > 0', () {
      final base = buildWhisperCliArgs(
        modelPath: 'm',
        wavPath: 'w',
        language: 'vi',
        outBase: 'o',
      );
      expect(base, isNot(contains('-t')));
      final withThreads = buildWhisperCliArgs(
        modelPath: 'm',
        wavPath: 'w',
        language: 'vi',
        outBase: 'o',
        threads: 4,
      );
      expect(withThreads.sublist(withThreads.indexOf('-t'), withThreads.indexOf('-t') + 2),
          <String>['-t', '4']);
    });

    test('file SRT: đường chuẩn + biến thể whisper.cpp hay ghi', () {
      expect(srtPathFor(r'C:\t\out'), r'C:\t\out.srt');
      expect(srtPathFor('out.SRT'), 'out.SRT');
      expect(
        alternateSrtPaths('out', 'a.wav'),
        containsAll(<String>['out.srt', 'a.wav.srt']),
      );
    });
  });

  group('Phân loại DLL', () {
    test('họ ggml: mọi biến thể CPU quy về ggml-cpu', () {
      expect(ggmlFamilyOf('ggml-cpu-haswell.dll'), 'ggml-cpu');
      expect(ggmlFamilyOf('ggml-cpu.dll'), 'ggml-cpu');
      expect(ggmlFamilyOf('ggml-base.dll'), 'ggml-base');
      expect(ggmlFamilyOf('ggml.dll'), 'ggml');
      expect(ggmlFamilyOf('whisper.dll'), isNull);
    });

    test('DLL hệ thống + MSVC runtime không bao giờ bị coi là "thiếu"', () {
      expect(kWindowsSystemDlls, contains('kernel32.dll'));
      expect(isMsvcRuntimeDll('vcruntime140.dll'), isTrue);
      expect(isMsvcRuntimeDll('whisper.dll'), isFalse);
    });
  });
}
