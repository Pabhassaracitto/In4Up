// YT-EXPLORER-CACHE-001 (#YT1-06 owner 2026-11-09) — bộ nhớ đệm cho tầng 1.
//
// Vì sao: mỗi lần mở Explorer đều gọi mạng (tìm kiếm + danh sách video của
// kênh). Mất mạng là màn trống, và quay lại sau 1 phút cũng phải chờ tải lại.
//
// Nguyên tắc (owner chốt 2026-11-09):
//   • Cache **có tính dung lượng** — hiện được, xoá được, và **ẩn được** trong
//     cài đặt YouTube (`YtLearningSettings.showCacheSize`).
//   • **Có TTL**, nhưng dùng kiểu *stale-while-revalidate*: hiện bản cũ NGAY,
//     làm mới ngầm, và nói rõ "cập nhật 2 giờ trước". Không bao giờ chặn người
//     dùng bằng spinner khi đã có dữ liệu cũ.
//
// TTL theo loại (đo bằng thời gian thực, không phải số lần mở):
//   • tìm kiếm theo từ khoá : 24 giờ  (nội dung mới ra nhanh, lặp lại trong ngày nhiều)
//   • danh sách video kênh  : 3 ngày  (kênh học ít đăng)
//   • thông tin kênh        : 30 ngày (gần như tĩnh)
//   • phụ đề đã tải         : KHÔNG hết hạn — nằm ở `YtMediaStore`, người dùng tự xoá.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'yt_initial_data_parser.dart' show YtSearchHit;

/// Loại dữ liệu được đệm — quyết định TTL.
enum YtCacheKind {
  /// Kết quả tìm kiếm theo từ khoá.
  search,

  /// Danh sách video của một kênh.
  channel,
}

class YtCacheEntry {
  const YtCacheEntry({
    required this.hits,
    required this.savedAt,
  });

  final List<YtSearchHit> hits;
  final DateTime savedAt;

  Duration get age => DateTime.now().difference(savedAt);

  /// Chuỗi "2 giờ trước" KHÔNG nằm ở đây (model không chứa tiếng Việt); UI ghép
  /// từ [age] qua template `{value0} giờ trước`.

  Map<String, dynamic> toJson() => {
        't': savedAt.millisecondsSinceEpoch,
        'items': [
          for (final h in hits)
            {
              'id': h.id,
              'title': h.title,
              'channel': h.channel,
              'channelId': h.channelId,
              if (h.thumb != null) 'thumb': h.thumb,
              if (h.duration != null) 'dur': h.duration!.inSeconds,
              if (h.viewCount != null) 'views': h.viewCount,
              if (h.publishedAt != null)
                'pub': h.publishedAt!.millisecondsSinceEpoch,
            },
        ],
      };

  static YtCacheEntry? fromJson(Map<String, dynamic> j) {
    // `as num?` ném khi dữ liệu hỏng (chuỗi) — cache hỏng phải trả null chứ
    // không được làm sập Explorer.
    final rawT = j['t'];
    if (rawT is! num) return null;
    final t = rawT.toInt();
    final raw = j['items'];
    if (raw is! List) return null;
    final hits = <YtSearchHit>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final id = (e['id'] as String?)?.trim() ?? '';
      if (id.isEmpty) continue;
      final dur = e['dur'] is num ? (e['dur'] as num).toInt() : null;
      final pub = e['pub'] is num ? (e['pub'] as num).toInt() : null;
      hits.add(YtSearchHit(
        id: id,
        title: (e['title'] as String?) ?? '',
        channel: (e['channel'] as String?) ?? '',
        channelId: (e['channelId'] as String?) ?? '',
        thumb: e['thumb'] as String?,
        duration: dur == null ? null : Duration(seconds: dur),
        viewCount: e['views'] is num ? (e['views'] as num).toInt() : null,
        publishedAt:
            pub == null ? null : DateTime.fromMillisecondsSinceEpoch(pub),
      ));
    }
    return YtCacheEntry(
      hits: hits,
      savedAt: DateTime.fromMillisecondsSinceEpoch(t),
    );
  }
}

class YtExplorerCache {
  YtExplorerCache._();
  static final YtExplorerCache instance = YtExplorerCache._();

  static const String boxName = 'yt_explorer_cache';

  /// TTL theo loại.
  static const Map<YtCacheKind, Duration> ttl = {
    YtCacheKind.search: Duration(hours: 24),
    YtCacheKind.channel: Duration(days: 3),
  };

  Future<void> ensureOpen() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<String>(boxName);
    }
  }

  String _key(YtCacheKind kind, String id) => '${kind.name}:$id';

  /// Đọc cache. Trả `null` nếu chưa có (hoặc dữ liệu hỏng).
  Future<YtCacheEntry?> read(YtCacheKind kind, String id) async {
    final key = _key(kind, id.trim());
    try {
      await ensureOpen();
      final raw = Hive.box<String>(boxName).get(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return YtCacheEntry.fromJson(Map<String, dynamic>.from(decoded));
    } catch (e) {
      debugPrint('[in4up-yt] cache read failed: $e');
      return null;
    }
  }

  /// Đã hết hạn chưa (TTL theo loại). Vẫn có thể dùng để hiện tạm.
  static bool expired(YtCacheKind kind, YtCacheEntry e) =>
      e.age > (ttl[kind] ?? const Duration(days: 1));

  Future<void> write(
    YtCacheKind kind,
    String id,
    List<YtSearchHit> hits,
  ) async {
    if (hits.isEmpty) return;
    final key = _key(kind, id.trim());
    try {
      await ensureOpen();
      await Hive.box<String>(boxName).put(
        key,
        jsonEncode(YtCacheEntry(hits: hits, savedAt: DateTime.now()).toJson()),
      );
    } catch (e) {
      debugPrint('[in4up-yt] cache write failed: $e');
    }
  }

  /// Dựng lại toàn bộ cache (nút "Làm mới" = bỏ qua TTL).
  Future<void> clear() async {
    try {
      await ensureOpen();
      await Hive.box<String>(boxName).clear();
    } catch (e) {
      debugPrint('[in4up-yt] cache clear failed: $e');
    }
  }

  Future<void> remove(YtCacheKind kind, String id) async {
    try {
      await ensureOpen();
      await Hive.box<String>(boxName).delete(_key(kind, id.trim()));
    } catch (_) {}
  }

  /// Dung lượng cache (byte, ước lượng theo UTF-8 của JSON đã lưu).
  ///
  /// Đây là số ĐO từ dữ liệu thật đang nằm trong Hive, không phải hằng số đoán;
  /// Hive thêm overhead nhỏ cho mỗi key nhưng chênh lệch không đáng kể so với
  /// vài chục KB của một trang kết quả.
  Future<int> totalBytes() async {
    try {
      await ensureOpen();
      final box = Hive.box<String>(boxName);
      var bytes = 0;
      for (final k in box.keys) {
        final v = box.get(k);
        if (v != null) bytes += utf8.encode(v).length;
      }
      return bytes;
    } catch (_) {
      return 0;
    }
  }

  /// Số mục đang đệm.
  Future<int> length() async {
    try {
      await ensureOpen();
      return Hive.box<String>(boxName).length;
    } catch (_) {
      return 0;
    }
  }
}
