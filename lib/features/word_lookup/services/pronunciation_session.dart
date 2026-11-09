// lib/features/word_lookup/services/pronunciation_session.dart
//
// PRON-002 (quyết định D4 — "Tương tác với Read Aloud") — mở sheet phát âm
// trong lúc đang đọc bài thì PHẢI nhường tiếng, và khi tắt sheet thì ĐỌC TIẾP
// đúng dòng đang đọc.
//
// Vì sao không có "pause" thật: `flutter_tts` không có pause — `TextProvider`
// chỉ có stop (`stopSpeaking()` → `_stopAllTts(clearReadingCursor: true)`,
// `currentLineIndex` bị xoá). Nên "tạm dừng" ở đây = **ghi lại dòng neo TRƯỚC
// khi stop, rồi restore bằng `speakAllLines(startIndex: anchor)`**. Đã đối
// chiếu `lib/providers/text_provider.dart` trên tip `0706d8f` (speak :1498,
// stopSpeaking :1514, speakAllLines :1458, currentLineIndex :225).
//
// GIỚI HẠN thành thật (ghi rõ trong KANBAN PRON-002):
//  * Segment playback / AB-loop (`isPlayingSegment`) cũng bị dừng để nhường
//    tiếng, nhưng KHÔNG tự chạy lại — nó ngắn và có nút điều khiển riêng;
//    restore tự động dễ thành "tự nhiên đọc lại đoạn cũ".
//  * Nếu người dùng bấm phát âm (hay bất kỳ TTS nào) NGAY TRONG sheet, ta
//    không restore đè lên — xem `_shouldRestore`.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../providers/text_provider.dart';

class PronunciationSession {
  PronunciationSession._();

  static int _depth = 0;
  static bool _wasReading = false;
  static int _anchorLine = -1;
  static bool _wasPlayingSegment = false;

  /// Có đang mở một sheet phát âm được bọc bởi session này không.
  static bool get isActive => _depth > 0;

  /// Chạy [openSheet] (thường là `await showModalBottomSheet(...)`) với quyền
  /// nhường tiếng: dừng đọc bài, ghi neo dòng, và đọc tiếp khi sheet đóng.
  static Future<void> wrapRead(
    BuildContext context,
    Future<void> Function() openSheet,
  ) async {
    final TextProvider tp;
    try {
      tp = context.read<TextProvider>();
    } catch (_) {
      // Không có TextProvider (vd surface ngoài Read Mode) ⇒ chỉ mở sheet.
      await openSheet();
      return;
    }

    if (_depth == 0) {
      _wasReading = tp.isSpeaking;
      _anchorLine = _wasReading ? tp.currentLineIndex : -1;
      _wasPlayingSegment = tp.isPlayingSegment;
      if (_wasReading) {
        await tp.stopSpeaking();
      }
      if (_wasPlayingSegment) {
        await tp.stopSegmentPlayback();
      }
    }

    _depth++;
    try {
      await openSheet();
    } finally {
      _depth--;
      if (_depth == 0) {
        final wasReading = _wasReading;
        final anchor = _anchorLine;
        final wasPlayingSegment = _wasPlayingSegment;
        _wasReading = false;
        _anchorLine = -1;
        _wasPlayingSegment = false;

        // Restore reading trừ khi: không có gì để restore, người dùng đã tự
        // bắt đầu TTS khác (đừng đè), hoặc segment đang chạy trở lại.
        final shouldRestore = wasReading &&
            anchor >= 0 &&
            !tp.isSpeaking &&
            !tp.isPlayingSegment &&
            !wasPlayingSegment;
        if (shouldRestore) {
          unawaited(tp.speakAllLines(startIndex: anchor));
        }
      }
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _depth = 0;
    _wasReading = false;
    _anchorLine = -1;
    _wasPlayingSegment = false;
  }
}
