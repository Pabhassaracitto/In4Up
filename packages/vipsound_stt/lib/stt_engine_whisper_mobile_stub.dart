import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/stt_model_info.dart';
import 'models/stt_result.dart';
import 'stt_model_manager.dart';

// This is a stub implementation for platforms where the full mobile
// implementation (using ffmpeg_kit_flutter_new and whisper_flutter_new)
// is not available or not desired (e.g., Windows).
Future<SttResult> transcribeMobileImpl({
  required String audioPath,
  required WhisperModelLevel level,
  String? language,
  bool translateToEnglish = false,
  bool wordTimestamps = true,
  required SttModelManager modelManager,
  required StreamController<double> progressController,
  required Stopwatch stopwatch,
}) async {
  debugPrint(
      '⚠️ transcribeMobileImpl (stub) called. This should not happen on Windows.');
  return SttResult.empty(SttEngineType.whisper,
      errorMessage: 'Mobile STT not supported on this platform.');
}
