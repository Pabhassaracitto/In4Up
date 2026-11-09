// test/services/battery_prompt_single_test.dart
//
// BATTERY-PROMPT-001 — yêu cầu chủ dự án (2026-11-09):
//   "bình thường người dùng mở lên phải gặp 2 thông báo về pin, tôi muốn chỉ có
//    1 thông báo và bấm vô là vào chỗ mở pin."
//
// Test gồm 2 lớp:
//
//   A. HÀNH VI (thuần Dart, không cần plugin):
//      `BatteryPromptGate` chỉ cho MỘT lời gọi vào cùng lúc — đây là thứ chặn
//      2 màn hệ thống mở chồng nhau.
//
//   B. QUÉT NGUỒN (source-scan) — chốt cấu trúc để không tái phát:
//      1. Chỉ MỘT điểm gọi `maybeRequestOnStartup` trong `lib/`
//         (nếu ai thêm điểm thứ hai ⇒ user gặp 2 thông báo pin).
//      2. Service là nguồn sự thật duy nhất: có cờ `_shownThisSession` chặn
//         cấp process.
//      3. Có đường native mở thẳng màn tối ưu pin (`in4up/platform` +
//         `openBatteryOptimizationSettings`) — đây là "bấm là vào chỗ mở pin".
//      4. Kotlin `MainActivity` dùng `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATIONS`
//         với `package:` (mở THẲNG hộp thoại cho app) và có đường lùi.
//      5. Màn Quản lý Model AI chỉ còn MỘT chỗ nói về pin (đã bỏ icon AppBar).
//
// Không có assert nào phụ thuộc thiết bị ⇒ chạy được trong CI.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/services/battery_prompt_gate.dart';

/// Đọc file và cắt comment `//` để chỉ so CODE THẬT (tránh pass giả nhờ chính
/// comment giải thích).
String _codeOnly(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Thiếu file: $path');
  return file
      .readAsLinesSync()
      .map((line) {
        final index = line.indexOf('//');
        return index >= 0 ? line.substring(0, index) : line;
      })
      .join('\n');
}

/// Tìm mọi file `.dart` dưới `lib/` có chứa [needle] (bỏ comment).
List<String> _filesContaining(String needle) {
  final hits = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final code = entity
        .readAsLinesSync()
        .map((line) {
          final index = line.indexOf('//');
          return index >= 0 ? line.substring(0, index) : line;
        })
        .join('\n');
    if (code.contains(needle)) hits.add(entity.path);
  }
  hits.sort();
  return hits;
}

