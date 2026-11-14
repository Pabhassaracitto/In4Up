// PSRC-233 — tab Đọc «tự động đồng bộ» sai đoạn đang phát.
//
// Audit v1.28.0: bật «Đồng bộ tự động» mà vị trí hiển thị không nhảy đúng
// đoạn đang đọc. Test này khoá 3 nguyên nhân gốc:
//   1. chọn dòng theo thời gian (thuần Dart) — LRC song ngữ có 2 dòng CÙNG
//      mốc, `endTime` bị gán = mốc kế ⇒ cửa sổ 0 giây ⇒ bỏ câu / tô bản dịch;
//   2. cuộn tới `index * 85.0` (hằng số) thay vì đo item thật bằng
//      `RenderAbstractViewport` + `GlobalKey`;
//   3. listener audio không kiểm tra «đang phát» ⇒ giành highlight với TTS,
//      và đường «đọc cả bài» bằng TTS không cuộn theo.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/screens/read_mode/services/read_line_sync.dart';

String _src(String path) => File(path).readAsStringSync();

List<Duration?> _starts(List<int> seconds) =>
    [for (final s in seconds) Duration(seconds: s)];

List<Duration?> _ends(List<int?> seconds) => [
      for (final s in seconds) s == null ? null : Duration(seconds: s),
    ];

