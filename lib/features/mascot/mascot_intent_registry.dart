// lib/features/mascot/mascot_intent_registry.dart
//
// MASCOT-001 — Registry hành động của linh vật Sara (PLAN-050, ADR-0036 D2).
//
// NGUỒN SỰ THẬT DUY NHẤT cho «linh vật làm được gì»: palette «Mở nhanh»
// (MASCOT-002), lệnh giọng deterministic (P2) và yêu cầu hành động từ LLM
// (P1, JSON `{"say", "action"}`) đều đi qua cổng này. Một hành động mới của
// app chỉ cần đăng ký MỘT dòng ở đây để mọi mặt đều gọi được.
//
// THUẦN DART — không import Flutter/plugin: test được trong sandbox/CI
// (sandbox không có Flutter SDK; oracle là `flutter test test/mascot/`).
//
// Tương thích lùi: 8 intent `lib/features/voice_command/` cũ được đăng ký lại
// cùng ngữ nghĩa (nhóm playback) — parser cũ GIỮ NGUYÊN cho luồng phát lại
// trong tab Nghe; mascot không gọi executor cũ ở P0 (chưa nối — xem
// ShellActionHub.execute, nhóm playback trả `executed: false`).
//
// Nhãn ([MascotActionDef.label]) là nhãn gốc tiếng Việt dùng cho log/fallback;
// chrome UI KHÔNG dịch từ đây — UI lấy nhãn đã dịch từ ToolItem/l10n rồi áp
// `context.uiText(...)` (rule #5 AGENTS.md). Từ khoá lệnh là NỘI DUNG lệnh
// (giống grammar voice_command), không phải chrome — không đưa vào catalog.

import 'dart:math' as math;

/// Nhóm hành động — quyết định đường thực thi ở [ShellActionHub].
enum MascotActionGroup {
  /// Chuyển tab chính (home/listen/read/understand/remember).
  tab,

  /// Chuyển sub-mode (Nghe/Nói/Xem, Đọc/Viết) — cần shell gắn sẵn.
  mode,

  /// Mở tool của shell — id TRÙNG `_handleTool` trong `main_shell.dart`.
  tool,

  /// 8 intent phát lại kế thừa từ voice_command — P0 chỉ đăng ký, chưa nối.
  playback,
}

/// Định danh một hành động linh vật có thể làm.
class MascotActionDef {
  /// Id ổn định: tool dùng đúng id của `_handleTool`; tab/mode có tiền tố
  /// `tab_`/`mode_` để tránh trùng.
  final String id;

  final MascotActionGroup group;

  /// Nhãn gốc (vi) cho log/fallback — chrome lấy nhãn dịch ở tầng UI.
  final String label;

  /// Từ khoá lệnh đã chuẩn hoá không dấu (vi + en) — dùng
  /// [mascotNormalizeCommand] để chuẩn hoá đầu vào trước khi so khớp.
  final List<String> keywords;

  const MascotActionDef(
    this.id,
    this.group,
    this.label,
    this.keywords,
  );
}

/// Kết quả so khớp một lệnh với hành động.
class MascotActionMatch {
  final MascotActionDef action;

  /// Điểm khớp — càng cao càng tin (exact > bắt đầu bằng > chứa).
  final double score;

  const MascotActionMatch(this.action, this.score);
}

