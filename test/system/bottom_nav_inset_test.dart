// test/system/bottom_nav_inset_test.dart
//
// SAFE-INSET-001 — chống "thanh nội dung / bottom bar chìm dưới thanh điều
// hướng hệ thống" (Android gesture bar / 3-button nav, iOS home indicator).
//
// Bối cảnh: `targetSdk = 35` (android/app/build.gradle.kts) ⇒ Android 15 ép
// edge-to-edge, cửa sổ app vẽ TRÀN xuống dưới thanh điều hướng. Flutter tự chừa
// cho `Scaffold.bottomNavigationBar`, nhưng **KHÔNG** tự chừa cho thanh neo đáy
// tự dựng trong `Stack`/`Positioned`.
//
// Test này gồm 3 lớp:
//   1. Đơn vị: `systemBottomInset` / `bottomInsetOffset` / `bottomInsetExtra`.
//   2. Widget: `BottomSafeArea` chừa đúng inset, tôn trọng `minimum`, và trả về
//      nguyên vẹn widget con khi inset = 0 (không thêm layout layer).
//   3. Quét nguồn (source-scan): những surface đã biết là route toàn màn hình
//      PHẢI dùng helper — nếu ai đó xoá, test đỏ ngay.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/utils/system_insets.dart';

/// Bọc [child] trong MediaQuery có inset đáy [bottom] (giả lập thanh điều hướng).
Widget _withBottomInset(double bottom, Widget child) {
  return MediaQuery(
    data: MediaQueryData(padding: EdgeInsets.only(bottom: bottom)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    ),
  );
}

