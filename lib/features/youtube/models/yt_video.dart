import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─── YtVideo ─────────────────────────────────────────────────

class YtVideo {
  final String id;
  final String title;
  final String channel;
  final String? thumb;

  const YtVideo({
    required this.id,
    required this.title,
    required this.channel,
    this.thumb,
  });

  String get shortTitle =>
      title.length > 55 ? '${title.substring(0, 53)}...' : title;

  String get embedUrl =>
      'https://www.youtube.com/embed/$id?autoplay=1&rel=0&modestbranding=1';

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'channel': channel, 'thumb': thumb};

  factory YtVideo.fromJson(Map<String, dynamic> j) => YtVideo(
        id: j['id'] ?? '',
        title: j['title'] ?? 'Unknown',
        channel: j['channel'] ?? '',
        thumb: j['thumb'],
      );

  /// Parse video ID từ URL hoặc trả về null
  static String? extractId(String input) {
    final p = RegExp(r'(?:v=|youtu\.be/|embed/|shorts/)([a-zA-Z0-9_-]{11})');
    final m = p.firstMatch(input.trim());
    if (m != null) return m.group(1);
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(input.trim()))
      return input.trim();
    return null;
  }
}

// ─── YtCaptionLine ────────────────────────────────────────────

class YtCaptionLine {
  final Duration start;
  final Duration end;
  final String text;
  final String? translation;

  const YtCaptionLine(this.start, this.end, this.text, {this.translation});

  String toLrc() {
    final mm = start.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = start.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs =
        (start.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    if (translation != null) {
      return '[$mm:$ss.$cs]$text | $translation';
    }
    return '[$mm:$ss.$cs]$text';
  }

  YtCaptionLine copyWith({String? translation}) {
    return YtCaptionLine(start, end, text,
        translation: translation ?? this.translation);
  }
}

// ─── YtHistory (Hive-backed) ──────────────────────────────────

class YtHistory {
  static const _boxName = 'yt_unified_history';

  static Future<void> ensureOpen() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
  }

  static List<YtVideo> load() {
    try {
      if (!Hive.isBoxOpen(_boxName)) return [];
      final raw = Hive.box<String>(_boxName).get('history');
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((e) => YtVideo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(YtVideo v) async {
    final list = load()..removeWhere((h) => h.id == v.id);
    list.insert(0, v);
    await _save(list.take(50).toList());
  }

  static Future<void> remove(String id) async {
    final list = load()..removeWhere((h) => h.id == id);
    await _save(list);
  }

  static Future<void> _save(List<YtVideo> list) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) return;
      await Hive.box<String>(_boxName)
          .put('history', jsonEncode(list.map((v) => v.toJson()).toList()));
    } catch (e) {
      debugPrint('YtHistory._save: $e');
    }
  }
}
