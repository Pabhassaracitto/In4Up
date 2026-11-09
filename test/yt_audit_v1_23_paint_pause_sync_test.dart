// Audit v1.23.0 — mục #2 / #3 / #4 (owner chốt 2026-11-06).
//
// Pin bằng cách quét MÃ NGUỒN (test thuần, không cần WebView / mạng / máy ảo)
// để các fix đã bàn giao không bị regress lặng lẽ:
//   • #3 YT-PAINT-002  — khay màu cho CẢ danh sách transcript.
//   • #4 YT-PAUSE-LOOKUP-001 — chạm từ khi đang phát thì tạm dừng cả video lẫn
//     giọng đọc TTS, đóng bảng tra từ thì chạy tiếp đúng chỗ.
//   • #2 YT-DIFF-SYNC-001 — màu YouTube ghi sang độ khó dùng chung (1 chiều).
//   • #5 YT-WATCH-QUICK-001 — lối tắt YouTube lên góc trái app bar tab Xem.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final player =
      File('lib/features/youtube/yt_player_screen.dart').readAsStringSync();
  final shell = File('lib/screens/main_shell.dart').readAsStringSync();
  final overrides =
      File('lib/core/language/priority_ui_overrides.dart').readAsStringSync();

  /// Cắt một hàm/phương thức ra khỏi file theo `void <name>(` hoặc
  /// `Widget <name>(` … cân ngoặc. Trả `''` nếu không thấy.
  String bodyOf(String src, String signature) {
    final start = src.indexOf(signature);
    if (start < 0) return '';
    var depth = 0;
    var opened = false;
    for (var i = start; i < src.length; i++) {
      final c = src[i];
      if (c == '{') {
        depth++;
        opened = true;
      } else if (c == '}') {
        depth--;
        if (opened && depth == 0) return src.substring(start, i + 1);
      }
    }
    return '';
  }

  group('#3 — khay màu cho danh sách transcript', () {
    test('có trạng thái + builder riêng cho khay của danh sách', () {
      expect(player.contains('WordState? _tsPaintState;'), isTrue);
      expect(player.contains('bool _tsPaintOpen = false;'), isTrue);
      expect(player.contains('Widget _buildTranscriptPaintTray()'), isTrue);
      expect(player.contains('void _tsPaintWord(LrWord word)'), isTrue);
    });

    test('tab Phụ đề mở được khay màu (icon 🎨 trong header)', () {
      final tab = bodyOf(player, 'Widget _buildTranscriptTab()');
      expect(tab, isNotEmpty);
      expect(tab.contains('Icons.palette_outlined'), isTrue);
      expect(tab.contains('_tsPaintOpen = !_tsPaintOpen'), isTrue);
      expect(tab.contains('_buildTranscriptPaintTray()'), isTrue);
    });

    test('chạm từ trong danh sách: đang mở khay thì TÔ, không mở bảng tra từ',
        () {
      final words = bodyOf(player, 'Widget _buildTranscriptWords(');
      expect(words, isNotEmpty);
      expect(words.contains('final painting = _tsPaintOpen;'), isTrue);
      expect(words.contains('_tsPaintWord(w)'), isTrue);
      expect(words.contains('_showWordPopup(w)'), isTrue);
      // Từ chưa chọn màu vẫn phải được nhắc, không im lặng không làm gì.
      expect(player.contains('Chưa chọn màu'), isTrue);
    });

    test('khay dòng đang phát và khay danh sách là HAI biến riêng', () {
      expect(player.contains('WordState? _paintState;'), isTrue);
      // `_paintWord` (khay dòng hiện tại) không được đọc `_tsPaintState`.
      final paintWord = bodyOf(player, 'void _paintWord(LrWord word)');
      expect(paintWord, isNotEmpty);
      expect(paintWord.contains('_tsPaintState'), isFalse);
    });

    test('nhãn khay màu transcript có bản dịch (rule #5)', () {
      for (final label in <String>[
        'Khay màu cho cả danh sách',
        'Chọn màu, rồi bấm vào từ ở bất kỳ dòng nào',
        'Chưa chọn màu — bấm Đã biết / Đang học / Bỏ qua trước khi tô',
        'Màu này áp cho cả hệ (Đọc / Web / Từ vựng) — đổi ở đâu cũng đổi chung',
      ]) {
        expect(overrides.contains("'$label':"), isTrue,
            reason: 'thiếu bản dịch cho "$label"');
      }
    });
  });

  group('#4 — tạm dừng khi chạm từ để tra nghĩa', () {
    test('_pauseVideo/_resumeVideo có đường dự phòng ngoài wrapper', () {
      final pause = bodyOf(player, 'void _pauseVideo()');
      final resume = bodyOf(player, 'void _resumeVideo()');
      expect(pause, isNotEmpty);
      expect(resume, isNotEmpty);
      for (final fn in <String>[pause, resume]) {
        // Wrapper GitHub Pages (window._in4up*) KHÔNG phải đường duy nhất:
        // player API và thẻ <video> của tài liệu là hai đường còn lại.
        expect(fn.contains('window.player'), isTrue);
        expect(fn.contains('_in4up'), isTrue);
        expect(fn.contains("querySelector('video')"), isTrue);
      }
    });

    test('_isVideoPlaying hỏi player API trước khi dò thẻ <video>', () {
      final playing = bodyOf(player, 'Future<bool> _isVideoPlaying()');
      expect(playing, isNotEmpty);
      expect(playing.contains('getPlayerState'), isTrue);
      // So vị trí của MÃ (không phải chữ trong chú thích — chú thích cũng
      // nhắc `querySelector` nên phải bám vào câu lệnh thật).
      final apiAt = playing.indexOf('window.player.getPlayerState');
      final videoAt = playing.indexOf('var v=document.querySelector');
      expect(apiAt, greaterThan(-1));
      expect(videoAt, greaterThan(-1));
      expect(apiAt, lessThan(videoAt),
          reason: 'player API phải được hỏi TRƯỚC (querySelector không thấy '
              'video trong iframe khác origin)');
    });

    test('đóng bảng tra từ thì chỉ chạy tiếp thứ CHÍNH APP đã dừng', () {
      final popup = bodyOf(player, 'Future<void> _showWordPopup(LrWord word)');
      expect(popup, isNotEmpty);
      expect(popup.contains('final wasPlaying = await _isVideoPlaying();'),
          isTrue);
      // TTS đang chạy ⇒ dừng và nhớ dòng đang đọc.
      expect(popup.contains('ctrl.isRunning'), isTrue);
      expect(popup.contains('ctrl.activeLine'), isTrue);
      expect(popup.contains('await ctrl.stop();'), isTrue);
      // Chạy tiếp đúng bên đã dừng.
      expect(popup.contains('_startReadAloud(fromIndex: resumeReadFrom)'),
          isTrue);
      expect(popup.contains('if (wasPlaying && !_readAloudRunning) _resumeVideo();'),
          isTrue);
    });

    test('đọc-aloud có MỘT nơi dựng tham số TTS (start lại được từ dòng bất kỳ)',
        () {
      expect(player.contains('Future<void> _startReadAloud({required int fromIndex})'),
          isTrue);
      final open = bodyOf(player, 'Future<void> _openReadAloud()');
      expect(open, isNotEmpty);
      expect(open.contains('_startReadAloud('), isTrue);
      // Không còn gọi thẳng `ctrl.start(` trong _openReadAloud.
      expect(open.contains('ctrl.start('), isFalse);
    });
  });

  group('#2 — màu YouTube ghi sang độ khó dùng chung (một chiều)', () {
    test('3 màu ánh xạ sang DifficultyLevel, "chưa đánh dấu" thì không xoá', () {
      final map = bodyOf(player, 'static DifficultyLevel? _difficultyForState(');
      expect(map, isNotEmpty);
      expect(map.contains('DifficultyLevel.easy'), isTrue);
      expect(map.contains('DifficultyLevel.hard'), isTrue);
      expect(map.contains('DifficultyLevel.veryHard'), isTrue);
      expect(map.contains('WordState.unknown'), isTrue);
      // unknown ⇒ null (không ghi đè độ khó người dùng đặt ở tab Đọc).
      final unknownAt = map.indexOf('case WordState.unknown:');
      expect(map.substring(unknownAt).contains('return null;'), isTrue);
    });

    test('đường ghi là VocabularyBridge.upsertDifficulty (dùng lại API sẵn có)',
        () {
      final sync = bodyOf(player, 'void _syncSharedDifficulty(');
      expect(sync, isNotEmpty);
      expect(sync.contains('VocabularyBridge.upsertDifficulty('), isTrue);
      // Chưa init() thì no-op, KHÔNG được làm hỏng thao tác tô màu.
      expect(sync.contains('try {'), isTrue);
      expect(sync.contains('catch (e)'), isTrue);
    });

    test('_setWordState gọi đồng bộ độ khó', () {
      final set = bodyOf(player, 'void _setWordState(String word, WordState state)');
      expect(set, isNotEmpty);
      expect(set.contains('_syncSharedDifficulty(word, state);'), isTrue);
    });

    test('không đọc NGƯỢC (tab Đọc → YouTube): YouTube không đọc userDifficulty',
        () {
      // Một chiều là quyết định của owner: 3 màu ↔ 4 mức là ánh xạ mất mát.
      expect(player.contains('difficultyOf('), isFalse,
          reason: 'YouTube không được đọc ngược độ khó từ hệ chung');
    });
  });

  group('#5 — tab Xem: lối tắt lên góc trên trái', () {
    test('app bar tab Xem có thư viện văn bản + YouTube + thư viện video', () {
      final appBar = bodyOf(shell, 'Widget _buildAppBar(BuildContext context)');
      expect(appBar, isNotEmpty);
      expect(appBar.contains("_handleTool('youtube_downloader')"), isTrue);
      expect(appBar.contains("_handleTool('video_library')"), isTrue);
      expect(appBar.contains('Icons.menu_book_rounded'), isTrue);
      // Nhánh bấm nút trái: tab Xem đi cùng đường với tab Đọc.
      expect(appBar.contains('if (isReader || isWatch)'), isTrue);
    });

    test('header "Video thiết bị" không còn nút YouTube lặp lại', () {
      final header = bodyOf(shell, 'Widget _buildListenContextHeader(');
      expect(header, isNotEmpty);
      final watchBranchStart = header.indexOf('_listenModeIndex == 2');
      expect(watchBranchStart, greaterThan(-1));
      final watchBranch = header.substring(watchBranchStart);
      expect(watchBranch.contains('youtube_downloader'), isFalse,
          reason: 'nút YouTube đã lên app bar, không được lặp ở header');
    });
  });
}
