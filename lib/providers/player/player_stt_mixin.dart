// lib/providers/player/player_stt_mixin.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';
import 'package:in4up_stt/stt_service_facade.dart';

import '../../features/vad/pipeline/vad_pipeline_integration.dart';
import '../../features/vad/pipeline/vad_whisper_pipeline.dart';
import '../../screens/understand_mode/understand_mode.dart' hide LrcLine;
import '../../services/source_artifact_store.dart';

mixin PlayerSttMixin on ChangeNotifier {
  // Dependencies required from PlayerProvider
  String? get currentSongPath;
  UnderstandProvider? get understandProvider;
  Future<void> pause();
  Duration get playbackDuration;

  final SttServiceFacade _sttService = SttServiceFacade();
  SttServiceFacade get sttService => _sttService;

  SttTranscribeOutput? _lastTranscribeOutput;
  SttTranscribeOutput? get lastTranscribeOutput => _lastTranscribeOutput;

  bool _lrcJustGenerated = false;
  bool get lrcJustGenerated => _lrcJustGenerated;

  void consumeLrcJustGenerated() {
    if (_lrcJustGenerated) {
      _lrcJustGenerated = false;
    }
  }

  Future<void> initializeStt() async {
    try {
      await _sttService.initialize();
      debugPrint('✅ PlayerProvider: STT initialized');
    } catch (e) {
      debugPrint('⚠️ PlayerProvider: STT init failed (non-fatal): $e');
    }
  }

  Stream<SttProgress> get sttProgressStream => _sttService.progressStream;
  SttProgress get sttProgress => _sttService.currentProgress;

  Future<CachedLrcHit?> peekCachedLrc({String? path}) async {
    final audioPath = path ?? currentSongPath;
    if (audioPath == null || audioPath.isEmpty) return null;
    try {
      final hit = await SourceArtifactStore.instance.findLrc(
        audioPath,
        durationMs: playbackDuration.inMilliseconds,
      );
      if (hit != null) return hit;
      final outputFromStt = _lastSttOutput;
      if (outputFromStt?.lrcFilePath != null) {
        final lrcFile = File(outputFromStt!.lrcFilePath!);
        if (await lrcFile.exists()) {
          return CachedLrcHit(lrcPath: outputFromStt.lrcFilePath!);
        }
      }
    } catch (e) {
      debugPrint('⚠️ peekCachedLrc error: $e');
    }
    return null;
  }

  Future<String?> findCachedLrcPath(String normalizedPath) async {
    final hit = await peekCachedLrc(path: normalizedPath);
    return hit?.lrcPath;
  }

  String _replaceExtension(String path, String newExt) {
    final lastDot = path.lastIndexOf('.');
    final lastSlash = path.lastIndexOf('/');
    if (lastDot > lastSlash && lastDot >= 0) {
      return '${path.substring(0, lastDot)}$newExt';
    }
    return '$path$newExt';
  }

  Future<List<LrcLine>> parseLrcFile(String lrcPath) async {
    try {
      final file = File(lrcPath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      // Dùng SttLrcConverter để tách đúng: bỏ inline `<mm:ss.cs>` khỏi text
      // hiển thị và lưu vào words cho karaoke (tránh lộ timestamps ra chữ).
      final lines = await SttLrcConverter().parseLrcContent(content);
      debugPrint('📄 Parsed ${lines.length} LRC lines from $lrcPath');
      return lines;
    } catch (e) {
      debugPrint('⚠️ _parseLrcFile error: $e');
      return [];
    }
  }

  // Handover SECTION 2 — VAD Pipeline integration
  // File 1h từ 20p -> 8-10p nhờ loại bỏ silence + chunk tối ưu
  final VadPipelineIntegration _vadIntegration = VadPipelineIntegration();

  /// Tạo LRC dùng VAD pipeline tối ưu (khuyên dùng cho file dài >60s)
  /// Pipeline: File Audio -> VAD -> Chunk Extractor -> Whisper Isolate -> Offset Corrector -> UI Stream
  Future<SttTranscribeOutput?> generateLrcWithVadPipeline({
    WhisperModelLevel? level,
    String language = 'vi',
    SttSegmentGrouping grouping = SttSegmentGrouping.sentence,
    bool skipSilence = true,
  }) async {
    final path = currentSongPath;
    if (path == null) {
      _lastSttError = 'Chưa có file audio đang phát';
      notifyListeners();
      return null;
    }

    _isGeneratingLrc = true;
    _lastSttError = null;

    try {
      await pause();
      debugPrint('[VAD Pipeline] Paused player, delay 1s for BufferPool release');
      await Future.delayed(const Duration(milliseconds: 1000));
    } catch (_) {}

    understandProvider?.clear();
    notifyListeners();

    try {
      final modelLevel = level ?? WhisperModelLevel.tiny;

      final output = await _vadIntegration.transcribeWithVad(
        audioPath: path,
        modelLevel: modelLevel,
        language: language,
        skipSilence: skipSilence,
        onProgress: (prog) {
          debugPrint(
            '[VAD Pipeline] ${prog.status.name} ${prog.progress.toStringAsFixed(2)} '
            '${prog.message} chunk ${prog.currentChunkIndex}/${prog.totalChunks}',
          );
          // Có thể emit progress ra UI qua _sttService hoặc notifyListeners
        },
        onPartialResult: (partial) async {
          if (partial.segments.isEmpty || understandProvider == null) return;
          final lrcLines = partial.segments
              .map((s) => LrcLine(
                    timestamp: Duration(milliseconds: s.startMs),
                    text: s.text,
                  ))
              .where((l) => l.text.trim().isNotEmpty)
              .toList();
          if (lrcLines.isNotEmpty) {
            understandProvider!.loadLrcLines(lrcLines);
          }
        },
      );

      _lastSttOutput = output;
      _lastSttError = output.success ? null : output.errorMessage;

      if (output.success && understandProvider != null) {
        final lrcLines = output.result.segments
            .map((s) => LrcLine(
                  timestamp: Duration(milliseconds: s.startMs),
                  text: s.text,
                ))
            .where((l) => l.text.trim().isNotEmpty)
            .toList();
        if (lrcLines.isNotEmpty) {
          understandProvider!.loadLrcLines(lrcLines);
          debugPrint('✅ VAD Pipeline loaded ${lrcLines.length} LRC lines');
        }
        _lrcJustGenerated = true;
        await _rememberGeneratedLrc(path, output.lrcFilePath);
      }

      return output;
    } catch (e) {
      _lastSttError = e.toString();
      debugPrint('❌ VAD Pipeline error: $e');
      return null;
    } finally {
      _isGeneratingLrc = false;
      notifyListeners();
    }
  }

  Future<SttTranscribeOutput?> generateLrcForCurrentAudio({
    WhisperModelLevel? level,
    SttSegmentGrouping grouping = SttSegmentGrouping.sentence,
  }) async {
    final path = currentSongPath;
    if (path == null) {
      _lastSttError = 'Chưa có file audio đang phát';
      notifyListeners();
      return null;
    }

    // Handover tối ưu: file dài >60s dùng VAD pipeline để giảm 20p -> 8-10p
    try {
      final file = File(path);
      if (await file.exists()) {
        // Nếu file >60s, tự động dùng VAD pipeline tối ưu
        // Probe duration đơn giản qua file size hoặc dùng AudioConverter
        // Ở đây dùng ngưỡng 5MB ~ >60s ở 128kbps
        final size = await file.length();
        if (size > 5 * 1024 * 1024) {
          debugPrint('[SttMixin] File lớn (${size}bytes) >5MB, chuyển sang VAD pipeline tối ưu');
          return await generateLrcWithVadPipeline(
            level: level,
            language: 'en',
            grouping: grouping,
            skipSilence: true,
          );
        }
      }
    } catch (_) {}

    _isGeneratingLrc = true;
    _lastSttError = null;

    // FIX OOM v3: dung player truoc khi transcribe de giai phong ExoPlayer (BufferPoolAccessor) + FFmpeg native RAM
    // v7: them delay 1s sau pause de ExoPlayer giai phong buffer pool truoc khi Whisper chiem RAM
    try {
      await pause();
      debugPrint('[SttMixin] Paused player before transcription to free RAM, delay 1s for BufferPool release');
      await Future.delayed(const Duration(milliseconds: 1000));
    } catch (_) {}

    // ★ Xoá lời thoại bài cũ khi bắt đầu tạo cho audio mới — tránh giữ
    //   chữ bài cũ chạy lệch với âm thanh mới ("râu ông nọ cắm cằm bà kia").
    understandProvider?.clear();
    notifyListeners();

    try {
      final stt = SttServiceFacade();

      // ★ Stream kết quả từng phần: hiện dần lyrics mỗi khi xong 1 chunk,
      //   thay vì đợi hết cả file mới hiện.
      final partialSub = stt.partialResultStream.listen((partial) {
        if (partial.segments.isEmpty || understandProvider == null) return;
        // Chuyển partial → LrcLine để UnderstandProvider hiện dần
        final lrcLines = partial.segments
            .map((s) => LrcLine(
                  timestamp: Duration(milliseconds: s.startMs),
                  text: s.text,
                ))
            .where((l) => l.text.trim().isNotEmpty)
            .toList();
        if (lrcLines.isNotEmpty) {
          understandProvider!.loadLrcLines(lrcLines);
        }
      });

      try {
        final SttTranscribeOutput output;
        if (level == null) {
          output = await stt.transcribeAuto(
            path,
            language: 'en',
            generateLrc: true,
            grouping: grouping,
          );
        } else {
          output = await stt.transcribeFile(
            path,
            config: SttConfig.deepLearning.copyWith(
              preferredEngine: SttEngineType.whisper,
              whisperModel: level,
              language: 'en',
              generateLrc: true,
              grouping: grouping,
            ),
            generateLrc: true,
          );
        }

        _lastSttOutput = output;
        _lastSttError = output.success ? null : output.errorMessage;

        if (output.lrcFilePath != null) {
          _lastGeneratedLrcPath = output.lrcFilePath;
        }

        if (output.success &&
            output.lrcFilePath != null &&
            understandProvider != null) {
          final lrcLines = await parseLrcFile(output.lrcFilePath!);
          if (lrcLines.isNotEmpty) {
            understandProvider!.loadLrcLines(lrcLines);
            debugPrint(
              '✅ Auto-loaded ${lrcLines.length} LRC lines after generate',
            );
          }
          _lrcJustGenerated = true;
          await _rememberGeneratedLrc(path, output.lrcFilePath);
        }

        return output;
      } finally {
        partialSub.cancel();
      }
    } catch (e) {
      _lastSttError = e.toString();
      return null;
    } finally {
      _isGeneratingLrc = false;
      notifyListeners();
    }
  }

  /// Dừng tạo LRC đang chạy (chunk transcribe). Đặt lại trạng thái để
  /// người dùng không bị "kẹt" ở màn hình đang xử lý.
  Future<void> cancelLrcGeneration() async {
    debugPrint('⏹️ cancelLrcGeneration() — hủy transcribe');
    try {
      _sttService.cancelTranscription();
    } catch (e) {
      debugPrint('⚠️ cancelLrcGeneration error: $e');
    }
    // Reset trạng thái đang xử lý — để nút khả dụng lại ngay.
    _isGeneratingLrc = false;
    notifyListeners();
  }

  Future<String> transcribeForShadowing(String audioPath) async {
    try {
      final output = await _sttService.transcribeQuick(audioPath);
      return output.success ? output.result.fullText : '';
    } catch (_) {
      return '';
    }
  }

  SttModelInfo getSttModelInfo(WhisperModelLevel level) =>
      _sttService.getModelInfo(level);

  Future<void> autoLoadCachedLrc(String normalizedPath) async {
    try {
      final cachedLrcPath = await findCachedLrcPath(normalizedPath);

      if (cachedLrcPath != null) {
        final lrcLines = await parseLrcFile(cachedLrcPath);
        if (lrcLines.isNotEmpty && understandProvider != null) {
          understandProvider!.loadLrcLines(lrcLines);
          _lastGeneratedLrcPath = cachedLrcPath;
          debugPrint(
            '✅ Auto-loaded cached LRC (${lrcLines.length} lines): $cachedLrcPath',
          );
          notifyListeners();
        }
      } else {
        _shouldOpenAiPanel = true;
        notifyListeners();
        debugPrint(
          'ℹ️ No cached LRC found for: $normalizedPath → open AI panel',
        );
      }
    } catch (e) {
      debugPrint('⚠️ _autoLoadCachedLrc error: $e');
    }
  }

  bool _shouldOpenAiPanel = false;
  bool get shouldOpenAiPanel => _shouldOpenAiPanel;

  void consumeShouldOpenAiPanel() {
    if (_shouldOpenAiPanel) {
      _shouldOpenAiPanel = false;
    }
  }

  void disposeStt() {
    _sttService.dispose();
  }

  SttTranscribeOutput? _lastSttOutput;
  SttTranscribeOutput? get lastSttOutput => _lastSttOutput;
  set lastSttOutput(SttTranscribeOutput? value) => _lastSttOutput = value;

  String? _lastSttError;
  String? get lastSttError => _lastSttError;

  bool _isGeneratingLrc = false;
  bool get isGeneratingLrc => _isGeneratingLrc;

  String get lastTranscriptText => _lastSttOutput?.result.fullText ?? '';

  String? _lastGeneratedLrcPath;
  String? get lastGeneratedLrcPath => _lastGeneratedLrcPath;

  void clearSttError() {
    if (_lastSttError != null) {
      _lastSttError = null;
      notifyListeners();
    }
  }
}
