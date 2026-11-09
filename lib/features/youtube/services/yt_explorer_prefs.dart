// YT-EXPLORER-PREFS-001 (#YT1-10 owner 2026-11-09) — Explorer NHỚ người dùng.
//
// Trước đây kênh đang chọn, kiểu sắp xếp, bộ lọc cấp độ, ghim kênh và từ khoá
// gần nhất chỉ nằm trong RAM của màn hình (`setState`) ⇒ thoát ra vào lại là mất
// sạch. Người dùng phải chọn lại từ đầu mỗi lần — cảm giác "app không nhớ mình".
//
// Lưu bằng `shared_preferences` (đã có trong app, local-first, không cần
// đăng nhập). Dữ liệu vài trăm byte nên không ảnh hưởng dung lượng.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class YtExplorerPrefs {
  YtExplorerPrefs._();
  static final YtExplorerPrefs instance = YtExplorerPrefs._();

  static const _kChannel = 'yt_explorer_channel_v1';
  static const _kSort = 'yt_explorer_sort_v1';
  static const _kBand = 'yt_explorer_band_v1';
  static const _kQuery = 'yt_explorer_query_v1';
  static const _kPinned = 'yt_explorer_pinned_v1';

  SharedPreferences? _sp;

  Future<SharedPreferences> _prefs() async =>
      _sp ??= await SharedPreferences.getInstance();

  Future<({String? channelId, String sort, String band, String query})>
      load() async {
    try {
      final sp = await _prefs();
      return (
        channelId: sp.getString(_kChannel),
        sort: sp.getString(_kSort) ?? 'date',
        band: sp.getString(_kBand) ?? '',
        query: sp.getString(_kQuery) ?? '',
      );
    } catch (e) {
      debugPrint('[in4up-yt] prefs load failed: $e');
      return (channelId: null, sort: 'date', band: '', query: '');
    }
  }

  Future<void> saveChannel(String? id) async {
    try {
      final sp = await _prefs();
      if (id == null || id.isEmpty) {
        await sp.remove(_kChannel);
      } else {
        await sp.setString(_kChannel, id);
      }
    } catch (_) {}
  }

  Future<void> saveSort(String sort) async {
    try {
      await (await _prefs()).setString(_kSort, sort);
    } catch (_) {}
  }

  /// `''` = Tất cả.
  Future<void> saveBand(String band) async {
    try {
      await (await _prefs()).setString(_kBand, band);
    } catch (_) {}
  }

  Future<void> saveQuery(String query) async {
    try {
      final sp = await _prefs();
      if (query.trim().isEmpty) {
        await sp.remove(_kQuery);
      } else {
        await sp.setString(_kQuery, query.trim());
      }
    } catch (_) {}
  }

  /// Kênh đã ghim — trước đây `isPinned` chỉ là cờ RAM, thoát màn là mất.
  Future<Set<String>> loadPinned() async {
    try {
      final sp = await _prefs();
      return (sp.getStringList(_kPinned) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> savePinned(Iterable<String> ids) async {
    try {
      await (await _prefs()).setStringList(_kPinned, ids.toList());
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final sp = await _prefs();
      for (final k in <String>[
        _kChannel,
        _kSort,
        _kBand,
        _kQuery,
        _kPinned,
      ]) {
        await sp.remove(k);
      }
    } catch (_) {}
  }
}
