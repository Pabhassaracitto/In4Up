// packages/in4up_stt/lib/utils/src/whisper_cli_locator.dart
//
// WHISPER-CLI-WIN-001 (audit 1.29.0-Beta) — TÌM + SOI binary whisper.cpp
// trước khi chạy. Tách khỏi `stt_engine_whisper.dart` để:
//   • logic tìm kiếm test được trên host VM (file thật trong thư mục tạm);
//   • phần thuần (đọc PE, phân loại DLL) nằm ở `whisper_cli_runtime.dart`;
//   • thư mục DLL phụ thuộc được ĐĂNG KÝ từ tầng app (app tự tải bộ chạy) mà
//     `in4up_stt` không phải phụ thuộc `path_provider`.
//
// Vì sao phải soi PE trước khi chạy (bằng chứng từ audit 1.29.0-Beta):
//   người dùng đã chép "4 file" vào cạnh app ⇒ Windows trả
//   `exit -1073741515` (0xC0000135) với STDOUT/STDERR RỖNG. 4 file đó
//   (whisper-cli.exe + ggml.dll + ggml-base.dll + ggml-cpu-*.dll) THIẾU
//   `whisper.dll` — file chứa toàn bộ hàm whisper_*. Loader Windows nạp DLL
//   trước `main()` nên không có dòng log nào để đọc: chỉ import table mới
//   nói được thiếu gì.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:path/path.dart' as path;

import 'whisper_cli_runtime.dart';

/// Cấu hình do tầng app bơm vào (app tự tải bộ chạy Whisper, biết thư mục
/// `documents/` mà package này không được phép hỏi trực tiếp).
class WhisperRuntimeRegistry {
  WhisperRuntimeRegistry._();

  /// `whisper-cli.exe` do CHÍNH APP cài (ưu tiên cao nhất).
  static String? registeredBinaryPath;

  /// Thư mục chứa DLL phụ thuộc của bộ chạy app đã cài — được thêm vào `PATH`
  /// của tiến trình con để Windows tìm thấy.
  static final List<String> extraDllDirs = <String>[];

  /// Gợi ý thư mục (đồng bộ) — app trả về `documents/whisper_runtime`.
  static String? Function()? directoryHintProvider;

  static void register({
    String? binaryPath,
    Iterable<String>? dllDirs,
    String? Function()? directoryHint,
  }) {
    if (binaryPath != null) {
      registeredBinaryPath = binaryPath.isEmpty ? null : binaryPath;
    }
    if (dllDirs != null) {
      // Rỗng = "không biết thêm thư mục nào" ⇒ GIỮ nguyên danh sách cũ, không
      // xoá: `init()` của bootstrap chạy sau `rememberInstalled` sẽ làm mất
      // thư mục DLL vừa đăng ký và binary chết với 0xC0000135.
      final kept = dllDirs.where((d) => d.isNotEmpty).toList(growable: false);
      if (kept.isNotEmpty) {
        extraDllDirs
          ..clear()
          ..addAll(kept);
      }
    }
    if (directoryHint != null) directoryHintProvider = directoryHint;
  }

