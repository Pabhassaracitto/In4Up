// lib/features/mascot/mascot_search_index.dart
//
// MASCOT-002 — Chỉ mục tìm kiếm hợp nhất cho palette «Mở nhanh» của linh vật
// Sara (PLAN-050 §7, ADR-0036 D2).
//
// Thuần Dart — không Flutter/plugin: chấm điểm, fuzzy KHÔNG DẤU (người Việt
// gõ «phat am» vẫn ra «Phát âm»), cộng boost do caller tính (usage + ngữ cảnh
// tab — khuôn `_quickActionScore` của main_shell).
//
// P0: main_shell nạp mục từ ToolItem (tool) + tab/mode + tệp gần đây
// (RecentFilesService) + thư viện âm thanh (AudioLibraryProvider). Các nguồn
// khác (TextLibrary/Tipiṭaka/WordList) nối cùng khớp loại ở P1 khi mascot
// controller có payload mở nguồn thật (card MASCOT-003).

import 'mascot_intent_registry.dart' show mascotNormalizeCommand;

/// Loại mục trong chỉ mục — quyết định icon/chip ở palette.
enum MascotSearchKind { tab, mode, tool, file, audio, note }

/// Một mục tìm kiếm. [title] đã được dịch ở tầng UI (ToolItem/l10n/uiText).
class MascotSearchEntry {
  /// Id hành động: tab_/mode_/tool id của registry, hoặc `file:`/`audio:`
  /// kèm định danh nguồn thật (mở qua service hiện có — quy tắc vàng 3).
  final String id;

  final MascotSearchKind kind;

  final String title;

  final String? subtitle;

  /// Trọng số ưu tiên 0..1 — usage + ngữ cảnh tab hiện tại (do caller tính).
  final double boost;

  const MascotSearchEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.boost = 0,
  });
}

class MascotSearchResult {
  final MascotSearchEntry entry;

  final double score;

  const MascotSearchResult(this.entry, this.score);
}

class MascotSearchIndex {
  MascotSearchIndex(List<MascotSearchEntry> entries)
      : _entries = List<MascotSearchEntry>.unmodifiable(entries),
        _titles = List<String>.unmodifiable(
            entries.map((e) => mascotNormalizeCommand(e.title))),
        _subtitles = List<String>.unmodifiable(entries
            .map((e) => e.subtitle == null
                ? ''
                : mascotNormalizeCommand(e.subtitle!))) {
    assert(_entries.length == _titles.length);
  }

  final List<MascotSearchEntry> _entries;
  final List<String> _titles;
  final List<String> _subtitles;

  int get size => _entries.length;

  /// Tìm theo truy vấn. Truy vấn rỗng ⇒ gợi ý theo [MascotSearchEntry.boost].
  ///
  /// Điểm khớp tiêu đề: exact 100 · bắt đầu bằng 82 · tiền tố từ 70 · chứa 58 ·
  /// fuzzy subsequence (bỏ khoảng trắng) 36. Phụ đề chỉ hỗ trợ mức phụ
  /// (chứa 30 · fuzzy 20) — không lấn át khớp tiêu đề. Boost cộng tối đa +10.
  List<MascotSearchResult> search(String rawQuery, {int limit = 14}) {
    final query = mascotNormalizeCommand(rawQuery);

    // Ghép (index, score) để sort ổn định theo index khi đồng điểm.
    final scored = <int, double>{};

    if (query.isEmpty) {
      for (var i = 0; i < _entries.length; i++) {
        scored[i] = _entries[i].boost;
      }
    } else {
      final fuzzyQuery = query.replaceAll(' ', '');
      for (var i = 0; i < _entries.length; i++) {
        final score = _score(i, query, fuzzyQuery);
        if (score > 0) scored[i] = score;
      }
    }

    final order = scored.keys.toList()
      ..sort((a, b) {
        final byScore = scored[b]!.compareTo(scored[a]!);
        if (byScore != 0) return byScore;
        return a.compareTo(b);
      });

    return [
      for (final i in order.take(limit))
        MascotSearchResult(_entries[i], scored[i]!),
    ];
  }

  double _score(int i, String query, String fuzzyQuery) {
    final title = _titles[i];
    final subtitle = _subtitles[i];

    var best = 0.0;
    if (title == query) {
      best = 100;
    } else if (title.startsWith(query)) {
      best = 82;
    } else if (_wordPrefix(title, query)) {
      best = 70;
    } else if (title.contains(query)) {
      best = 58;
    } else if (_isSubsequence(fuzzyQuery, title.replaceAll(' ', ''))) {
      best = 36;
    }

    // Phụ đề chỉ nâng mục lên khi tiêu đề chưa khớp rõ.
    if (best < 30 && subtitle.isNotEmpty) {
      if (subtitle.contains(query)) {
        best = 30;
      } else if (_isSubsequence(fuzzyQuery, subtitle.replaceAll(' ', ''))) {
        best = 20;
      }
    }

    if (best <= 0) return 0;
    return best + _entries[i].boost * 10;
  }

  /// Một TỪ của tiêu đề có bắt đầu bằng truy vấn không («tu» khớp «Từ điển»).
  static bool _wordPrefix(String text, String query) {
    if (query.isEmpty) return false;
    var start = 0;
    while (true) {
      final space = text.indexOf(' ', start);
      final word =
          space == -1 ? text.substring(start) : text.substring(start, space);
      if (word.startsWith(query)) return true;
      if (space == -1) return false;
      start = space + 1;
    }
  }

  /// Các ký tự của [needle] xuất hiện theo đúng thứ tự trong [haystack].
  /// Cho phép gõ thiếu («tamg» → «tam giac») mà không cần package bên ngoài.
  static bool _isSubsequence(String needle, String haystack) {
    if (needle.isEmpty || haystack.length < needle.length) return false;
    var pos = 0;
    for (var i = 0; i < haystack.length && pos < needle.length; i++) {
      if (haystack.codeUnitAt(i) == needle.codeUnitAt(pos)) pos++;
    }
    return pos == needle.length;
  }
}
