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
// PSRC-177/180 (audit 1.26.0) — SUA GOP: P0 doc ket qua NGAY sau khi bat dau.
//   `executeWithArgumentsAsync` tra ve ngay khi session duoc TAO (tai lieu
//   plugin noi ro). Vi vay:
//     • `getReturnCode()` = null ⇒ `ReturnCode.isSuccess(null)` = false ⇒
//       "Tạo lời" luon bao *chuyen doi am thanh that bai (FFmpegKit)* (PSRC-180);
//     • `getOutput()` = '' ⇒ probe khong thay `Stream #0:0: Audio` ⇒ moi lan
//       xuat file deu bao *"File nguon khong co am thanh"* (PSRC-177).
//   Nay: cho `FFmpegSessionCompleteCallback` qua `SessionCompletionGate`, roi
//   moi doc return code/log; thêm 2 lop chan:
//     (a) log duoc thu song song qua logCallback (cat con ~200 KB) ⇒ neu native
//         da xoa log (mot `clearSessions()` khac chen vao) van con log de phan
//         loai loi va de probe doc thong tin luong;
//     (b) `clearSessions()` chi goi khi KHONG con session nao khac dang chay —
//         truoc day moi lenh deu xoa log cua MOI session, ke ca session dang
//         chay song song (vd. probe trong luc xuat file) ⇒ log bien mat giua
//         duong, cung gay ra "khong co am thanh" / "that bai" gia.
//
// `runFFmpegKit(List<String>)` va `probeFFmpegKit(String)` giu NGUYEN chu ky
// de moi caller cu (AudioConverter, VAD, Whisper) khong phai sua.

import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';

import 'ffmpeg_common.dart';
import 'session_completion_gate.dart';

/// Tran ky tu log giu lai trong RAM cho mot lan chay.
///
/// 200 KB ~ vai nghin dong — du de doc `Duration`/`Stream #`, du de biet vi sao
/// FFmpeg that bai, va khong lam phinh bo nho khi ma hoa file 2 gio.
const int _kMaxCapturedLogChars = 200000;

/// Phan log giu lai sau khi cat (nua tran) — cat nua dau, giu phan cuoi vi loi
/// that nam o cuoi log.
const int _kKeptAfterTrim = 100000;

