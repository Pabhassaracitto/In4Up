// PSRC-157 — Nhập bài hát ở tab Nghe KHÔNG được tự bật popup "Tạo lời".
//
// Trước đây `autoLoadCachedLrc()` đặt `_shouldOpenAiPanel = true` khi không tìm
// thấy LRC cache; `_SmartActionBarState` nghe signal đó và mở sheet AI ngay khi
// audio vừa load xong. Nay LRC cache vẫn được nạp im lặng, còn Whisper/LRC là
// hành động do người dùng bấm nút "Tạo lời".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/providers/player_provider.dart';

import 'support/fake_queue_player.dart';

void main() {
  final mixinSource = File('lib/providers/player/player_stt_mixin.dart')
      .readAsStringSync();
  final screenSource = File('lib/screens/listen_mode/listen_mode_screen.dart')
      .readAsStringSync();

  test('không còn signal tự mở sheet Tạo lời trong provider', () {
    expect(
      mixinSource.contains('_shouldOpenAiPanel = true'),
      isFalse,
      reason: 'Signal này làm popup Tạo lời chiếm màn hình khi nhập bài hát.',
    );
    expect(mixinSource, contains('PSRC-157'));
  });

  test('màn Nghe không còn nhánh tự mở AI panel theo signal', () {
    expect(screenSource.contains('shouldOpenAiPanel'), isFalse);
    expect(screenSource, contains('PSRC-157'));
    // Nút "Tạo lời" vẫn phải còn để người dùng chủ động mở.
    expect(screenSource, contains("label: 'Tạo lời'"));
  });

  test('provider mới không báo hiệu mở popup, kể cả khi gọi nạp LRC cache',
      () async {
    final player = PlayerProvider(
      audioService: FakeQueueAudio(),
      storage: FakeQueueStorage(),
      initializeSttService: false,
      loadCachedLrc: false,
    );
    addTearDown(player.dispose);
    expect(player.shouldOpenAiPanel, isFalse);
    // Không có LRC cache cho file này (plugin path_provider có thể vắng mặt
    // trong flutter_test — peekCachedLrc bắt lỗi và trả null).
    await player.autoLoadCachedLrc('/tmp/psrc-157-no-cache.mp3');
    expect(player.shouldOpenAiPanel, isFalse);
    expect(player.lrcJustGenerated, isFalse);
  });
}
