// AGENTS.md — Quy tắc vàng #5: locale ≠ tiếng Việt → chrome UI không được còn
// tiếng Việt; thiếu bản dịch thì hiện English, không bao giờ fallback về `vi`.
//
// Vì sao cần file này (bối cảnh thật): bước CI *"Rule 5 test"* chỉ quét CATALOG
// đã sinh (`generatedUiTranslations`). Một nhãn hard-code trong widget **không
// đi qua catalog** thì không ai bắt — C-30 (`docs/ux/42` §4.2) tìm thấy đúng 7
// nhãn như vậy trong `lib/widgets/shell/` (command palette + global chat).
// Test này là máy bắt 3 tầng cho vùng đó:
//   1. NGUỒN: mọi literal có dấu Việt trong `lib/widgets/shell/` phải được bọc
//      `uiText(...)`/`tr(...)` — không nhờ shim `Text` "bắt hộ" (AGENTS: shim chỉ
//      exact, không template).
//   2. CATALOG: mỗi nhãn bọc đó phải dịch được cho MỌI locale ≠ vi (en + T2
//      thiếu bản dịch thì rơi về en — không rơi về vi).
//   3. RUNTIME: dựng thật 2 surface ở locale `en`, quét mọi chuỗi render ra
//      (Text/RichText/Tooltip) — không được còn ký tự Việt nào.
//
// KHÔNG áp dụng cho: nội dung user (tin nhắn, tài liệu), output AI, transcript.
// Vì vậy `global_chat_surface.dart` render bong bóng tin nhắn bằng
// `material.Text` (có tiền tố) — đường đó cố tình KHÔNG đi qua cơ chế dịch.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/language/app_ui_translations.dart';
import 'package:in4up/widgets/shell/command_palette.dart';
import 'package:in4up/widgets/shell/global_chat_surface.dart';

/// Ký tự chỉ có ở tiếng Việt (loại các chữ có dấu trùng Romance: é/á/ó/è/ù...).
final RegExp _viDiacritics = RegExp(
  r'[đĐơƠưƯ]'
  r'|[àáảãạằắẳẵặầấẩẫậ]'
  r'|[èéẻẽẹềếểễệ]'
  r'|[ìíỉĩị]'
  r'|[òóỏõọồốổỗộờớởỡợ]'
  r'|[ùúủũụừứửữự]'
  r'|[ỳýỷỹỵ]',
  caseSensitive: false,
);

/// Mọi literal chuỗi một dòng (bỏ literal có nội suy `$`).
final RegExp _literal = RegExp(r"""['']([^'\\\n$]{3,})['']""");

/// Literal nằm NGAY trong lời gọi dịch: `uiText('...')` / `tr('...')`.
final RegExp _wrappedCall = RegExp(r"""(?:uiText|tr)\(\s*['']([^'\\\n$]{3,})['']""");

/// Vùng chrome được canh bởi test này.
const String _shellDir = 'lib/widgets/shell';

/// Ngoại lệ hợp lệ (literal Việt không cần dịch vì là NỘI DUNG, kèm lý do).
/// Cố tình rỗng: vùng `lib/widgets/shell/` chỉ có chrome.
const Map<String, String> _contentAllowlist = <String, String>{};

List<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const <File>[];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Chuỗi đang thực sự được render: Text (data), RichText (mọi span) và Tooltip.
List<String> _renderedStrings(WidgetTester tester) {
  final out = <String>[];
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data;
    if (data != null && data.isNotEmpty) out.add(data);
  }
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    final plain = widget.text.toPlainText();
    if (plain.isNotEmpty) out.add(plain);
  }
  for (final widget in tester.widgetList<Tooltip>(find.byType(Tooltip))) {
    final message = widget.message;
    if (message != null && message.isNotEmpty) out.add(message);
  }
  return out;
}

