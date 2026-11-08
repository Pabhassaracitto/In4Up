// packages/in4up_stt/lib/utils/src/ffmpeg_binary_locator.dart
//
// AVTOOL-001 (PLAN-047 P0) — TIM BINARY FFMPEG tren desktop, TACH RIENG khoi
// `ffmpeg_runner.dart`.
//
// Vi sao phai tach (khong phai "cho gon"):
//   `ffmpeg_process_impl.dart` can tim binary, ma `ffmpeg_runner.dart` lai
//   import `ffmpeg_process_impl.dart`. De nguyen ham tim binary trong runner
//   tao vong import runner <-> process_impl: Dart cho phep, nhung analyzer bao
//   `depend_on_referenced_packages`/vong lap kho debug va co the gay loi khoi
//   tao static muon ve sau.
//
// Thu tu uu tien (cang len cang manh):
//   0a. Binary do CHINH APP cai (nguoi dung bam "Tai FFmpeg") — thang.
//   0b. Goi y duong dan app do duoc (sau khi khoi dong lai app).
//   1.  Bien moi truong FFMPEG_PATH (file hoac thu muc).
//   2.  Cung thu muc voi file thuc thi (ban build/flutter run).
//   3.  windows/libs/... (che do dev tu source).
//   4.  Vi tri cai dat pho bien tren Windows.
//   5.  De PATH cua he thong phan giai (`ffmpeg.exe` / `ffmpeg`).

import 'dart:io';

import 'package:path/path.dart' as path;

/// Trang thai dang ky dung chung (khong phu thuoc `ffmpeg_runner.dart`, de
/// `ffmpeg_process_impl.dart` doc duoc ma khong tao vong import).
class FfmpegBinaryRegistry {
  FfmpegBinaryRegistry._();

  /// Binary do CHINH APP cai (nguoi dung bam "Tai FFmpeg").
  static String? registeredPath;

  /// Ham goi y duong dan do tang app bom vao (`in4up_stt` khong import
  /// `path_provider`, giu nguyen phu thuoc cua package).
  static String? Function()? hintProvider;

  static String? hint() {
    try {
      return hintProvider?.call();
    } catch (_) {
      return null;
    }
  }

  /// Duong dan binary se dung, theo thu tu uu tien trong
  /// [resolveFfmpegBinaryPath].
  static String resolve() => resolveFfmpegBinaryPath(
        registeredPath: registeredPath,
        hintPath: hint(),
      );
}

/// Duong dan binary FFmpeg se dung. Khong bao gio nem loi: tra ve ten tran
/// (`ffmpeg.exe` / `ffmpeg`) de he dieu hanh tu phan giai qua PATH.
String resolveFfmpegBinaryPath({
  String? registeredPath,
  String? hintPath,
}) {
  // 0a. Binary do app tu tai ve (nguoi dung da bam "Tai FFmpeg").
  if (registeredPath != null &&
      registeredPath.isNotEmpty &&
      File(registeredPath).existsSync()) {
    return registeredPath;
  }

  // 0b. Duong dan app do duoc (documents/ffmpeg_runtime/...) — co the chi la
  // goi y luc chua dang ky, vi du sau khi khoi dong lai app.
  if (hintPath != null && hintPath.isNotEmpty) {
    final asFile = File(hintPath);
    if (asFile.existsSync()) return hintPath;
    final joined = path.join(
      hintPath,
      Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg',
    );
    if (File(joined).existsSync()) return joined;
  }

  // 1. Env var
  final envPath = Platform.environment['FFMPEG_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    final f = File(envPath);
    if (f.existsSync()) return envPath;
    // if env var is dir
    final joined = path.join(envPath, Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg');
    if (File(joined).existsSync()) return joined;
  }

  if (Platform.isWindows) {
    // 2. Same dir as executable (flutter build output)
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = [
        path.join(exeDir, 'ffmpeg.exe'),
        path.join(exeDir, 'data', 'ffmpeg.exe'),
        path.join(exeDir, 'data', 'flutter_assets', 'ffmpeg.exe'),
      ];
      for (final c in candidates) {
        if (File(c).existsSync()) return c;
      }
    } catch (_) {}

    // 3. Project local libs (dev) — windows/libs/ffmpeg.exe
    // This only works when running from source with flutter run
    try {
      final current = Directory.current.path;
      final devCandidates = [
        path.join(current, 'windows', 'libs', 'ffmpeg.exe'),
        path.join(current, 'windows', 'libs', 'ffmpeg', 'bin', 'ffmpeg.exe'),
        path.join(current, 'ffmpeg.exe'),
      ];
      for (final c in devCandidates) {
        if (File(c).existsSync()) return c;
      }
    } catch (_) {}

    // 4. Common Windows install locations
    const common = [
      r'C:\ffmpeg\bin\ffmpeg.exe',
      r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
    ];
    for (final c in common) {
      if (File(c).existsSync()) return c;
    }

    // 5. Let system PATH resolve 'ffmpeg.exe'
    return 'ffmpeg.exe';
  } else {
    // macOS / Linux
    return 'ffmpeg';
  }
}
