// IN4-81 — YouTube: ưu tiên phát video, lời/dịch song song, đổi video
// phải bỏ kết quả cũ, và phải ĐO được các mốc thời gian.
//
// Root cause (đã xác minh trong code):
// - `fetchBilingualCaptions` chờ TẤT CẢ (gồm dịch AI toàn bộ lời) rồi mới
//   trả về ⇒ UI không hiện gì cho tới khi xong, video bị overlay đen che.
// - Không có cơ chế huỷ kết quả cũ khi đổi video.
//
// Fix (yt_player_screen.dart + yt_service.dart):
// - 3 pha: (A) phụ đề gốc → hiện ngay; (B) phụ đề đích trên YT → ghép;
//   (C) dịch AI theo lô nhỏ → hiện tăng dần.
// - Token thế hệ `_loadGeneration` ⇒ kết quả của video cũ bị bỏ.
// - Overlay loading KHÔNG che video (spinner ở góc).
// - Log TIMING: khung hình đầu / phụ đề đầu / bản dịch đầu / bản dịch đủ.
//
// Test thuần này pin các ràng buộc cấu trúc (không cần WebView thật).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final player = File('lib/features/youtube/yt_player_screen.dart')
      .readAsStringSync();
  final service = File('lib/features/youtube/services/yt_service.dart')
      .readAsStringSync();

  group('IN4-81 — ưu tiên video, lời/dịch không chặn player', () {
    test('overlay loading KHÔNG che video (không còn Container phủ đen)',
        () {
      // Overlay cũ: Container(color: Colors.black) phủ kín vùng video.
      expect(
        player.contains('color: Colors.black,\n            alignment:'),
        isFalse,
        reason: 'Overlay đen phủ kín video ⇒ video bị che khi chờ lời/dịch.',
      );
      expect(player.contains('Positioned('), isTrue,
          reason: 'Spinner phải đặt ở góc, không phủ video.');
    });

    test('player dùng IFrame API thật (không còn postMessage thô)', () {
      // Wrapper (IN4-78) dùng IFrame API ⇒ không còn script postMessage thô.
      expect(player.contains("'t:' + window.player.getCurrentTime()"), isFalse,
          reason: 'Wrapper dùng IFrame API — mã JS nằm ở file gh-pages.');
    });
  });

  group('IN4-81 — tải lời/dịch TĂNG DẦN', () {
    test('3 pha: phụ đề gốc → ghép bản dịch YT → dịch AI theo lô', () {
      // YT-AUDIT-04 (IN4-103): pha A lấy phụ đề gốc theo ngôn ngữ NGƯỜI DÙNG
      // CHỌN (`_settings.subtitleLang`) — bản cũ hard-code 'en' ⇒ sai khi học
      // tiếng Nhật/Hàn/Trung (và cả sourceLang đưa vào AI translate).
      expect(player.contains('fetchCaptions(videoId, lang: subLang)'), isTrue,
          reason: 'Pha A: lấy phụ đề GỐC trước (hiện ngay).');
      expect(player.contains('final subLang = _settings.subtitleLang;'), isTrue,
          reason: 'Ngôn ngữ phụ đề gốc phải theo cài đặt, không hard-code.');
      expect(player.contains("fetchCaptions(videoId, lang: 'en')"), isFalse,
          reason: "Hard-code 'en' ⇒ học tiếng Nhật/Hàn/Trung sẽ sai.");
      expect(player.contains('sourceLang: subLang.startsWith'), isTrue,
          reason: 'Nguồn đưa vào AI translate phải là ngôn ngữ phụ đề gốc.');
      expect(player.contains('mergeCaptions(base, localized)'), isTrue,
          reason: 'Pha B: ghép bản dịch có sẵn trên YT.');
      expect(player.contains('translateLines('), isTrue,
          reason: 'Pha C: dịch AI theo lô.');
      expect(player.contains('const chunkSize = 6;'), isTrue,
          reason: 'Dịch theo lô nhỏ để hiện tăng dần.');
    });

    test('UI hiện phụ đề GỐC trước khi có bản dịch (_applyCaptionLines)', () {
      expect(player.contains('void _applyCaptionLines('), isTrue);
      // apply trước khi bắt đầu dịch AI:
      final applyIdx = player.indexOf('_applyCaptionLines(base);');
      final translateIdx = player.indexOf('translateLines(');
      expect(applyIdx, greaterThan(0));
      expect(translateIdx, greaterThan(applyIdx),
          reason: 'Phải hiện lời gốc TRƯỚC khi dịch AI bắt đầu.');
    });

    test('YtService có API công khai: mergeCaptions + translateLines', () {
      expect(service.contains('List<YtCaptionLine> mergeCaptions('), isTrue);
      expect(service.contains('Future<List<String>> translateLines('), isTrue);
    });
  });

  group('IN4-81 — đổi video phải bỏ kết quả cũ', () {
    test('có token thế hệ + hàm kiểm tra stale', () {
      expect(player.contains('int _loadGeneration = 0;'), isTrue);
      expect(player.contains('bool _isStale(int generation)'), isTrue);
      expect(player.contains('++_loadGeneration'), isTrue);
    });

    test('didUpdateWidget xử lý đổi video (huỷ lời cũ + nạp lại)', () {
      expect(player.contains('void didUpdateWidget('), isTrue);
      final idx = player.indexOf('void didUpdateWidget(');
      final body = player.substring(idx, idx + 1600);
      expect(body, contains('oldWidget.video.id != widget.video.id'));
      expect(body, contains('_loadGeneration++'));
      expect(body, contains('_lines.clear()'));
    });
  });

  group('IN4-81 — đo các mốc thời gian', () {
    test('log TIMING: khung hình đầu, phụ đề đầu, bản dịch đầu/đủ', () {
      expect(player.contains('TIMING khung hình đầu tiên'), isTrue);
      expect(player.contains('TIMING phụ đề đầu tiên'), isTrue);
      expect(player.contains('TIMING bản dịch đầu tiên'), isTrue);
      expect(player.contains('TIMING bản dịch đầy đủ'), isTrue);
    });
  });
}
