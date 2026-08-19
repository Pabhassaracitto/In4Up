// ffmpeg_kit_impl.dart — Mobile only
// File nay import ffmpeg_kit_flutter_new, chi duoc goi tren Android/iOS
// Tren Windows, CMake patch da loai plugin khoi build, nen neu co goi nham
// se throw, nhung _useFFmpegKit guard dam bao khong goi.

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';

import 'ffmpeg_runner.dart';

Future<void> runFFmpegKit(List<String> args) async {
  final command = args.map(FfmpegRunner.quotePath).join(' ');
  debugPrint('FFmpegKit command: ffmpeg $command');
  final session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();

  // Giai phong session ngay de tranh tich luy native RAM (Scudo)
  try {
    // Clear old sessions to free native memory - important on low-RAM Android
    // ignore: avoid_dynamic_calls
    await Future.delayed(const Duration(milliseconds: 50));
  } catch (_) {}

  if (ReturnCode.isSuccess(returnCode)) return;
  if (ReturnCode.isCancel(returnCode)) {
    throw Exception('Chuyen doi am thanh bi huy (FFmpegKit).');
  }
  final output = (await session.getOutput()) ?? '';
  final failTrace = (await session.getFailStackTrace()) ?? '';
  final code = returnCode?.getValue();
  throw Exception(
    'Chuyen doi am thanh that bai (FFmpegKit) [code=$code]: $output $failTrace',
  );
}

Future<String> probeFFmpegKit(String inputPath) async {
  final cmd = '-i ${FfmpegRunner.quotePath(inputPath)} -f null -';
  final session = await FFmpegKit.execute(cmd);
  final out = await session.getOutput() ?? '';
  // small delay to let native release
  await Future.delayed(const Duration(milliseconds: 30));
  return out;
}