/// Chuẩn hoá lệnh: bỏ dấu tiếng Việt (kể cả đ→d), thường hoá, chỉ giữ
/// `[a-z0-9 ]`. Cùng phương pháp với `_normalize` của voice_command_parser
/// (người Việt gõ/nói không dấu vẫn khớp).
String mascotNormalizeCommand(String value) {
  const from =
      'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  var result = value.toLowerCase();
  // Map phải CÂN BẰNG 67=67 — assert lúc chạy để sớm phát hiện ai
  // sửa lệch (bug gốc: 'to' thiếu 3 'o', thừa 1 'u' ⇒ RangeError
  // vòng 65 với MỌI chuỗi có dấu; tìm ra khi test mascot đỏ).
  assert(from.length == to.length,
      'mascotNormalizeCommand: map dấu lệch độ dài '
      '${from.length} vs ${to.length}');
  for (var i = 0; i < from.length; i++) {
    result = result.replaceAll(from[i], to[i]);
  }
  return result
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Registry hành động — nguồn sự thật duy nhất (ADR-0036 D2).
class MascotIntentRegistry {
  MascotIntentRegistry._();

  /// Toàn bộ hành động đã đăng ký. Thứ tự khai báo = thứ tự ưu tiên khi
  /// đồng điểm (mục khai báo trước đứng trước).
  static const List<MascotActionDef> actions = [
    // ── Tab chính (5) ──────────────────────────────────────────
    MascotActionDef('tab_home', MascotActionGroup.tab, 'Trang chủ',
        ['trang chu', 'home', 've trang chu']),
    MascotActionDef('tab_listen', MascotActionGroup.tab, 'Nghe',
        ['nghe', 'listen']),
    MascotActionDef(
        'tab_read', MascotActionGroup.tab, 'Đọc', ['doc', 'read']),
    MascotActionDef('tab_understand', MascotActionGroup.tab, 'Hiểu',
        ['hieu', 'understand']),
    MascotActionDef('tab_remember', MascotActionGroup.tab, 'Nhớ',
        ['nho', 'ghi nho', 'remember', 'memory']),

    // ── Sub-mode (5) ───────────────────────────────────────────
    // mode_listen trùng đường đi với tab_listen — chủ đích: lệnh «nghe» ra
    // cả hai mục, đều mở tab Nghe (chế độ 0).
    MascotActionDef(
        'mode_listen', MascotActionGroup.mode, 'Nghe', ['nghe', 'listen']),
    MascotActionDef('mode_speak', MascotActionGroup.mode, 'Nói',
        ['noi', 'luyen noi', 'speak', 'shadowing']),
    MascotActionDef(
        'mode_watch', MascotActionGroup.mode, 'Xem', ['xem', 'watch']),
    MascotActionDef(
        'mode_read', MascotActionGroup.mode, 'Đọc', ['doc', 'read']),
    MascotActionDef('mode_write', MascotActionGroup.mode, 'Viết',
        ['viet', 'luyen viet', 'write']),

    // ── Tool (id trùng `_handleTool`) ──────────────────────────
    // Không đăng ký lại speak_mode/write_mode/understand_tab — trùng đường
    // đi với mode_speak/mode_write/tab_understand (đã có ở trên).
    MascotActionDef('mascot_palette', MascotActionGroup.tool, 'Mở nhanh',
        ['mo nhanh', 'quick open', 'tim kiem', 'search', 'palette']),
    MascotActionDef('shell_ui_settings', MascotActionGroup.tool,
        'Giao diện shell', ['giao dien shell', 'shell ui', 'cau hinh shell']),
    MascotActionDef('live_cabin', MascotActionGroup.tool, 'Dịch Live Cabin',
        ['cabin', 'live cabin', 'dich live', 'dich cabin']),
    MascotActionDef('youtube_downloader', MascotActionGroup.tool, 'YouTube',
        ['youtube', 'tai youtube', 'kho media youtube']),
    MascotActionDef('web_reader', MascotActionGroup.tool, 'Web Reader',
        ['web', 'doc web', 'web reader', 'doc trang web']),
    MascotActionDef('pdf_reader', MascotActionGroup.tool, 'PDF Reader',
        ['pdf', 'mo pdf', 'open pdf', 'doc pdf']),
    MascotActionDef('tipitaka', MascotActionGroup.tool, 'Tipiṭaka',
        ['tipitaka', 'tam tang', 'kinh dien', 'kinh']),
    MascotActionDef('video_library', MascotActionGroup.tool, 'Thư viện video',
        ['thu vien video', 'video library', 'kho video', 'video']),
    MascotActionDef('video_player', MascotActionGroup.tool, 'Video local',
        ['xem video local', 'video local', 'phat video']),
    MascotActionDef('media_tools', MascotActionGroup.tool, 'Công cụ media',
        [
          'media tools',
          'cong cu media',
          'chuyen doi am thanh',
          'cat am thanh',
          'tach am thanh',
          'noi am thanh',
        ]),
    MascotActionDef('dict_manager', MascotActionGroup.tool, 'Từ điển MDX',
        ['quan ly tu dien', 'tu dien mdx', 'dictionary manager']),
    MascotActionDef('dictionary', MascotActionGroup.tool, 'Từ điển',
        ['tu dien', 'tra tu', 'dictionary', 'tra nghia']),
    MascotActionDef('dict_packs', MascotActionGroup.tool, 'Tải bộ từ điển',
        ['tai bo tu dien', 'bo tu dien', 'dict packs', 'tai tu dien']),
    MascotActionDef('understand_ai_coach', MascotActionGroup.tool, 'Hỏi AI',
        ['hoi ai', 'tro ly hieu bai', 'ai coach', 'coach']),
    MascotActionDef(
        'youglish', MascotActionGroup.tool, 'YouGlish', ['youglish']),
    MascotActionDef('learn_by_heart', MascotActionGroup.tool, 'Thuộc lòng',
        ['thuoc long', 'hoc thuoc long', 'learn by heart', 'kinh phap cu']),
    MascotActionDef('review', MascotActionGroup.tool, 'Ôn lại',
        ['on lai', 'on tap', 'review', 'on tu']),
    MascotActionDef('word_list', MascotActionGroup.tool, 'Danh sách từ',
        ['danh sach tu', 'word list', 'wordlist', 'tu vung']),
    MascotActionDef('sound_list', MascotActionGroup.tool, 'Âm mục',
        ['am muc', 'sound list', 'muc luc am thanh']),
    MascotActionDef('timeline', MascotActionGroup.tool, 'Timeline',
        ['timeline', 'dong thoi gian']),
    MascotActionDef('wordlist_stats', MascotActionGroup.tool,
        'Thống kê danh sách từ',
        ['wordlist stats', 'thong ke danh sach tu', 'thong ke tu']),
    MascotActionDef('stats', MascotActionGroup.tool, 'Tổng quan',
        ['thong ke', 'tong quan', 'stats', 'bao cao']),
    MascotActionDef(
        'word_map', MascotActionGroup.tool, 'Bản đồ từ', ['word map', 'ban do tu']),
    MascotActionDef(
        'triangle', MascotActionGroup.tool, 'Tam giác', ['triangle', 'tam giac']),
    MascotActionDef('venn', MascotActionGroup.tool, 'Venn', ['venn']),

    // ── Playback (kế thừa 8 intent voice_command — P0 chưa nối) ─
    MascotActionDef('playback_play', MascotActionGroup.playback, 'Phát',
        ['phat', 'choi', 'play', 'tiep tuc', 'bat dau']),
    MascotActionDef('playback_pause', MascotActionGroup.playback, 'Tạm dừng',
        ['tam dung', 'dung', 'pause', 'ngung']),
    MascotActionDef('playback_next', MascotActionGroup.playback, 'Tiếp theo',
        ['tiep theo', 'tai tiep', 'bai tiep', 'next', 'tiep']),
    MascotActionDef('playback_previous', MascotActionGroup.playback,
        'Bài trước', ['bai truoc', 'truoc', 'previous', 'quay lai', 'lui']),
    MascotActionDef('playback_faster', MascotActionGroup.playback, 'Nhanh hơn',
        ['nhanh hon', 'tang toc', 'faster']),
    MascotActionDef('playback_slower', MascotActionGroup.playback, 'Chậm hơn',
        ['cham hon', 'giam toc', 'slower']),
    MascotActionDef('playback_toggle_lyrics', MascotActionGroup.playback,
        'Hiện/ẩn lời', ['hien loi', 'an loi', 'lyrics']),
    MascotActionDef('playback_translate', MascotActionGroup.playback, 'Dịch',
        ['dich', 'translate']),
  ];

  static final Map<String, MascotActionDef> _byId = {
    for (final action in actions) action.id: action,
  };

  /// Tra hành động theo id — null nếu chưa đăng ký.
  static MascotActionDef? byId(String id) => _byId[id];

  /// So khớp lệnh (chữ hoặc giọng đã STT) với registry.
  ///
  /// Điểm: exact = 100 · bắt đầu bằng = 80+ · chứa = 60+ (từ khoá dài hơn
  /// được điểm cao hơn vì cụ thể hơn). Đồng điểm giữ thứ tự khai báo.
  static List<MascotActionMatch> matchCommands(
    String rawInput, {
    int limit = 6,
  }) {
    final text = mascotNormalizeCommand(rawInput);
    if (text.isEmpty) return const <MascotActionMatch>[];

    final scored = <int, double>{};
    for (var i = 0; i < actions.length; i++) {
      final def = actions[i];
      var best = 0.0;
      for (final keyword in def.keywords) {
        if (text == keyword) {
          best = math.max(best, 100.0);
        } else if (text.startsWith('${keyword} ') || text.startsWith(keyword)) {
          // «bắt đầu bằng» vẫn cộng độ dài từ khoá: 'on tap' cụ thể hơn 'on'.
          best = math.max(best, 80.0 + keyword.length * 0.5);
        } else if (text.contains(keyword)) {
          best = math.max(best, 60.0 + keyword.length * 0.5);
        }
      }
      if (best > 0) scored[i] = best;
    }

    final order = scored.keys.toList()
      ..sort((a, b) {
        final byScore = scored[b]!.compareTo(scored[a]!);
        if (byScore != 0) return byScore;
        return a.compareTo(b);
      });

    return [
      for (final i in order.take(limit))
        MascotActionMatch(actions[i], scored[i]!),
    ];
  }
}