void main() {
  group('Rule 5 — chrome shell (lib/widgets/shell) không tiếng Việt khi locale ≠ vi',
      () {
    test('nguồn: mọi literal có dấu Việt đều được bọc uiText/tr', () {
      final files = _dartFiles(_shellDir);
      expect(files.length, greaterThanOrEqualTo(2),
          reason: 'không thấy mã shell — sai đường dẫn? test phải chạy từ gốc repo');

      final unwrapped = <String>[];
      final wrapped = <String>{};
      for (final file in files) {
        final src = file.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
        for (final match in _literal.allMatches(src)) {
          final label = match.group(1)!;
          if (!_viDiacritics.hasMatch(label)) continue;
          if (_contentAllowlist.containsKey(label)) continue;
          // `uiText(`/`tr(` phải nằm ngay trước literal (cho phép xuống dòng).
          final before = src.substring(
            match.start > 60 ? match.start - 60 : 0,
            match.start,
          );
          if (RegExp(r'(?:uiText|tr)\(\s*$').hasMatch(before)) {
            wrapped.add(label);
          } else {
            unwrapped.add('${file.path}: $label');
          }
        }
      }

      expect(
        unwrapped,
        isEmpty,
        reason: 'Chuỗi chrome tiếng Việt hard-code ⇒ locale ≠ vi hiện nguyên '
            'tiếng Việt (rule #5). Bọc `context.uiText(...)` + đăng ký English '
            'trong `lib/core/language/priority_ui_overrides.dart` và '
            '`tool/legacy_ui_english_overrides.json`.\n${unwrapped.join('\n')}',
      );

      // Cổng chặn "pass rỗng": vùng shell hiện có 7 nhãn Việt đã bọc. Nếu con số
      // này đổi vì lý do thật, cập nhật kèm lý do — đừng hạ xuống cho xanh.
      expect(
        wrapped.length,
        greaterThanOrEqualTo(7),
        reason: 'máy quét không tìm thấy nhãn Việt nào trong $_shellDir — '
            'regex hỏng hoặc chrome đã bị gỡ; cả hai đều phải xem lại tay',
      );
    });

    test('catalog: mỗi nhãn bọc dịch được ở mọi locale ≠ vi, không rơi về vi', () {
      final files = _dartFiles(_shellDir);
      final labels = <String>{};
      for (final file in files) {
        final src = file.readAsStringSync().replaceAll(RegExp(r'//[^\n]*'), '');
        for (final match in _wrappedCall.allMatches(src)) {
          if (_viDiacritics.hasMatch(match.group(1)!)) labels.add(match.group(1)!);
        }
      }
      expect(labels.length, greaterThanOrEqualTo(7),
          reason: 'không trích được nhãn bọc nào — regex lệch với mã nguồn?');

      const nonVietnamese = ['en', 'hi', 'zh', 'zh_TW', 'si', 'ja'];
      final failures = <String>[];
      for (final label in labels) {
        if (!AppUITranslations.containsSource(label)) {
          failures.add('$label → thiếu key trong catalog (sẽ hiện nguyên tiếng Việt)');
          continue;
        }
        for (final locale in nonVietnamese) {
          final translated = AppUITranslations.translate(label, locale);
          if (translated == label) {
            failures.add('$label [$locale] → trả nguyên tiếng Việt');
          } else if (_viDiacritics.hasMatch(translated)) {
            failures.add('$label [$locale] → "$translated" còn dấu Việt');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    testWidgets('runtime: Global Chat ở locale en không render ký tự Việt',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: I4uGlobalChatSurface(
              onSend: (message) async => 'echo: $message',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rendered = _renderedStrings(tester);
      expect(rendered, isNotEmpty, reason: 'không quét được chuỗi nào — test vô nghĩa');
      expect(
        rendered.where(_viDiacritics.hasMatch).toList(),
        isEmpty,
        reason: 'chrome Global Chat còn tiếng Việt ở locale `en`',
      );

      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((w) => w.message ?? '')
          .toList();
      expect(tooltips, contains('Send'),
          reason: 'tooltip nút gửi phải là English ở locale `en`');
      expect(rendered, contains('Ask a question to get started.'));
      expect(rendered, contains('No source context'));

      // Không có `onResetContext` ⇒ nút đổi context không được dựng.
      expect(tooltips, isNot(contains('Change context')));
    });

    testWidgets('runtime: Command Palette ở locale en không render ký tự Việt',
        (tester) async {
      const commands = <I4uCommand>[
        I4uCommand(id: 'open-reader', label: 'Open Reader', icon: Icons.menu_book),
      ];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showI4uCommandPalette(context, commands: commands),
                  child: const Text('open palette'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open palette'));
      await tester.pumpAndSettle();

      // Hint của ô tìm kiếm: chrome ⇒ phải là English.
      expect(
        find.text('Search commands or workspaces', findRichText: true),
        findsWidgets,
      );
      expect(
        _renderedStrings(tester).where(_viDiacritics.hasMatch).toList(),
        isEmpty,
        reason: 'chrome Command Palette còn tiếng Việt ở locale `en`',
      );

      // Lọc hết lệnh ⇒ empty state cũng phải là English.
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(
        find.text('No matching commands found.', findRichText: true),
        findsWidgets,
      );
      expect(
        _renderedStrings(tester).where(_viDiacritics.hasMatch).toList(),
        isEmpty,
        reason: 'empty state Command Palette còn tiếng Việt ở locale `en`',
      );
    });
  });
}
