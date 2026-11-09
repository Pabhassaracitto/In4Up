// ffmpeg_kit_impl.dart — Mobile only
// File nay import ffmpeg_kit_flutter_new, chi duoc goi tren Android/iOS
// Tren Windows, CMake patch da loai plugin khoi build, nen neu co goi nham
// se throw, nhung _useFFmpegKit guard dam bao khong goi.
//
// AVTOOL-001 (PLAN-047 P0) — ba thay doi, KHONG doi API cu:
//   1. Chay bang ARGUMENT (`executeWithArguments`) thay vi ghep mot chuoi
//      lenh. Truoc day `quotePath()` chi boc ngoac kep va escape `"` ⇒ ten
//      file co dau nhay don `'` lam FFmpegKit tach sai tham so (loi that,
//      xay ra voi ten file tieng Anh co apostrophe: "Don't stop.mp3").
//      Gio moi phan tu la 1 argv ⇒ khong con escaping thu cong.
//   2. GIU `FFmpegSession` ⇒ huy duoc tac vu dang chay (tac vu 90 phut tren
//      may yeu truoc day khong the dung lai). Callback tien trinh theo
//      session (khong dung callback global ⇒ khong tranh chap giua 2 tac vu).
//   3. `FFmpegKitConfig.clearSessions()` thay cho `Future.delayed(50ms)`
//      (comment cu ghi "giai phong native RAM" nhung delay khong giai phong
//      gi ca — session van nam trong history cua native).
//
// `runFFmpegKit(List<String>)` va `probeFFmpegKit(String)` giu NGUYEN chu ky
// de moi caller cu (AudioConverter, VAD, Whisper) khong phai sua.

import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';

import 'ffmpeg_common.dart';

/// Ket qua mot lan chay FFmpegKit (mobile).
class FfmpegKitOutcome {
  final bool success;
  final bool cancelled;

  /// Toan bo log cua phien (dung de bao loi cho nguoi dung / chan doan).
  final String output;

  const FfmpegKitOutcome({
    required this.success,
    required this.cancelled,
    required this.output,
  });
}

/// Tach huy (cancel) cho mot lan chay FFmpegKit.
///
/// Vi sao khong chi dung `Future` + `Timer`: huy phai xuong native
/// (`session.cancel()`), va neu nguoi dung bam Huy TRUOC khi session duoc tao
/// xong thi co phai nho y dinh do (`_cancelRequested`) de huy ngay khi co.
class FfmpegKitCancelToken {
  FFmpegSession? _session;
  bool _cancelRequested = false;

  bool get isCancelled => _cancelRequested;

  /// Gan session khi da tao xong. Neu da yeu cau huy truoc do (nguoi dung bam
  /// Huy trong luc FFmpegKit dang khoi tao session) thi huy ngay.
  void attach(FFmpegSession session) {
    _session = session;
    if (_cancelRequested) {
      // KHONG await: `cancel()` tren session chua kip chay co the treo
      // (native chua co handle) ⇒ ban UI se dung o "Dang huy...". Loi huy la
      // best-effort, `isCancelled` da duoc dat truoc khi goi.
      unawaited(_safeCancelSession(session));
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    final session = _session;
    if (session == null) return;
    await _safeCancelSession(session);
  }

  /// Huy co TRAN (timeout): dou be native khong bao gio tra loi (session dang
  /// khoi tao, plugin bi treo), nguoi dung KHONG duoc thay dialog quay mai.
  /// Sau 5 s ta bo cho va coi nhu da huy — `session.getReturnCode()` van la
  /// tin hieu chinh de biet tac vu that su dung.
  Future<void> _safeCancelSession(FFmpegSession session) async {
    try {
      await Future.any<void>([
        session.cancel(),
        Future<void>.delayed(const Duration(seconds: 5)),
      ]);
    } catch (e) {
      debugPrint('[FfmpegKit] cancel error: $e');
    }
  }
}

/// Noi [FfmpegCancelToken] dung chung (tang tren) vao duong FFmpegKit.
///
/// Nho lop noi nay, `ffmpeg_kit_impl.dart` khong phai biet gi ve desktop va
/// `ffmpeg_runner.dart` khong phai giu 2 token rieng.
FfmpegKitCancelToken _adapt(FfmpegCancelToken? shared) {
  final kit = FfmpegKitCancelToken();
  shared?.onCancel(() {
    kit.cancel();
  });
  return kit;
}

/// Chay FFmpegKit bang ARGUMENT, co tien trinh + huy duoc.
///
/// [onElapsed] nhan so mili-giay FFmpeg da xu ly (khong phai % — nguoi goi
/// biet tong thoi luong nen chia lay phan tram; nho vay lop nay khong phai
/// probe duration).
Future<FfmpegKitOutcome> runFFmpegKitWithProgress(
  List<String> args, {
  void Function(int elapsedMs)? onElapsed,
  FfmpegCancelToken? token,
}) async {
  final kitToken = _adapt(token);
  debugPrint('FFmpegKit args: ffmpeg ${args.join(' ')}');

  final session = await FFmpegKit.executeWithArgumentsAsync(
    args,
    null,
    null,
    onElapsed == null
        ? null
        : (statistics) {
            final ms = statistics.getTime();
            if (ms >= 0) onElapsed(ms);
          },
  );
  kitToken.attach(session);

  final returnCode = await session.getReturnCode();
  final output = (await session.getOutput()) ?? '';

  // Giai phong session khoi history native (thay cho Future.delayed gia lap).
  try {
    await FFmpegKitConfig.clearSessions();
  } catch (e) {
    debugPrint('[FfmpegKit] clearSessions error: $e');
  }

  if (ReturnCode.isCancel(returnCode) || kitToken.isCancelled) {
    return FfmpegKitOutcome(success: false, cancelled: true, output: output);
  }
  return FfmpegKitOutcome(
    success: ReturnCode.isSuccess(returnCode),
    cancelled: false,
    output: output,
  );
}

/// Chay FFmpegKit (mobile) — GIU NGUYEN chu ky cu cho caller san co.
Future<void> runFFmpegKit(List<String> args) async {
  final outcome = await runFFmpegKitWithProgress(args);
  if (outcome.success) return;
  if (outcome.cancelled) {
    throw Exception('Chuyen doi am thanh bi huy (FFmpegKit).');
  }
  throw Exception('Chuyen doi am thanh that bai (FFmpegKit): ${outcome.output}');
}

Future<String> probeFFmpegKit(String inputPath) async {
  final outcome = await runFFmpegKitWithProgress([
    '-hide_banner',
    '-i',
    inputPath,
    '-f',
    'null',
    '-',
  ]);
  // `ffmpeg -i` khong co output ⇒ return code khac 0 la BINH THUONG; thong tin
  // (Duration/Stream) nam trong log. Vi vay khong duoc throw o day.
  return outcome.output;
}
