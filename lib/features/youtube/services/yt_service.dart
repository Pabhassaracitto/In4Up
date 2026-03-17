//
// Fetch metadata (oEmbed) + captions (timedtext API)
// Không cần API key

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

import '../models/yt_video.dart';

class YtService {
  YtService._();
  static final YtService instance = YtService._();

  // ─── Fetch video info (oEmbed) ────────────────────────────

  Future<YtVideo?> fetchInfo(String videoId) async {
    try {
      final url =
          'https://www.youtube.com/oembed?format=json&url='
          '${Uri.encodeComponent('https://www.youtube.com/watch?v=$videoId')}';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return YtVideo(
        id: videoId,
        title: data['title'] ?? 'Unknown',
        channel: data['author_name'] ?? '',
        thumb: data['thumbnail_url'],
      );
    } catch (e) {
      debugPrint('YtService.fetchInfo: $e');
      return null;
    }
  }

  // ─── Fetch captions ───────────────────────────────────────

  Future<List<YtCaptionLine>> fetchCaptions(
    String videoId, {
    String lang = 'en',
  }) async {
    // 1. Thử timedtext API trực tiếp
    try {
      final uri = Uri.parse(
          'https://www.youtube.com/api/timedtext?v=$videoId&lang=$lang&fmt=srv3');
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        final lines = _parseXml(resp.body);
        if (lines.isNotEmpty) return lines;
      }
    } catch (_) {}

    // 2. Fallback: parse từ page HTML
    return _fetchFromPage(videoId, lang);
  }

  Future<List<YtCaptionLine>> _fetchFromPage(
      String videoId, String lang) async {
    try {
      final pageResp = await http.get(
        Uri.parse('https://www.youtube.com/watch?v=$videoId'),
        headers: {
          'Accept-Language': '$lang,en;q=0.9',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      final match = RegExp(
              r'"baseUrl":"([^"]+)"[^}]*"languageCode":"' + lang + '"')
          .firstMatch(pageResp.body);
      if (match == null) return [];

      final baseUrl = match.group(1)!.replaceAll(r'\u0026', '&');
      final captResp = await http
          .get(Uri.parse(baseUrl))
          .timeout(const Duration(seconds: 10));
      if (captResp.statusCode != 200) return [];
      return _parseXml(captResp.body);
    } catch (e) {
      debugPrint('YtService._fetchFromPage: $e');
      return [];
    }
  }

  List<YtCaptionLine> _parseXml(String xml) {
    final lines = <YtCaptionLine>[];

    // srv3: <p t="12345" d="2000">text</p>
    for (final m in RegExp(
            r'<p[^>]+\bt="(\d+)"[^>]+\bd="(\d+)"[^>]*>(.*?)</p>',
            dotAll: true)
        .allMatches(xml)) {
      final startMs = int.tryParse(m.group(1) ?? '0') ?? 0;
      final durMs = int.tryParse(m.group(2) ?? '0') ?? 0;
      final text = _clean(m.group(3) ?? '');
      if (text.isEmpty) continue;
      lines.add(YtCaptionLine(
        Duration(milliseconds: startMs),
        Duration(milliseconds: startMs + durMs),
        text,
      ));
    }

    // Fallback: <text start="1.23" dur="2.00">text</text>
    if (lines.isEmpty) {
      for (final m in RegExp(
              r'<text\s+start="([\d.]+)"\s+dur="([\d.]+)"[^>]*>(.*?)</text>',
              dotAll: true)
          .allMatches(xml)) {
        final s = (double.tryParse(m.group(1) ?? '0') ?? 0) * 1000;
        final d = (double.tryParse(m.group(2) ?? '0') ?? 0) * 1000;
        final text = _clean(m.group(3) ?? '');
        if (text.isEmpty) continue;
        lines.add(YtCaptionLine(
          Duration(milliseconds: s.round()),
          Duration(milliseconds: (s + d).round()),
          text,
        ));
      }
    }

    lines.sort((a, b) => a.start.compareTo(b.start));
    return lines;
  }

  String _clean(String raw) => raw
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('\n', ' ')
      .trim();

  // ─── Save LRC ─────────────────────────────────────────────

  String captionsToLrc(List<YtCaptionLine> captions, YtVideo video) {
    final buf = StringBuffer()
      ..writeln('[ti:${video.title}]')
      ..writeln('[ar:${video.channel}]')
      ..writeln('[by:VipSound]')
      ..writeln();
    for (final c in captions) {
      buf.writeln(c.toLrc());
    }
    return buf.toString();
  }

  Future<String?> saveLrc(
      List<YtCaptionLine> captions, YtVideo video) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/youtube_captions');
      if (!await folder.exists()) await folder.create(recursive: true);
      final safe = video.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .substring(0, video.title.length.clamp(0, 50));
      final path = '${folder.path}/$safe.lrc';
      await File(path).writeAsString(captionsToLrc(captions, video));
      return path;
    } catch (e) {
      debugPrint('YtService.saveLrc: $e');
      return null;
    }
  }
}
