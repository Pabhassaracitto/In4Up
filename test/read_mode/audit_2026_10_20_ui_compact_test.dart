// AUDIT-2026-10-20 (owner) — 5 mục giao diện.
//
// Mục 1 — Tab Đọc, chế độ Focus: chọn "Ẩn / Trên / Dưới" KHÔNG có tác dụng.
//   Root cause: màn Đọc chỉ watch `TextProvider` ⇒ `ReadModeController
//   .toggleFocusMode()` gọi `notifyListeners()` nhưng KHÔNG ai nghe ⇒ màn
//   không rebuild ⇒ Focus + vị trí tiêu đề không đổi gì.
// Mục 2 — Tab Đọc: thanh chức năng TRÊN chiếm nhiều không gian trên điện
//   thoại nhỏ ⇒ áp dụng cơ chế 2 TẦNG (gộp ⇄ bung bằng mũi tên) giống
//   thanh phát trong vùng đọc.
// Mục 3 — Tab Nhớ: thanh icon chức năng bị ẩn sau mấy giây (người dùng
//   chưa kịp chọn) ⇒ BỎ tự ẩn, thay bằng bung/gộp bằng mũi tên.
// Mục 4 — Tab Đọc: ô chữ → 1 pop NHỎ (từ + IPA + loại từ + CEFR + độ khó +
//   lưu + nghĩa), "rèm" ở đầu pop kéo lên ⇒ bung thông tin đầy đủ; kèm
//   thêm ảnh cho từ.
// Mục 5 — Tab Nghe/Đọc/Hiểu: header chức năng gọn gàng, tiết kiệm không
//   gian nhưng giữ đồng bộ giữa 3 tab.
//
// Test: source-scan (máy bắt) + widget test cho cơ chế 2 tầng.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/widgets/collapsible_action_bar.dart';

