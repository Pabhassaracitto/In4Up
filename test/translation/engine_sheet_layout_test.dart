// PSRC-191 (owner 2026-11-11) — *"Sắp xếp lại UI Translation engines"*
// (audit v1.27.0: rối, chữ dày đặc).
//
// Vấn đề: sheet "Engine dịch thuật" là MỘT cột dài gồm khối trạng thái engine,
// DeepLX (ô URL + 2 dòng chú thích + nút thử), 3 nhóm model, công tắc offline,
// glossary, nút Lưu — tất cả cùng cỡ chữ, cùng khoảng cách ⇒ user mở ra không
// biết đọc từ đâu.
//
// Hợp đồng sau khi sắp xếp lại:
//   1. Mỗi nhóm là một THẺ có tiêu đề (`EngineSheetSection`), nhóm nâng cao
//      THU GỌN mặc định ⇒ màn hình đầu chỉ còn nội dung hay dùng.
//   2. Thẻ thu gọn KHÔNG dựng children (bớt chữ thật, không chỉ ẩn).
//   3. Nhóm "Thường dùng" (gói offline) mở sẵn; nhóm còn lại đóng.
//   4. Không mất chức năng nào: tải/xoá gói, Thêm ngôn ngữ, Hy-MT import/tải,
//      chọn engine offline, công tắc chỉ-offline, glossary, Lưu.
//
// Test widget thuần (không plugin, không mạng) + source-scan.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/translation/widgets/engine_sheet_section.dart';

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Thiếu file: $path');
  return file.readAsStringSync();
}

void main() {
  final toolbar = _read('lib/features/translation/translation_toolbar.dart');

  group('EngineSheetSection — thẻ nhóm (thu gọn được)', () {
    testWidgets('mở sẵn khi initiallyExpanded=true, hiện cả nội dung',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineSheetSection(
            title: 'Gói dịch offline',
            subtitle: 'Dịch không cần mạng.',
            initiallyExpanded: true,
            children: const <Widget>[Text('NOI-DUNG-NHOM')],
          ),
        ),
      ));
      expect(find.text('Gói dịch offline'), findsOneWidget);
      expect(find.text('Dịch không cần mạng.'), findsOneWidget);
      expect(find.text('NOI-DUNG-NHOM'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
    });

    testWidgets('mặc định THU GỌN: nội dung không được dựng', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineSheetSection(
            title: 'DeepLX Server URL (tùy chọn)',
            children: const <Widget>[Text('NOI-DUNG-NHOM')],
          ),
        ),
      ));
      expect(find.text('DeepLX Server URL (tùy chọn)'), findsOneWidget,
          reason: 'Tiêu đề luôn hiện để user biết có nhóm này.');
      expect(find.text('NOI-DUNG-NHOM'), findsNothing,
          reason: 'Thu gọn phải BỚT CHỮ thật (không dựng children).');
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('bấm tiêu đề ⇒ mở ra; bấm lần nữa ⇒ thu lại', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineSheetSection(
            title: 'Nhóm',
            initiallyExpanded: false,
            children: const <Widget>[Text('NOI-DUNG-NHOM')],
          ),
        ),
      ));
      expect(find.text('NOI-DUNG-NHOM'), findsNothing);

      await tester.tap(find.text('Nhóm'));
      await tester.pumpAndSettle();
      expect(find.text('NOI-DUNG-NHOM'), findsOneWidget);

      await tester.tap(find.text('Nhóm'));
      await tester.pumpAndSettle();
      expect(find.text('NOI-DUNG-NHOM'), findsNothing);
    });

    testWidgets('badge trạng thái hiện ngay trên tiêu đề khi thu gọn',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineSheetSection(
            title: 'Gói dịch offline',
            trailing: const Text('2/19'),
            children: const <Widget>[Text('NOI-DUNG-NHOM')],
          ),
        ),
      ));
      expect(find.text('2/19'), findsOneWidget,
          reason: 'Thu gọn vẫn phải thấy tình trạng gói, không cần mở.');
    });
  });

  group('Sheet engine — mỗi nhóm một thẻ, không còn cột chữ dày', () {
    test('dùng EngineSheetSection cho các nhóm, không nhồi hết vào Column', () {
      expect(toolbar, contains('EngineSheetSection('),
          reason: 'PSRC-191: nhóm phải là thẻ có tiêu đề.');
      expect(toolbar, contains("import 'widgets/engine_sheet_section.dart'"));
      // Các nhóm phải tách khỏi build() thành method riêng — build() dài
      // nghĩa là lại quay về "một cột dài".
      for (final method in <String>[
        'Widget _buildOfflineOnlyCard()',
        'Widget _buildHymtSection()',
        'Widget _buildLlmSection()',
        'Widget _buildDeeplxSection()',
        'Widget _buildGlossaryCard()',
        'List<Widget> _buildOfflinePackChildren(',
      ]) {
        expect(toolbar, contains(method), reason: 'Thiếu $method');
      }
    });

    test('nhóm gói offline MỞ SẴN, các nhóm nâng cao ĐÓNG', () {
      final packStart = toolbar.indexOf("title: context.uiText('Gói dịch offline')");
      expect(packStart, greaterThan(0));
      final packBlock = toolbar.substring(packStart, packStart + 400);
      expect(packBlock, contains('initiallyExpanded: true'),
          reason: 'Gói offline là việc hay làm nhất ⇒ phải mở sẵn.');

      // DeepLX/Hy-MT/LLM không được mở sẵn (mặc định false).
      for (final title in <String>[
        "context.uiText('DeepLX Server URL (tùy chọn)')",
        "context.uiText('Dịch bằng LLM (Server & API)')",
      ]) {
        final idx = toolbar.indexOf(title);
        expect(idx, greaterThan(0), reason: 'Thiếu nhóm $title');
        final block = toolbar.substring(idx, idx + 500);
        expect(block.contains('initiallyExpanded: true'), isFalse,
            reason: '$title không nên mở sẵn (là nhóm nâng cao).');
      }
    });

    test('PSRC-191 không làm mất chức năng nào', () {
      // Tải/xoá gói (PSRC-182), thêm ngôn ngữ (PSRC-28), Hy-MT, công tắc
      // offline, glossary, Lưu.
      for (final pin in <String>[
        'Future<void> _downloadModel(String code)',
        'Future<void> _deleteModel(String code)',
        "_catalog.primary",
        "_catalog.extra",
        "context.uiText('Import .gguf')",
        'HyMtOfflinePreference.hymt',
        'widget.service.offlineOnly = v',
        'showGlossarySheet(',
        'void _saveAndClose()',
        "context.uiText('Lưu')",
      ]) {
        expect(toolbar, contains(pin), reason: 'Thiếu $pin sau khi sắp xếp lại.');
      }
    });

    test('Lưu vẫn chặn URL DeepLX rác trước khi đóng sheet', () {
      // AUDIT-1.21.0 #6 — nếu ai đó "dọn" nút Lưu thành Navigator.pop trơn
      // thì link hướng dẫn lại được lưu làm endpoint.
      final start = toolbar.indexOf('void _saveAndClose()');
      expect(start, greaterThan(0));
      final body = toolbar.substring(start, start + 900);
      expect(body, contains('assessDeepLXEndpoint(raw)'));
      expect(body, contains('DeepLXEndpointIssue.notConfigured'));
      expect(body, contains('widget.service.configure(deeplxUrl: raw)'));
      expect(body, contains('Navigator.pop(context)'));
    });
  });
}
