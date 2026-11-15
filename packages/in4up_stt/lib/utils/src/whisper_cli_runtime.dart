// packages/in4up_stt/lib/utils/src/whisper_cli_runtime.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — "Tạo mục lục tự động" trên Windows
// chết ở bước chạy `whisper-cli.exe`:
//
//   1. `Bad state: Khong tim thay whisper binary: whisper-cli.exe`
//      ⇒ phải đi tìm binary ở MỌI nơi app có thể đã đặt nó (cạnh .exe, bản
//        app đã cài, thư mục app tự tải, windows/libs của bản chạy từ source).
//   2. Sau khi người dùng chép ĐÚNG 4 file release vào cạnh app:
//      `whisper.exe thất bại (exit -1073741515)` + STDOUT/STDERR RỖNG
//      ⇒ `0xC0000135 = STATUS_DLL_NOT_FOUND`. KHÔNG phải lỗi whisper.cpp mà
//        là của WINDOWS LOADER: `whisper-cli.exe` cần
//        `whisper.dll` (mọi hàm trong whisper.h), `ggml.dll`,
//        `ggml-base.dll`, một `ggml-cpu-*.dll` và `SDL2.dll`
//        ⇒ **6 file**, không phải 4. Loader chạy TRƯỚC `main()` nên stderr
//        luôn rỗng — muốn biết thiếu gì phải đọc import table của PE.
//
// Phần THUẦN (đọc PE, so DLL, ghép câu báo lỗi, dựng argv) nằm ở đây để test
// được trên host VM; phần chạm đĩa ở `whisper_cli_locator.dart`.

import 'dart:typed_data';

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 1: IMPORT TABLE CỦA PE (.exe/.dll) — ĐỌC ĐƯỢC TRÊN MỌI HỆ ĐIỀU HÀNH
// ═══════════════════════════════════════════════════════════════════════════

/// Một DLL mà file PE cần có lúc nạp.
class PeImport {
  const PeImport(this.name);

  /// Tên file, luôn ở dạng thường (`whisper.dll`, `ggml.dll`).
  final String name;

  @override
  String toString() => name;
}

/// Một file nằm cạnh binary — đủ để biết "có đúng file, đúng cỡ không".
class PeDirEntry {
  const PeDirEntry({required this.name, required this.size});

  final String name;
  final int size;

  @override
  String toString() => '$name (${size}B)';
}

/// Đọc kết quả `parsePeImports`: import thường + import trì hoãn + machine.
class PeImageInfo {
  const PeImageInfo({
    required this.imports,
    required this.delayImports,
    required this.machine,
  });

  final List<PeImport> imports;
  final List<PeImport> delayImports;

  /// `0x8664` = x64, `0x14C` = x86 (32-bit), `0xAA64` = ARM64.
  final int machine;
}

/// Kiến trúc PE ứng với app Windows x64 mà Flutter build ra.
const int kPeMachineAmd64 = 0x8664;
const int kPeMachineX86 = 0x14C;

