// test/mascot/mascot_prompts_test.dart
//
// MASCOT-003 — test persona + giao thức hành động của Sara (PLAN-050 §6).
// Prompt là NỘI DUNG AI — kiểm nội dung mấu chốt, không kiểm i18n.

import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/features/mascot/mascot_intent_registry.dart';
import 'package:in4up/features/mascot/mascot_prompts.dart';

void main() {
  group('buildMascotSystemPrompt', () {
    final prompt = buildMascotSystemPrompt(mascotPromptActions());

    test('nêu đúng tên và 3 vai trò', () {
      expect(prompt, contains('Sara'));
      expect(prompt, contains('QUẢN GIA'));
      expect(prompt, contains('GIA SƯ'));
      expect(prompt, contains('HƯỚNG DẪN'));
      expect(prompt, contains('lá bồ đề'));
    });

    test('gia sư KHÔNG làm hộ bài', () {
      expect(prompt, contains('KHÔNG làm hộ'));
    });

    test('giao thức action: định dạng [[action:id]] + không bịa id', () {
      expect(prompt, contains('[[action:<id>]]'));
      expect(prompt, contains('KHÔNG bịa id ngoài danh sách'));
    });

    test('liệt kê hành động với id nguyên vẹn', () {
      expect(prompt, contains('pdf_reader | PDF Reader'));
      expect(prompt, contains('tab_listen | Nghe'));
      // playback bị loại (chưa nối executor P1)
      expect(prompt, isNot(contains('playback_play |')));
    });

    test('prompt ổn định (deterministic) cho snapshot', () {
      final again = buildMascotSystemPrompt(mascotPromptActions());
      expect(again, prompt);
    });
  });

  group('mascotPromptActions', () {
    test('không quảng cáo playback (chưa nối executor ở P1)', () {
      final actions = mascotPromptActions();
      expect(actions.where((a) => a.group == MascotActionGroup.playback),
          isEmpty);
      expect(actions.any((a) => a.group == MascotActionGroup.tool), isTrue);
    });
  });
}
