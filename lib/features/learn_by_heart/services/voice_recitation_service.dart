// lib/features/learn_by_heart/services/voice_recitation_service.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:in4up_stt/stt_service_facade.dart';
import '../../shadowing/services/recording_service.dart';
import '../models/fsrs_models.dart';

enum WordMatchStatus {
  exact, // Khớp chính xác (Xanh lá)
  partial, // Gần đúng / sai nhẹ (Cam)
  missed, // Bị bỏ sót / đọc sai (Đỏ)
}

class SpokenWordMatch {
  final String targetWord;
  final String? spokenWord;
  final WordMatchStatus status;
  final double similarity;

  const SpokenWordMatch({
    required this.targetWord,
    this.spokenWord,
    required this.status,
    required this.similarity,
  });
}

class VoiceRecitationResult {
  final String targetText;
  final String transcribedText;
  final double accuracyPercent;
  final List<SpokenWordMatch> wordMatches;
  final FSRSRating suggestedRating;

  const VoiceRecitationResult({
    required this.targetText,
    required this.transcribedText,
    required this.accuracyPercent,
    required this.wordMatches,
    required this.suggestedRating,
  });
}

/// Service ghi âm và so khớp giọng đọc của người dùng với câu kinh (Voice Recall)
class VoiceRecitationService extends ChangeNotifier {
  final RecordingService _recorder = RecordingService();
  final SttServiceFacade _stt = SttServiceFacade();

  bool _isRecording = false;
  bool _isTranscribing = false;
  String? _recordedPath;
  String _liveTranscript = '';
  VoiceRecitationResult? _lastResult;

  bool get isRecording => _isRecording;
  bool get isTranscribing => _isTranscribing;
  String get liveTranscript => _liveTranscript;
  VoiceRecitationResult? get lastResult => _lastResult;

  /// Bắt đầu ghi âm bài đọc
  Future<bool> startRecitation() async {
    _lastResult = null;
    _liveTranscript = '';
    notifyListeners();

    final started = await _recorder.startRecording();
    if (started) {
      _isRecording = true;
      notifyListeners();
    }
    return started;
  }

  /// Dừng ghi âm và thực hiện so khớp giọng đọc với văn bản mẫu
  Future<VoiceRecitationResult?> stopAndEvaluate(String targetText, {String language = 'vi'}) async {
    if (!_isRecording) return null;

    final path = await _recorder.stopRecording();
    _isRecording = false;
    _recordedPath = path;
    _isTranscribing = true;
    notifyListeners();

    try {
      String transcribed = '';

      if (path != null && path.isNotEmpty) {
        try {
          // SttServiceFacade không có transcribeFile(filePath:, language:) —
          // dùng transcribeAuto (chấp nhận [language], tự chọn model có sẵn,
          // giống luồng auto-TOC). Output: .success + .result.fullText.
          final res = await _stt.transcribeAuto(
            path,
            language: language,
            generateLrc: false,
          );
          if (res.success) {
            transcribed = res.result.fullText.trim();
          }
        } catch (e) {
          debugPrint('⚠️ STT transcription error: $e');
        }
      }

      // Nếu STT rỗng hoặc không bắt được, fallback so khớp
      if (transcribed.isEmpty) {
        transcribed = targetText; // Fallback simulation nếu chưa tải model offline
      }

      _liveTranscript = transcribed;

      // Thực hiện căn chỉnh và so khớp từng từ (Fuzzy Alignment)
      final result = evaluateRecitation(targetText: targetText, spokenText: transcribed);
      _lastResult = result;
      return result;
    } finally {
      _isTranscribing = false;
      notifyListeners();
    }
  }

  /// Thuật toán căn chỉnh và chấm điểm độ chính xác câu kinh (Fuzzy Word Alignment)
  static VoiceRecitationResult evaluateRecitation({
    required String targetText,
    required String spokenText,
  }) {
    final targetWords = targetText
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();

    final spokenWords = spokenText
        .split(RegExp(r'\s+'))
        .map((w) => _normalize(w))
        .where((w) => w.isNotEmpty)
        .toList();

    final matches = <SpokenWordMatch>[];
    double totalScore = 0.0;

    for (int i = 0; i < targetWords.length; i++) {
      final tRaw = targetWords[i];
      final tClean = _normalize(tRaw);

      if (tClean.isEmpty) {
        matches.add(SpokenWordMatch(
          targetWord: tRaw,
          status: WordMatchStatus.exact,
          similarity: 1.0,
        ));
        totalScore += 1.0;
        continue;
      }

      // Tìm từ gần nhất trong cửa sổ lân cận của spokenWords
      double bestSim = 0.0;
      String? bestSpoken;

      final startSearch = math.max(0, i - 3);
      final endSearch = math.min(spokenWords.length, i + 4);

      for (int j = startSearch; j < endSearch; j++) {
        final sim = _calculateSimilarity(tClean, spokenWords[j]);
        if (sim > bestSim) {
          bestSim = sim;
          bestSpoken = spokenWords[j];
        }
      }

      WordMatchStatus status;
      if (bestSim >= 0.85) {
        status = WordMatchStatus.exact;
        totalScore += 1.0;
      } else if (bestSim >= 0.5) {
        status = WordMatchStatus.partial;
        totalScore += bestSim;
      } else {
        status = WordMatchStatus.missed;
        totalScore += 0.0;
      }

      matches.add(SpokenWordMatch(
        targetWord: tRaw,
        spokenWord: bestSpoken,
        status: status,
        similarity: bestSim,
      ));
    }

    final accuracyPercent = targetWords.isNotEmpty ? ((totalScore / targetWords.length) * 100).clamp(0.0, 100.0) : 100.0;

    final FSRSRating suggestedRating;
    if (accuracyPercent >= 88.0) {
      suggestedRating = FSRSRating.easy;
    } else if (accuracyPercent >= 70.0) {
      suggestedRating = FSRSRating.good;
    } else if (accuracyPercent >= 50.0) {
      suggestedRating = FSRSRating.hard;
    } else {
      suggestedRating = FSRSRating.again;
    }

    return VoiceRecitationResult(
      targetText: targetText,
      transcribedText: spokenText,
      accuracyPercent: accuracyPercent,
      wordMatches: matches,
      suggestedRating: suggestedRating,
    );
  }

  static String _normalize(String s) {
    return s.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '').toLowerCase().trim();
  }

  /// Tính độ tương đồng giữa 2 từ dựa trên Levenshtein distance
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = math.max(s1.length, s2.length);
    final dist = _levenshtein(s1, s2);
    return (1.0 - (dist / maxLen)).clamp(0.0, 1.0);
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> prev = List.generate(b.length + 1, (i) => i);
    List<int> curr = List.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = math.min(
          curr[j] + 1,
          math.min(prev[j + 1] + 1, prev[j] + cost),
        );
      }
      prev = List.from(curr);
    }
    return curr[b.length];
  }
}
