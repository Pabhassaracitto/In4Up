// Test cho các mục nghiệm thu máy thật 2026-10-25 (đợt 6):
//   #2  YT-ONE-BAR-001     — một ô vừa tìm kiếm vừa nhận URL/ID
//   #8  YT-READ-LOOP-LESSON-001 — lặp CẢ BÀI (có "mãi mãi")
//   #9  YT-READ-SYNC-VIDEO-001  — tua/phát video theo dòng đang đọc
//
// Phần logic thuần, không cần plugin/mạng nên chạy được trong CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_learning_settings.dart';
import 'package:in4up/features/youtube/services/yt_read_aloud_sequence.dart';
import 'package:in4up/features/youtube/services/yt_search_service.dart';

void main() {
  group('#2 YT-ONE-BAR-001 — một ô cho cả URL và từ khoá', () {
    test('link đầy đủ watch?v= ⇒ lấy được ID', () {
      expect(
        ytVideoIdFromSearchInput('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('link youtu.be và shorts ⇒ lấy được ID', () {
      expect(ytVideoIdFromSearchInput('https://youtu.be/dQw4w9WgXcQ'),
          'dQw4w9WgXcQ');
      expect(
        ytVideoIdFromSearchInput('https://youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('ID trần 11 ký tự CÓ chữ số ⇒ nhận là ID', () {
      expect(ytVideoIdFromSearchInput('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('từ khoá 11 ký tự toàn chữ ⇒ đi TÌM KIẾM, không mở video rác', () {
      // Đây là cái bẫy khi gộp hai thanh: "learnenglis" đúng 11 ký tự.
      expect(ytVideoIdFromSearchInput('learnenglis'), isNull);
      expect(ytVideoIdFromSearchInput('englishsong'), isNull);
    });

    test('từ khoá thường ⇒ tìm kiếm', () {
      expect(ytVideoIdFromSearchInput('học tiếng anh giao tiếp'), isNull);
      expect(ytVideoIdFromSearchInput('BBC Learning English'), isNull);
    });

    test('rỗng / khoảng trắng ⇒ không phải video', () {
      expect(ytVideoIdFromSearchInput(''), isNull);
      expect(ytVideoIdFromSearchInput('   '), isNull);
    });

    test('link hỏng (không có ID hợp lệ) ⇒ tìm kiếm, không crash', () {
      expect(ytVideoIdFromSearchInput('https://youtu.be/abc'), isNull);
      expect(ytVideoIdFromSearchInput('https://example.com/video'), isNull);
    });
  });

  group('#8 YT-READ-LOOP-LESSON-001 — lặp cả bài', () {
    test('0 = mãi mãi (không có trần)', () {
      expect(ytPassCount(0), isNull);
    });

    test('1 = một lượt (hành vi cũ)', () {
      expect(ytPassCount(1), 1);
    });

    test('số dương giữ nguyên; số âm kẹp về 1', () {
      expect(ytPassCount(5), 5);
      expect(ytPassCount(-3), 1);
    });

    test('mặc định là 1 lượt, KHÔNG tự lặp mãi', () {
      const s = YtLearningSettings();
      expect(s.readAloudPasses, 1);
      expect(ytPassCount(s.readAloudPasses), 1);
    });

    test('copyWith: 0 được giữ là 0 (mãi mãi), không bị kẹp thành 1', () {
      final s = const YtLearningSettings().copyWith(readAloudPasses: 0);
      expect(s.readAloudPasses, 0);
    });

    test('copyWith: kẹp trần 20 và sàn 1 cho số dương', () {
      expect(
        const YtLearningSettings().copyWith(readAloudPasses: 999).readAloudPasses,
        20,
      );
      expect(
        const YtLearningSettings().copyWith(readAloudPasses: -5).readAloudPasses,
        1,
      );
    });

    test('JSON khứ hồi giữ 0 (mãi mãi)', () {
      final s = const YtLearningSettings().copyWith(
        readAloudPasses: 0,
        readAloudSyncVideo: true,
        readAloudPlayVideoAudio: true,
      );
      final back = YtLearningSettings.fromJson(s.toJson());
      expect(back.readAloudPasses, 0);
      expect(back.readAloudSyncVideo, isTrue);
      expect(back.readAloudPlayVideoAudio, isTrue);
    });

    test('dữ liệu CŨ (thiếu khoá) ⇒ 1 lượt, không tua video', () {
      final back = YtLearningSettings.fromJson(const <String, dynamic>{
        'translationMode': 'withTranslation',
        'subtitleLayout': 'stacked',
        'audioLeadMs': 0,
      });
      expect(back.readAloudPasses, 1);
      expect(back.readAloudSyncVideo, isFalse);
      expect(back.readAloudPlayVideoAudio, isFalse);
    });
  });

  group('#9 YT-READ-SYNC-VIDEO-001 — độc lập với chế độ đọc', () {
    test('chỉ dịch + tua video là tổ hợp hợp lệ (đúng yêu cầu owner)', () {
      final s = const YtLearningSettings().copyWith(
        readAloudMode: YtReadAloudMode.targetOnly,
        readAloudSyncVideo: true,
        readAloudPlayVideoAudio: false,
      );
      expect(s.readAloudMode, YtReadAloudMode.targetOnly);
      expect(s.readAloudSyncVideo, isTrue);
      // Vẫn không phát tiếng video ⇒ TTS không bị chồng tiếng.
      expect(s.readAloudPlayVideoAudio, isFalse);
    });

    test('bật tiếng video KHÔNG tự bật tua video (hai công tắc riêng)', () {
      final s = const YtLearningSettings()
          .copyWith(readAloudPlayVideoAudio: true);
      expect(s.readAloudPlayVideoAudio, isTrue);
      expect(s.readAloudSyncVideo, isFalse);
    });

    test('thứ tự đọc không đổi khi bật/tắt tua video', () {
      const lines = [
        YtReadAloudLine(source: 'Hello', target: 'Xin chào'),
      ];
      final a = buildYtReadAloudSequence(
        lines: lines,
        settings: const YtLearningSettings(),
      );
      final b = buildYtReadAloudSequence(
        lines: lines,
        settings: const YtLearningSettings().copyWith(
          readAloudSyncVideo: true,
          readAloudPlayVideoAudio: true,
        ),
      );
      expect(a.map((s) => s.text), b.map((s) => s.text));
    });
  });
}
