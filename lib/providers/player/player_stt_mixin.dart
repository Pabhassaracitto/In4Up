// lib/providers/player/player_stt_mixin.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in2up_stt/in2up_stt.dart';
import 'package:in2up_stt/stt_service_facade.dart';

import '../../screens/understand_mode/understand_mode.dart' hide LrcLine;

mixin PlayerSttMixin on ChangeNotifier {
  // Dependencies required from PlayerProvider
  String? get currentSongPath;
  UnderstandProvider? get understandProvider;

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

  String _computeFileHash(String normalizedPath) {
    return normalizedPath.hashCode.toRadixString(16);
  }

  Future<String?> findCachedLrcPath(String normalizedPath) async {
    try {
      final hash = _computeFileHash(normalizedPath);

      final candidates = <String>[
        '${normalizedPath.substring(0, normalizedPath.lastIndexOf('/'))}'
            '/${hash}.lrc',
        '/data/user/0/com.in2up.app/cache/lrc/$hash.lrc',
        _replaceExtension(normalizedPath, '.lrc'),
      ];

      for (final candidate in candidates) {
        final file = File(candidate);
        if (await file.exists()) {
          debugPrint('✅ Found cached LRC: $candidate');
          return candidate;
        }
      }

      final outputFromStt = _lastSttOutput;
      if (outputFromStt?.lrcFilePath != null) {
        final lrcFile = File(outputFromStt!.lrcFilePath!);
        if (await lrcFile.exists()) {
          return outputFromStt.lrcFilePath;
        }
      }

      return null;
    } catch (e) {
      debugPrint('⚠️ _findCachedLrcPath error: $e');
      return null;
    }
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
      final lines = <LrcLine>[];

      for (final rawLine in content.split('\n')) {
        final trimmed = rawLine.trim();
        if (trimmed.isEmpty) continue;

        final match = RegExp(
          r'^\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)$',
        ).firstMatch(trimmed);

        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final centisStr = match.group(3)!;
          final millis = centisStr.length == 2
              ? int.parse(centisStr) * 10
              : int.parse(centisStr);

          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          );
          final text = match.group(4)?.trim() ?? '';

          if (text.isNotEmpty) {
            lines.add(
              LrcLine(timestamp: timestamp, text: text),
            );
          }
        }
      }

      debugPrint('📄 Parsed ${lines.length} LRC lines from $lrcPath');
      return lines;
    } catch (e) {
      debugPrint('⚠️ _parseLrcFile error: $e');
      return [];
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

    _isGeneratingLrc = true;
    _lastSttError = null;

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
}
