// YT-MY-CHANNELS-001 — lưu danh sách kênh người dùng tự theo dõi.
//
// Dùng `shared_preferences` (đã có trong app, local-first): danh sách kênh chỉ
// là vài chục dòng JSON, không cần Firestore, không cần đăng nhập. Người dùng
// đổi máy thì dán lại/import OPML — chấp nhận được, và **không bao giờ mất dữ
// liệu vì lỗi đồng bộ**.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/yt_channel.dart';

class YtChannelStore {
  YtChannelStore._();
  static final YtChannelStore instance = YtChannelStore._();

  static const String _key = 'yt_followed_channels_v1';

  /// Cache trong RAM — sheet mở/đóng nhiều lần, không cần đọc lại đĩa.
  List<YtChannel>? _cache;

  Future<List<YtChannel>> load() async {
    final c = _cache;
    if (c != null) return List.unmodifiable(c);
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      final list = <YtChannel>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map<String, dynamic>) {
              final ch = YtChannel.fromJson(e);
              if (ch != null) list.add(ch);
            } else if (e is Map) {
              final ch = YtChannel.fromJson(Map<String, dynamic>.from(e));
              if (ch != null) list.add(ch);
            }
          }
        }
      }
      _cache = list;
      return List.unmodifiable(list);
    } catch (e) {
      debugPrint('YtChannelStore.load: $e');
      return const [];
    }
  }

  Future<void> _save(List<YtChannel> list) async {
    _cache = List.of(list);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _key,
        jsonEncode(list.map((c) => c.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('YtChannelStore._save: $e');
    }
  }

  /// Thêm/cập nhật một kênh. Trả `true` nếu là kênh MỚI.
  ///
  /// Cùng ID mà lần này phân giải được tên ⇒ cập nhật tên; không tạo bản trùng.
  Future<bool> add(YtChannel channel) async {
    final list = List<YtChannel>.of(await load());
    final i = list.indexWhere((c) => c.id == channel.id);
    if (i >= 0) {
      final old = list[i];
      list[i] = old.copyWith(
        title: channel.title.trim().isEmpty ? old.title : channel.title,
        handle: channel.handle ?? old.handle,
      );
      await _save(list);
      return false;
    }
    list.add(channel.copyWith(addedAt: channel.addedAt ?? DateTime.now()));
    await _save(list);
    return true;
  }

  /// Thêm nhiều kênh một lượt (import OPML). Trả số kênh MỚI.
  Future<int> addAll(Iterable<YtChannel> channels) async {
    final list = List<YtChannel>.of(await load());
    final ids = list.map((c) => c.id).toSet();
    var added = 0;
    for (final ch in channels) {
      if (ch.id.isEmpty) continue;
      if (ids.add(ch.id)) {
        list.add(ch.copyWith(addedAt: ch.addedAt ?? DateTime.now()));
        added++;
      } else {
        // Đã có: chỉ nâng cấp tên nếu đang trống.
        final i = list.indexWhere((c) => c.id == ch.id);
        if (i >= 0 && list[i].title.trim().isEmpty && ch.title.trim().isNotEmpty) {
          list[i] = list[i].copyWith(title: ch.title);
        }
      }
    }
    if (added > 0 || list.isNotEmpty) await _save(list);
    return added;
  }

  Future<void> remove(String channelId) async {
    final list = List<YtChannel>.of(await load());
    list.removeWhere((c) => c.id == channelId);
    await _save(list);
  }

  Future<bool> contains(String channelId) async =>
      (await load()).any((c) => c.id == channelId);

  /// Chỉ dùng cho test/khôi phục: xoá toàn bộ danh sách.
  Future<void> clear() async => _save(const []);

  @visibleForTesting
  void resetCacheForTest() => _cache = null;
}
