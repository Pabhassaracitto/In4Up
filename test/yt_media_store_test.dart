// YT-MEDIA-STORE-001 — test phần ĐẶT TÊN FILE và cài đặt nơi lưu.
//
// Phần I/O (thư mục, dung lượng, xoá) cần `path_provider` nên chỉ chạy được
// trên máy thật; ở đây khoá lại phần logic thuần — đúng phần liên quan trực
// tiếp tới lỗi "RangeError (end)" và tới việc ghép cặp phụ đề ↔ âm thanh.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_learning_settings.dart';
import 'package:in4up/features/youtube/services/yt_media_store.dart';

void main() {
  group('YtMediaStore.fileBaseFor', () {
    test('thêm tiền tố yt_ và giữ ID YouTube hợp lệ', () {
      expect(YtMediaStore.fileBaseFor('dQw4w9WgXcQ'), 'yt_dQw4w9WgXcQ');
    });

    test('bỏ ký tự không an toàn cho tên file', () {
      expect(YtMediaStore.fileBaseFor('a b/c:d'), 'yt_abcd');
    });

    test('ID rỗng ⇒ dùng "clip" (không tạo tên ".lrc" trần)', () {
      expect(YtMediaStore.fileBaseFor(''), 'yt_clip');
      expect(YtMediaStore.fileBaseFor('///'), 'yt_clip');
    });

    test('giữ nguyên gạch dưới và gạch ngang (ID thật có cả hai)', () {
      expect(YtMediaStore.fileBaseFor('abc-_123'), 'yt_abc-_123');
    });
  });

  group('YtLearningSettings — cài đặt mới (đọc + nơi lưu)', () {
    test('mặc định: xen kẽ, 1/1, nghỉ 500ms, tốc độ 1.0, lưu trong app', () {
      const s = YtLearningSettings();
      expect(s.readAloudMode, YtReadAloudMode.interleaved);
      expect(s.readAloudSourceRepeats, 1);
      expect(s.readAloudTargetRepeats, 1);
      expect(s.readAloudGapMs, 500);
      expect(s.readAloudSpeed, 1.0);
      expect(s.saveLocation, YtSaveLocation.appPrivate);
    });

    test('toJson/fromJson khứ hồi đầy đủ', () {
      final s = const YtLearningSettings().copyWith(
        readAloudMode: YtReadAloudMode.targetOnly,
        readAloudSourceRepeats: 2,
        readAloudTargetRepeats: 3,
        readAloudGapMs: 1500,
        readAloudSpeed: 1.5,
        saveLocation: YtSaveLocation.externalDownloads,
      );
      final back = YtLearningSettings.fromJson(s.toJson());
      expect(back.readAloudMode, YtReadAloudMode.targetOnly);
      expect(back.readAloudSourceRepeats, 2);
      expect(back.readAloudTargetRepeats, 3);
      expect(back.readAloudGapMs, 1500);
      expect(back.readAloudSpeed, 1.5);
      expect(back.saveLocation, YtSaveLocation.externalDownloads);
    });

    test('dữ liệu CŨ (thiếu khoá) rớt về mặc định, không crash', () {
      final back = YtLearningSettings.fromJson(const <String, dynamic>{
        'translationMode': 'withTranslation',
        'subtitleLayout': 'stacked',
        'audioLeadMs': 0,
      });
      expect(back.readAloudMode, YtReadAloudMode.interleaved);
      expect(back.readAloudSourceRepeats, 1);
      expect(back.readAloudTargetRepeats, 1);
      expect(back.readAloudGapMs, 500);
      expect(back.readAloudSpeed, 1.0);
      expect(back.saveLocation, YtSaveLocation.appPrivate);
    });

    test('giá trị rác trong JSON không làm crash', () {
      final back = YtLearningSettings.fromJson(const <String, dynamic>{
        'readAloudMode': 'khong_ton_tai',
        'saveLocation': 'cung_khong_ton_tai',
      });
      expect(back.readAloudMode, YtReadAloudMode.interleaved);
      expect(back.saveLocation, YtSaveLocation.appPrivate);
    });

    test('số lần lặp bị kẹp 0..5, tốc độ kẹp 0.5..2.0', () {
      final s = const YtLearningSettings().copyWith(
        readAloudSourceRepeats: 99,
        readAloudTargetRepeats: -3,
        readAloudSpeed: 9.0,
      );
      expect(s.readAloudSourceRepeats, 5);
      expect(s.readAloudTargetRepeats, 0);
      expect(s.readAloudSpeed, 2.0);
    });

    test('copyWith không đổi gì ⇒ giữ nguyên mọi giá trị cũ', () {
      final a = const YtLearningSettings().copyWith(
        readAloudMode: YtReadAloudMode.sourceOnly,
        readAloudSpeed: 0.75,
      );
      final b = a.copyWith();
      expect(b.readAloudMode, YtReadAloudMode.sourceOnly);
      expect(b.readAloudSpeed, 0.75);
      expect(b.subtitleLang, a.subtitleLang);
    });
  });
}
