import 'package:record/record.dart';

/// Cabin uses the microphone and its own TTS player concurrently. On Android,
/// record 6.x defaults to pause-on-focus-loss with *manual* resume. The
/// just_audio player requests focus for Piper, so that default pauses the PCM
/// stream at the first spoken translation and never resumes it. Do not claim
/// recording focus for Cabin on Android; this does not change other recorders.
/// The system can still restrict/silence microphone capture during calls or
/// another application's recording, as dictated by Android.
RecordConfig cabinRecordConfig({required bool isAndroid}) => RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      audioInterruption:
          isAndroid ? AudioInterruptionMode.none : AudioInterruptionMode.pause,
    );