/// So session FFmpegKit dang chay tren tien trinh nay.
///
/// `FFmpegKitConfig.clearSessions()` xoa log cua MOI session trong history ⇒
/// chi duoc goi khi bo dem nay ve 0.
int _inFlightSessions = 0;

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

  /// Goi khi duong huy da chay xong (du thanh cong hay khong).
  ///
  /// Muc dich: mo cong cho ket thuc lan chay ⇒ native treo thi UI van thoat.
  void Function()? onCancelSettled;

  bool get isCancelled => _cancelRequested;

  /// Gan session khi da tao xong. Neu da yeu cau huy truoc do (nguoi dung bam
  /// Huy trong luc FFmpegKit dang khoi tao session) thi huy ngay.
  void attach(FFmpegSession session) {
    _session = session;
    if (_cancelRequested) {
      // KHONG await: `cancel()` tren session chua kip chay co the treo
      // (native chua co handle) ⇒ ban UI se dung o "Dang huy...". Loi huy la
      // best-effort, `isCancelled` da duoc dat truoc khi goi.
      unawaited(_safeCancelSession(session).then((_) => onCancelSettled?.call()));
    }
  }

  Future<void> cancel() async {
    _cancelRequested = true;
    final session = _session;
    if (session == null) {
      // Chua co session ⇒ chi can mo cong; `attach` se huy ngay khi co.
      onCancelSettled?.call();
      return;
    }
    await _safeCancelSession(session);
    onCancelSettled?.call();
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

/// Giu phan cuoi cua log khi vuot tran (loi that nam o cuoi).
void _appendCapped(StringBuffer buffer, String message) {
  if (message.isEmpty) return;
  buffer.write(message);
  if (buffer.length <= _kMaxCapturedLogChars) return;
  final text = buffer.toString();
  buffer
    ..clear()
    ..write(text.substring(text.length - _kKeptAfterTrim));
}

/// Chay FFmpegKit bang ARGUMENT, co tien trinh + huy duoc.
///
/// [onElapsed] nhan so mili-giay FFmpeg da xu ly (khong phai % — nguoi goi
/// biet tong thoi luong nen chia lay phan tram; nho vay lop nay khong phai
/// probe duration).
///
/// HAM NAY CHI TRA VE KHI SESSION DA KET THUC (hoac da huy). Moi thay doi
/// trong thu tu duoi day deu phai giu dung tinh chat do — xem
/// `session_completion_gate.dart` (PSRC-177/180).
Future<FfmpegKitOutcome> runFFmpegKitWithProgress(
  List<String> args, {
  void Function(int elapsedMs)? onElapsed,
  FfmpegCancelToken? token,
}) async {
  final kitToken = _adapt(token);
  debugPrint('FFmpegKit args: ffmpeg ${args.join(' ')}');

  final gate = SessionCompletionGate<FFmpegSession?>();
  // Duong huy phai mo cong: native co the khong bao gio goi complete callback
  // (plugin treo) ⇒ ban UI dung o "Dang huy..." vo han.
  kitToken.onCancelSettled = () => gate.complete(null);

  final capturedLog = StringBuffer();

  _inFlightSessions++;
  try {
    final started = await FFmpegKit.executeWithArgumentsAsync(
      args,
      // (1) TIN HIEU KET THUC THAT SU. Khong duoc bo trong 3 tham so callback
      // nay: thieu complete callback ⇒ ham tra ve khi FFmpeg con dang chay.
      (session) => gate.complete(session),
      // (2) Log thu song song — du phong khi native da xoa log cua session.
      (Log log) => _appendCapped(capturedLog, log.getMessage()),
      onElapsed == null
          ? null
          : (statistics) {
              final ms = statistics.getTime();
              if (ms >= 0) onElapsed(ms);
            },
    );
    kitToken.attach(started);

    final finished = await gate.future;
    final session = finished ?? started;

    // Uu tien co huy: nguoi dung bam Huy thi ket qua la `cancelled`, khong
    // phai "that bai" (FFmpeg bi kill luon tra exit != 0 kem log rac).
    if (kitToken.isCancelled || finished == null) {
      final partial = await _safeReadOutput(session) ?? capturedLog.toString();
      return FfmpegKitOutcome(
        success: false,
        cancelled: true,
        output: partial,
      );
    }

    final returnCode = await _awaitReturnCode(session);
    final nativeOutput = await _safeReadOutput(session);
    final output = (nativeOutput != null && nativeOutput.isNotEmpty)
        ? nativeOutput
        : capturedLog.toString();

    if (ReturnCode.isCancel(returnCode) || kitToken.isCancelled) {
      return FfmpegKitOutcome(success: false, cancelled: true, output: output);
    }
    return FfmpegKitOutcome(
      success: ReturnCode.isSuccess(returnCode),
      cancelled: false,
      output: output,
    );
  } finally {
    _inFlightSessions--;
    if (_inFlightSessions <= 0) {
      _inFlightSessions = 0;
      // Giai phong session khoi history native (thay cho Future.delayed gia
      // lap). Chi khi khong con session nao khac dang chay — neu khong, log
      // cua session kia bi xoa giua duong (PSRC-177).
      try {
        await FFmpegKitConfig.clearSessions();
      } catch (e) {
        debugPrint('[FfmpegKit] clearSessions error: $e');
      }
    }
  }
}

/// Doc return code sau khi session da ket thuc.
///
/// Native co the tra `null` trong vai chuc mili-giay dau (session vua chuyen
/// sang COMPLETED) ⇒ cho ngan, toi da ~2 s. Van `null` ⇒ coi la that bai
/// (session FAILED: plugin khong tra return code cho trang thai do).
Future<ReturnCode?> _awaitReturnCode(FFmpegSession session) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final code = await session.getReturnCode();
    if (code != null) return code;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return null;
}

/// Doc log cua session, khong nem loi (native co the da xoa session).
Future<String?> _safeReadOutput(FFmpegSession session) async {
  try {
    return await session.getOutput();
  } catch (e) {
    debugPrint('[FfmpegKit] getOutput error: $e');
    return null;
  }
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

/// Probe thong tin input (`Duration`, `Stream #0:0: Audio: ...`).
///
/// KHONG truyen output ⇒ FFmpeg in header roi thoat voi "At least one output
/// file must be specified". Truoc day ham nay dung `-f null -`, tuc la GIAI MA
/// TOAN BO file chi de doc header: file 2 gio mat vai phut, va log bi cat ngan
/// ⇒ probe de "khong co am thanh". Return code o day la 1 (binh thuong) nen
/// KHONG duoc doi hoi success.
Future<String> probeFFmpegKit(String inputPath) async {
  final outcome = await runFFmpegKitWithProgress([
    '-hide_banner',
    '-nostdin',
    '-i',
    inputPath,
  ]);
  // `ffmpeg -i` khong co output ⇒ return code khac 0 la BINH THUONG; thong tin
  // (Duration/Stream) nam trong log. Vi vay khong duoc throw o day.
  return outcome.output;
}
