// lib/services/external_open_service.dart
//
// PSRC-202/203/219/220 — "mở ngoài app" bằng trình của HỆ ĐIỀU HÀNH.
//
// Vì sao cần một chỗ duy nhất: có ba tình huống app KHÔNG tự mở được tệp
// nhưng người dùng vẫn phải có đường lấy/hiện nội dung:
//   • bản xuất đã bị dời/xoá sau khi tạo (202, 203) ⇒ mở thư mục chứa tệp;
//   • Linux chưa có backend âm thanh trong app (219) ⇒ mở bằng player hệ thống;
//   • `video_player` không có plugin cho Linux/Windows (220) ⇒ mở bằng
//     trình phát video của hệ thống.
//
// Nguyên tắc: phần QUYẾT ĐỊNH (nền tảng → lệnh gì) là hàm THUẦN để CI khoá
// lại được; phần chạy lệnh chỉ là một lớp mỏng `Process.run`. Mobile/Web
// không có API "mở tệp bất kỳ" ⇒ trả false để UI nói thật là không mở được
// (mobile đã có share sheet).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Nền tảng mà lớp mở-tệp-ngoài-app biết cách xử lý.
enum ExternalOpenPlatform { windows, macOS, linux, android, iOS, web, unknown }

/// Ánh xạ `Platform.operatingSystem` → enum thuần (test được trên host VM).
ExternalOpenPlatform externalOpenPlatformFor(String operatingSystem) {
  switch (operatingSystem) {
    case 'windows':
      return ExternalOpenPlatform.windows;
    case 'macos':
      return ExternalOpenPlatform.macOS;
    case 'linux':
      return ExternalOpenPlatform.linux;
    case 'android':
      return ExternalOpenPlatform.android;
    case 'ios':
      return ExternalOpenPlatform.iOS;
    default:
      return ExternalOpenPlatform.unknown;
  }
}

/// Nền tảng hiện tại (web = [ExternalOpenPlatform.web]).
ExternalOpenPlatform get currentExternalOpenPlatform =>
    kIsWeb ? ExternalOpenPlatform.web : externalOpenPlatformFor(Platform.operatingSystem);

/// Một lệnh mở tệp/thư mục bằng trình của hệ điều hành.
class ExternalOpenCommand {
  const ExternalOpenCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

/// Dựng lệnh mở [path] (hoặc thư mục CHỨA [path] khi [revealInFolder]).
///
/// Trả `null` khi nền tảng không hỗ trợ (mobile/web/unknown) — UI phải nói
/// thật thay vì im lặng.
ExternalOpenCommand? buildExternalOpenCommand({
  required ExternalOpenPlatform platform,
  required String path,
  bool revealInFolder = false,
}) {
  if (path.trim().isEmpty) return null;
  // Kiểu đường dẫn phải theo NỀN TẢNG ĐÍCH, không theo host đang chạy:
  // `p.dirname` mặc định dùng kiểu của host, nên trên Linux nó trả `'.'` cho
  // một đường dẫn Windows ⇒ lệnh `/select,` bị coi là không dựng được (và
  // test thuần trên CI Linux không kiểm được nhánh Windows — gặp thật ở run
  // 43493960039).
  final style = platform == ExternalOpenPlatform.windows ? p.windows : p.posix;
  final target = revealInFolder ? style.dirname(path) : path;
  if (target.trim().isEmpty || target == '.') return null;
  switch (platform) {
    case ExternalOpenPlatform.windows:
      // `/select,<file>` mở Explorer và chọn đúng tệp; mở thư mục thì mở thẳng.
      return revealInFolder
          ? ExternalOpenCommand('explorer.exe', <String>['/select,', path])
          : ExternalOpenCommand('explorer.exe', <String>[target]);
    case ExternalOpenPlatform.macOS:
      return revealInFolder
          ? ExternalOpenCommand('open', <String>['-R', path])
          : ExternalOpenCommand('open', <String>[target]);
    case ExternalOpenPlatform.linux:
      return ExternalOpenCommand('xdg-open', <String>[target]);
    case ExternalOpenPlatform.android:
    case ExternalOpenPlatform.iOS:
    case ExternalOpenPlatform.web:
    case ExternalOpenPlatform.unknown:
      return null;
  }
}

/// Mở thư mục CHỨA tệp bằng trình quản lý tệp của hệ điều hành.
Future<bool> openExportFolder(String filePath) =>
    _run(buildExternalOpenCommand(
      platform: currentExternalOpenPlatform,
      path: filePath,
      revealInFolder: true,
    ));

/// Mở chính tệp bằng ứng dụng mặc định của hệ điều hành.
Future<bool> openFileExternally(String filePath) =>
    _run(buildExternalOpenCommand(
      platform: currentExternalOpenPlatform,
      path: filePath,
    ));

Future<bool> _run(ExternalOpenCommand? command) async {
  if (command == null) return false;
  try {
    final result = await Process.run(
      command.executable,
      command.arguments,
      runInShell: false,
    );
    // `xdg-open`/`open`/`explorer` có thể trả mã khác 0 dù đã mở (explorer
    // trả 1 khi tham số /select, trên vài bản Windows). Chỉ coi là thất bại
    // khi tiến trình không chạy được (bắt ở catch).
    if (result.exitCode != 0) {
      debugPrint(
        '[ExternalOpen] ${command.executable} exit ${result.exitCode} '
        'với ${command.arguments.join(' ')}',
      );
    }
    return true;
  } catch (e) {
    debugPrint('[ExternalOpen] không chạy được lệnh mở ngoài: $e');
    return false;
  }
}
