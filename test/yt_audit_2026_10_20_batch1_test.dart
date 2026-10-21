// YT-AUDIT — Đợt 1/4 (audit 2026-10-20, owner báo 11 mục).
//
// Đợt này pin 6 mục "lỗi nhỏ nhưng khó chịu":
//   1. Tải audio chỉ được một đoạn rồi dừng   → IN4-97
//   2. "Làm mờ bản dịch" không thấy hiệu ứng  → IN4-98
//   3. Dịch đôi khi ra tiếng Anh              → IN4-101
//   7. Lịch sử không ghi nhận                 → IN4-99
//   8. Bảng tra từ không hiện từ loại         → IN4-100
//  10. Tab VĂN BẢN không theo dòng đang phát  → IN4-102
//
// (Mục 4, 5, 6, 11 làm ở các đợt sau: IN4-103 / IN4-105 / IN4-104 / IN4-106.)
//
// Test thuần — pin ràng buộc cấu trúc, không cần WebView/AI/mạng.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final player =
      File('lib/features/youtube/yt_player_screen.dart').readAsStringSync();
  final explorer =
      File('lib/features/youtube/youtube_explorer_screen.dart')
          .readAsStringSync();
  final downloader =
      File('lib/features/youtube/services/yt_downloader.dart')
          .readAsStringSync();
  final settings =
      File('lib/features/youtube/models/yt_learning_settings.dart')
          .readAsStringSync();
  final sheet =
      File('lib/features/youtube/widgets/yt_subtitle_settings_sheet.dart')
          .readAsStringSync();
  final panel =
      File('lib/features/youtube/widgets/yt_word_panel.dart')
          .readAsStringSync();
  final translation =
      File('lib/features/translation/translation_service.dart')
          .readAsStringSync();
  final syntax =
      File('lib/services/syntax_highlighter_service.dart').readAsStringSync();

  // ── #1 — IN4-97: tải audio phải resume được + kiểm tra đủ byte ─────────
  group('#1 (IN4-97) — tải audio không được dừng giữa chừng', () {
    test('tải bằng HTTP Range (resume được)', () {
      expect(
        downloader.contains('_downloadResumable'),
        isTrue,
        reason: 'Phải có hàm tải riêng hỗ trợ nối tiếp, thay vì await for '
            'một mạch trên streamsClient.get().',
      );
      expect(
        downloader.contains("req.headers[HttpHeaders.rangeHeader] = 'bytes="),
        isTrue,
        reason: 'Nối tiếp bằng header Range: bytes=<offset>-',
      );
      expect(
        downloader.contains("import 'package:http/http.dart' as http;"),
        isTrue,
        reason: 'Cần http để gửi request có Range.',
      );
    });

    test('chỉ báo XONG khi nhận ĐỦ totalBytes', () {
      expect(
        downloader.contains('if (knownSize && received >= totalBytes)'),
        isTrue,
        reason: 'BUG GỐC: bản cũ emit YtDownloadDone khi stream tự kết thúc '
            'mà không so `downloaded` với `totalBytes` ⇒ file CỤT vẫn báo '
            'thành công (triệu chứng "chỉ tải một xíu xong dừng").',
      );
      expect(
        downloader.contains("fail(\n          'Tải chưa xong ("),
        isTrue,
        reason: 'Thiếu byte ⇒ phải báo lỗi rõ ràng, không được im lặng.',
      );
    });

    test('ghi ra .part, có watchdog kẹt tiến trình và retry', () {
      expect(
        downloader.contains("final partPath = '\$filePath.part';"),
        isTrue,
        reason: 'File tạm .part để file cụt không lẫn vào thư viện.',
      );
      expect(
        downloader.contains('_stallTimeout'),
        isTrue,
        reason: 'Watchdog: 20 giây không có byte nào ⇒ thử lại.',
      );
      expect(
        downloader.contains('resp.stream.timeout('),
        isTrue,
        reason: 'Stream.timeout reset đồng hồ sau mỗi chunk ⇒ đúng nghĩa '
            'watchdog kẹt tiến trình.',
      );
      expect(
        downloader.contains('static const int _maxAttempts = 8;'),
        isTrue,
        reason: 'Phải thử lại nhiều lần thay vì bỏ cuộc ngay.',
      );
      expect(
        downloader.contains('resp.statusCode == 403'),
        isTrue,
        reason: 'URL stream của YouTube có hạn ⇒ gặp 403 phải xin URL mới.',
      );
    });
  });

  // ── #2 — IN4-98: làm mờ bản dịch phải NHÌN THẤY được ──────────────────
  group('#2 (IN4-98) — "Làm mờ bản dịch" phải thấy được', () {
    test('làm mờ bằng TextStyle.shadows (không phụ thuộc backend)', () {
      expect(
        player.contains('shadows: <Shadow>['),
        isTrue,
        reason: 'ImageFiltered từng render TRỐNG; MaskFilter trên paint của '
            'chữ bị Impeller bỏ qua. Text shadow được Skia lẫn Impeller hỗ '
            'trợ đầy đủ.',
      );
      expect(
        player.contains('Shadow(color: Color(0xFFFFC107), blurRadius: 7)'),
        isTrue,
        reason: '2 lớp bóng mờ cùng màu ⇒ chữ thành vệt mờ.',
      );
      expect(
        player.contains('color: Color(0x4DFFC107)'),
        isTrue,
        reason: 'Nét chữ thật phải gần trong suốt để chỉ còn vệt mờ.',
      );
    });

    test('không còn MaskFilter / ImageFilter / dart:ui', () {
      expect(player.contains('MaskFilter.blur('), isFalse);
      expect(player.contains('ImageFilter.blur('), isFalse);
      expect(player.contains("import 'dart:ui'"), isFalse);
    });

    test('vẫn giữ lối bấm để hiện tạm', () {
      expect(
        player.contains('_translationRevealed = !_translationRevealed'),
        isTrue,
      );
    });
  });

  // ── #3 — IN4-101: không nhận bản dịch rớt về ngôn ngữ nguồn ───────────
  group('#3 (IN4-101) — dịch không được rớt về tiếng Anh', () {
    test('có bước soi đầu ra trước khi nhận kết quả engine', () {
      expect(
        translation.contains('bool _looksUntranslated('),
        isTrue,
        reason: 'BUG GỐC: _runEngineChain nhận mọi kết quả isSuccess, trong '
            'khi MyMemory/Libre/Google trả nguyên văn bản nguồn khi hết quota '
            '⇒ app dùng tiếng Anh làm "bản dịch tiếng Việt".',
      );
      expect(
        translation.contains('static String _normalizeForCompare(String s)'),
        isTrue,
        reason: 'So "trùng nhau" phải bỏ qua hoa/thường và dấu câu.',
      );
    });

    test('áp dụng tại mọi điểm nhận kết quả trong chuỗi engine', () {
      final uses = '_looksUntranslated('.allMatches(translation).length;
      expect(
        uses >= 5,
        isTrue,
        reason: 'Phải soi ở online engines, Hy-MT, ML Kit và LLM '
            '(tìm thấy $uses chỗ, cần ít nhất 5: 1 định nghĩa + 4 điểm dùng).',
      );
    });

    test('có log để owner đọc được trên logcat khi bỏ qua', () {
      expect(
        translation.contains('trả về NGÔN NGỮ NGUỒN'),
        isTrue,
        reason: 'Bỏ qua mà không log ⇒ không bao giờ biết tại sao.',
      );
    });
  });

  // ── #7 — IN4-99: lịch sử phải được ghi ────────────────────────────────
  group('#7 (IN4-99) — lịch sử hoạt động phải ghi nhận', () {
    test('player ghi lịch sử (mọi đường vào đều đi qua đây)', () {
      expect(
        player.contains('await YtHistory.ensureOpen();'),
        isTrue,
        reason: 'Hive box có thể chưa mở ở luồng này.',
      );
      expect(
        player.contains('await YtHistory.add('),
        isTrue,
        reason: 'BUG GỐC: YtHistory.add() từng CHỈ được gọi ở '
            'youtube_sheet.dart (tầng 1 đã bị bỏ ở IN4-95) ⇒ luồng mới '
            'không bao giờ ghi lịch sử.',
      );
      // Gọi ở cả initState lẫn didUpdateWidget (đổi video trong player).
      final calls = 'unawaited(_recordHistory());'.allMatches(player).length;
      expect(
        calls >= 2,
        isTrue,
        reason: 'Phải ghi khi mở player và khi đổi video (thấy $calls chỗ).',
      );
    });

    test('explorer nạp lại lịch sử sau khi quay lại từ player', () {
      expect(
        explorer.contains('await _loadHistory();'),
        isTrue,
        reason: 'Nếu không nạp lại, danh sách Lịch sử vẫn là bản cũ đọc lúc '
            'initState.',
      );
      expect(
        explorer.contains('Future<void> _openVideo(YtExVideo v) async {'),
        isTrue,
        reason: 'Phải await Navigator.push để nạp lại sau khi pop.',
      );
    });
  });

  // ── #8 — IN4-100: từ loại phải hiện đúng ──────────────────────────────
  group('#8 (IN4-100) — bảng tra từ phải hiện từ loại', () {
    test('_classifyWordBasic có nhánh trạng từ', () {
      final body = syntax.substring(
        syntax.indexOf('WordType _classifyWordBasic(String w) {'),
        syntax.indexOf('WordType _classifyStopWord(String w) {'),
      );
      expect(
        body.contains('if (_adverbs.contains(w)) return WordType.adverb;'),
        isTrue,
        reason: 'BUG GỐC: nhánh _adverbs chỉ có trong _classifyStopWord, còn '
            '"very" không nằm trong _stopWords ⇒ rơi xuống unknown ⇒ hiện '
            '"từ" thay vì "trạng từ".',
      );
    });

    test('_parseWords map đầy đủ WordType', () {
      for (final entry in const [
        "WordType.verb => 'verb'",
        "WordType.adverb => 'adv'",
        "WordType.pronoun => 'pron'",
        "WordType.determiner => 'det'",
        "WordType.number => 'num'",
        "WordType.interjection => 'intj'",
      ]) {
        expect(player.contains(entry), isTrue, reason: 'Thiếu map $entry');
      }
    });

    test('_typeLabel có nhãn cho mọi từ loại mới', () {
      for (final entry in const [
        "'adv' => context.uiText('trạng từ')",
        "'pron' => context.uiText('đại từ')",
        "'det' => context.uiText('từ hạn định')",
        "'num' => context.uiText('số từ')",
        "'intj' => context.uiText('thán từ')",
      ]) {
        expect(panel.contains(entry), isTrue, reason: 'Thiếu nhãn $entry');
      }
    });
  });

  // ── #10 — IN4-102: tab VĂN BẢN tự động theo dòng hiện tại ─────────────
  group('#10 (IN4-102) — tab VĂN BẢN: tự do / tự động (mặc định tự động)',
      () {
    test('cài đặt mặc định BẬT và được lưu', () {
      expect(
        settings.contains('this.transcriptAutoFollow = true,'),
        isTrue,
        reason: 'Owner yêu cầu "auto là mặc định".',
      );
      expect(
        settings.contains("'transcriptAutoFollow': transcriptAutoFollow,"),
        isTrue,
        reason: 'Phải persist để không phải bật lại mỗi lần mở video.',
      );
      expect(
        settings.contains(
            "transcriptAutoFollow: json['transcriptAutoFollow'] as bool? ?? true,"),
        isTrue,
        reason: 'Dữ liệu cũ không có khoá này ⇒ vẫn mặc định BẬT.',
      );
    });

    test('cuộn tới dòng active bằng key RIÊNG của dòng đó', () {
      expect(
        player.contains('final GlobalKey _activeLineKey = GlobalKey();'),
        isTrue,
        reason: 'BUG GỐC: _buildTranscriptTab là ListView.builder trần, '
            'không có ScrollController ⇒ không theo dõi gì cả.',
      );
      expect(
        player.contains('key: isActive ? _activeLineKey : null,'),
        isTrue,
        reason: 'Chỉ gắn key cho dòng active — không phải hàng nghìn dòng.',
      );
      expect(
        player.contains('Scrollable.ensureVisible('),
        isTrue,
        reason: 'Cuộn chính xác bất kể chiều cao các dòng khác nhau.',
      );
      expect(
        player.contains('_followActiveLine();'),
        isTrue,
      );
    });

    test('có công tắc cho người dùng ở cả 2 nơi', () {
      expect(
        player.contains('Switch('),
        isTrue,
        reason: 'Công tắc ngay đầu tab VĂN BẢN.',
      );
      expect(
        player.contains('onChanged: _onAutoFollowChanged,'),
        isTrue,
      );
      expect(
        sheet.contains('transcriptAutoFollow: _autoFollow,'),
        isTrue,
        reason: 'Cùng một tuỳ chọn trong "Cài đặt phụ đề".',
      );
    });

    test('tôn trọng lựa chọn: tắt thì KHÔNG tự cuộn', () {
      expect(
        player.contains('if (!_settings.transcriptAutoFollow) return;'),
        isTrue,
        reason: 'Chế độ "cuộn tự do" không được giật lại vị trí đang đọc.',
      );
    });
  });
}