void main() {
  final readScreen =
      File('lib/screens/read_mode/read_mode_screen.dart').readAsStringSync();
  final topBar = File('lib/screens/read_mode/widgets/read_top_bar.dart')
      .readAsStringSync();
  final controller = File(
          'lib/screens/read_mode/controllers/read_mode_controller.dart')
      .readAsStringSync();
  final settingsSheet = File(
          'lib/screens/read_mode/sheets/read_settings_sheet.dart')
      .readAsStringSync();
  final coloredText = File(
          'lib/screens/read_mode/widgets/colored_text_widget.dart')
      .readAsStringSync();
  final miniPop = File('lib/screens/read_mode/widgets/word_mini_pop.dart')
      .readAsStringSync();
  final rememberScreen =
      File('lib/screens/memory_mode/remember_workspace_screen.dart')
          .readAsStringSync();
  final rememberHeader = File(
          'lib/screens/memory_mode/widgets/remember_workspace_header.dart')
      .readAsStringSync();
  final shell = File('lib/screens/main_shell.dart').readAsStringSync();

  group('mục 1 — Focus mode: màn Đọc PHẢI rebuild khi controller đổi', () {
    test('màn Đọc lắng nghe controller (trước đây không có ai nghe)', () {
      expect(readScreen.contains('addListener(_onControllerChanged)'), isTrue,
          reason: 'Không có listener ⇒ notifyListeners() của controller không '
              'ai nghe ⇒ bấm nút Focus KHÔNG đổi gì trên màn.');
      expect(readScreen.contains('removeListener(_onControllerChanged)'), isTrue);
    });

    test('khi controller đổi ⇒ đọc lại vị trí tiêu đề Focus', () {
      expect(readScreen.contains('getReadFocusTitlePosition()'), isTrue);
      expect(
        readScreen.contains(
            "_focusTitlePosition == 'top'") &&
            readScreen.contains("_focusTitlePosition == 'bottom'"),
        isTrue,
        reason: 'Chọn Ẩn/Trên/Dưới phải dựng lại thanh tiêu đề tương ứng.',
      );
    });

    test('đóng sheet Cài đặt ⇒ báo controller refresh (có hiệu lực ngay)', () {
      expect(controller.contains('requestRefresh()'), isTrue);
      expect(settingsSheet.contains('requestRefresh()'), isTrue);
    });

    test('toggle focus đọc trạng thái MỚI (trước dùng giá trị cũ)', () {
      expect(readScreen.contains('!_controller.isFocusMode'), isTrue);
    });
  });

  group('mục 2 — Tab Đọc: thanh trên 2 tầng (gộp ⇄ bung)', () {
    test('top bar dùng CollapsibleActionBar', () {
      expect(topBar.contains('CollapsibleActionBar('), isTrue);
      expect(topBar.contains('collapsible_action_bar.dart'), isTrue);
    });

    test('không còn chip cũ tự dựng (đã gộp về 1 widget chung)', () {
      expect(topBar.contains('class _ColorModeChip'), isFalse);
      expect(topBar.contains('class _WordTapChip'), isFalse);
      expect(topBar.contains('class _AutoSyncChip'), isFalse);
    });
  });

  group('mục 3 — Tab Nhớ: bỏ tự ẩn sau N giây, thay bằng bung/gộp', () {
    test('không còn AutoHideInfoBanner bọc thanh chức năng', () {
      // Kiểm TRA LỜI GỌI widget (không kiểm tra chuỗi trong comment).
      expect(rememberScreen.contains('AutoHideInfoBanner('), isFalse,
          reason: 'AutoHideInfoBanner ẩn cả thanh sau 5 giây ⇒ người dùng '
              'chưa kịp chọn.');
      expect(rememberScreen.contains('auto_hide_banner.dart'), isFalse);
    });

    test('nhóm công cụ "Xem tiến độ" dùng CollapsibleActionBar', () {
      expect(rememberHeader.contains('CollapsibleActionBar('), isTrue);
      expect(rememberHeader.contains('collapsible_action_bar.dart'), isTrue);
    });

    test('giữ nguyên key công cụ (test cũ vẫn tìm được)', () {
      for (final key in [
        'rememberToolWordListKey',
        'rememberToolTimelineKey',
        'rememberToolStatsKey',
        'rememberToolWordMapKey',
        'rememberToolQuickActionsKey',
      ]) {
        expect(rememberHeader.contains(key), isTrue, reason: 'thiếu $key');
      }
    });
  });

  group('mục 4 — pop nhỏ cho ô chữ + "rèm" kéo lên bung thông tin đầy đủ', () {
    test('có widget pop nhỏ riêng với các thông tin cơ bản', () {
      expect(miniPop.contains('class WordMiniPop'), isTrue);
      expect(miniPop.contains('wordMiniPopCurtainKey'), isTrue);
      expect(miniPop.contains('wordMiniPopExpandKey'), isTrue);
      expect(miniPop.contains('wordMiniPopSaveKey'), isTrue);
      expect(miniPop.contains('wordMiniPopImageKey'), isTrue);
      // Thông tin cơ bản owner yêu cầu.
      expect(miniPop.contains('cefrLevel'), isTrue);
      expect(miniPop.contains('userDifficulty'), isTrue);
      expect(miniPop.contains('wordType'), isTrue);
      expect(miniPop.contains('phonetic'), isTrue);
    });

    test('kéo lên ("rèm") ⇒ mở bảng chi tiết đầy đủ', () {
      expect(miniPop.contains('onVerticalDragEnd'), isTrue);
      expect(miniPop.contains('WordActionsSheet.show('), isTrue);
    });

    test('có thêm ảnh (dùng lại cơ chế tìm/chọn ảnh của Worklist)', () {
      expect(miniPop.contains('VocabImagePicker('), isTrue);
    });

    test('chạm đúp và nhấn giữ đều mở pop nhỏ', () {
      expect(coloredText.contains('WordMiniPop.show('), isTrue);
      expect(coloredText.contains('_openMiniPop'), isTrue);
    });

    test('pop có nút quay lại chế độ bôi nhiều chữ (READ-SELECT-002)', () {
      expect(miniPop.contains('onSelectMore'), isTrue);
      expect(coloredText.contains('onSelectMore:'), isTrue);
    });
  });

  group('mục 5 — header chung Nghe/Đọc/Hiểu gọn + đồng bộ', () {
    test('3 tab dùng chung CollapsibleActionBar qua _WorkspaceHeaderActions',
        () {
      expect(shell.contains('class _WorkspaceHeaderActions'), isTrue);
      expect(shell.contains('CollapsibleActionBar('), isTrue);
      expect(shell.contains('collapsible_action_bar.dart'), isTrue);
    });

    test('nhãn + nguồn/chế độ chung một hàng (tiết kiệm bề dọc)', () {
      expect(shell.contains('AUDIT-2026-10-20 (mục 5)'), isTrue);
    });
  });

  group('widget — cơ chế 2 tầng dùng chung', () {
    testWidgets('hẹp: mặc định GỘP (chỉ icon) + có nút mũi tên bung',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: CollapsibleActionBar(
                actions: [
                  CollapsibleAction(
                    label: 'Dịch',
                    icon: Icons.translate,
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Gộp: KHÔNG hiện nhãn, nhưng CÓ nút mũi tên để bung.
      expect(find.text('Dịch'), findsNothing);
      expect(find.byKey(collapsibleActionBarToggleKey), findsOneWidget);

      // Bấm mũi tên ⇒ bung ra nhãn.
      await tester.tap(find.byKey(collapsibleActionBarToggleKey));
      await tester.pumpAndSettle();
      expect(find.text('Dịch'), findsOneWidget);
    });

    testWidgets('rộng: luôn BUNG (có nhãn), không hiện mũi tên',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: CollapsibleActionBar(
                actions: [
                  CollapsibleAction(
                    label: 'Dịch',
                    icon: Icons.translate,
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dịch'), findsOneWidget);
      expect(find.byKey(collapsibleActionBarToggleKey), findsNothing);
    });
  });
}