void main() {
  group('SAFE-INSET-001 — đơn vị', () {
    testWidgets('systemBottomInset đọc đúng padding hệ thống',
        (tester) async {
      late double inside34;
      late double inside0;
      await tester.pumpWidget(_withBottomInset(
        34,
        Builder(builder: (context) {
          inside34 = systemBottomInset(context);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpWidget(_withBottomInset(
        0,
        Builder(builder: (context) {
          inside0 = systemBottomInset(context);
          return const SizedBox.shrink();
        }),
      ));
      expect(inside34, 34);
      expect(inside0, 0);
    });

    testWidgets('bottomInsetOffset = base + inset, clamp >= 0', (tester) async {
      late double noInset;
      late double withInset;
      late double negative;
      await tester.pumpWidget(_withBottomInset(
        0,
        Builder(builder: (context) {
          noInset = bottomInsetOffset(context, 16);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpWidget(_withBottomInset(
        34,
        Builder(builder: (context) {
          withInset = bottomInsetOffset(context, 16);
          negative = bottomInsetOffset(context, -100);
          return const SizedBox.shrink();
        }),
      ));
      expect(noInset, 16, reason: 'không có thanh điều hướng ⇒ giữ nguyên');
      expect(withInset, 50, reason: '16 + 34');
      expect(negative, 0, reason: 'clamp: base âm không được ra số âm');
    });

    testWidgets('bottomInsetExtra chỉ cộng cạnh đáy', (tester) async {
      late EdgeInsets result;
      await tester.pumpWidget(_withBottomInset(
        34,
        Builder(builder: (context) {
          result = bottomInsetExtra(context, const EdgeInsets.all(8));
          return const SizedBox.shrink();
        }),
      ));
      expect(result.left, 8);
      expect(result.top, 8);
      expect(result.right, 8);
      expect(result.bottom, 42, reason: '8 + 34');
    });
  });

  group('SAFE-INSET-001 — BottomSafeArea', () {
    testWidgets('chừa đúng inset hệ thống', (tester) async {
      await tester.pumpWidget(_withBottomInset(
        34,
        const BottomSafeArea(child: SizedBox(height: 50, width: 10)),
      ));
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect((padding.padding as EdgeInsets).bottom, 34);
    });

    testWidgets('tôn trọng minimum khi inset nhỏ hơn', (tester) async {
      await tester.pumpWidget(_withBottomInset(
        4,
        const BottomSafeArea(minimum: 12, child: SizedBox(height: 50)),
      ));
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect((padding.padding as EdgeInsets).bottom, 12);
    });

    testWidgets('inset = 0 và minimum = 0 ⇒ KHÔNG tạo Padding', (tester) async {
      await tester.pumpWidget(_withBottomInset(
        0,
        const BottomSafeArea(child: SizedBox(height: 40, key: Key('kid'))),
      ));
      expect(find.byType(Padding), findsNothing,
          reason: 'máy không có thanh điều hướng ⇒ chi phí layout phải = 0');
      expect(find.byKey(const Key('kid')), findsOneWidget);
    });
  });

  group('SAFE-INSET-001 — quét nguồn (surface route toàn màn hình)', () {
    /// Đọc file và cắt hết comment dạng `//` để chỉ quét CODE THẬT — nếu không,
    /// chính comment giải thích cũng sẽ làm test "pass" một cách giả tạo.
    String codeOnly(String path) {
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

    test('PDF reader: thanh TTS neo đáy phải nằm trong BottomSafeArea', () {
      final code = codeOnly('lib/features/pdf_reader/pdf_reader_screen.dart');
      expect(code.contains('BottomSafeArea'), isTrue,
          reason: 'PDF reader là route toàn màn hình — thanh TTS neo '
              '`Positioned(bottom: 0)` sẽ chìm dưới thanh điều hướng nếu '
              'không bọc BottomSafeArea');
    });

    test('PDF reader: chú giải + padding Text Mode phải cộng inset', () {
      final code = codeOnly('lib/features/pdf_reader/pdf_reader_screen.dart');
      final rawBottomLiterals = RegExp(r'bottom:\s*(88|84)\s*,')
          .allMatches(code)
          .map((m) => m.group(0))
          .toList();
      expect(rawBottomLiterals, isEmpty,
          reason: 'Còn neo đáy bằng số cứng (${rawBottomLiterals.join(", ")}) '
              '⇒ phải đổi sang bottomInsetOffset(context, N)');
      expect(code.contains('bottomInsetOffset'), isTrue);
    });

    test('Web reader: chú giải phải cộng inset', () {
      final code = codeOnly('lib/features/web_reader/web_reader_screen.dart');
      final raw = RegExp(r'bottom:\s*16\s*,').allMatches(code).length;
      expect(raw, 0,
          reason: 'Còn $raw neo đáy số cứng 16 ⇒ phải dùng bottomInsetOffset');
      expect(code.contains('bottomInsetOffset'), isTrue);
    });

    test('Shell: bottomNavigationBar phải được chừa safe area', () {
      final code = codeOnly('lib/screens/main_shell.dart');
      expect(RegExp(r'SafeArea\([\s\S]{0,80}?bottom:\s*false').hasMatch(code) ||
              code.contains('SafeArea'), isTrue,
          reason: 'Bottom nav của shell phải chừa vùng thanh điều hướng');
      // Bottom nav là thanh neo đáy DUY NHẤT được Flutter tự chừa (Scaffold),
      // nhưng chỉ khi bên trong nó có SafeArea — repo đang có, pin lại.
      final navBlock = RegExp(r'Widget _buildBottomNav[\s\S]*?\n  \}')
          .firstMatch(code);
      expect(navBlock, isNotNull, reason: 'Không tìm thấy _buildBottomNav');
      expect(navBlock!.group(0)!.contains('SafeArea'), isTrue,
          reason: '_buildBottomNav phải bọc SafeArea');
    });

    test('Video player: phụ đề phải cộng inset (toàn màn hình)', () {
      final code =
          codeOnly('lib/features/video/widgets/video_player_screen.dart');
      final raw = RegExp(r'bottom:\s*16\s*,').allMatches(code).length;
      expect(raw, 0,
          reason: 'Phụ đề neo `bottom: 16` cứng sẽ chìm dưới thanh điều hướng '
              'khi xem toàn màn hình ⇒ phải dùng bottomInsetOffset');
      expect(code.contains('bottomInsetOffset'), isTrue);
    });

    test('Bottom sheet / dialog dạng kéo lên do framework chừa (không pin)', () {
      // Ghi chú có chủ đích: `showModalBottomSheet` / `Scaffold.bottomSheet`
      // do Flutter tự chừa inset ⇒ KHÔNG cần BottomSafeArea, tránh cộng 2 lần.
      expect(true, isTrue);
    });
  });
}
