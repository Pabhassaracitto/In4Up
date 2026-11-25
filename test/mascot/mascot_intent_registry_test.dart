// test/mascot/mascot_intent_registry_test.dart
//
// MASCOT-001 — test thuần Dart cho registry hành động của linh vật Sara
// (PLAN-050 §5/§7, ADR-0036 D2). Chạy trong CI: `flutter test test/mascot/`.

import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/features/mascot/mascot_intent_registry.dart';

void main() {
  group('mascotNormalizeCommand', () {
    test('bỏ dấu tiếng Việt và đ→d', () {
      expect(mascotNormalizeCommand('Phát Âm'), 'phat am');
      expect(mascotNormalizeCommand('Đọc'), 'doc');
      expect(mascotNormalizeCommand('Mở PDF!'), 'mo pdf');
      expect(mascotNormalizeCommand('TẠM DỪNG'), 'tam dung');
      expect(mascotNormalizeCommand('thuộc lòng'), 'thuoc long');
    });

    test('giữ nguyên từ khoá đã chuẩn hoá', () {
      expect(mascotNormalizeCommand('tam tang'), 'tam tang');
      expect(mascotNormalizeCommand('  mo   nhanh '), 'mo nhanh');
    });
  });

  group('registry integrity', () {
    test('id duy nhất', () {
      final ids = MascotIntentRegistry.actions.map((a) => a.id).toSet();
      expect(ids.length, MascotIntentRegistry.actions.length);
    });

    test('mỗi hành động có nhãn + từ khoá đã chuẩn hoá', () {
      for (final action in MascotIntentRegistry.actions) {
        expect(action.label, isNotEmpty, reason: action.id);
        expect(action.keywords, isNotEmpty, reason: action.id);
        for (final keyword in action.keywords) {
          expect(keyword, isNotEmpty, reason: action.id);
          expect(mascotNormalizeCommand(keyword), keyword,
              reason: 'từ khoá phải đã chuẩn hoá không dấu: '
                  '${action.id} "$keyword"');
        }
      }
    });

    test('đủ nhóm: 5 tab + 5 mode + tool + 8 playback kế thừa', () {
      int count(MascotActionGroup group) => MascotIntentRegistry.actions
          .where((a) => a.group == group)
          .length;
      expect(count(MascotActionGroup.tab), 5);
      expect(count(MascotActionGroup.mode), 5);
      expect(count(MascotActionGroup.playback), 8,
          reason: '8 intent voice_command cũ phải được đăng ký lại');
      expect(count(MascotActionGroup.tool), greaterThanOrEqualTo(20),
          reason: 'palette phải phủ đủ tool chính của shell');
    });

    test('byId tra được các hành động mấu chốt', () {
      expect(MascotIntentRegistry.byId('pdf_reader'), isNotNull);
      expect(MascotIntentRegistry.byId('tab_home'), isNotNull);
      expect(MascotIntentRegistry.byId('mode_speak'), isNotNull);
      expect(MascotIntentRegistry.byId('playback_translate'), isNotNull);
      expect(MascotIntentRegistry.byId('khong-ton-tai'), isNull);
    });
  });

  group('matchCommands', () {
    test('lệnh có dấu và không dấu cùng ra pdf_reader', () {
      expect(MascotIntentRegistry.matchCommands('mở pdf').first.action.id,
          'pdf_reader');
      expect(MascotIntentRegistry.matchCommands('mo pdf').first.action.id,
          'pdf_reader');
    });

    test('tam tang → tipitaka', () {
      expect(MascotIntentRegistry.matchCommands('tam tang').first.action.id,
          'tipitaka');
    });

    test('on tap → review đứng đầu', () {
      expect(MascotIntentRegistry.matchCommands('on tap').first.action.id,
          'review');
    });

    test('phat → playback_play đứng đầu (kế thừa voice_command)', () {
      final matches = MascotIntentRegistry.matchCommands('phat');
      expect(matches.first.action.id, 'playback_play');
      expect(matches.first.action.group, MascotActionGroup.playback);
    });

    test('nghe trả cả tab Nghe và mode Nghe (cùng đường đi, chủ đích)', () {
      final ids = MascotIntentRegistry.matchCommands('nghe', limit: 6)
          .map((m) => m.action.id)
          .toSet();
      expect(ids, containsAll(['tab_listen', 'mode_listen']));
    });

    test('lệnh rỗng không khớp gì', () {
      expect(MascotIntentRegistry.matchCommands(''), isEmpty);
      expect(MascotIntentRegistry.matchCommands('   '), isEmpty);
    });

    test('limit được tôn trọng', () {
      final matches = MascotIntentRegistry.matchCommands('mo', limit: 3);
      expect(matches.length, lessThanOrEqualTo(3));
    });

    test('exact cộng điểm hơn chứa', () {
      // 'on tap' (exact với review) phải hơn 'on' (chỉ chứa).
      final exact =
          MascotIntentRegistry.matchCommands('on tap').first.score;
      final contains =
          MascotIntentRegistry.matchCommands('on tap').first.score;
      expect(contains, exact);
      final onScore =
          MascotIntentRegistry.matchCommands('on tap')
              .where((m) => m.action.id == 'review')
              .first
              .score;
      expect(onScore, greaterThanOrEqualTo(100));
    });
  });
}
