// test/tts/voice_catalog_grouping_test.dart
//
// AUDIT v1.30.1 (mục 5) — «danh sách giọng Microsoft Edge chiếm nhiều chỗ ⇒
// cho thu gọn/bung». Test khoá lại phần dữ liệu của bảng chọn mới:
//   * gom nhóm theo ngôn ngữ, giữ thứ tự engine trả về (không sort chữ cái);
//   * không mất giọng, không tạo nhóm trùng;
//   * nhóm mở sẵn = nhóm đang dùng + tối đa N nhóm nhỏ.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/tts/engines/tts_engine.dart' show TtsVoice;
import 'package:in4up/features/tts/voice_catalog_grouping.dart';

TtsVoice _voice(String id, String language, {String? name}) => TtsVoice(
      id: id,
      name: name ?? id,
      language: language,
      gender: 'female',
      engine: 'edge_tts',
    );

void main() {
  group('groupVoicesByLanguage', () {
    test('gom đúng số nhóm và đếm đúng số giọng', () {
      final groups = groupVoicesByLanguage([
        _voice('en-US-AriaNeural', 'en-US'),
        _voice('en-US-GuyNeural', 'en-US'),
        _voice('vi-VN-HoaiMyNeural', 'vi-VN'),
        _voice('ja-JP-NanamiNeural', 'ja-JP'),
      ]);

      expect(groups.length, 3);
      final byLanguage = {for (final g in groups) g.language: g};
      expect(byLanguage['en-US']!.count, 2);
      expect(byLanguage['vi-VN']!.count, 1);
      expect(byLanguage['ja-JP']!.count, 1);
    });

    test('giữ thứ tự xuất hiện đầu tiên của ngôn ngữ', () {
      final groups = groupVoicesByLanguage([
        _voice('ja', 'ja-JP'),
        _voice('en', 'en-US'),
        _voice('vi', 'vi-VN'),
        _voice('en2', 'en-US'),
      ]);
      expect(groups.map((g) => g.language).toList(),
          ['ja-JP', 'en-US', 'vi-VN']);
    });

    test('không mất giọng nào', () {
      final voices = [
        for (var i = 0; i < 35; i++)
          _voice('v$i', 'lang-${i % 17}', name: 'Voice $i'),
      ];
      final groups = groupVoicesByLanguage(voices);
      final total = groups.fold<int>(0, (sum, g) => sum + g.count);
      expect(total, voices.length);
    });

    test('ngôn ngữ rỗng vẫn có nhóm riêng (dòng «mặc định» của engine)', () {
      final groups = groupVoicesByLanguage([
        _voice('default', ''),
        _voice('vi', 'vi-VN'),
      ]);
      expect(groups.length, 2);
      expect(groups.first.language, '');
      expect(groups.first.shortLabel, '—');
    });

    test('shortLabel lấy phần ngôn ngữ, không lấy vùng', () {
      final groups = groupVoicesByLanguage([
        _voice('a', 'en-US'),
        _voice('b', 'zh-TW'),
        _voice('c', 'vi_VN'),
      ]);
      expect(groups.map((g) => g.shortLabel).toList(), ['EN', 'ZH', 'VI']);
    });

    test('danh sách rỗng → không nhóm', () {
      expect(groupVoicesByLanguage(const []), isEmpty);
    });
  });

  group('defaultExpandedVoiceGroups', () {
    test('mở nhóm chứa giọng đang chọn', () {
      final groups = groupVoicesByLanguage([
        _voice('en1', 'en-US'),
        _voice('en2', 'en-US'),
        _voice('ja1', 'ja-JP'),
        _voice('vi1', 'vi-VN'),
      ]);
      final opened = defaultExpandedVoiceGroups(groups, selectedVoiceId: 'ja1');
      expect(opened, contains('ja-JP'));
    });

    test('không vượt quá số nhóm tối đa', () {
      final groups = groupVoicesByLanguage([
        for (var i = 0; i < 17; i++) _voice('v$i', 'lang-$i'),
      ]);
      final opened = defaultExpandedVoiceGroups(groups, maxOpenGroups: 2);
      expect(opened.length, lessThanOrEqualTo(2));
    });

    test('ưu tiên nhóm ÍT giọng khi không có giọng đang chọn', () {
      final groups = groupVoicesByLanguage([
        for (var i = 0; i < 10; i++) _voice('big$i', 'en-US'),
        _voice('small', 'ko-KR'),
      ]);
      final opened = defaultExpandedVoiceGroups(groups, maxOpenGroups: 1);
      expect(opened, {'ko-KR'});
    });

    test('không mở nhóm quá lớn (>= 7 giọng) khi chưa chọn gì', () {
      final groups = groupVoicesByLanguage([
        for (var i = 0; i < 8; i++) _voice('en$i', 'en-US'),
      ]);
      final opened = defaultExpandedVoiceGroups(groups);
      expect(opened, isEmpty);
    });

    test('giọng đang chọn không khớp → vẫn mở nhóm nhỏ', () {
      final groups = groupVoicesByLanguage([
        _voice('en1', 'en-US'),
        _voice('ja1', 'ja-JP'),
      ]);
      final opened =
          defaultExpandedVoiceGroups(groups, selectedVoiceId: 'missing-id');
      expect(opened.isNotEmpty, isTrue);
    });
  });
}
