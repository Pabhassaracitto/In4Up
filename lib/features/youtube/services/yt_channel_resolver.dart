// YT-MY-CHANNELS-001 — đổi "@handle" hoặc URL kênh thành `UC...` + tên kênh.
//
// Vì sao phải có bước này: `YtSearchService.fetchChannelVideos()` cần **channel
// ID** (đi qua uploads playlist `UU...`), trong khi người dùng tự nhiên dán
// `@bbclearningenglish` hoặc link kênh. Phân giải một lần rồi LƯU ID ⇒ lần sau
// mở kênh không cần gọi mạng để đoán nữa.
//
// Không dùng YouTube Data API (không cần key, đúng tinh thần local-first):
// trang kênh HTML luôn chứa `"channelId":"UC…"`.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/yt_channel.dart';

class YtChannelResolver {
  YtChannelResolver._();
  static final YtChannelResolver instance = YtChannelResolver._();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  /// Phân giải đầu vào người dùng. Trả `null` khi không nhận ra hoặc mạng lỗi.
  ///
  /// [input] nhận mọi thứ `parseYtChannelInput` hiểu. Với ID trần, vẫn gọi
  /// mạng MỘT lần để lấy tên kênh — nếu lỗi thì vẫn thêm được kênh (tên tạm
  /// là ID) chứ không chặn người dùng.
  Future<YtChannel?> resolve(String input) async {
    final ref = parseYtChannelInput(input);
    if (ref == null) return null;

    if (ref.isResolved) {
      final id = ref.channelId!;
      final title = await _fetchTitle('https://www.youtube.com/channel/$id');
      return YtChannel(id: id, title: title ?? '', handle: ref.handle);
    }

    final handle = ref.handle;
    if (handle == null || handle.trim().isEmpty) return null;

    // Thử lần lượt các dạng URL mà YouTube còn hỗ trợ.
    final candidates = <String>[
      if (handle.startsWith('@')) 'https://www.youtube.com/$handle',
      if (!handle.startsWith('@')) ...[
        'https://www.youtube.com/@$handle',
        'https://www.youtube.com/c/$handle',
        'https://www.youtube.com/user/$handle',
      ],
    ];

    for (final url in candidates) {
      final html = await _fetch(url);
      if (html == null) continue;
      final id = ytChannelIdFromHtml(html);
      if (id == null) continue;
      return YtChannel(
        id: id,
        title: ytChannelTitleFromHtml(html) ?? handle,
        handle: handle,
      );
    }
    debugPrint('❌ [in4up-yt] không phân giải được kênh "$input"');
    return null;
  }

  Future<String?> _fetchTitle(String url) async {
    final html = await _fetch(url);
    if (html == null) return null;
    return ytChannelTitleFromHtml(html);
  }

  Future<String?> _fetch(String url) async {
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Accept-Language': 'en'},
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        debugPrint('❌ [in4up-yt] kênh HTTP ${resp.statusCode}: $url');
        return null;
      }
      return resp.body;
    } catch (e) {
      debugPrint('❌ [in4up-yt] kênh lỗi mạng: $e');
      return null;
    }
  }
}