void main() {
  group('A. BatteryPromptGate — chỉ một lời gọi vào cùng lúc', () {
    test('lần đầu vào được, lần hai bị chặn', () {
      final gate = BatteryPromptGate();
      expect(gate.tryEnter(), isTrue,
          reason: 'Lần đầu phải vào được để mở màn hệ thống');
      expect(gate.tryEnter(), isFalse,
          reason: 'Đang trong lúc mở màn thì lời gọi thứ hai PHẢI bị chặn — '
              'nếu không, 2 màn hệ thống mở chồng nhau = "2 thông báo pin"');
    });

    test('leave() trả lại quyền vào', () {
      final gate = BatteryPromptGate();
      expect(gate.tryEnter(), isTrue);
      gate.leave();
      expect(gate.tryEnter(), isTrue,
          reason: 'Sau khi màn trước đóng, lần gọi sau (vd từ Settings) phải '
              'được phép — nếu không user bấm mà không có gì xảy ra');
    });

    test('nhiều gate độc lập không ảnh hưởng nhau', () {
      final a = BatteryPromptGate();
      final b = BatteryPromptGate();
      expect(a.tryEnter(), isTrue);
      expect(b.tryEnter(), isTrue,
          reason: 'Gate là trạng thái theo instance — test này chốt rằng việc '
              'chặn toàn cục KHÔNG nằm ở đây mà ở `_shownThisSession` của '
              'BatteryOptimizationService');
    });
  });

  group('B. Quét nguồn — một thông báo pin, và bấm là mở màn pin', () {
    test('chỉ MỘT điểm gọi maybeRequestOnStartup trong lib/', () {
      final hits = _filesContaining('maybeRequestOnStartup(');
      // Bỏ chính file service (nơi ĐỊNH NGHĨA hàm).
      final callSites = hits
          .where((p) => !p.endsWith('battery_optimization_service.dart'))
          .toList();
      expect(
        callSites,
        ['lib/screens/main_shell.dart'],
        reason: 'Phải có ĐÚNG MỘT điểm gọi lúc khởi động. Có thêm chỗ thứ hai '
            '⇒ mỗi lần mở app user gặp 2 thông báo pin.\n'
            'Tìm thấy: $callSites',
      );
    });

    test('service có cờ chặn theo PHIÊN (_shownThisSession)', () {
      final code = _codeOnly('lib/services/battery_optimization_service.dart');
      expect(
        RegExp(r'static\s+bool\s+_shownThisSession').hasMatch(code),
        isTrue,
        reason: 'Thiếu cờ cấp process — hai lời gọi trong cùng phiên sẽ mở '
            'màn hệ thống 2 lần',
      );
      expect(
        RegExp(r'if\s*\(_shownThisSession\)\s*return').hasMatch(code),
        isTrue,
        reason: 'Có cờ mà không kiểm tra thì vô dụng',
      );
    });

    test('service gọi channel native để mở màn tối ưu pin', () {
      final code = _codeOnly('lib/services/battery_optimization_service.dart');
      expect(code.contains("MethodChannel('in4up/platform')"), isTrue,
          reason: 'Phải có channel native — đây là đường "bấm là vào chỗ mở pin"');
      expect(code.contains('openBatteryOptimizationSettings'), isTrue,
          reason: 'Phải gọi đúng tên method của channel');
      expect(
        code.contains('MissingPluginException'),
        isTrue,
        reason: 'Máy/plugin không có channel ⇒ phải nuốt lỗi và lùi về '
            'permission_handler, không được crash',
      );
    });

    test('Kotlin mở THẲNG màn cho app này + có đường lùi', () {
      final kotlin = _codeOnly(
        'android/app/src/main/kotlin/com/in4up/MainActivity.kt',
      );
      expect(kotlin.contains('import android.provider.Settings'), isTrue);
      expect(
        kotlin.contains('Settings.ACTION_IGNORE_BATTERY_OPTIMIZATIONS'),
        isTrue,
        reason: 'Đây là action mở thẳng hộp thoại "Dừng tối ưu pin" cho app',
      );
      expect(
        RegExp(r'package:\$packageName').hasMatch(kotlin),
        isTrue,
        reason: 'Thiếu `data = package:<appId>` thì Android KHÔNG mở hộp thoại '
            'cho app mà chỉ mở danh sách chung',
      );
      // Đường lùi cho ROM ẩn hộp thoại.
      expect(
        kotlin.contains('Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS'),
        isTrue,
        reason: 'Nhiều ROM (MIUI/OneUI/EMUI) ẩn hộp thoại riêng ⇒ cần lùi về '
            'danh sách tối ưu pin',
      );
      expect(
        kotlin.contains('Settings.ACTION_BATTERY_SAVER_SETTINGS'),
        isTrue,
        reason: 'Thêm một bậc lùi nữa cho máy không có 2 màn trên',
      );
    });

    test('không còn icon pin thứ hai trên AppBar màn Model AI', () {
      final code = _codeOnly(
        'lib/screens/settings/stt_model_settings_screen.dart',
      );
      expect(
        code.contains('_BatteryStatusAction'),
        isFalse,
        reason: 'Icon pin trên AppBar đã bị bỏ (owner 2026-11-09): màn này có '
            '2 tín hiệu pin, cộng với thông báo lúc mở app ⇒ quá nhiều chỗ. '
            'Nay chỉ còn thẻ pin trong sheet "!".',
      );
      // Chỗ duy nhất còn nói về pin là thẻ trong sheet.
      expect(
        code.contains('_BatteryOptimizationCard'),
        isTrue,
        reason: 'Vẫn phải có MỘT chỗ để user xem/cấp quyền pin khi họ chủ động',
      );
    });

    test('thẻ pin cập nhật khi user quay lại từ màn hệ thống', () {
      final code = _codeOnly(
        'lib/screens/settings/stt_model_settings_screen.dart',
      );
      expect(
        code.contains('didChangeAppLifecycleState'),
        isTrue,
        reason: 'Bấm "Cho phép" mở màn hệ thống rồi quay lại — không nghe vòng '
            'đời thì thẻ vẫn hiện "Chưa cho phép" dù user đã bật',
      );
      expect(
        code.contains('AppLifecycleState.resumed'),
        isTrue,
        reason: 'Phải refresh đúng lúc app được resumed',
      );
    });
  });
}
