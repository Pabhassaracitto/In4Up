// test/read_mode/psrc246_248_read_surfaces_test.dart
//
// PSRC-246 / PSRC-247 / PSRC-248 — hợp đồng nguồn cho ba chỉnh UI của owner
// (2026-11-15). Repo này đã dùng lối test "đọc mã nguồn" cho các hợp đồng UI
// thuần bố cục (xem `psrc_236_read_settings_groups_test.dart`): nó chặn được
// đúng loại hồi quy mà widget test khó bắt — một nhánh `if` bị thêm lại.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('PSRC-246 — panel «Công cụ đọc» có lối về Thư viện đọc', () {
    test('dock có chip «Về thư viện đọc» và nhường chỗ cho «Mở nguồn»', () {
      final dock = _read('lib/screens/read_mode/widgets/read_bottom_dock.dart');
      expect(dock.contains("read-dock-open-library"), isTrue);
      expect(dock.contains("uiText('Về thư viện đọc')"), isTrue);
      // «Mở nguồn» chỉ còn cho nguồn Web / Tam tạng.
      expect(dock.contains("uiText('Mở nguồn')"), isTrue);
      expect(
        dock.indexOf("uiText('Về thư viện đọc')") <
            dock.indexOf("uiText('Mở nguồn')"),
        isTrue,
      );
    });

    test('tab Đọc nối lối về thư viện và chỉ bật cho nguồn Tài liệu', () {
      final screen = _read('lib/screens/read_mode/read_mode_screen.dart');
      expect(screen.contains('onOpenReadLibrary'), isTrue);
      expect(
        screen.contains('_source == ReadContentSource.document'),
        isTrue,
        reason: 'Nguồn Web/Tam tạng không có thư viện 3 tab',
      );
    });

    test('shell mở ReadLibraryScreen có nút quay lại', () {
      final shell = _read('lib/screens/main_shell.dart');
      expect(shell.contains('ReadLibraryScreen(showBackButton: true)'), isTrue);
      final library = _read('lib/screens/read_mode/widgets/library_screen.dart');
      expect(library.contains("Key('read-library-back')"), isTrue);
    });
  });

  group('PSRC-247 — hoán đổi icon robot ⇄ thư viện', () {
    test('ô góc trái trên của shell không còn đổi nghĩa theo tab Home', () {
      final shell = _read('lib/screens/main_shell.dart');
      expect(
        shell.contains("if (_currentTab == _PrimaryTab.home) return Icons.smart_toy_outlined;"),
        isFalse,
        reason: 'Robot phải rời AppBar shell (về header Home)',
      );
      expect(
        shell.contains("if (_currentTab == _PrimaryTab.home) return 'Quản lý Model AI';"),
        isFalse,
      );
    });

    test('header Home có robot Model AI cạnh nút đăng nhập, không còn icon sách', () {
      final home = _read('lib/screens/home/home_screen.dart');
      final header = home.substring(
        home.indexOf('Widget _buildGlassHeader'),
      );
      expect(header.contains("Key('home-model-ai')"), isTrue);
      expect(header.contains('SttModelSettingsScreen'), isTrue);
      expect(
        header.contains('Icons.menu_book_rounded'),
        isFalse,
        reason: 'Thư viện Đọc đã về AppBar shell ⇒ bỏ khỏi header Home',
      );
    });
  });

  group('PSRC-248 — bảng hướng dẫn đọc theo dòng khớp cử chỉ thật', () {
    test('không còn câu hứa sai (chạm đúp để tra nghĩa / giữ dòng để sửa)', () {
      final hint = _read('lib/screens/read_mode/widgets/read_line_hint.dart');
      final body = hint.substring(hint.indexOf('static Future<void> showSheet'));
      expect(body.contains('Chạm hai lần vào một từ: xem nghĩa nhanh.'), isFalse);
      expect(body.contains('Giữ một dòng: sửa nội dung dòng đó.'), isFalse);
      expect(body.contains('giữ một từ để tra nghĩa'), isFalse);
    });

    test('câu mới nói đúng: chạm từ = nghe, chạm đúp = đọc + dịch cả dòng', () {
      final hint = _read('lib/screens/read_mode/widgets/read_line_hint.dart');
      final body = hint.substring(hint.indexOf('static Future<void> showSheet'));
      expect(
        body.contains('Chạm hai lần vào một từ hoặc một dòng: đọc và dịch cả dòng.'),
        isTrue,
      );
      expect(
        body.contains('Giữ một dòng: mở bảng hành động của dòng (đọc, lưu, sửa dòng…).'),
        isTrue,
      );
    });
  });

  group('PSRC-249-A — import TRỌN BỘ thư mục không phụ thuộc tên «voices»', () {
    final service = _read('lib/features/tts/tts_service.dart');

    test('quét giọng theo NỘI DUNG ở mọi độ sâu, không lọc theo tên thư mục', () {
      expect(service.contains('_collectVoiceFolders('), isTrue);
      expect(
        service.contains("p.basename(entity.path).toLowerCase() != 'voices'"),
        isFalse,
        reason: 'Chọn thẳng thư mục voices/ hoặc gói đổi tên phải vẫn import được',
      );
    });

    test('dừng nhánh khi gặp thư mục giọng (không đếm samples/ thành giọng 2)', () {
      expect(service.contains('if (isVoice) {\n      out.add(dir);\n      return;'), isTrue);
    });
  });
}
