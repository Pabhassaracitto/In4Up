// I4U18-PDF-OCR-TTS-001 (Agent F · F3) — máy trạng thái Play/Pause/Stop/Next.
//
// Ba lỗi thực địa được khoá ở đây:
//   • Stop rồi mà callback của phiên cũ vẫn phát tiếp;
//   • Next nhảy nhiều dòng vì callback cũ và phiên mới cùng đẩy chỉ số;
//   • bấm hai lần thật nhanh mở hai phiên chồng nhau.

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_tts_machine.dart';

void main() {
  group('PdfTtsMachine — chuyển trạng thái cơ bản', () {
    test('mặc định là idle, chưa có phiên nào sống', () {
      final m = PdfTtsMachine();
      expect(m.state, PdfTtsState.idle);
      expect(m.isActive, isFalse);
      expect(m.isCurrent(m.session), isFalse);
    });

    test('idle → Play = start; phiên mới ở trạng thái loading', () {
      final m = PdfTtsMachine();
      expect(m.onPlayPressed(), PdfTtsCommand.start);

      final session = m.beginSession();
      expect(m.state, PdfTtsState.loading);
      expect(m.isCurrent(session), isTrue);

      m.markPlaying(session);
      expect(m.state, PdfTtsState.playing);
    });

    test('playing → Play = pause; paused → Play = resume', () {
      final m = PdfTtsMachine();
      final s = m.beginSession();
      m.markPlaying(s);

      expect(m.onPlayPressed(), PdfTtsCommand.pause);
      m.markPaused(s);
      expect(m.state, PdfTtsState.paused);
      expect(m.isActive, isTrue, reason: 'tạm dừng vẫn là đang trong phiên');

      expect(m.onPlayPressed(), PdfTtsCommand.resume);
      m.markResumed(s);
      expect(m.state, PdfTtsState.playing);
    });

    test('loading → Play lần nữa = stop (đổi ý, không xếp thêm phiên)', () {
      final m = PdfTtsMachine();
      m.beginSession();
      expect(m.onPlayPressed(), PdfTtsCommand.stop);
    });
  });

  group('Stop chặn callback phát tiếp', () {
    test('markStopped đổi phiên → callback phiên cũ hết hiệu lực', () {
      final m = PdfTtsMachine();
      final s = m.beginSession();
      m.markPlaying(s);

      m.markStopped();

      expect(m.state, PdfTtsState.idle);
      expect(m.isCurrent(s), isFalse);
      // Callback đến muộn của phiên cũ không được bật lại trạng thái phát.
      m.markPlaying(s);
      expect(m.state, PdfTtsState.idle);
    });

    test('finally của phiên CŨ không được đạp lên phiên MỚI', () {
      final m = PdfTtsMachine();
      final old = m.beginSession();
      m.markPlaying(old);

      m.markStopped(); // Next/Stop
      final fresh = m.beginSession();
      m.markPlaying(fresh);

      // Vòng lặp cũ mới kết thúc bây giờ:
      m.markFinished(old);

      expect(m.state, PdfTtsState.playing,
          reason: 'phiên mới phải sống sót qua cái chết của phiên cũ');
      expect(m.isCurrent(fresh), isTrue);
    });

    test('markFinished của phiên hiện tại mới hạ về idle', () {
      final m = PdfTtsMachine();
      final s = m.beginSession();
      m.markPlaying(s);
      m.markFinished(s);
      expect(m.state, PdfTtsState.idle);
    });
  });

  group('Next line — đúng một dòng, không lướt', () {
    test('đang phát → restartAtCue (dừng phiên cũ rồi phát câu mục tiêu)', () {
      final m = PdfTtsMachine();
      final s = m.beginSession();
      m.markPlaying(s);
      expect(m.onStepPressed(), PdfTtsCommand.restartAtCue);
    });

    test('đang tạm dừng → chỉ dời con trỏ, KHÔNG tự phát', () {
      final m = PdfTtsMachine();
      final s = m.beginSession();
      m.markPlaying(s);
      m.markPaused(s);
      expect(m.onStepPressed(), PdfTtsCommand.none);
      expect(m.state, PdfTtsState.paused);
    });

    test('đang idle → không phát gì cả', () {
      final m = PdfTtsMachine();
      expect(m.onStepPressed(), PdfTtsCommand.none);
      expect(m.state, PdfTtsState.idle);
    });

    test('mỗi lần Next chỉ tăng phiên một lần', () {
      final m = PdfTtsMachine();
      final s0 = m.beginSession();
      m.markPlaying(s0);

      m.markStopped();
      final s1 = m.beginSession();
      m.markPlaying(s1);

      expect(s1, greaterThan(s0));
      expect(m.isCurrent(s0), isFalse);
      expect(m.isCurrent(s1), isTrue);
    });
  });

  group('Guard double-tap / reentrant', () {
    test('beginTransition thứ hai bị từ chối tới khi endTransition', () {
      final m = PdfTtsMachine();
      expect(m.beginTransition(), isTrue);
      expect(m.beginTransition(), isFalse, reason: 'double-tap phải bị nuốt');
      expect(m.isBusy, isTrue);

      m.endTransition();
      expect(m.isBusy, isFalse);
      expect(m.beginTransition(), isTrue);
    });

    test('hai lần bấm Play sát nhau chỉ mở MỘT phiên', () {
      final m = PdfTtsMachine();

      var sessionsOpened = 0;
      void tapPlay() {
        if (!m.beginTransition()) return;
        // Cố ý KHÔNG endTransition: lần bấm thứ hai xảy ra TRƯỚC khi lần
        // đầu kết thúc — đúng kịch bản double-tap.
        if (m.onPlayPressed() == PdfTtsCommand.start) {
          m.beginSession();
          sessionsOpened++;
        }
      }

      tapPlay();
      tapPlay();

      expect(sessionsOpened, 1);
      m.endTransition();
    });
  });
}
