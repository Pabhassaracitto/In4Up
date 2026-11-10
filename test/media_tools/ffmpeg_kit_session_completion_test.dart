// test/media_tools/ffmpeg_kit_session_completion_test.dart
//
// PSRC-177 + PSRC-180 (audit v1.26.0) — MÁY BẮT cho gốc của cả hai issue.
//
// Gốc: `FFmpegKit.executeWithArgumentsAsync` trả về NGAY khi session vừa được
// TẠO (tài liệu plugin: "returns immediately and does not wait the execution to
// complete"). Bản P0 (AVTOOL-001) đọc `getReturnCode()` / `getOutput()` ngay
// sau lời gọi:
//   • `getReturnCode()` = null ⇒ `isSuccess(null)` = false ⇒ "Tạo lời" báo
//     *chuyển đổi âm thanh thất bại (FFmpegKit)* dù FFmpeg đang chạy đúng;
//   • `getOutput()` = '' ⇒ probe không thấy luồng nào ⇒ mọi lần xuất báo
//     *"File nguồn không có âm thanh"*.
//
// Vì plugin không chạy được trên host VM (PlatformException / native), test
// gồm hai lớp:
//   (1) hành vi của `SessionCompletionGate` — hàm THUẦN, đây là thứ buộc phải
//       `await` trước khi đọc kết quả;
//   (2) quét NGUỒN `ffmpeg_kit_impl.dart` để khẳng định THỨ TỰ đã đúng
//       (bỏ comment trước khi quét để không pass giả).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up_stt/utils/src/session_completion_gate.dart';

/// Bỏ comment dòng + comment khối (giữ nguyên số ký tự không cần thiết — chỉ
/// cần nguồn không còn chữ trong comment để không "pass giả").
String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(
    RegExp(r'/\*[\s\S]*?\*/'),
    '',
  );
  return withoutBlocks
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx >= 0 ? line.substring(0, idx) : line;
      })
      .join('\n');
}

const _kitImplPath =
    'packages/in4up_stt/lib/utils/src/ffmpeg_kit_impl.dart';

void main() {
  group('SessionCompletionGate', () {
    test('future KHÔNG hoàn tất trước complete() — đây chính là lỗi PSRC-180',
        () async {
      final gate = SessionCompletionGate<String>();
      var resolved = false;
      // ignore: unawaited_futures
      gate.future.then((_) => resolved = true);

      // Nhường event loop: nếu future "tự xong" thì test này đỏ.
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse,
          reason: 'cổng phải đóng cho tới khi native gọi complete callback');
      expect(gate.isCompleted, isFalse);

      gate.complete('session-xong');
      expect(await gate.future, 'session-xong');
      expect(gate.isCompleted, isTrue);
    });

    test('complete() lần hai là no-op (callback muộn sau khi đã Huỷ)', () async {
      final gate = SessionCompletionGate<String?>();
      expect(gate.complete(null), isTrue);
      // Khi người dùng bấm Huỷ, đường huỷ mở cổng trước; complete callback
      // của native tới sau ⇒ KHÔNG được ném StateError.
      expect(gate.complete('muộn'), isFalse);
      expect(await gate.future, isNull);
    });

    test('complete() nhiều lần chỉ có tác dụng lần đầu', () async {
      final gate = SessionCompletionGate<int>();
      expect(gate.complete(1), isTrue);
      expect(gate.complete(2), isFalse);
      expect(await gate.future, 1);
    });
  });

  group('ffmpeg_kit_impl.dart — thứ tự đọc kết quả (PSRC-177/180)', () {
    late String source;

    setUpAll(() {
      final file = File(_kitImplPath);
      expect(file.existsSync(), isTrue,
          reason: 'Không thấy $_kitImplPath — test chạy từ gốc repo');
      source = _stripComments(file.readAsStringSync());
    });

    test('chờ complete callback TRƯỚC khi đọc return code / log', () {
      final iExecute = source.indexOf('executeWithArgumentsAsync(');
      expect(iExecute, greaterThan(-1));

      final iComplete =
          source.indexOf('gate.complete', iExecute);
      final iAwaitGate = source.indexOf('await gate.future', iExecute);
      final iReturnCode =
          source.indexOf('_awaitReturnCode(session)', iExecute);

      expect(iComplete, greaterThan(iExecute),
          reason: 'phải truyền complete callback cho executeWithArgumentsAsync');
      expect(iAwaitGate, greaterThan(iComplete),
          reason: 'phải await cổng kết thúc');
      expect(iReturnCode, greaterThan(iAwaitGate),
          reason:
              'ĐỌC getReturnCode() TRƯỚC khi session xong ⇒ luôn null ⇒ '
              '"chuyển đổi âm thanh thất bại (FfmpegKit)" (PSRC-180)');
    });

    test('log được thu song song và có trần kích thước', () {
      expect(source, contains('capturedLog'),
          reason: 'cần bản log dự phòng khi native đã xoá log của session');
      expect(source, contains('_kMaxCapturedLogChars'),
          reason: 'log 2 giờ không được phình RAM vô hạn');
      expect(source, contains('_appendCapped'));
    });

    test('clearSessions() chỉ chạy khi không còn session nào khác', () {
      final iGuard = source.indexOf('_inFlightSessions <= 0');
      final iClear = source.indexOf('clearSessions()');
      expect(iGuard, greaterThan(-1),
          reason: 'clearSessions() xoá log của MỌI session ⇒ phải có cờ');
      expect(iClear, greaterThan(iGuard),
          reason: 'clearSessions() phải nằm TRONG nhánh đã kiểm cờ');
    });

    test('probe không giải mã toàn bộ file (`-f null -`)', () {
      final iProbe = source.indexOf('Future<String> probeFFmpegKit(');
      expect(iProbe, greaterThan(-1));
      final probeBody = source.substring(iProbe);
      expect(probeBody, contains("'-i'"));
      expect(probeBody, isNot(contains("'-f'")),
          reason:
              'decode cả file chỉ để đọc header khiến probe chậm và log bị cắt '
              '⇒ "File nguồn không có âm thanh" (PSRC-177)');
    });

    test('không đọc return code khi chưa có tín hiệu kết thúc ở đường huỷ', () {
      expect(source, contains('onCancelSettled'),
          reason:
              'native treo ⇒ đường huỷ phải mở cổng, nếu không UI đứng ở '
              '"Đang huỷ..." vô hạn');
    });
  });
}
