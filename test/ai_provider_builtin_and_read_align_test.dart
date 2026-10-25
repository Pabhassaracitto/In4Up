// 3 việc owner giao (2026-10-17):
//
// 1. SỌC VÀNG-ĐEN 64px ở "Cài đặt → Sửa nhà cung cấp" = Flutter **overflow
//    warning** (vạch vàng-đen) — do DropdownButton (mặc định
//    isExpanded: false) rộng hơn khung khi tên model dài.
// 2. Provider CÓ SẴN cho OpenRouter (key + model minimax/minimax-m3.1-flash:free,
//    bật) + routing "Khi nào dùng model online" (Chat & Phân tích AI) →
//    Ưu tiên online, nhà cung cấp OpenRouter.
// 3. Tab Đọc — khi canh giữa, đoạn dài RỚT DÒNG bị canh trái (hàng đầu
//    canh giữa) ⇒ mọi hàng phải canh như nhau.
//
// Test thuần + source-scan (máy bắt).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_ai/in4up_ai.dart';

void main() {
  final providersScreen =
      File('lib/screens/settings/ai_providers_screen.dart').readAsStringSync();
  final coloredText = File(
          'lib/screens/read_mode/widgets/colored_text_widget.dart')
      .readAsStringSync();
  final textLine = File('lib/screens/read_mode/widgets/text_line_widget.dart')
      .readAsStringSync();

  group('1 — hết vạch vàng-đen (overflow) ở màn nhà cung cấp', () {
    test('dropdown model dùng isExpanded (không tràn ngang)', () {
      final idx = providersScreen.indexOf('class _ModelDropdown');
      expect(idx, greaterThan(0));
      final body = providersScreen.substring(idx, providersScreen.length);
      expect(body, contains('isExpanded: true'),
          reason: 'Tên model dài (vd minimax/minimax-m3.1-flash:free) gây TRÀN '
              'NGANG khi DropdownButton không isExpanded ⇒ vạch vàng-đen.');
      expect(body, contains('TextOverflow.ellipsis'));
    });

    test('dropdown provider ở mục routing: Expanded + isExpanded', () {
      final idx = providersScreen.indexOf('class _RoutingTile');
      expect(idx, greaterThan(0));
      final body = providersScreen.substring(idx, providersScreen.length);
      expect(body, contains('isExpanded: true'));
      expect(body, contains('Expanded('),
          reason: 'Dropdown provider phải nằm trong Expanded để không tràn.');
    });
  });

  group('2 — provider có sẵn OpenRouter + routing ưu tiên online', () {
    test('có provider OpenRouter bật, đúng base URL + model', () {
      final p = builtinOpenRouterProvider();
      expect(p.id, 'openrouter');
      expect(p.label, 'OpenRouter');
      expect(p.baseUrl, 'https://openrouter.ai/api/v1');
      expect(p.enabled, isTrue, reason: 'Provider có sẵn phải BẬT.');
      expect(p.chatModel, 'minimax/minimax-m3.1-flash:free');
      // Provider có sẵn phải hỗ trợ năng lực chat (để routing chọn được).
      expect(p.supports(AiRouteCapability.chat), isTrue);
    });

    test('API key đến từ môi trường, KHÔNG hard-code trong repo', () {
      // GitHub chặn push khi có secret trong source ⇒ key phải từ
      // --dart-define (CI secret OPENROUTER_API_KEY).
      final src = File(
              'packages/in4up_ai/lib/src/provider/builtin_ai_providers.dart')
          .readAsStringSync();
      expect(src, contains("String.fromEnvironment('OPENROUTER_API_KEY')"));
      expect(
        RegExp(r'sk-or-v1-[0-9a-f]{32,}').hasMatch(src),
        isFalse,
        reason: 'KHÔNG được hard-code key trong repo (GitHub chặn push; ai có '
            'repo đều dùng được key).',
      );
      // CI phải chèn define + cảnh báo khi thiếu secret.
      final wf = File('.github/workflows/build_final_complete.yml')
          .readAsStringSync();
      expect(wf, contains('OPENROUTER_API_KEY'));
      expect(wf, contains('--dart-define=OPENROUTER_API_KEY='));
      // Mọi nền tảng build đều phải có define (Android + desktop + iOS):
      // provider có sẵn được seed trên mọi nền tảng, thiếu define ở job
      // nào thì bản build đó phải dán key tay.
      for (final job in ['flutter build apk', 'flutter build linux',
        'flutter build windows', 'flutter build ios']) {
        final i = wf.indexOf(job);
        expect(i, greaterThan(0), reason: 'Không thấy lệnh build: $job');
        final seg = wf.substring(i, wf.length);
        final end = seg.indexOf('\n\n');
        final block = end > 0 ? seg.substring(0, end) : seg;
        expect(block, contains('--dart-define=OPENROUTER_API_KEY='),
            reason: 'Job "$job" thiếu --dart-define=OPENROUTER_API_KEY ⇒ bản '
                'build đó provider có sẵn sẽ không có key.');
      }
    });

    test('routing mặc định: Chat → ưu tiên online + OpenRouter', () {
      final r = builtinAiRouting();
      expect(r.modeOf(AiRouteCapability.chat), AiRouteMode.onlineFirst,
          reason: '"Khi nào dùng model online" cho Chat & Phân tích AI phải là '
              'ƯU TIÊN ONLINE.');
      expect(r.preferredProviderOf(AiRouteCapability.chat), 'openrouter');
    });

    test('store có cờ seed 1 lần (xoá provider không bị thêm lại)', () {
      final store =
          File('packages/in4up_ai/lib/src/provider/ai_provider_store.dart')
              .readAsStringSync();
      expect(store.contains('_kBuiltinSeeded'), isTrue);
      expect(store.contains('_seedBuiltinProviders'), isTrue);
      // Không ghi đè lựa chọn của user (putIfAbsent).
      expect(store.contains('putIfAbsent'), isTrue);
    });

    test('cờ "đã seed" đặt SAU khi lưu (lỗi persist không bỏ sót provider)',
        () {
      final store =
          File('packages/in4up_ai/lib/src/provider/ai_provider_store.dart')
              .readAsStringSync();
      final seedIdx = store.indexOf('Future<void> _seedBuiltinProviders');
      expect(seedIdx, greaterThan(0));
      final body = store.substring(seedIdx);
      final persistIdx = body.indexOf('await _persist();');
      final flagIdx = body.indexOf('await prefs.setBool(_kBuiltinSeeded, true);');
      expect(persistIdx, greaterThan(0));
      expect(flagIdx, greaterThan(0));
      expect(flagIdx, greaterThan(persistIdx),
          reason: 'Nếu cờ "đã seed" bật TRƯỚC khi _persist() lỗi ⇒ provider '
              'có sẵn không bao giờ được thêm lại ở lần mở app sau.');
    });

    test('package export provider có sẵn', () {
      final pkg = File('packages/in4up_ai/lib/in4up_ai.dart').readAsStringSync();
      expect(pkg, contains('builtin_ai_providers.dart'));
    });
  });

  group('3 — tab Đọc: mọi hàng (kể cả hàng rớt) cùng căn lề', () {
    test('ColoredTextWidget nhận textAlign + canh từng hàng của Wrap', () {
      expect(coloredText, contains('final TextAlign textAlign;'));
      expect(coloredText, contains('alignment: widget.textAlign == TextAlign.center'),
          reason: 'Wrap mặc định WrapAlignment.start ⇒ hàng rớt bị canh TRÁI '
              'trong khi hàng đầu (do Align ngoài) canh giữa.');
      expect(coloredText, contains('WrapAlignment.center'));
      expect(coloredText, contains('WrapAlignment.start'));
    });

    test('tầng dòng truyền textAlign xuống ColoredTextWidget', () {
      expect(textLine, contains('textAlign: data.textAlign'));
    });

    // READ-ALIGN-001 (owner 2026-10-25, mục 5): mặc định phải là CĂN GIỮA
    // (trước đây trái) và lựa chọn phải được LƯU qua lần mở app sau (trước
    // đây bị "tạm thời bỏ qua" nên mở lại là mất).
    test('mặc định là căn GIỮA và có lưu/khôi phục lựa chọn', () {
      final provider =
          File('lib/providers/text_provider.dart').readAsStringSync();
      expect(provider, contains('TextAlign _textAlign = TextAlign.center;'));
      expect(provider, isNot(contains('TextAlign _textAlign = TextAlign.left;')));
      expect(provider, contains('saveReadTextAlign('));
      expect(provider, contains('getReadTextAlign('));
      expect(provider, isNot(contains('Tạm thời bỏ qua')));

      final storage = File('lib/services/storage_service.dart').readAsStringSync();
      expect(storage, contains('read_text_align'));

      // Tab Đọc vẫn phải vẽ được cả hai lựa chọn (giữa + trái).
      expect(coloredText, contains('TextAlign.center'));
    });
  });
}
