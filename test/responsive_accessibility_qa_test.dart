import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/qa/responsive_accessibility_qa.dart';
import 'package:in4up/core/responsive/app_responsive.dart';
import 'package:in4up/core/responsive/safe_area_overlay_policy.dart';
import 'package:in4up/widgets/shell/command_palette.dart';
import 'package:in4up/widgets/shell/global_chat_surface.dart';

/// Bằng chứng đo trên widget thật — chỉ `flutter_test` mới đo được.
/// Gom lại rồi nạp vào harness ở test tổng hợp (khai báo CUỐI file).
final List<I4uResponsiveEvidence> _widgetEvidence = <I4uResponsiveEvidence>[];

void _record({
  required String id,
  required I4uResponsiveArea area,
  required String requirement,
  required bool passed,
  String? detail,
}) {
  _widgetEvidence.add(I4uResponsiveEvidence(
    id: id,
    area: area,
    requirement: requirement,
    passed: passed,
    detail: detail,
  ));
}

void main() {
  // ───────────────────────── logic thuần (5/7 vùng) ─────────────────────────
  test('C-30 — harness logic giữ đúng 5 vùng, và KHÔNG tự nhận đạt 2 vùng cần widget', () async {
    final report = await const I4uResponsiveQa().run();

    expect(
      report.failures
          .map((failure) => '${failure.id} (${failure.area.slug}): ${failure.detail}')
          .toList(),
      isEmpty,
      reason: report.toSummary(),
    );

    // Cổng chặn: chưa có bằng chứng widget ⇒ 2 vùng đó phải bị coi là CHƯA ĐO ĐƯỢC.
    expect(
      report.uncoveredAreas.toSet(),
      <I4uResponsiveArea>{
        I4uResponsiveArea.screenReaderLabels,
        I4uResponsiveArea.touchTargets,
      },
    );
    expect(report.isComplete, isFalse, reason: 'thiếu bằng chứng mà vẫn nhận đạt');
    expect(report.toQualityRun().hasBlocker, isTrue,
        reason: 'vùng chưa đo được phải là blocker, không phải pass rỗng');
    expect(report.toQualityRun().isReadyForFreeze, isFalse);
  });

  test('C-30 — drift guard: ngưỡng cứng trong main_shell phải khớp policy (không đẻ ngưỡng thứ hai)', () {
    final source = File('lib/screens/main_shell.dart').readAsStringSync();
    final literals = RegExp(r'>= ?(\d{3,4})\b')
        .allMatches(source)
        .map((match) => match.group(1)!)
        .toSet();
    const policyThresholds = <int>{600, 1024, 1440};
    final unknown = literals.where((value) => !policyThresholds.contains(int.parse(value))).toList();

    _record(
      id: 'C30-W-ORI-04',
      area: I4uResponsiveArea.orientation,
      requirement: 'Ngưỡng breakpoint trong shell trùng policy AppResponsive (không có ngưỡng thứ hai)',
      passed: unknown.isEmpty,
      detail: unknown.isEmpty
          ? 'ngưỡng dùng trong shell: $literals (đều thuộc policy)'
          : 'ngưỡng lạ ngoài policy: $unknown',
    );

    expect(unknown, isEmpty);
  });

  // ───────────────────────── safe-area (widget thật) ─────────────────────────
  testWidgets('C-30 SAF — surface nổi bám inset runtime: mặc định, notch, bàn phím', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    const childKey = Key('c30-floating-child');

    Future<double> bottomGap({required double safeBottom, required double viewBottom}) async {
      tester.view.padding = FakeViewPadding(bottom: safeBottom);
      tester.view.viewInsets = FakeViewPadding(bottom: viewBottom);
      await tester.pumpWidget(const MaterialApp(
        home: I4uSafeAreaFloatingHost(
          navigationHeight: 64,
          child: SizedBox(key: childKey, width: 40, height: 10),
        ),
      ));
      await tester.pump();
      return 800 - tester.getBottomLeft(find.byKey(childKey)).dy;
    }

    final resting = await bottomGap(safeBottom: 0, viewBottom: 0);
    final notched = await bottomGap(safeBottom: 34, viewBottom: 0);
    final keyboard = await bottomGap(safeBottom: 34, viewBottom: 300);

    _record(
      id: 'C30-W-SAF-01',
      area: I4uResponsiveArea.safeArea,
      requirement: 'Offset = inset hiệu dụng + navigation + spacing, đo trên widget thật',
      passed: resting == 76 && notched == 110 && keyboard == 376,
      detail: 'đo được: mặc định=$resting (mong 76), notch=$notched (mong 110), '
          'bàn phím=$keyboard (mong 376)',
    );

    expect(resting, 76, reason: 'navigation 64 + spacing 12');
    expect(notched, 110, reason: 'safe-area 34 + 64 + 12');
    expect(keyboard, 376, reason: 'bàn phím 300 thay cho safe-area (max), + 64 + 12');
  });

  // ─────────────── Command Palette: nhãn đọc + vùng chạm + chữ lớn ───────────────
  const commands = <I4uCommand>[
    I4uCommand(id: 'open-reader', label: 'Mở Đọc', icon: Icons.menu_book),
    I4uCommand(id: 'open-listen', label: 'Mở Nghe', icon: Icons.headphones),
  ];

  Widget paletteHost({double textScale = 1.0}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showI4uCommandPalette(context, commands: commands),
                child: const Text('mở bảng lệnh'),
              ),
            ),
          ),
        ),
      );

  testWidgets('C-30 A11Y — Command Palette: mỗi lệnh có nhãn đọc và vùng chạm ≥ 48', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(paletteHost());
    await tester.tap(find.text('mở bảng lệnh'));
    await tester.pumpAndSettle();

    var allLabelled = true;
    for (final command in commands) {
      if (find.bySemanticsLabel(command.label).evaluate().isEmpty) {
        allLabelled = false;
      }
    }
    _record(
      id: 'C30-W-A11Y-01',
      area: I4uResponsiveArea.screenReaderLabels,
      requirement: 'Mỗi mục trong Command Palette có nhãn đọc được (không icon trần)',
      passed: allLabelled,
      detail: allLabelled
          ? 'đã tìm thấy nhãn cho ${commands.length} lệnh'
          : 'thiếu nhãn cho ít nhất 1 lệnh',
    );
    expect(allLabelled, isTrue,
        reason: 'lệnh thiếu nhãn ⇒ screen reader chỉ đọc "button" • '
            'đo được: ${_widgetEvidence.last.detail}');

    final tiles = find.byType(ListTile);
    expect(tiles.evaluate().length, commands.length);
    var minRowHeight = double.infinity;
    for (var index = 0; index < commands.length; index++) {
      minRowHeight = minRowHeight < tester.getSize(tiles.at(index)).height
          ? minRowHeight
          : tester.getSize(tiles.at(index)).height;
    }
    _record(
      id: 'C30-W-TCH-01',
      area: I4uResponsiveArea.touchTargets,
      requirement: 'Vùng chạm của mục lệnh ≥ 48 logical px',
      passed: minRowHeight >= 48,
      detail: 'chiều cao nhỏ nhất đo được: $minRowHeight',
    );
    expect(minRowHeight, greaterThanOrEqualTo(48.0),
        reason: 'vùng chạm mục lệnh • đo được: ${_widgetEvidence.last.detail}');
  });

  testWidgets('C-30 TXT — Command Palette không tràn ở trần cỡ chữ chính sách (1.15)', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    // Trần chính sách = AppResponsive.clampTextScale(3.0) = 1.15.
    final ceiling = AppResponsive.clampTextScale(3.0);
    await tester.pumpWidget(paletteHost(textScale: ceiling));
    await tester.tap(find.text('mở bảng lệnh'));
    await tester.pumpAndSettle();

    final overflow = tester.takeException();
    _record(
      id: 'C30-W-TXT-01',
      area: I4uResponsiveArea.textScale,
      requirement: 'Command Palette hiển thị được ở trần cỡ chữ chính sách (không tràn)',
      passed: overflow == null,
      detail: overflow == null ? 'trần $ceiling: không tràn' : 'tràn: $overflow',
    );
    expect(overflow, isNull, reason: 'tràn ở trần cỡ chữ chính sách');
  });

  // ─────────── Chat surface: nhãn + vùng chạm + bàn phím + xoay máy ───────────
  Widget chatHost() => MaterialApp(
        home: Scaffold(
          body: I4uGlobalChatSurface(onSend: (message) async => 'echo: $message'),
        ),
      );

  testWidgets('C-30 A11Y — Chat surface: nút icon có nhãn đọc và vùng chạm đủ lớn', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(chatHost());
    await tester.pumpAndSettle();

    final send = tester.getSemantics(find.byTooltip('Gửi')).getSemanticsData();
    final hasLabel = send.label.isNotEmpty || send.tooltip.isNotEmpty;
    _record(
      id: 'C30-W-A11Y-02',
      area: I4uResponsiveArea.screenReaderLabels,
      requirement: 'Nút gửi (icon trần) có nhãn đọc được',
      passed: hasLabel,
      detail: hasLabel ? 'label="${send.label}" tooltip="${send.tooltip}"' : 'không có nhãn',
    );
    expect(hasLabel, isTrue,
        reason: 'nút gửi icon-only không có nhãn cho screen reader • '
            'đo được: ${_widgetEvidence.last.detail}');

    final sendSize = tester.getSize(find.byTooltip('Gửi'));
    // Ghi lại số đo TRƯỚC khi kiểm để reason luôn có dữ liệu chẩn đoán.
    _record(
      id: 'C30-W-TCH-02',
      area: I4uResponsiveArea.touchTargets,
      requirement: 'Nút icon ≥ 40 logical px VÀ tap target không bị shrinkWrap (vùng chạm 48)',
      passed: false,
      detail: 'đang đo… kích thước nút gửi=$sendSize',
    );
    _widgetEvidence.removeLast();
    final theme = Theme.of(tester.element(find.byType(I4uGlobalChatSurface)));
    // IconButton Material 3 mặc định 40×40 + MaterialTapTargetSize.padded ⇒ vùng chạm
    // hiệu dụng ≥ 48. Cả hai điều kiện đều được kiểm, không chỉ nhìn kích thước widget.
    final targetOk = sendSize.width >= 40 && sendSize.height >= 40 &&
        theme.materialTapTargetSize == MaterialTapTargetSize.padded;
    _record(
      id: 'C30-W-TCH-02',
      area: I4uResponsiveArea.touchTargets,
      requirement: 'Nút icon ≥ 40 logical px VÀ tap target không bị shrinkWrap (vùng chạm 48)',
      passed: targetOk,
      detail: 'kích thước=$sendSize, materialTapTargetSize=${theme.materialTapTargetSize}',
    );
    expect(targetOk, isTrue);
  });

  testWidgets('C-30 KBD — bàn phím mở không che ô nhập của Chat surface', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewInsets = FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(chatHost());
    await tester.pumpAndSettle();

    final inputBottom = tester.getBottomLeft(find.byType(TextField)).dy;
    const keyboardTop = 800 - 300;
    final visible = inputBottom <= keyboardTop + 0.5;
    _record(
      id: 'C30-W-KBD-01',
      area: I4uResponsiveArea.keyboard,
      requirement: 'Ô nhập nằm trên bàn phím (bottom ≤ mép bàn phím)',
      passed: visible,
      detail: 'đáy ô nhập=$inputBottom, mép bàn phím=$keyboardTop',
    );
    expect(visible, isTrue, reason: 'bàn phím che ô nhập');
  });

  testWidgets('C-30 ORI — xoay dọc ↔ ngang: không tràn, ô nhập vẫn còn', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(chatHost());
    await tester.pumpAndSettle();
    final portraitOk = tester.takeException() == null && find.byType(TextField).evaluate().isNotEmpty;

    tester.view.physicalSize = const Size(800, 400); // ngang
    await tester.pumpAndSettle();
    final landscapeOverflow = tester.takeException();
    final landscapeOk = landscapeOverflow == null && find.byType(TextField).evaluate().isNotEmpty;

    _record(
      id: 'C30-W-ORI-01',
      area: I4uResponsiveArea.orientation,
      requirement: 'Đổi hướng chỉ đổi bố cục: không tràn, không mất ô nhập',
      passed: portraitOk && landscapeOk,
      detail: portraitOk
          ? (landscapeOk ? 'dọc OK, ngang OK' : 'ngang lỗi: $landscapeOverflow')
          : 'dọc lỗi ngay từ đầu',
    );
    expect(portraitOk, isTrue);
    expect(landscapeOk, isTrue, reason: 'xoay ngang làm tràn/mất ô nhập');
  });

  // ─────────────── tổng hợp: phải khai báo CUỐI để có đủ bằng chứng ───────────────
  test('C-30 — báo cáo đầy đủ (logic + widget) mới được coi là đạt', () async {
    final report = await I4uResponsiveQa(
      evidence: List<I4uResponsiveEvidence>.unmodifiable(_widgetEvidence),
    ).run();

    expect(
      report.failures
          .map((failure) => '${failure.id} (${failure.area.slug}): ${failure.detail}')
          .toList(),
      isEmpty,
      reason: report.toSummary(),
    );
    expect(report.uncoveredAreas, isEmpty, reason: report.toSummary());
    expect(report.isComplete, isTrue, reason: report.toSummary());

    final run = report.toQualityRun();
    expect(run.hasBlocker, isFalse, reason: report.toSummary());
    expect(run.isReadyForFreeze, isTrue, reason: report.toSummary());
  });
}
