// YT-LR-004 / IN4-94 — Nhấn icon YouTube phải vào THẲNG tầng 2
// (`YoutubeExplorerScreen`, nơi search được) thay vì tầng 1 cũ (bottom sheet
// `YoutubeSheet` chỉ có ô dán URL, không search được).
//
// Lý do: tầng 1 cũ là bottom sheet `YoutubeSheet` với 3 tab
// (Audio / Captions / Lịch sử) và ĐẦU TRANG là ô "Dán URL YouTube..." — muốn
// tìm video phải bấm thêm nút "Khám phá kênh" mới sang được tầng 2. Tầng 2 đã
// có sẵn cả ô tìm kiếm (chạy keyless) LẪN ô dán URL, nên tầng 1 trở thành một
// bước thừa.
//
// Test thuần này pin các ràng buộc cấu trúc (không cần máy thật).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final shell = File('lib/screens/main_shell.dart').readAsStringSync();
  final explorer =
      File('lib/features/youtube/youtube_explorer_screen.dart').readAsStringSync();

  group('IN4-94 — icon YouTube vào thẳng tầng 2 (bỏ tầng 1 cũ)', () {
    test('main_shell KHÔNG còn gọi YoutubeSheet (tầng 1 cũ)', () {
      expect(
        shell.contains('YoutubeSheet.show('),
        isFalse,
        reason: 'Tầng 1 cũ chỉ dán được URL, không search được ⇒ bỏ.',
      );
      expect(
        shell.contains("import '../features/youtube/youtube_sheet.dart';"),
        isFalse,
        reason: 'Import tầng 1 cũ phải được gỡ (nếu không sẽ là unused '
            'import và CI analyze đỏ).',
      );
    });

    test('main_shell đẩy thẳng YoutubeExplorerScreen (tầng 2)', () {
      expect(
        shell.contains("import '../features/youtube/youtube_explorer_screen.dart';"),
        isTrue,
      );
      expect(
        shell.contains('MaterialPageRoute(builder: (_) => const YoutubeExplorerScreen())'),
        isTrue,
        reason: 'Nhấn icon YouTube ⇒ Navigator.push tầng 2 (không phải '
            'showModalBottomSheet tầng 1).',
      );
    });

    test('tầng 2 có CẢ ô tìm kiếm lẫn ô dán URL (không mất tính năng)', () {
      // Ô tìm kiếm (keyless, có focus ngay khi mở — IN4-77).
      expect(explorer.contains('_searchCtrl'), isTrue,
          reason: 'Tầng 2 phải có ô tìm kiếm.');
      expect(explorer.contains('_searchFocus.requestFocus();'), isTrue,
          reason: 'Mở lên phải thẳng vào ô tìm kiếm.');
      // Ô dán URL (việc duy nhất mà tầng 1 cũ làm được).
      expect(explorer.contains('_urlCtrl'), isTrue,
          reason: 'Vẫn phải dán được URL như tầng 1 cũ.');
      expect(explorer.contains("context.uiText('Dán URL YouTube...')"), isTrue);
    });

    test('tầng 2 responsive: sidebar chỉ hiện khi đủ rộng', () {
      expect(
        explorer.contains('final isWide = c.maxWidth >= 560;'),
        isTrue,
        reason: 'Tầng 2 giờ là cửa vào DUY NHẤT ⇒ phải dùng được trên '
            'điện thoại đứng (sidebar cố định 195px sẽ ép kết quả còn ~165px).',
      );
      expect(
        explorer.contains('if (isWide) _sidebar(),'),
        isTrue,
        reason: 'Sidebar chỉ được render khi màn đủ rộng.',
      );
      expect(
        explorer.contains('Widget _sidebarContent() => Container('),
        isTrue,
        reason: 'Bộ lọc phải tách khỏi khung 195px để dùng lại ở sheet.',
      );
    });

    test('màn hẹp có nút Bộ lọc mở bottom sheet', () {
      expect(explorer.contains('void _showFilters() {'), isTrue);
      expect(explorer.contains('if (!isWide)'), isTrue,
          reason: 'Nút Bộ lọc chỉ hiện khi màn hẹp (rộng thì đã có sidebar).');
      expect(explorer.contains('Expanded(child: _sidebarContent()),'), isTrue);
    });

    test('giữ Lịch sử xem (từng là tab ở tầng 1 cũ)', () {
      expect(
        explorer.contains("import 'widgets/yt_video_card.dart' show YtHistoryItem;"),
        isTrue,
        reason: 'Tầng 1 cũ có tab Lịch sử ⇒ bỏ tầng 1 không được mất nó.',
      );
      expect(explorer.contains('void _showHistory() {'), isTrue);
      expect(explorer.contains('List<YtVideo> _history = const [];'), isTrue);
    });
  });
}
