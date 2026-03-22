//
// FIX captions "en" không tìm thấy:
//  1. Dùng youtube_explode_dart ClosedCaptionsClient (ổn định nhất)
//     → thử exact match, prefix match, auto-generated (a.en)
//  2. Fallback: timedtext API với nhiều lang code variants
//  3. Fallback cuối: parse từ page HTML
// Giữ nguyên fetchInfo và saveLrc từ bản cũ

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_exp;

import '../models/yt_video.dart';

class YtService {
  YtService._();
  static final YtService instance = YtService._();

  // ─── Fetch video info (oEmbed — giữ nguyên bản cũ) ───

  Future<YtVideo?> fetchInfo(String videoId) async {
    try {
      final url = 'https://www.youtube.com/oembed?format=json&url='
          '${Uri.encodeComponent('https://www.youtube.com/watch?v=$videoId')}';
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final body = resp.body;

      String extract(String key) {
        final pattern = '"$key":"';
        final start = body.indexOf(pattern);
        if (start < 0) return '';
        final vs = start + pattern.length;
        final end = body.indexOf('"', vs);
        if (end < 0) return '';
        return body
            .substring(vs, end)
            .replaceAll(r'\u0026', '&')
            .replaceAll(r'\/', '/');
      }

      final title = extract('title');
      return YtVideo(
        id: videoId,
        title: title.isEmpty ? 'Unknown' : title,
        channel: extract('author_name'),
        thumb: extract('thumbnail_url'),
      );
    } catch (e) {
      debugPrint('YtService.fetchInfo: $e');
      return null;
    }
  }

  // ─── Fetch captions (3 tầng fallback) ────────────────
  //
  // Tầng 1: youtube_explode_dart ClosedCaptionsClient
  //   → thử exact / prefix / auto-generated (a.en) / first available
  // Tầng 2: timedtext API trực tiếp với nhiều lang variants
  // Tầng 3: parse baseUrl từ page HTML
  Future<List<YtCaptionLine>> fetchCaptions(
    String videoId, {
    String lang = 'en',
  }) async {
    // Tầng 1: youtube_explode_dart
    try {
      final lines = await _fetchWithExplode(videoId, lang: lang);
      if (lines.isNotEmpty) {
        debugPrint('✅ Captions explode: ${lines.length} dòng (lang=$lang)');
        return lines;
      }
    } catch (e) {
      debugPrint('explode captions failed: $e');
    }

    // Tầng 2: timedtext API với nhiều variants
    for (final code in _langVariants(lang)) {
      try {
        final lines = await _fetchTimedtext(videoId, code);
        if (lines.isNotEmpty) {
          debugPrint('✅ Captions timedtext ($code): ${lines.length} dòng');
          return lines;
        }
      } catch (e) {
        debugPrint('timedtext [$code] failed: $e');
      }
    }

    // Tầng 3: parse page HTML
    try {
      final lines = await _fetchFromPageHtml(videoId, lang);
      if (lines.isNotEmpty) {
        debugPrint('✅ Captions page HTML: ${lines.length} dòng');
        return lines;
      }
    } catch (e) {
      debugPrint('page HTML captions failed: $e');
    }

    debugPrint('❌ Không tìm thấy captions cho lang=$lang');
    return [];
  }

  /// Lấy danh sách ngôn ngữ có sẵn
  Future<List<({String code, String name})>> getAvailableLanguages(
      String videoId) async {
    // Thử explode trước
    try {
      final yt = yt_exp.YoutubeExplode();
      try {
        final manifest =
            await yt.videos.closedCaptions.getManifest(videoId);
        if (manifest.tracks.isNotEmpty) {
          // Loại bỏ auto-generated duplicates (a.en vs en)
          final seen = <String>{};
          final result = <({String code, String name})>[];
          for (final t in manifest.tracks) {
            final code = t.language.code;
            // Normalise: "a.en" → hiển thị là "en (auto)"
            final display = code.startsWith('a.')
                ? '${code.substring(2)} (auto)'
                : t.language.name;
            final key = code.startsWith('a.')
                ? code.substring(2)
                : code;
            if (!seen.contains(key)) {
              seen.add(key);
              result.add((code: code, name: display));
            }
          }
          return result;
        }
      } finally {
        yt.close();
      }
    } catch (_) {}

    // Fallback: danh sách mặc định
    return [
      (code: 'en', name: 'English'),
      (code: 'vi', name: 'Vietnamese'),
      (code: 'zh-Hans', name: 'Chinese (Simplified)'),
      (code: 'ja', name: 'Japanese'),
      (code: 'ko', name: 'Korean'),
      (code: 'fr', name: 'French'),
      (code: 'de', name: 'German'),
      (code: 'es', name: 'Spanish'),
    ];
  }

  // ─── Tầng 1: youtube_explode_dart ────────────────────

