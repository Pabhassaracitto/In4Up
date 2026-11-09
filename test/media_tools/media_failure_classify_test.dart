// test/media_tools/media_failure_classify_test.dart
//
// AVTOOL-002 (PLAN-047 P1) — máy bắt cho "lỗi FFmpeg thô → lỗi người hiểu",
// cộng khoá lại 2 quyết định định dạng của owner (PLAN-047 §12.3/§12.4).
//
// Vì sao cần: nếu chỉ hiện log thô, người dùng thấy "moov atom not found" và
// tưởng app hỏng. Phân loại sai còn tệ hơn: gộp "no space" vào "failed" thì
// mất cơ hội nhắc người dùng dọn máy, họ bấm lại nhiều lần vô ích.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/media_tools/models/media_export_models.dart';
import 'package:in4up/features/media_tools/services/media_ffmpeg_engine.dart';

void main() {
  group('classifyFfmpegFailure', () {
    MediaExportErrorKind classify(
      String out, {
      bool cancelled = false,
      bool missing = false,
    }) =>
        classifyFfmpegFailure(
          output: out,
          cancelled: cancelled,
          ffmpegMissing: missing,
        );

    test('huỷ luôn thắng mọi mẫu log khác', () {
      expect(
        classify('No space left on device', cancelled: true),
        MediaExportErrorKind.cancelled,
      );
    });

    test('thiếu binary ⇒ ffmpegMissing (để UI mời tải, không báo "failed")', () {
      expect(classify('', missing: true), MediaExportErrorKind.ffmpegMissing);
    });

    test('file không đọc được', () {
      expect(
        classify('talk.m4a: No such file or directory'),
        MediaExportErrorKind.inputUnreadable,
      );
      expect(
        classify('moov atom not found'),
        MediaExportErrorKind.inputUnreadable,
      );
    });

    test('không có luồng âm thanh (video câm)', () {
      expect(
        classify('Output file does not contain any stream'),
        MediaExportErrorKind.noAudioTrack,
      );
    });

    test('hết dung lượng — KHÔNG được gộp vào failed', () {
      expect(
        classify('av_interleaved_write_frame(): No space left on device'),
        MediaExportErrorKind.noSpace,
      );
    });

    test('thiếu encoder / codec', () {
      expect(
        classify('Unknown encoder libmp3lame'),
        MediaExportErrorKind.unsupported,
      );
      expect(classify('Protocol not found'), MediaExportErrorKind.unsupported);
    });

    test('lỗi lạ ⇒ failed (không đoán bừa)', () {
      expect(classify('Conversion failed!'), MediaExportErrorKind.failed);
    });
  });

  group('MediaExportError', () {
    test('mọi loại lỗi có thông điệp canonical TIẾNG ANH (rule #5)', () {
      final vietnamese = RegExp(r'[đĐơƠưƯảạằắẳẵặầấẩẫậẻẽẹềếểễệỉĩịỏọồốổỗộờớởỡợủũụừứửữựỳỷỹỵ]');
      for (final kind in MediaExportErrorKind.values) {
        final message = MediaExportError(kind).technicalMessage;
        expect(message, isNotEmpty, reason: kind.name);
        expect(
          vietnamese.hasMatch(message),
          isFalse,
          reason: '${kind.name} — tầng service không có BuildContext, '
              'chuỗi canonical phải là tiếng Anh',
        );
      }
    });
  });

  group('MediaExportProgress', () {
    test('done/failed/cancelled là trạng thái kết thúc', () {
      for (final phase in MediaExportPhase.values) {
        final progress = MediaExportProgress(phase: phase);
        final terminal = phase == MediaExportPhase.done ||
            phase == MediaExportPhase.failed ||
            phase == MediaExportPhase.cancelled;
        expect(progress.isTerminal, terminal, reason: phase.name);
      }
    });
  });

  group('MediaExportPreset — quyết định định dạng của owner (§12.3)', () {
    test('CLIP A–B mặc định MP3 192 kbps', () {
      expect(
        MediaExportPreset.recommended(inputExtension: '.wav', isClip: true),
        MediaExportPreset.mp3Standard,
      );
      expect(
        MediaExportPreset.recommended(inputExtension: '.m4a', isClip: true),
        MediaExportPreset.mp3Standard,
      );
    });

    test('cả file AAC/MP4 mặc định copy sang m4a (nhanh, không mất chất)', () {
      for (final ext in ['.m4a', '.mp4', '.m4b', '.aac', 'm4a', 'M4A']) {
        expect(
          MediaExportPreset.recommended(inputExtension: ext),
          MediaExportPreset.m4aCopy,
          reason: ext,
        );
      }
    });

    test('cả file khác (mp3/wav/opus/flac/ogg) mặc định MP3 192 kbps', () {
      for (final ext in ['.mp3', '.wav', '.opus', '.flac', '.ogg']) {
        expect(
          MediaExportPreset.recommended(inputExtension: ext),
          MediaExportPreset.mp3Standard,
          reason: ext,
        );
      }
    });

    test('CHỈ m4aCopy là chế độ copy — còn lại đều mã hoá lại', () {
      for (final preset in MediaExportPreset.values) {
        expect(
          preset.isCopy,
          preset == MediaExportPreset.m4aCopy,
          reason: preset.name,
        );
      }
    });

    test('mọi preset có nhãn nguồn để dịch (rule #5)', () {
      for (final preset in MediaExportPreset.values) {
        expect(preset.labelKey.trim(), isNotEmpty, reason: preset.name);
      }
    });

    test('preset copy không có bitrate ước lượng (phải lấy từ nguồn)', () {
      expect(MediaExportPreset.m4aCopy.estimatedBitrateKbps, isNull);
    });
  });

  group('MediaExportRequest.copyWith', () {
    test('giữ nguyên trường không truyền', () {
      const request = MediaExportRequest(
        inputPath: '/in.mp3',
        preset: MediaExportPreset.mp3Standard,
        scope: MediaExportScope.clip,
        start: Duration(seconds: 5),
        title: 'Câu 1',
      );
      final copy = request.copyWith(preset: MediaExportPreset.m4aAac);
      expect(copy.preset, MediaExportPreset.m4aAac);
      expect(copy.scope, MediaExportScope.clip);
      expect(copy.start, const Duration(seconds: 5));
      expect(copy.inputPath, '/in.mp3');
      expect(copy.title, 'Câu 1');
    });
  });
}
