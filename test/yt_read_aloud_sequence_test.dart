// YT-TTS-READ-001 — test phần LOGIC THUẦN của "đọc bản dịch".
//
// Vì sao phải test riêng: thứ tự đọc (lặp mấy lần, xen kẽ, bên nhiều bên ít,
// dòng thiếu bản dịch, bắt đầu từ dòng đang phát) là chỗ dễ sai nhất và là
// đúng thứ owner yêu cầu. `YtReadAloudController` chỉ việc phát danh sách
// bước do hàm thuần này trả về.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_learning_settings.dart';
import 'package:in4up/features/youtube/services/yt_read_aloud_sequence.dart';

YtLearningSettings _settings({
  YtReadAloudMode mode = YtReadAloudMode.interleaved,
  int src = 1,
  int tgt = 1,
}) =>
    YtLearningSettings(
      readAloudMode: mode,
      readAloudSourceRepeats: src,
      readAloudTargetRepeats: tgt,
    );

const _lines = [
  YtReadAloudLine(source: 'Hello there', target: 'Xin chào'),
  YtReadAloudLine(source: 'How are you', target: 'Bạn khoẻ không'),
];

void main() {
  group('buildYtReadAloudSequence', () {
    test('xen kẽ 1/1: gốc rồi dịch, từng dòng một', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(),
      );
      expect(steps.map((s) => s.text).toList(), [
        'Hello there',
        'Xin chào',
        'How are you',
        'Bạn khoẻ không',
      ]);
      expect(steps.map((s) => s.isTarget).toList(),
          [false, true, false, true]);
      expect(steps.map((s) => s.line).toList(), [0, 0, 1, 1]);
    });

    test('bên nhiều bên ít: gốc 2 lần, dịch 1 lần', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(src: 2, tgt: 1),
      );
      expect(steps.map((s) => s.text).toList(), [
        'Hello there',
        'Hello there',
        'Xin chào',
        'How are you',
        'How are you',
        'Bạn khoẻ không',
      ]);
    });

    test('chỉ bản dịch: KHÔNG đọc bản gốc', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(mode: YtReadAloudMode.targetOnly),
      );
      expect(steps.every((s) => s.isTarget), isTrue);
      expect(steps.length, 2);
    });

    test('chỉ bản gốc: KHÔNG đọc bản dịch', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(mode: YtReadAloudMode.sourceOnly),
      );
      expect(steps.every((s) => !s.isTarget), isTrue);
      expect(steps.map((s) => s.text), ['Hello there', 'How are you']);
    });

    test('chế độ chỉ dịch mà dòng KHÔNG có bản dịch ⇒ đọc gốc, không im lặng',
        () {
      final steps = buildYtReadAloudSequence(
        lines: const [YtReadAloudLine(source: 'No translation here')],
        settings: _settings(mode: YtReadAloudMode.targetOnly),
      );
      expect(steps.length, 1);
      expect(steps.first.text, 'No translation here');
      expect(steps.first.isTarget, isFalse);
    });

    test('đặt 0 lần cả hai bên ⇒ không có bước nào', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(src: 0, tgt: 0),
      );
      expect(steps, isEmpty);
    });

    test('đặt 0 lần bên gốc ⇒ chỉ đọc dịch (không nhân đôi vì thiếu bản gốc)',
        () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(src: 0, tgt: 1),
      );
      expect(steps.map((s) => s.text), ['Xin chào', 'Bạn khoẻ không']);
    });

    test('dòng rỗng bị bỏ qua (TTS không đọc được chuỗi rỗng)', () {
      final steps = buildYtReadAloudSequence(
        lines: const [
          YtReadAloudLine(source: '   ', target: '   '),
          YtReadAloudLine(source: 'Real line', target: 'Dòng thật'),
        ],
        settings: _settings(),
      );
      expect(steps.map((s) => s.text), ['Real line', 'Dòng thật']);
    });

    test('startIndex = dòng đang phát ⇒ bỏ các dòng trước', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(),
        startIndex: 1,
      );
      expect(steps.map((s) => s.text), ['How are you', 'Bạn khoẻ không']);
    });

    test('startIndex ngoài phạm vi không làm crash (kẹp vào dòng cuối)', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(),
        startIndex: 99,
      );
      expect(steps.map((s) => s.text), ['How are you', 'Bạn khoẻ không']);
    });

    test('startIndex âm ⇒ đọc từ đầu', () {
      final steps = buildYtReadAloudSequence(
        lines: _lines,
        settings: _settings(),
        startIndex: -5,
      );
      expect(steps.length, 4);
      expect(steps.first.text, 'Hello there');
    });

    test('danh sách rỗng ⇒ không có bước nào', () {
      expect(
        buildYtReadAloudSequence(lines: const [], settings: _settings()),
        isEmpty,
      );
    });
  });
}