  static String? get hintedDirectory {
    try {
      return directoryHintProvider?.call();
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void reset() {
    registeredBinaryPath = null;
    extraDllDirs.clear();
    directoryHintProvider = null;
  }
}

/// Kết quả tìm binary: đường dẫn + thư mục DLL + kết quả soi import table.
class WhisperCliLocation {
  const WhisperCliLocation({
    required this.binaryPath,
    required this.dllDirs,
    required this.probe,
    required this.searched,
    required this.found,
  });

  final String binaryPath;
  final List<String> dllDirs;

  /// `null` khi không tìm được binary.
  final WhisperBinaryProbe? probe;

  /// Các nơi đã tìm (để câu báo lỗi nói rõ "đã tìm ở đâu").
  final List<String> searched;

  final bool found;

  /// Thư mục của binary — nơi Windows tìm DLL trước tiên.
  String get binaryDir => File(binaryPath).parent.path;

  /// Biến môi trường cho tiến trình con: gộp các thư mục DLL vào `PATH`
  /// (giữ nguyên PATH cũ để không phá phụ thuộc hệ thống).
  Map<String, String> get childEnvironment {
    final existing = Platform.environment['PATH'] ?? '';
    final dirs = <String>{
      binaryDir,
      ...dllDirs,
      if (existing.isNotEmpty) ...existing.split(';'),
    }.where((d) => d.trim().isNotEmpty).toList();
    return <String, String>{'PATH': dirs.join(';')};
  }

  static const WhisperCliLocation notFound = WhisperCliLocation(
    binaryPath: '',
    dllDirs: <String>[],
    probe: null,
    searched: <String>[],
    found: false,
  );
}

/// Tìm `whisper-cli.exe` (hoặc `whisper.exe` / `main.exe` bản cũ) cùng các
/// DLL của nó. Không ném lỗi: trả [WhisperCliLocation.notFound] để tầng gọi
/// dựng câu báo lỗi có hướng dẫn.
class WhisperCliLocator {
  WhisperCliLocator._();

  /// Tên binary, ưu tiên tên MỚI. `whisper.exe` bản cũ chỉ in cảnh báo rồi
  /// thoát, nên nó phải đứng sau.
  static const List<String> windowsNames = <String>[
    'whisper-cli.exe',
    'whisper.exe',
    'main.exe',
  ];

  static const List<String> posixNames = <String>[
    'whisper-cli',
    'whisper',
    'main',
  ];

  /// Binary nhỏ hơn ngưỡng này là "shim"/file rỗng do bản build tạo ra.
  static const int minBinaryBytes = 50000;

  /// Số byte đầu file đọc để tìm bảng import (đủ cho binary whisper; lớn hơn
  /// thì đọc tiếp toàn file khi cần).
  static const int headerProbeBytes = 512 * 1024;

  static List<String> get _names => Platform.isWindows ? windowsNames : posixNames;

  /// Tìm + soi. Kết quả được cache theo "phiên" — người dùng cài bộ chạy giữa
  /// chừng thì gọi [invalidateCache].
  static WhisperCliLocation? _cached;

  static void invalidateCache() => _cached = null;

  static WhisperCliLocation resolve({bool forceRefresh = false}) {
    if (!forceRefresh && _cached != null) return _cached!;

    final searched = <String>[];
    final dllDirs = <String>{...WhisperRuntimeRegistry.extraDllDirs};

    String? candidate;

    // ── 0. Bộ chạy do CHÍNH APP cài (thắng mọi nguồn khác) ────────────────
    final registered = WhisperRuntimeRegistry.registeredBinaryPath;
    if (registered != null && registered.isNotEmpty) {
      searched.add('app-runtime: $registered');
      if (_isUsableBinary(registered)) {
        candidate = registered;
      } else {
        final dir = File(registered).parent.path;
        if (Directory(dir).existsSync()) dllDirs.add(dir);
      }
    }

    // ── 0b. Gợi ý thư mục từ app (documents/whisper_runtime) ──────────────
    if (candidate == null) {
      final hint = WhisperRuntimeRegistry.hintedDirectory;
      if (hint != null && hint.isNotEmpty) {
        searched.add('app-hint: $hint');
        candidate = _scanDir(hint, searched: searched, dllDirs: dllDirs);
      }
    }

    // ── 1. Biến môi trường ────────────────────────────────────────────────
    if (candidate == null) {
      for (final key in const ['WHISPER_PATH', 'WHISPER_CPP_PATH', 'WHISPER_BIN']) {
        final raw = Platform.environment[key];
        if (raw == null || raw.trim().isEmpty) continue;
        searched.add('env $key=$raw');
        final trimmed = raw.trim();
        if (_isUsableBinary(trimmed)) {
          candidate = trimmed;
          break;
        }
        final asDir = _scanDir(trimmed, searched: searched, dllDirs: dllDirs);
        if (asDir != null) {
          candidate = asDir;
          break;
        }
      }
    }

    // ── 2. Cạnh file thực thi (bản đã build/Release) ──────────────────────
    if (candidate == null) {
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        searched.add('exe dir: $exeDir');
        candidate = _scanDir(exeDir, searched: searched, dllDirs: dllDirs);
        if (candidate == null) {
          candidate = _scanDir(path.join(exeDir, 'whisper'), searched: searched, dllDirs: dllDirs);
        }
        if (candidate == null) {
          candidate = _scanDir(
            path.join(exeDir, 'data', 'flutter_assets'),
            searched: searched,
            dllDirs: dllDirs,
          );
        }
      } catch (_) {}
    }

    // ── 3. Thư mục làm việc (chạy từ source: flutter run) ────────────────
    if (candidate == null) {
      try {
        final cwd = Directory.current.path;
        for (final rel in const <String>[
          'windows/libs',
          'windows/libs/whisper',
          'windows/libs/ffmpeg/bin',
          'build/windows/x64/runner/Debug',
          'build/windows/x64/runner/Profile',
          'build/windows/x64/runner/Release',
        ]) {
          candidate = _scanDir(path.join(cwd, rel), searched: searched, dllDirs: dllDirs);
          if (candidate != null) break;
        }
      } catch (_) {}
    }

    // ── 4. PATH của hệ thống ─────────────────────────────────────────────
    if (candidate == null) {
      for (final name in _names) {
        try {
          final result = Platform.isWindows
              ? Process.runSync('where', <String>[name])
              : Process.runSync('which', <String>[name]);
          if (result.exitCode != 0) continue;
          final lines = (result.stdout as String)
              .split(RegExp(r'\r?\n'))
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty);
          for (final line in lines) {
            searched.add('PATH: $line');
            if (_isUsableBinary(line)) {
              candidate = line;
              break;
            }
          }
        } catch (_) {}
        if (candidate != null) break;
      }
    }

    // ── 5. Vị trí cài phổ biến ────────────────────────────────────────────
    if (candidate == null) {
      const common = <String>[
        r'C:\whisper',
        r'C:\whisper.cpp',
        r'C:\Program Files\whisper',
        r'C:\Program Files\whisper.cpp',
        '/usr/local/bin',
        '/opt/whisper.cpp',
      ];
      for (final dir in common) {
        candidate = _scanDir(dir, searched: searched, dllDirs: dllDirs);
        if (candidate != null) break;
      }
    }

    if (candidate == null) {
      _cached = WhisperCliLocation(
        binaryPath: '',
        dllDirs: dllDirs.toList(growable: false),
        probe: null,
        searched: List<String>.unmodifiable(searched),
        found: false,
      );
      debugPrint('[WhisperCLI] Không tìm thấy binary. Đã tìm: $searched');
      return _cached!;
    }

    dllDirs.add(File(candidate).parent.path);
    final probe = probeBinary(candidate);

    _cached = WhisperCliLocation(
      binaryPath: candidate,
      dllDirs: dllDirs.toList(growable: false),
      probe: probe,
      searched: List<String>.unmodifiable(searched),
      found: true,
    );
    debugPrint('[WhisperCLI] Dùng ${probe.summary}');
    return _cached!;
  }

