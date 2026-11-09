// YT-AUDIT-11 (IN4-106) — Bù trễ âm thanh / chữ.
//
// Triệu chứng owner báo (2026-10-20):
//   "Âm thanh nhanh hơn chữ ~2,5 giây."
//
// Hai phần lệch, TÁCH RÕ (đừng trộn):
//   (A) Độ trễ KÊNH WebView → Flutter  ⇒ ĐO ĐƯỢC (JS gửi kèm Date.now()).
//   (B) Track phụ đề lệch so với audio ⇒ KHÔNG đo được nếu không có PCM
//       (VAD đã bị bác: iframe WebView không lấy được PCM) ⇒ tay người dùng.
//
// Test thuần — không cần thiết bị / mạng / WebView.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/youtube/models/yt_learning_settings.dart';
import 'package:in4up/features/youtube/yt_player_screen.dart';

void main() {
  group('đấu nối (pin nguồn) — bù trễ + chia câu', () {
    final player =
        File('lib/features/youtube/yt_player_screen.dart').readAsStringSync();
    final sheet = File('lib/features/youtube/widgets/yt_subtitle_settings_sheet'
            '.dart')
        .readAsStringSync();

    test('JS gửi kèm mốc Date.now() để Dart ĐO được độ trễ kênh', () {
      expect(player.contains("var stamp = t + '|' + Date.now();"), isTrue,
          reason: 'Không có mốc ⇒ không đo được, chỉ còn đoán (bị bác)');
      expect(player.contains("YtSync.postMessage('t:' + stamp);"), isTrue);
      // Nhánh poll dự phòng cũng phải gửi mốc, nếu không đo chập chờn.
      expect(
        player.contains(
            "YtSync.postMessage('t:' + String(v.currentTime) + '|' + Date.now());"),
        isTrue,
      );
    });

    test('player truyền mốc cho _updateTime', () {
      expect(player.contains('_updateTime(time, sentAtMs: ytParseSentAt(m));'),
          isTrue);
    });

    test('chọn dòng phụ đề dùng syncMs (đã bù), phát/seek vẫn dùng ms', () {
      expect(
        player.contains(
            'final syncMs = ms + _settings.audioLeadMs.round() + _autoLagMs;'),
        isTrue,
        reason: 'Bù trễ chỉ được phép đổi CHỖ CHỌN DÒNG, không được đổi '
            'vị trí phát thật (seek/lặp sẽ lệch)',
      );
      // Hai chỗ duyệt dòng phải dùng syncMs, không còn dùng ms.
      expect(
        player.contains(
            'if (syncMs >= l.start.inMilliseconds && syncMs < l.end.inMilliseconds)'),
        isTrue,
      );
      expect(player.contains('if (syncMs >= l.start.inMilliseconds) idx = i;'),
          isTrue);
    });

    test('PHÉP ĐO drift giữ nguyên theo ms (không bị bù trễ che)', () {
      // Chẩn đoán phải nói lên LỆCH GỐC. Nếu thay bằng syncMs thì drift ≈ 0
      // mãi ⇒ mất tác dụng (pin IN4-81 trong yt_lr_002_fixes_test.dart cũng
      // đòi đúng dòng này).
      expect(
        player.contains('final drift = ms - line.start.inMilliseconds;'),
        isTrue,
      );
      // Bù trễ được ghi riêng để đọc được: còn dư/thiếu bao nhiêu.
      expect(player.contains('| sync=\${syncMs}ms '), isTrue);
    });

    test('chia câu chạy TRƯỚC khi dựng dòng (và trước khi dịch)', () {
      final atSegment = player.indexOf('YtSentenceSegmenter.segmentCaptions(base)');
      final atApply = player.indexOf('_applyCaptionLines(base)');
      expect(atSegment, greaterThan(-1));
      expect(atApply, greaterThan(atSegment),
          reason: 'Gộp câu phải xong TRƯỚC ⇒ dịch nguyên câu, không dịch mẩu');
    });

    test('sheet nhận độ trễ đã đo để gợi ý', () {
      expect(player.contains('measuredLagMs: measuredLagMs,'), isTrue);
      expect(sheet.contains('int measuredLagMs = 0,'), isTrue);
    });
  });

  group('ytParseTimeMessage — vẫn đọc được định dạng CŨ', () {
    test('t:<s> (không kèm mốc) vẫn parse được', () {
      expect(ytParseTimeMessage('t:12.345'), 12.345);
      expect(ytParseTimeMessage('t:0'), 0.0);
    });

    test('không phải tin thời gian ⇒ null', () {
      expect(ytParseTimeMessage('ready'), isNull);
      expect(ytParseTimeMessage('state:1'), isNull);
      expect(ytParseTimeMessage('err:153'), isNull);
      expect(ytParseTimeMessage('t:abc'), isNull);
      expect(ytParseTimeMessage(''), isNull);
    });
  });

  group('ytParseTimeMessage — định dạng MỚI có kèm mốc JS', () {
    test('bỏ qua phần sau dấu | khi đọc vị trí phát', () {
      expect(ytParseTimeMessage('t:12.345|1700000000000'), 12.345);
      expect(ytParseTimeMessage('t:0|0'), 0.0);
    });

    test('phần giây hỏng ⇒ null (không rớt sang số mốc)', () {
      expect(ytParseTimeMessage('t:abc|1'), isNull);
    });
  });

  group('ytParseSentAt — mốc thời gian JS gửi (để đo độ trễ kênh)', () {
    test('đọc đúng epoch ms', () {
      expect(ytParseSentAt('t:12.3|1700000000123'), 1700000000123);
      expect(ytParseSentAt('t:0|0'), 0);
    });

    test('định dạng CŨ không có mốc ⇒ null (không đo được thì thôi)', () {
      expect(ytParseSentAt('t:12.3'), isNull);
    });

    test('không phải tin thời gian / mốc hỏng ⇒ null', () {
      expect(ytParseSentAt('ready'), isNull);
      expect(ytParseSentAt('t:12.3|x'), isNull);
      expect(ytParseSentAt(''), isNull);
    });
  });

  group('YtLearningSettings.audioLeadMs — bù trễ thủ công', () {
    test('mặc định 0 (không bù)', () {
      const s = YtLearningSettings();
      expect(s.audioLeadMs, 0);
      expect(s.audioLeadSeconds, 0);
    });

    test('biên ±3000 ms, bước 100 ms', () {
      expect(YtLearningSettings.kAudioLeadMin, -3000);
      expect(YtLearningSettings.kAudioLeadMax, 3000);
      expect(YtLearningSettings.kAudioLeadStep, 100);
    });

    test('copyWith tự kẹp biên (không để slider vọt quá)', () {
      const s = YtLearningSettings();
      expect(s.copyWith(audioLeadMs: 9999).audioLeadMs, 3000);
      expect(s.copyWith(audioLeadMs: -9999).audioLeadMs, -3000);
      expect(s.copyWith(audioLeadMs: 2500).audioLeadMs, 2500);
    });

    test('copyWith không truyền ⇒ giữ nguyên', () {
      const s = YtLearningSettings(audioLeadMs: 1200);
      expect(s.copyWith(subtitleLang: 'ja').audioLeadMs, 1200);
    });

    test('clampAudioLead chịu NaN (slider hỏng không được làm crash)', () {
      expect(YtLearningSettings.clampAudioLead(double.nan), 0);
    });

    test('snapAudioLead ép về đúng bước 100 ms', () {
      // Slider có `divisions` vẫn trả rác dấu phẩy động.
      expect(YtLearningSettings.snapAudioLead(100.00000000000001), 100);
      expect(YtLearningSettings.snapAudioLead(437), 400);
      expect(YtLearningSettings.snapAudioLead(-437), -400);
      expect(YtLearningSettings.snapAudioLead(2500), 2500);
    });

    test('snapAudioLead kẹp biên luôn (không vọt quá ±3000)', () {
      expect(YtLearningSettings.snapAudioLead(99999), 3000);
      expect(YtLearningSettings.snapAudioLead(-99999), -3000);
    });

    test('snapAudioLead trả 0.0 (không phải -0.0) ở giữa', () {
      // UI so sánh `lead == 0` để hiện "Đang khớp"; -0.0 làm sai nhãn.
      final v = YtLearningSettings.snapAudioLead(-1.4e-14);
      expect(v, 0);
      expect(v.isNegative, isFalse);
      expect(v.toString(), '0.0');
    });

    test('audioLeadSeconds đọc theo giây', () {
      const s = YtLearningSettings(audioLeadMs: 2500);
      expect(s.audioLeadSeconds, 2.5);
      const neg = YtLearningSettings(audioLeadMs: -1500);
      expect(neg.audioLeadSeconds, -1.5);
    });

    test('JSON round-trip giữ nguyên bù trễ', () {
      const s = YtLearningSettings(audioLeadMs: -800);
      final decoded = YtLearningSettings.fromJson(s.toJson());
      expect(decoded.audioLeadMs, -800);
    });

    test('dữ liệu CŨ không có khoá ⇒ 0, không crash', () {
      final decoded = YtLearningSettings.fromJson(<String, dynamic>{
        'translationMode': 'withTranslation',
      });
      expect(decoded.audioLeadMs, 0);
    });
  });
}
