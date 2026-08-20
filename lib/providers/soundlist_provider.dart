// lib/providers/soundlist_provider.dart
// Soundlist – "Âm mục": bộ máy trung tâm quản lý
//   • Điểm   (SoundMark)   – mốc thời gian + nhãn + ghi chú + tag + loại
//   • Chương (SoundChapter)– cây mục lục linh hoạt theo file audio
//   • Đoạn   (Segment)     – tái sử dụng Segment có sẵn (A–B loop) của app
//
// Dữ liệu được lưu vào Hive qua StorageService (offline-first, đồng bộ như
// các tính năng khác của app).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in4up_stt/in4up_stt.dart';

import '../models/segment.dart';
import '../models/sound_chapter.dart';
import '../models/sound_loop_stat.dart';
import '../models/sound_mark.dart';
import '../models/sound_transcript.dart';
import '../models/vad_settings.dart';
import '../services/sound_auto_toc_service.dart';
import '../services/storage_service.dart';
import 'player_provider.dart';

class SoundlistProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<SoundMark> _marks = [];
  List<SoundChapter> _chapters = [];
  Map<String, SoundTranscript> _transcripts = {};
  List<SoundLoopStat> _loopStats = [];
  VadSettings _vadSettings = const VadSettings();
  bool _loaded = false;

  PlayerProvider? _player;
  String? _lastLoopKey;
  int _lastLoopCount = 0;

  List<SoundMark> get marks => List.unmodifiable(_marks);
  List<SoundChapter> get chapters => List.unmodifiable(_chapters);
  VadSettings get vadSettings => _vadSettings;
  bool get isLoaded => _loaded;

  /// Nạp toàn bộ dữ liệu từ Hive (gọi 1 lần khi app khởi động).
  Future<void> load() async {
    _marks = _storage.getAllSoundMarks();
    _chapters = _storage.getAllSoundChapters();
    _transcripts = _storage.getAllSoundTranscripts();
    _loopStats = _storage.getAllSoundLoopStats();
    _vadSettings = _storage.getVadSettings();
    _loaded = true;
    notifyListeners();
  }

  /// Đọc lại từ Hive — dùng khi mở panel để chắc chắn thấy dữ liệu mới nhất.
  Future<void> reload() async {
    _marks = _storage.getAllSoundMarks();
    _chapters = _storage.getAllSoundChapters();
    _transcripts = _storage.getAllSoundTranscripts();
    _loopStats = _storage.getAllSoundLoopStats();
    notifyListeners();
  }

  // ─────────────────── THEO DÕI THÓI QUEN LẶP A–B ───────────────────

  /// Gắn PlayerProvider để lắng nghe các vòng lặp A–B (gọi từ main.dart).
  void attachPlayer(PlayerProvider player) {
    _player?.removeListener(_onPlayerChanged);
    _player = player;
    _player!.addListener(_onPlayerChanged);
  }

  void _onPlayerChanged() {
    final p = _player;
    if (p == null) return;
    final path = p.currentSongPath;
    final start = p.loopStart;
    final end = p.loopEnd;
    final count = p.loopCount;

    if (path == null || start == null || end == null) {
      _lastLoopKey = null;
      _lastLoopCount = 0;
      return;
    }
    final key = '$path|${start.inMilliseconds}|${end.inMilliseconds}';
    if (_lastLoopKey != key) {
      _lastLoopKey = key;
      _lastLoopCount = count;
      return;
    }
    if (count > _lastLoopCount) {
      unawaited(_recordLoopIncrement(path, start, end, count - _lastLoopCount));
      _lastLoopCount = count;
    }
  }

  Future<void> _recordLoopIncrement(
    String audioPath,
    Duration start,
    Duration end,
    int delta,
  ) async {
    final id = '$audioPath|${start.inMilliseconds}|${end.inMilliseconds}';
    final existing = _loopStats.where((s) => s.id == id).firstOrNull;
    if (existing != null) {
      existing.count += delta;
      existing.lastUsed = DateTime.now();
      _loopStats = [..._loopStats];
      await _storage.saveSoundLoopStat(existing);
    } else {
      final stat = SoundLoopStat(
        id: id,
        audioPath: audioPath,
        start: start,
        end: end,
        count: delta,
        lastUsed: DateTime.now(),
      );
      _loopStats.add(stat);
      await _storage.saveSoundLoopStat(stat);
    }
    notifyListeners();
  }

  /// Danh sách gợi ý "đoạn khó" cho file: lặp ≥ [minCount] lần, gần đây,
  /// chưa bị bỏ qua, chưa có điểm "Khó" sát đầu đoạn.
  List<SoundLoopStat> suggestionsForSong(
    String audioPath, {
    int minCount = 3,
  }) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final stats = _loopStats
        .where((s) =>
            s.audioPath == audioPath &&
            !s.dismissed &&
            s.count >= minCount &&
            s.lastUsed.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return stats
        .where((s) {
          final hasHardNearStart = _marks.any((m) =>
              m.audioPath == audioPath &&
              m.kind == SoundMarkKind.hard &&
              (m.position.inMilliseconds - s.start.inMilliseconds).abs() <
                  1500);
          return !hasHardNearStart;
        })
        .take(3)
        .toList();
  }

  Future<void> dismissSuggestion(String id) async {
    final idx = _loopStats.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    _loopStats[idx].dismissed = true;
    await _storage.saveSoundLoopStat(_loopStats[idx]);
    notifyListeners();
  }

  // ─────────────────────────── CÀI ĐẶT VAD ───────────────────────────

  Future<void> setVadSettings(VadSettings settings) async {
    _vadSettings = settings;
    await _storage.saveVadSettings(settings);
    notifyListeners();
  }

  // ─────────────────────────── TRANSCRIPT ───────────────────────────

  SoundTranscript? transcriptFor(String audioPath) => _transcripts[audioPath];

  Future<void> saveTranscript(SoundTranscript transcript) async {
    _transcripts[transcript.audioPath] = transcript;
    await _storage.saveSoundTranscript(transcript);
    notifyListeners();
  }

  /// Dựng transcript từ các dòng LRC có sẵn (Understand/LRC đã sinh trước đó).
  SoundTranscript? transcriptFromLrcLines(
    String audioPath,
    List<LrcLine> lines,
  ) {
    if (lines.isEmpty) return null;
    final tLines = <TranscriptLine>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.text.trim().isEmpty) continue;
      // end = timestamp dòng KẾ TIẾP CÓ NỘI DUNG; nếu không còn dòng nào
      // (hoặc chỉ còn dòng rỗng) → fallback +3s. (Fix: trước đây lấy thẳng
      // lines[i+1] kể cả khi dòng đó rỗng → dòng cuối có nội dung bị end
      // sai bằng timestamp dòng rỗng.)
      Duration end;
      var next = i + 1;
      while (next < lines.length && lines[next].text.trim().isEmpty) {
        next++;
      }
      end = next < lines.length
          ? lines[next].timestamp
          : line.timestamp + const Duration(seconds: 3);
      tLines.add(TranscriptLine(
        start: line.timestamp,
        end: end,
        text: line.text.trim(),
      ));
    }
    if (tLines.isEmpty) return null;
    return SoundTranscript(
      audioPath: audioPath,
      lines: tLines,
      updatedAt: DateTime.now(),
    );
  }

  // ─────────────────────────── TRUY VẤN ───────────────────────────

  List<SoundMark> marksForSong(String audioPath) {
    final list = _marks.where((m) => m.audioPath == audioPath).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return list;
  }

  /// Tất cả chương/mục của một file, sắp theo cây (cha trước, con sau).
  List<SoundChapter> chaptersForSong(String audioPath) {
    final list = _chapters.where((c) => c.audioPath == audioPath).toList();
    final roots = list.where((c) => c.isRoot).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final ordered = <SoundChapter>[];
    for (final root in roots) {
      ordered.add(root);
      ordered.addAll(_childrenInOrder(root, list));
    }
    return ordered;
  }

  List<SoundChapter> _childrenInOrder(
    SoundChapter parent,
    List<SoundChapter> all,
  ) {
    final children = all.where((c) => c.parentId == parent.id).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final result = <SoundChapter>[];
    for (final child in children) {
      result.add(child);
      result.addAll(_childrenInOrder(child, all));
    }
    return result;
  }

  List<SoundChapter> childChaptersOf(SoundChapter parent) {
    final list = _chapters.where((c) => c.parentId == parent.id).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Tổng số chương con trực tiếp của một chương.
  int childCountOf(String chapterId) =>
      _chapters.where((c) => c.parentId == chapterId).length;

  // ─────────────────────────── ĐIỂM (MARK) ───────────────────────────

  Future<SoundMark> addMark({
    required String audioPath,
    required Duration position,
    SoundMarkKind kind = SoundMarkKind.other,
    String? label,
    String? note,
    List<String> tags = const [],
  }) async {
    final mark = SoundMark(
      id: 'mark_${DateTime.now().microsecondsSinceEpoch}',
      audioPath: audioPath,
      position: position,
      label: (label?.trim().isNotEmpty ?? false)
          ? label!.trim()
          : SoundMark.defaultLabel(position),
      kind: kind,
      note: (note?.trim().isNotEmpty ?? false) ? note!.trim() : null,
      tags: tags,
      createdAt: DateTime.now(),
    );
    _marks.add(mark);
    await _storage.saveSoundMark(mark);
    notifyListeners();
    return mark;
  }

  Future<void> updateMark(SoundMark mark) async {
    final idx = _marks.indexWhere((m) => m.id == mark.id);
    if (idx >= 0) {
      _marks[idx] = mark;
    } else {
      _marks.add(mark);
    }
    await _storage.saveSoundMark(mark);
    notifyListeners();
  }

  Future<void> deleteMark(String id) async {
    _marks.removeWhere((m) => m.id == id);
    await _storage.deleteSoundMark(id);
    notifyListeners();
  }

  // ─────────────────────────── CHƯƠNG / MỤC ───────────────────────────

  /// ⚡ TỰ TẠO MỤC LỤC: VAD (tách đoạn theo khoảng lặng) + Whisper (tự đặt tên).
  ///
  /// [useWhisper] = true  → VAD + Whisper: chương có tiêu đề = câu mở đầu.
  /// [useWhisper] = false → Chỉ VAD: chương "Đoạn N · mm:ss" (không cần model).
  /// [language]   = 'vi' | 'en' | 'auto' — ngôn ngữ nhận diện (D16).
  ///
  /// Thay thế toàn bộ chương/mục hiện có của file (UI xác nhận trước khi gọi).
  /// [onStatus] callback cho UI hiển thị tiến trình ("Đang phân tích…").
  Future<SoundAutoTocResult> autoGenerateToc({
    required String audioPath,
    Duration? totalDuration,
    bool useWhisper = true,
    WhisperModelLevel? whisperLevel,
    String language = 'auto',
    ValueChanged<String>? onStatus,
  }) async {
    onStatus?.call('Phân tích khoảng lặng (VAD)…');

    final slices = await SoundAutoTocService.vadSplit(
      audioPath,
      totalDuration: totalDuration,
      minSilenceSec: _vadSettings.minSilenceSec,
      minSegmentSec: _vadSettings.minSegmentSec,
      thresholdFactor: _vadSettings.thresholdFactor,
    );

    SttResult? stt;
    if (useWhisper) {
      onStatus?.call('Đang nhận diện giọng nói (Whisper)…\n'
          'File dài có thể mất vài phút.');
      stt = await SoundAutoTocService.transcribe(
        audioPath,
        language: language,
      );
    }

    final chapters = SoundAutoTocService.buildChapters(
      audioPath: audioPath,
      slices: slices,
      sttSegments: stt?.segments,
      useWhisper: useWhisper,
    );

    if (chapters.isNotEmpty) {
      await _replaceChaptersForFile(audioPath, chapters);
    }

    // Lưu transcript (nếu Whisper chạy thành công) để dùng cho "Tìm trong audio".
    if (stt != null && stt.segments.isNotEmpty) {
      final tLines = <TranscriptLine>[];
      for (int i = 0; i < stt.segments.length; i++) {
        final s = stt.segments[i];
        if (s.text.trim().isEmpty) continue;
        final end = i + 1 < stt.segments.length
            ? stt.segments[i + 1].startDuration
            : s.endDuration;
        tLines.add(TranscriptLine(
          start: s.startDuration,
          end: end,
          text: s.text.trim(),
        ));
      }
      if (tLines.isNotEmpty) {
        await saveTranscript(SoundTranscript(
          audioPath: audioPath,
          lines: tLines,
          updatedAt: DateTime.now(),
        ));
      }
    }

    return SoundAutoTocResult(
      chapters: chapters,
      sliceCount: slices.length,
      usedWhisper: useWhisper && stt != null,
      transcriptText: stt?.fullText,
    );
  }

  /// Thay toàn bộ chương/mục của một file bằng danh sách mới.
  Future<void> _replaceChaptersForFile(
    String audioPath,
    List<SoundChapter> chapters,
  ) async {
    final old = _chapters
        .where((c) => c.audioPath == audioPath)
        .map((c) => c.id)
        .toList();
    for (final id in old) {
      await _storage.deleteSoundChapter(id);
    }
    _chapters.removeWhere((c) => c.audioPath == audioPath);
    for (final chapter in chapters) {
      _chapters.add(chapter);
      await _storage.saveSoundChapter(chapter);
    }
    notifyListeners();
  }

  Future<SoundChapter> addChapter({
    required String audioPath,
    required String title,
    String? note,
    Duration? position,
    String? parentId,
  }) async {
    // Thứ tự: xếp cuối danh sách anh em cùng cha.
    final siblings = _chapters
        .where((c) => c.audioPath == audioPath && c.parentId == parentId)
        .length;
    final chapter = SoundChapter(
      id: 'chapter_${DateTime.now().microsecondsSinceEpoch}',
      audioPath: audioPath,
      title: title.trim().isEmpty ? 'Chương mới' : title.trim(),
      note: (note?.trim().isNotEmpty ?? false) ? note!.trim() : null,
      position: position,
      parentId: parentId,
      order: siblings,
      createdAt: DateTime.now(),
    );
    _chapters.add(chapter);
    await _storage.saveSoundChapter(chapter);
    notifyListeners();
    return chapter;
  }

  Future<void> renameChapter(String id, String title) async {
    final idx = _chapters.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final updated = _chapters[idx];
    _chapters[idx] = SoundChapter(
      id: updated.id,
      audioPath: updated.audioPath,
      title: title.trim().isEmpty ? updated.title : title.trim(),
      note: updated.note,
      position: updated.position,
      parentId: updated.parentId,
      order: updated.order,
      createdAt: updated.createdAt,
    );
    await _storage.saveSoundChapter(_chapters[idx]);
    notifyListeners();
  }

  Future<void> setChapterNote(String id, String? note) async {
    final idx = _chapters.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    final updated = _chapters[idx];
    _chapters[idx] = SoundChapter(
      id: updated.id,
      audioPath: updated.audioPath,
      title: updated.title,
      note: (note?.trim().isNotEmpty ?? false) ? note!.trim() : null,
      position: updated.position,
      parentId: updated.parentId,
      order: updated.order,
      createdAt: updated.createdAt,
    );
    await _storage.saveSoundChapter(_chapters[idx]);
    notifyListeners();
  }

  /// Di chuyển chương sang cha khác (null = lên mục gốc).
  Future<void> moveChapter(String id, {String? parentId}) async {
    final idx = _chapters.indexWhere((c) => c.id == id);
    if (idx < 0 || _chapters[idx].parentId == parentId) return;
    final updated = _chapters[idx];
    final siblings = _chapters
        .where((c) => c.audioPath == updated.audioPath && c.parentId == parentId)
        .length;
    _chapters[idx] = SoundChapter(
      id: updated.id,
      audioPath: updated.audioPath,
      title: updated.title,
      note: updated.note,
      position: updated.position,
      parentId: parentId,
      order: siblings,
      createdAt: updated.createdAt,
    );
    await _storage.saveSoundChapter(_chapters[idx]);
    notifyListeners();
  }

  /// Xóa chương — xóa luôn toàn bộ mục con (cascade).
  Future<void> deleteChapter(String id) async {
    final children = _chapters.where((c) => c.parentId == id).toList();
    for (final child in children) {
      await deleteChapter(child.id);
    }
    _chapters.removeWhere((c) => c.id == id);
    await _storage.deleteSoundChapter(id);
    notifyListeners();
  }

  // ─────────────────────────── ĐOẠN (SEGMENT) ───────────────────────────

  /// Đọc toàn bộ đoạn từ Hive (nguồn chân lý — PlayerProvider cũng ghi vào đây).
  List<Segment> getAllSegments() => _storage.getAllAudioSegments();

  List<Segment> segmentsForSong(String audioPath) {
    final list = _storage
        .getAllAudioSegments()
        .where((s) => s.audioPath == audioPath)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  // ─────────────────────────── THƯ VIỆN TỔNG HỢP ───────────────────────────

  /// Xây chỉ mục tổng hợp theo từng file audio (cho màn hình Âm mục chính).
  List<SoundFileIndex> buildFileIndex() {
    final segments = _storage.getAllAudioSegments();
    final files = <String, SoundFileIndex>{};

    for (final mark in _marks) {
      files
          .putIfAbsent(mark.audioPath, () => SoundFileIndex(mark.audioPath))
          .marks
          .add(mark);
    }
    for (final chapter in _chapters) {
      files
          .putIfAbsent(chapter.audioPath, () => SoundFileIndex(chapter.audioPath))
          .chapters
          .add(chapter);
    }
    for (final segment in segments) {
      files
          .putIfAbsent(segment.audioPath, () => SoundFileIndex(segment.audioPath))
          .segments
          .add(segment);
    }
    for (final transcript in _transcripts.values) {
      final file = files.putIfAbsent(
        transcript.audioPath,
        () => SoundFileIndex(transcript.audioPath),
      );
      file.transcriptText = transcript.fullText;
      file.transcriptLines = transcript.lines;
    }

    // Gắn các vùng "lặp nhiều" (cho gợi ý thông minh).
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    for (final stat in _loopStats) {
      if (stat.dismissed || stat.count < 3 || !stat.lastUsed.isAfter(cutoff)) {
        continue;
      }
      files
          .putIfAbsent(stat.audioPath, () => SoundFileIndex(stat.audioPath))
          .hotRanges
          .add(stat);
    }

    final list = files.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    for (final file in list) {
      file.marks.sort((a, b) => a.position.compareTo(b.position));
      file.segments.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return list;
  }
}

/// Chỉ mục tổng hợp của một file audio trong thư viện Âm mục.
class SoundFileIndex {
  final String path;
  final String title;
  final List<SoundMark> marks;
  final List<SoundChapter> chapters;
  final List<Segment> segments;

  /// Toàn bộ nội dung transcript (nếu có) — phục vụ tìm kiếm toàn file.
  String? transcriptText;

  /// Các dòng transcript (có timestamp) — hiển thị trước trong thư viện.
  List<TranscriptLine> transcriptLines = [];

  /// Các vùng bị lặp nhiều lần gần đây (cho gợi ý thông minh).
  final List<SoundLoopStat> hotRanges;

  SoundFileIndex(this.path)
      : title = _basename(path),
        marks = [],
        chapters = [],
        segments = [],
        hotRanges = [];

  static String _basename(String p) {
    final normalized = p.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isNotEmpty ? parts.last : normalized;
  }

  int get markCount => marks.length;
  int get chapterCount => chapters.length;
  int get segmentCount => segments.length;
  int get hotRangeCount => hotRanges.length;
  bool get isEmpty =>
      marks.isEmpty &&
      chapters.isEmpty &&
      segments.isEmpty &&
      (transcriptText == null || transcriptText!.isEmpty) &&
      hotRanges.isEmpty;

  /// Nhãn loại nội dung dựa trên đoạn (dharma / english / audiobook / khác).
  String get contentKindLabel {
    if (segments.any((s) => s.type == SegmentType.dharma)) return 'Pháp thoại';
    if (segments.any((s) => s.type == SegmentType.english)) return 'Tiếng Anh';
    if (segments.any((s) => s.type == SegmentType.practice)) return 'Luyện tập';
    if (marks.any((m) => m.kind == SoundMarkKind.quote)) return 'Câu hay';
    return 'Âm thanh';
  }
}