  /// Thư mục gợi ý để người dùng chép tay bộ file (cạnh app).
  static String suggestedDirectory() {
    try {
      return File(Platform.resolvedExecutable).parent.path;
    } catch (_) {
      return Directory.current.path;
    }
  }

  /// Soi binary: đọc PE + liệt kê file cùng thư mục.
  static WhisperBinaryProbe probeBinary(String binaryPath) {
    PeImageInfo? image;
    try {
      final file = File(binaryPath);
      final length = file.lengthSync();
      final head = _readHead(file, length < headerProbeBytes ? length : headerProbeBytes);
      image = parsePeImports(head);
      if (image == null && length > head.length && length <= 64 * 1024 * 1024) {
        // Bảng import nằm ngoài phần đầu ⇒ đọc cả file (binary whisper ≤ 40 MB).
        image = parsePeImports(file.readAsBytesSync());
      }
    } catch (e) {
      debugPrint('[WhisperCLI] Không đọc được PE $binaryPath: $e');
      image = null;
    }

    final siblings = <PeDirEntry>[];
    try {
      final dir = Directory(File(binaryPath).parent.path);
      if (dir.existsSync()) {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is! File) continue;
          final name = path.basename(entity.path);
          final lower = name.toLowerCase();
          if (!lower.endsWith('.dll') && !_isExeName(lower)) continue;
          try {
            siblings.add(PeDirEntry(name: name, size: entity.lengthSync()));
          } catch (_) {}
          if (siblings.length > 400) break;
        }
      }
    } catch (_) {}

    return probeWhisperBinary(
      binaryPath: binaryPath,
      image: image,
      siblings: siblings,
      expectedMachine: Platform.isWindows && _is64BitHost ? kPeMachineAmd64 : 0,
    );
  }

  // ── Nội bộ ──────────────────────────────────────────────────────────────

  static bool get _is64BitHost {
    // `Platform.version` không nói được; Windows x64 là mặc định của app
    // (Flutter desktop chỉ phát hành x64). ARM64 cũng nạp được x64 qua
    // emulator, và PE machine của nó là 0xAA64 ⇒ chỉ chặn x86 32-bit.
    return true;
  }

  static bool _isExeName(String lower) =>
      lower.endsWith('.exe') || (!Platform.isWindows && !lower.contains('.'));

  static Uint8List _readHead(File file, int count) {
    final raf = file.openSync();
    try {
      return raf.readSync(count);
    } finally {
      raf.closeSync();
    }
  }

  /// File có phải binary whisper dùng được không (tồn tại, đủ lớn, không phải
  /// file rỗng do bản build tạo).
  static bool _isUsableBinary(String candidate) {
    try {
      final file = File(candidate);
      if (!file.existsSync()) return false;
      final lower = candidate.toLowerCase();
      final isWhisperNamed = lower.endsWith('whisper.exe') || lower.endsWith('main.exe');
      final size = file.lengthSync();
      // `whisper.exe` cũ của whisper.cpp chỉ in "this example is deprecated"
      // rồi thoát 1 — bản shim hợp lệ thì nhỏ; bản thật thì lớn.
      if (isWhisperNamed && size < minBinaryBytes) {
        debugPrint('[WhisperCLI] Bỏ qua file nhỏ ($size B): $candidate');
        return false;
      }
      if (size < 1024) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Quét một thư mục tìm binary; ghi mọi ứng viên vào [searched] và mọi thư
  /// mục có DLL vào [dllDirs].
  static String? _scanDir(
    String dirPath, {
    required List<String> searched,
    required Set<String> dllDirs,
  }) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        searched.add('$dirPath (không có)');
        return null;
      }
      searched.add(dirPath);
      // HAI LƯỢT: `Directory.listSync` không bảo đảm thứ tự, nên lượt cũ
      // (`hasDll` tính trong lúc quét) có thể thấy `whisper-cli.exe` TRƯỚC
      // `whisper.dll` ⇒ không thêm thư mục DLL vào `PATH` của tiến trình con
      // ⇒ binary chết với 0xC0000135 dù DLL nằm ngay cạnh.
      final files = <File>[];
      var hasDll = false;
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        files.add(entity);
        if (path.basename(entity.path).toLowerCase().endsWith('.dll')) {
          hasDll = true;
        }
      }
      if (hasDll) dllDirs.add(dirPath);
      for (final entity in files) {
        final lower = path.basename(entity.path).toLowerCase();
        if (!_names.any((n) => lower == n.toLowerCase())) continue;
        if (_isUsableBinary(entity.path)) return entity.path;
      }
      return null;
    } catch (e) {
      searched.add('$dirPath (lỗi: $e)');
      return null;
    }
  }
}

/// Soi một binary trên đĩa (dùng cho installer + bootstrap, không qua cache
/// tìm kiếm). Trả [WhisperBinaryProbe] — `scanned == false` khi không đọc
/// được PE (file hỏng/rỗng).
WhisperBinaryProbe probeWhisperBinaryOnDisk(String binaryPath) =>
    WhisperCliLocator.probeBinary(binaryPath);