/// Đọc import table (và delay-import) của một file PE **từ bộ nhớ**.
///
/// Trả `null` khi file không phải PE hợp lệ / bị cắt cụt — "không biết",
/// KHÔNG phải "không cần DLL nào". Chỉ cần header + section table + bảng
/// import trong [data]; caller đọc ~64 KB đầu file là đủ cho binary whisper
/// (import table của nó nằm ở `.idata` ngay sau header).
PeImageInfo? parsePeImports(Uint8List data) {
  if (data.length < 0x40) return null;
  final view = ByteData.sublistView(data);

  // "MZ"
  if (data[0] != 0x4D || data[1] != 0x5A) return null;

  final peOffset = view.getUint32(0x3C, Endian.little);
  if (peOffset <= 0 || peOffset + 24 > data.length) return null;
  // "PE\0\0"
  if (data[peOffset] != 0x50 ||
      data[peOffset + 1] != 0x45 ||
      data[peOffset + 2] != 0x00 ||
      data[peOffset + 3] != 0x00) {
    return null;
  }

  final machine = view.getUint16(peOffset + 4, Endian.little);
  final numberOfSections = view.getUint16(peOffset + 6, Endian.little);
  final sizeOfOptionalHeader = view.getUint16(peOffset + 20, Endian.little);

  final optionalStart = peOffset + 24;
  if (optionalStart + 2 > data.length) return null;
  final magic = view.getUint16(optionalStart, Endian.little);
  final is64 = magic == 0x20B; // PE32+
  if (!is64 && magic != 0x10B) return null; // PE32

  // Data directory: PE32 → offset 96, PE32+ → offset 112 trong optional
  // header; mỗi mục 8 byte (RVA + size). Import = mục 1, delay-import = 13.
  final dirStart = optionalStart + (is64 ? 112 : 96);
  final dirCountAt = optionalStart + (is64 ? 108 : 92);
  final dirCount = dirCountAt + 4 <= data.length
      ? view.getUint32(dirCountAt, Endian.little)
      : 0;

  int? directoryRva(int index) {
    if (index >= dirCount) return null;
    final at = dirStart + index * 8;
    if (at + 8 > data.length) return null;
    final rva = view.getUint32(at, Endian.little);
    return rva == 0 ? null : rva;
  }

  final importRva = directoryRva(1);
  final delayRva = directoryRva(13);
  if (importRva == null && delayRva == null) {
    return PeImageInfo(imports: const [], delayImports: const [], machine: machine);
  }

  // Section table để đổi RVA → file offset.
  final sectionStart = optionalStart + sizeOfOptionalHeader;
  final sections = <List<int>>[]; // [va, rawSize, rawPtr]
  for (var i = 0; i < numberOfSections; i++) {
    final at = sectionStart + i * 40;
    if (at + 40 > data.length) break;
    sections.add(<int>[
      view.getUint32(at + 12, Endian.little), // VirtualAddress
      view.getUint32(at + 16, Endian.little), // SizeOfRawData
      view.getUint32(at + 20, Endian.little), // PointerToRawData
    ]);
  }

  int? offsetOf(int rva) {
    for (final s in sections) {
      if (rva >= s[0] && rva < s[0] + s[1]) {
        final off = s[2] + (rva - s[0]);
        return off < data.length ? off : null;
      }
    }
    return rva < data.length ? rva : null;
  }

  String? readName(int rva) {
    final start = offsetOf(rva);
    if (start == null) return null;
    var cursor = start;
    while (cursor < data.length && data[cursor] != 0) {
      cursor++;
    }
    if (cursor <= start || cursor - start > 260) return null;
    final raw = String.fromCharCodes(data, start, cursor).trim();
    if (raw.isEmpty) return null;
    return raw.toLowerCase();
  }

  List<PeImport> readTable(int rva, {required bool delays}) {
    final start = offsetOf(rva);
    if (start == null) return const [];
    final result = <PeImport>[];
    // IMPORT: descriptor 20 byte, tên DLL ở +12, kết thúc bằng descriptor 0.
    // DELAY:  descriptor 32 byte, +0 = attributes, tên DLL ở +4; attributes
    //         bit 0 (dlattrRva) = 1 nghĩa là các trường là RVA (bản hiện đại).
    final stride = delays ? 32 : 20;
    for (var i = 0; i < 512; i++) {
      final at = start + i * stride;
      if (at + stride > data.length) break;
      final attributes = delays ? view.getUint32(at, Endian.little) : 0;
      final nameRva = view.getUint32(at + (delays ? 4 : 12), Endian.little);
      if (!delays && nameRva == 0) break;
      if (delays && attributes == 0 && nameRva == 0) break;
      if (nameRva == 0) continue;
      // Chỉ nhận tên khi các trường là RVA (bit 0). Bản cũ dùng VA tuyệt đối
      // ⇒ bỏ qua thay vì đọc rác thành tên file.
      if (delays && (attributes & 1) == 0) continue;
      final name = readName(nameRva);
      if (name != null) result.add(PeImport(name));
    }
    return result;
  }

  return PeImageInfo(
    imports: importRva == null ? const [] : readTable(importRva, delays: false),
    delayImports: delayRva == null ? const [] : readTable(delayRva, delays: true),
    machine: machine,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 2: MÃ THOÁT WINDOWS
// ═══════════════════════════════════════════════════════════════════════════

/// `0xC0000135` — Windows không nạp nổi vì thiếu DLL phụ thuộc.
const int kStatusDllNotFound = -1073741515;

/// `0xC000007B` — sai kiến trúc (32-bit vs 64-bit) ở binary hoặc DLL.
const int kStatusInvalidImageFormat = -1073741701;

/// `0xC0000005` — native crash (access violation).
const int kStatusAccessViolation = -1073741819;

/// Mã thoát có phải "không nạp nổi vì DLL/kiến trúc" không.
bool isNativeLoadFailure(int exitCode) =>
    exitCode == kStatusDllNotFound || exitCode == kStatusInvalidImageFormat;

/// Diễn giải mã thoát của tiến trình trên Windows (thay cho con số trơ).
String describeWindowsExitCode(int code) {
  switch (code) {
    case kStatusDllNotFound:
      return '0xC0000135 STATUS_DLL_NOT_FOUND (thiếu DLL cạnh file .exe)';
    case kStatusInvalidImageFormat:
      return '0xC000007B STATUS_INVALID_IMAGE_FORMAT (sai 32/64-bit)';
    case kStatusAccessViolation:
      return '0xC0000005 STATUS_ACCESS_VIOLATION (native crash)';
  }
  final hex = code.toRadixString(16).toUpperCase();
  return 'mã $code (0x$hex)';
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 3: PHÂN LOẠI DLL
// ═══════════════════════════════════════════════════════════════════════════

/// DLL hệ thống của Windows — luôn có sẵn, KHÔNG cần chép cạnh binary.
const Set<String> kWindowsSystemDlls = <String>{
  'advapi32.dll', 'bcrypt.dll', 'bcryptprimitives.dll', 'cabinet.dll',
  'combase.dll', 'comctl32.dll', 'comdlg32.dll', 'crypt32.dll', 'cryptbase.dll',
  'dbghelp.dll', 'dwmapi.dll', 'd3d11.dll', 'd3d9.dll', 'd2d1.dll', 'dxgi.dll',
  'dwrite.dll', 'dnsapi.dll', 'evr.dll', 'gdi32.dll', 'gdiplus.dll', 'hid.dll',
  'imm32.dll', 'iphlpapi.dll', 'kernel32.dll', 'mf.dll', 'mfplat.dll',
  'mfreadwrite.dll', 'mfuuid.dll', 'mpr.dll', 'msimg32.dll', 'msvcrt.dll',
  'msvcp_win.dll', 'mswsock.dll', 'ncrypt.dll', 'netapi32.dll',
  'normaliz.dll', 'ntdll.dll', 'ole32.dll', 'oleacc.dll', 'oleaut32.dll',
  'opengl32.dll', 'powrprof.dll', 'propsys.dll', 'psapi.dll', 'rpcrt4.dll',
  'sechost.dll', 'secur32.dll', 'setupapi.dll', 'shell32.dll', 'shfolder.dll',
  'shlwapi.dll', 'strmiids.dll', 'user32.dll', 'userenv.dll', 'usp10.dll',
  'uxtheme.dll', 'version.dll', 'wldap32.dll', 'winhttp.dll', 'wininet.dll',
  'winmm.dll', 'ws2_32.dll', 'wsock32.dll', 'wtsapi32.dll',
  // UCRT (Windows 10+ là thành phần hệ thống)
  'ucrtbase.dll', 'api-ms-win-crt-runtime-l1-1-0.dll',
};

/// DLL runtime C++ của MSVC. Bản release chính thức của whisper.cpp
/// static-link nên bình thường KHÔNG xuất hiện; nếu có (bản tự build /shared)
/// thì phải chép kèm — không tự tải.
bool isMsvcRuntimeDll(String name) =>
    name.startsWith('vcruntime') ||
    name.startsWith('msvcp') ||
    name.startsWith('concrt');

/// Tên "họ" của DLL GGML: `ggml-cpu-haswell.dll` → `ggml-cpu`.
///
/// Bản release x64 build với `-DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON`
/// nên mỗi tập lệnh CPU là một file riêng và whisper.cpp chỉ cần MỘT trong số
/// đó (tự chọn theo `ggml_backend_score`). Đòi ĐÚNG tên file là sai.
String? ggmlFamilyOf(String name) {
  final lower = name.toLowerCase();
  if (!lower.startsWith('ggml') || !lower.endsWith('.dll')) return null;
  final stem = lower.substring(0, lower.length - 4);
  const families = <String>[
    'ggml-base', 'ggml-cpu', 'ggml-blas', 'ggml-cuda', 'ggml-vulkan',
    'ggml-opencl', 'ggml-sycl', 'ggml-rpc', 'ggml-hip', 'ggml-cann',
    'ggml-openvino', 'ggml-zendnn', 'ggml-musa', 'ggml-hexagon',
    'ggml-virtgpu', 'ggml-webgpu',
  ];
  for (final family in families) {
    if (stem == family || stem.startsWith('$family-')) return family;
  }
  return stem;
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 4: SOI MỘT BINARY WHISPER TRƯỚC KHI CHẠY
// ═══════════════════════════════════════════════════════════════════════════

/// Kết quả soi một binary trước khi chạy.
class WhisperBinaryProbe {
  const WhisperBinaryProbe({
    required this.path,
    required this.imports,
    required this.missing,
    required this.emptyDlls,
    required this.machineMismatch,
    required this.notes,
    required this.scanned,
  });

  final String path;

  /// DLL app phải có (đã trừ DLL hệ thống + MSVC runtime).
  final List<PeImport> imports;

  /// Thiếu trong thư mục của binary ⇒ nguyên nhân `-1073741515`.
  final List<PeImport> missing;

  /// File CÓ nhưng 0 byte (bản build CI tạo file rỗng) — Windows coi như thiếu.
  final List<PeDirEntry> emptyDlls;

  /// Tên file sai kiến trúc so với binary.
  final List<String> machineMismatch;

  /// Ghi chú thêm (import trì hoãn, binary sai kiến trúc…).
  final List<String> notes;

  /// `false` khi không đọc được PE ⇒ mọi kết luận "thiếu" là không đáng tin.
  final bool scanned;

  /// `scanned == false` KHÔNG được coi là chạy được: file hỏng/rỗng thì Windows
  /// trả 0xC0000135, và installer sẽ lặng lẽ đăng ký một bộ chạy chết.
  bool get isRunnable =>
      scanned &&
      missing.isEmpty &&
      emptyDlls.isEmpty &&
      machineMismatch.isEmpty;

  /// Tóm tắt 1 dòng cho log.
  String get summary {
    if (!scanned) return '$path (không đọc được PE)';
    if (isRunnable) return '$path → import table OK';
    return '$path → thiếu ${missing.map((i) => i.name).join(', ')}'
        '${emptyDlls.isEmpty ? '' : ' · rỗng ${emptyDlls.map((e) => e.name).join(', ')}'}'
        '${machineMismatch.isEmpty ? '' : ' · sai 32/64-bit ${machineMismatch.join(', ')}'}';
  }
}

/// Soi [image] của binary + [siblings] (file cùng thư mục, đã có size).
///
/// HÀM THUẦN — test bơm dữ liệu PE dựng tay / file thật.
WhisperBinaryProbe probeWhisperBinary({
  required String binaryPath,
  required PeImageInfo? image,
  required List<PeDirEntry> siblings,
  int expectedMachine = kPeMachineAmd64,
}) {
  if (image == null) {
    return WhisperBinaryProbe(
      path: binaryPath,
      imports: const [],
      missing: const [],
      emptyDlls: const [],
      machineMismatch: const [],
      notes: const ['không đọc được PE (file hỏng/rỗng?)'],
      scanned: false,
    );
  }

  final present = <String, PeDirEntry>{
    for (final entry in siblings) entry.name.toLowerCase(): entry,
  };

  final imports = <PeImport>[];
  final missing = <PeImport>[];
  final empty = <PeDirEntry>[];
  final mismatch = <String>[];
  final notes = <String>[];

  if (expectedMachine != 0 &&
      image.machine != 0 &&
      image.machine != expectedMachine) {
    final actual = image.machine == kPeMachineX86
        ? '32-bit (x86)'
        : '0x${image.machine.toRadixString(16)}';
    final want = expectedMachine == kPeMachineX86 ? '32-bit' : '64-bit (x64)';
    // Ghi vào machineMismatch (không chỉ notes): đây là lỗi CHẶN — Windows trả
    // 0xC000007B trước khi chương trình chạy, nên `isRunnable` phải false.
    mismatch.add('binary là $actual nhưng app là $want');
    notes.add('binary là $actual nhưng app là $want ⇒ Windows trả 0xC000007B');
  }

  bool familyPresent(String name) {
    final family = ggmlFamilyOf(name);
    if (family == null) return false;
    return siblings.any((s) =>
        s.size > 0 && ggmlFamilyOf(s.name.toLowerCase()) == family);
  }

  for (final import in image.imports) {
    final name = import.name.toLowerCase();
    if (kWindowsSystemDlls.contains(name) || isMsvcRuntimeDll(name)) continue;
    imports.add(import);
    final entry = present[name];
    if (entry != null) {
      if (entry.size == 0 && !empty.any((e) => e.name == entry.name)) {
        empty.add(entry);
      }
      continue;
    }
    if (familyPresent(name)) continue; // ggml-cpu-haswell.dll thay ggml-cpu-sse42.dll
    missing.add(import);
  }

  // DLL trì hoãn: loader không cần lúc mở ⇒ chỉ báo, không chặn.
  for (final delayed in image.delayImports) {
    final name = delayed.name.toLowerCase();
    if (kWindowsSystemDlls.contains(name) || isMsvcRuntimeDll(name)) continue;
    if (present.containsKey(name) || familyPresent(name)) continue;
    notes.add('import trì hoãn (chưa cần khi mở): ${delayed.name}');
  }

  // File 0 byte cùng thư mục: kể cả file không nằm trong import trực tiếp
  // (DLL phụ thuộc bậc 2) — bản build CI tạo file rỗng là bẫy có thật.
  for (final entry in siblings) {
    if (entry.size == 0 && !empty.any((e) => e.name == entry.name)) {
      empty.add(entry);
    }
  }

  return WhisperBinaryProbe(
    path: binaryPath,
    imports: imports,
    missing: missing,
    emptyDlls: empty,
    machineMismatch: mismatch,
    notes: notes,
    scanned: true,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PHẦN 5: CÂU BÁO LỖI + LỆNH CHẠY
// ═══════════════════════════════════════════════════════════════════════════

/// Bộ file "đầy đủ" trên Windows dùng trong hướng dẫn cho người dùng.
const List<String> kWindowsWhisperFileSet = <String>[
  'whisper-cli.exe',
  'whisper.dll',
  'ggml.dll',
  'ggml-base.dll',
  'ggml-cpu-*.dll',
  'SDL2.dll',
];

/// Câu báo lỗi khi exit code là mã nạp DLL của Windows.
///
/// Đây là chỗ người dùng đọc để biết **thiếu đúng file nào** — thay cho
/// "exit -1073741515" kèm STDOUT/STDERR rỗng.
String describeDllLoadFailure({
  required WhisperBinaryProbe? probe,
  required String binaryDir,
  required int exitCode,
}) {
  final lines = <String>[
    'Windows KHÔNG chạy được binary Whisper: ${describeWindowsExitCode(exitCode)}.',
    'Loader của Windows chạy TRƯỚC chương trình nên STDOUT/STDERR luôn rỗng — '
        'file .exe cần các DLL phụ thuộc nằm CẠNH nó.',
  ];

  if (probe == null) {
    lines.add('Bộ file đầy đủ cho Windows (6 file, không phải 4): '
        '${kWindowsWhisperFileSet.join(', ')} → chép vào $binaryDir');
    return lines.join('\n');
  }

  if (!probe.scanned) {
    lines.add('Không đọc được PE của binary (file hỏng/rỗng?). '
        'Hãy tải lại whisper.cpp release và chép đè.');
  } else if (probe.isRunnable) {
    lines.add('Đã soi import table: mọi DLL trực tiếp đều có trong $binaryDir. '
        'Nếu vẫn lỗi, kiểm tra DLL phụ thuộc bậc 2 bằng Dependencies.exe.');
  } else {
    if (probe.missing.isNotEmpty) {
      lines.add('THIẾU trong $binaryDir: '
          '${probe.missing.map((i) => i.name).join(', ')}');
    }
    if (probe.emptyDlls.isNotEmpty) {
      lines.add('CÓ nhưng 0 byte (file rỗng do bản build tự tạo — phải chép đè '
          'bản thật): ${probe.emptyDlls.map((e) => e.name).join(', ')}');
    }
    if (probe.machineMismatch.isNotEmpty) {
      lines.add('SAI KIẾN TRÚC: ${probe.machineMismatch.join(', ')}');
    }
    for (final note in probe.notes) {
      lines.add('• $note');
    }
    lines.add('Bộ file đầy đủ cho Windows: ${kWindowsWhisperFileSet.join(', ')} '
        '→ chép TẤT CẢ vào $binaryDir');
  }
  return lines.join('\n');
}

/// Câu báo lỗi khi KHÔNG tìm thấy binary nào.
String describeMissingBinary({
  required List<String> searched,
  required String suggestedDir,
}) {
  return <String>[
    'Không tìm thấy binary whisper.cpp (whisper-cli.exe) trên máy.',
    'Cách 1 — để app tự cài (khuyến nghị): Cài đặt → Quản lý Model AI → '
        'Whisper → "Cài bộ chạy Whisper".',
    'Cách 2 — tải tay: https://github.com/ggml-org/whisper.cpp/releases '
        '(file whisper-bin-x64.zip), giải nén rồi chép ĐỦ 6 file '
        '(whisper-cli.exe, whisper.dll, ggml.dll, ggml-base.dll, '
        'ggml-cpu-*.dll, SDL2.dll) vào thư mục: $suggestedDir',
    'Cách 3 — đặt biến môi trường WHISPER_PATH trỏ tới whisper-cli.exe '
        '(hoặc tới thư mục chứa nó), rồi mở lại app.',
    if (searched.isNotEmpty)
      'Đã tìm ở: ${searched.take(12).join(' · ')}'
          '${searched.length > 12 ? ' … (${searched.length - 12} nơi khác)' : ''}',
  ].join('\n');
}

/// Dựng argv cho `whisper-cli` (và bản `whisper.exe` cũ — cùng tham số).
///
///  - `-np`: whisper.cpp in rất nhiều ra stderr; app chỉ cần file SRT.
///  - `-bs 1`: mặc định của CLI là 5 beam ⇒ file dài chậm gấp nhiều lần trên
///    CPU. Mục lục chỉ cần 1 beam.
///  - `-l auto`: whisper.cpp tự nhận diện (đúng chuỗi "auto", không phải "").
List<String> buildWhisperCliArgs({
  required String modelPath,
  required String wavPath,
  required String language,
  required String outBase,
  String outputFormat = 'srt',
  bool noPrints = true,
  int beamSize = 1,
  int threads = 0,
}) {
  final formatFlag = switch (outputFormat) {
    'srt' => '-osrt',
    'vtt' => '-ovtt',
    'txt' => '-otxt',
    'json' => '-oj',
    'jsonFull' => '-ojf',
    'lrc' => '-olrc',
    _ => '-osrt',
  };
  return <String>[
    '-m', modelPath,
    '-f', wavPath,
    '-l', language,
    if (threads > 0) ...['-t', '$threads'],
    '-bs', '$beamSize',
    if (noPrints) '-np',
    formatFlag,
    '-of', outBase,
  ];
}

/// File SRT mà `whisper-cli -of <outBase> -osrt` sẽ tạo.
String srtPathFor(String outBase) =>
    outBase.toLowerCase().endsWith('.srt') ? outBase : '$outBase.srt';

/// Các vị trí SRT khác mà whisper.cpp có thể ghi (bản cũ hiểu `-of` là tên
/// file đầu vào nên gắn thêm đuôi `.wav`).
List<String> alternateSrtPaths(String outBase, String wavPath) {
  return <String>{
    srtPathFor(outBase),
    '$outBase.wav.srt',
    '$wavPath.srt',
  }.toList(growable: false);
}