void main() {
  group('lineIndexForPosition — chọn dòng đang phát (thuần Dart)', () {
    int at(List<int> starts, int positionInSeconds, {List<int?>? endSeconds}) =>
        lineIndexForPosition(
          starts: _starts(starts),
          ends: _ends(endSeconds ?? const <int?>[]),
          position: Duration(seconds: positionInSeconds),
        );

    test('LRC thường: cửa sổ là [start_i, start_{i+1})', () {
      // 3 dòng: 0s, 5s, 12s
      expect(at([0, 5, 12], 0), 0);
      expect(at([0, 5, 12], 4), 0);
      expect(at([0, 5, 12], 5), 1, reason: 'đúng mốc kế ⇒ sang dòng kế');
      expect(at([0, 5, 12], 11), 1);
      expect(at([0, 5, 12], 12), 2);
    });

    test('PSRC-233: LRC SONG NGỮ 2 dòng cùng mốc ⇒ highlight dòng NGUỒN', () {
      // [00:12]Hello / [00:12]Xin chào / [00:17]Bye
      // `_parseLrc` từng gán endTime(0) = 12s ⇒ cửa sổ 0 giây ⇒ dòng 0
      // gần như không bao giờ khớp; dòng 1 (bản dịch) chiếm trọn 12–17s.
      expect(at([0, 12, 12, 17], 12), 1);
      expect(
        at([0, 12, 12, 17], 15),
        1,
        reason: 'giữa mốc 12s và 17s ⇒ vẫn là câu gốc của cặp (dòng đầu nhóm)',
      );
      expect(at([0, 12, 12, 17], 17), 3, reason: 'hết cặp ⇒ sang câu kế');
    });

    test('endTime đã lưu KHÔNG được dùng để chặn (end == start)', () {
      // Dòng 1 có endTime = 12s (bằng start) — bản cũ loại nó ra.
      final starts = _starts([5, 12, 12, 20]);
      final ends = [
        const Duration(seconds: 12),
        const Duration(seconds: 12),
        const Duration(seconds: 20),
        const Duration(seconds: 25),
      ];
      final index = lineIndexForPosition(
        starts: starts,
        ends: ends,
        position: const Duration(seconds: 14),
      );
      expect(index, 1);
    });

    test('trước mốc đầu tiên ⇒ -1 (chưa có gì để tô)', () {
      expect(at([5, 9], 0), -1);
    });

    test('dòng không có mốc thời gian bị bỏ qua', () {
      final starts = <Duration?>[null, const Duration(seconds: 3)];
      expect(
        lineIndexForPosition(
          starts: starts,
          ends: const <Duration?>[null, null],
          position: const Duration(seconds: 1),
        ),
        -1,
      );
      expect(
        lineIndexForPosition(
          starts: starts,
          ends: const <Duration?>[null, null],
          position: const Duration(seconds: 3),
        ),
        1,
      );
    });

    test('hết bài ⇒ tắt highlight sau khi giữ dòng cuối', () {
      // Dòng cuối bắt đầu 10s, không có end ⇒ giữ 5s rồi tắt.
      expect(at([0, 10], 12), 1);
      expect(at([0, 10], 16), -1,
          reason: 'quá 5s sau mốc cuối ⇒ KHÔNG dính highlight câu cuối mãi');
    });

    test('SRT dòng cuối có end thật ⇒ tôn trọng end', () {
      final index = lineIndexForPosition(
        starts: _starts([0, 10]),
        ends: [
          const Duration(seconds: 10),
          const Duration(seconds: 40),
        ],
        position: const Duration(seconds: 30),
      );
      expect(index, 1);
      expect(
        lineIndexForPosition(
          starts: _starts([0, 10]),
          ends: [
            const Duration(seconds: 10),
            const Duration(seconds: 40),
          ],
          position: const Duration(seconds: 41),
        ),
        -1,
      );
    });

    test('danh sách rỗng ⇒ -1, không crash', () {
      expect(
        lineIndexForPosition(
          starts: const <Duration?>[],
          ends: const <Duration?>[],
          position: Duration.zero,
        ),
        -1,
      );
    });
  });

  group('estimatedLineOffset — chỉ là ước lượng để ListView dựng tới', () {
    test('kẹp trong [0, maxScrollExtent]', () {
      expect(
        estimatedLineOffset(
          index: 0,
          lineHeight: 85,
          viewportHeight: 800,
          maxScrollExtent: 5000,
        ),
        0,
        reason: 'dòng đầu không được cuộn âm',
      );
      expect(
        estimatedLineOffset(
          index: 200,
          lineHeight: 85,
          viewportHeight: 800,
          maxScrollExtent: 5000,
        ),
        5000,
      );
    });

    test('đặt dòng ở ~1/3 trên viewport', () {
      final offset = estimatedLineOffset(
        index: 10,
        lineHeight: 100,
        viewportHeight: 900,
        maxScrollExtent: 10000,
      );
      expect(offset, closeTo(1000 - 900 * 0.28, 0.01));
    });
  });

  group('Source-pin — không quay lại cách tính cũ', () {
    final controller =
        _src('lib/screens/read_mode/controllers/read_mode_controller.dart');
    final screen = _src('lib/screens/read_mode/read_mode_screen.dart');
    final textProvider = _src('lib/providers/text_provider.dart');

    test('controller cuộn theo item THẬT, không theo hằng số 85px', () {
      expect(controller.contains('RenderAbstractViewport'), isTrue);
      expect(controller.contains('getOffsetToReveal'), isTrue);
      expect(controller.contains('GlobalKey lineKey(int index)'), isTrue);
      expect(
        controller.contains('final targetOffset = index * estimatedLineHeight;'),
        isFalse,
        reason: 'đây chính là lỗi PSRC-233 (dòng cao thấp khác nhau)',
      );
    });

    test('highlight không còn bị chặn bởi animation cuộn', () {
      expect(
        controller.contains('if (!_autoSyncEnabled || _isScrolling) return -1;'),
        isFalse,
        reason: '400 ms animation từng làm mất highlight câu kế tiếp',
      );
      expect(controller.contains('lineIndexForPosition('), isTrue);
    });

    test('màn Đọc gắn key dòng + chỉ đồng bộ khi audio ĐANG phát', () {
      expect(screen.contains('key: _controller.lineKey(index)'), isTrue);
      expect(screen.contains('if (!pp.isPlaying) return;'), isTrue);
      expect(screen.contains('_playbackRef?.isRunning ?? false'), isTrue,
          reason: 'TTS đang đọc thì PlayerProvider không được giành highlight');
    });

    test('đường «đọc cả bài» bằng TTS có listener cuộn theo', () {
      expect(screen.contains('_ttsLineListener'), isTrue);
      expect(screen.contains('if (!tp.isSpeaking) return;'), isTrue);
      expect(screen.contains('_textProviderRef!.removeListener(_ttsLineListener!)'),
          isTrue);
    });

    test('LRC song ngữ: KHÔNG tạo cửa sổ 0 giây (start == end)', () {
      expect(
        textProvider.contains('nextStart > start'),
        isTrue,
        reason: '_parseLrc từng gán endTime = mốc kế kể cả khi trùng mốc',
      );
    });

    test('highlight không phụ thuộc công tắc «Đồng bộ tự động»', () {
      expect(
        screen.contains('if (!_controller.autoSyncEnabled || !playback.isRunning) return;'),
        isFalse,
        reason: 'công tắc đó chỉ nói về TỰ CUỘN, không phải tô dòng',
      );
    });
  });
}