  Future<List<YtCaptionLine>> _fetchWithExplode(
    String videoId, {
    required String lang,
  }) async {
    final yt = yt_exp.YoutubeExplode();
    try {
      final manifest =
          await yt.videos.closedCaptions.getManifest(videoId);
      if (manifest.tracks.isEmpty) return [];

      yt_exp.ClosedCaptionTrackInfo? track;

      // 1. Exact match
      track = _findTrack(manifest.tracks, lang);

      // 2. Prefix match: 'en' match 'en-US', 'en-GB'
      if (track == null) {
        track = manifest.tracks
            .cast<yt_exp.ClosedCaptionTrackInfo?>()
            .firstWhere(
              (t) => t!.language.code.startsWith('$lang-'),
              orElse: () => null,
            );
      }

      // 3. Auto-generated: 'en' → 'a.en'
      if (track == null) {
        track = _findTrack(manifest.tracks, 'a.$lang');
      }

      // 4. Auto-generated với hyphen: 'a.en-US'
      if (track == null) {
        track = manifest.tracks
            .cast<yt_exp.ClosedCaptionTrackInfo?>()
            .firstWhere(
              (t) => t!.language.code.startsWith('a.$lang'),
              orElse: () => null,
            );
      }

      // 5. Không tìm thấy đúng lang → không fallback sang lang khác
      //    (để UI có thể thông báo đúng)
      if (track == null) return [];

      final captions = await yt.videos.closedCaptions.get(track);
      return captions.captions
          .map((c) => YtCaptionLine(
                c.offset,
                c.offset + c.duration,
                _clean(c.text),
              ))
          .where((c) => c.text.isNotEmpty)
          .toList();
    } finally {
      yt.close();
    }
  }

  yt_exp.ClosedCaptionTrackInfo? _findTrack(
    List<yt_exp.ClosedCaptionTrackInfo> tracks,
    String code,
  ) =>
      tracks.cast<yt_exp.ClosedCaptionTrackInfo?>().firstWhere(
            (t) => t!.language.code == code,
            orElse: () => null,
          );

  // ─── Tầng 2: timedtext API ────────────────────────────

  Future<List<YtCaptionLine>> _fetchTimedtext(
      String videoId, String langCode) async {
    final uri = Uri.parse(
      'https://www.youtube.com/api/timedtext'
      '?v=$videoId&lang=$langCode&fmt=srv3',
    );
    final resp = await http.get(uri, headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }).timeout(const Duration(seconds: 12));

    if (resp.statusCode != 200 || resp.body.trim().isEmpty) return [];
    return _parseXml(resp.body);
  }

  // ─── Tầng 3: page HTML ────────────────────────────────

  Future<List<YtCaptionLine>> _fetchFromPageHtml(
      String videoId, String lang) async {
    final resp = await http.get(
      Uri.parse('https://www.youtube.com/watch?v=$videoId'),
      headers: {
        'Accept-Language': '$lang,en;q=0.9',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return [];
    final body = resp.body;

    String? baseUrl;

    // Pattern 1: exact lang
    final p1 = RegExp(
      '"baseUrl":"([^"]+)"[^}]{0,200}"languageCode":"' +
          RegExp.escape(lang) +
          '"',
    );
    baseUrl = p1.firstMatch(body)?.group(1);

    // Pattern 2: auto-generated a.lang
    if (baseUrl == null) {
      final p2 = RegExp(
        '"baseUrl":"([^"]+)"[^}]{0,200}"languageCode":"a\\.' +
            RegExp.escape(lang) +
            '"',
      );
      baseUrl = p2.firstMatch(body)?.group(1);
    }

    // Pattern 3: bất kỳ timedtext URL (fallback)
    if (baseUrl == null) {
      final p3 = RegExp(
          r'"baseUrl":"(https://www\.youtube\.com/api/timedtext[^"]+)"');
      baseUrl = p3.firstMatch(body)?.group(1);
    }

    if (baseUrl == null) return [];

    baseUrl =
        baseUrl.replaceAll(r'\u0026', '&').replaceAll(r'\/', '/');

    final captResp = await http
        .get(Uri.parse(baseUrl))
        .timeout(const Duration(seconds: 12));

    if (captResp.statusCode != 200) return [];
    return _parseXml(captResp.body);
  }

  // ─── Helpers ──────────────────────────────────────────

  /// Danh sách lang code variants để thử
  List<String> _langVariants(String lang) {
    final variants = <String>[lang];
    switch (lang) {
      case 'en':
        variants.addAll(['en-US', 'en-GB', 'en-CA', 'en-AU',
            'a.en', 'a.en-US', 'a.en-GB']);
        break;
      case 'zh':
      case 'zh-Hans':
        variants.addAll(['zh-Hans', 'zh', 'zh-CN', 'a.zh', 'a.zh-Hans']);
        break;
      case 'pt':
        variants.addAll(['pt-BR', 'pt-PT', 'a.pt', 'a.pt-BR']);
        break;
      case 'es':
        variants.addAll(['es-419', 'es-US', 'es-ES', 'a.es']);
        break;
      default:
        variants.add('a.$lang');
    }
    return variants;
  }

  /// Parse XML từ timedtext API (srv3 + legacy format)
  List<YtCaptionLine> _parseXml(String xml) {
    final lines = <YtCaptionLine>[];

    // srv3: <p t="12345" d="2000">text</p>
    for (final m in RegExp(
      r'<p[^>]+\bt="(\d+)"[^>]+\bd="(\d+)"[^>]*>(.*?)</p>',
      dotAll: true,
    ).allMatches(xml)) {
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

    // Legacy: <text start="1.23" dur="2.00">text</text>
    if (lines.isEmpty) {
      for (final m in RegExp(
        r'<text\s+start="([\d.]+)"\s+dur="([\d.]+)"[^>]*>(.*?)</text>',
        dotAll: true,
      ).allMatches(xml)) {
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
      .replaceAll('&quot;', '"')
      .replaceAll('\n', ' ')
      .trim();

  // ─── Save LRC (giữ nguyên bản cũ) ────────────────────

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
