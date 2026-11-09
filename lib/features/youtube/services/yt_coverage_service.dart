// YT-LEVEL-001 (#YT1-01 owner 2026-11-09) — "Cấp độ từ vựng" của một VIDEO.
//
// BỐI CẢNH: thanh trượt "Cấp độ từ vựng" ở Explorer trước đây là **điều khiển
// giả** — `_rankMin/_rankMax` chỉ được vẽ ra, `_loadVideos` không đọc, và
// `YtExVideo.langRank` không bao giờ được gán. Tệ hơn: `langRank` trong player
// cũng KHÔNG phải tần suất thật mà là số thứ tự từ trong dòng
// (`rank = 100; rank += 40`), trong khi `YtLearningSettings.isEasy()` lại so nó
// với ngưỡng 300 ⇒ toàn bộ "từ dễ / đã quen" đang dựa trên dữ liệu bịa.
//
// Vì app KHÔNG có bảng tần suất từ (không có asset, không có API), thước đo
// trung thực và rẻ nhất là **độ phủ từ đã biết**:
//
//     cấp độ = (số từ NỘI DUNG người dùng đã biết) / (tổng số từ nội dung)
//
// Nó trả lời đúng câu người học hỏi — "video này có vừa sức tôi không?" — thay
// vì một con số tần suất trừu tượng. Chi phí băng thông: **0 byte** khi video đã
// có phụ đề trên máy; chỉ khi người dùng bấm "Phân tích cả trang" mới tải phụ
// đề (~20–60 KB/video, xem `analyzeByDownloading`).
//
// Phụ đề tải về được LƯU LẠI vào `YtMediaStore` (quyết định (c): cache có dung
// lượng, hiện được, xoá được, dùng lại được ở tab Đọc) chứ không tải rồi vứt.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:in4up_core/vocab_level_difficulty.dart';

import '../../../models/word_entry.dart' show WordEntry;
import '../../../providers/vocabulary_bridge.dart';
import '../models/yt_video.dart' show YtCaptionLine;
import 'yt_media_store.dart';
import 'yt_service.dart';

/// Kết quả đo một video.
class YtVideoCoverage {
  const YtVideoCoverage({
    required this.videoId,
    required this.known,
    required this.tokens,
    required this.at,
  });

  final String videoId;

  /// Số từ nội dung người dùng đã biết / tổng số từ nội dung.
  final int known;
  final int tokens;

  /// Lúc đo — để UI nói "đo 3 ngày trước".
  final DateTime at;

  /// 0..1. `tokens == 0` ⇒ 0 (không có gì để đo).
  double get ratio => tokens == 0 ? 0 : known / tokens;

  int get percent => (ratio * 100).round();

  /// Nhóm để lọc trong danh sách. Ngưỡng chọn theo kinh nghiệm đọc hiểu:
  /// ≥ 95% đọc trôi chảy; 85–95% còn phải tra vài từ; dưới 85% là "thử thách".
  YtCoverageBand get band {
    if (tokens == 0) return YtCoverageBand.unknown;
    if (ratio >= 0.95) return YtCoverageBand.easy;
    if (ratio >= 0.85) return YtCoverageBand.fair;
    return YtCoverageBand.hard;
  }

  Map<String, dynamic> toJson() => {
        'v': videoId,
        'k': known,
        't': tokens,
        'at': at.millisecondsSinceEpoch,
      };

  static YtVideoCoverage? fromJson(Map<String, dynamic> j) {
    final id = (j['v'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;
    return YtVideoCoverage(
      videoId: id,
      known: (j['k'] as num?)?.toInt() ?? 0,
      tokens: (j['t'] as num?)?.toInt() ?? 0,
      at: DateTime.fromMillisecondsSinceEpoch(
          (j['at'] as num?)?.toInt() ?? 0),
    );
  }
}

/// Nhóm cấp độ dùng cho bộ lọc — tách khỏi UI để test được.
enum YtCoverageBand { easy, fair, hard, unknown }

class YtCoverageService {
  YtCoverageService._();
  static final YtCoverageService instance = YtCoverageService._();

  static const String _boxName = 'yt_coverage';

  final Map<String, YtVideoCoverage> _cache = {};

  /// Đọc lại từ Hive (nhỏ: mỗi video ~60 byte). Gọi 1 lần khi mở Explorer.
  Future<void> ensureLoaded() async {
    if (_cache.isNotEmpty) return;
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<String>(_boxName);
      }
      final box = Hive.box<String>(_boxName);
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw == null) continue;
        try {
          final c = YtVideoCoverage.fromJson(
              jsonDecode(raw) as Map<String, dynamic>);
          if (c != null) _cache[c.videoId] = c;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[in4up-yt] coverage load failed: $e');
    }
  }

  YtVideoCoverage? of(String videoId) => _cache[videoId.trim()];

  Map<String, YtVideoCoverage> get all => Map.unmodifiable(_cache);

  Future<void> _persist(YtVideoCoverage c) async {
    _cache[c.videoId] = c;
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<String>(_boxName);
      }
      await Hive.box<String>(_boxName)
          .put(c.videoId, jsonEncode(c.toJson()));
    } catch (e) {
      debugPrint('[in4up-yt] coverage save failed: $e');
    }
  }

  /// Xoá số đo (khi người dùng xoá phụ đề hoặc muốn đo lại).
  Future<void> forget(String videoId) async {
    _cache.remove(videoId);
    try {
      if (Hive.isBoxOpen(_boxName)) {
        await Hive.box<String>(_boxName).delete(videoId);
      }
    } catch (_) {}
  }

  // ─── Đo ─────────────────────────────────────────────────────────────

  /// Đo từ **phụ đề đã có trên máy**. Trả `null` nếu video chưa có phụ đề.
  ///
  /// Không chạm mạng, không ghi gì thêm — chỉ đọc file `.lrc`. Đây là đường
  /// chính (quyết định của owner: "chỉ tính video đã có phụ đề trên máy").
  Future<YtVideoCoverage?> analyzeLocal(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) return null;
    try {
      final text = await readLocalCaptionText(id);
      if (text == null || text.trim().isEmpty) return null;
      final c = computeCoverage(id: id, rawCaptionText: text);
      if (c == null) return null;
      await _persist(c);
      return c;
    } catch (e) {
      debugPrint('[in4up-yt] coverage local failed: $e');
      return null;
    }
  }

  /// `videoId → đường dẫn .lrc` — quét thư mục media 1 lần thay vì mỗi video
  /// một lần (đo cả trang 30 video = 30 lần đọc thư mục nếu không cache).
  Map<String, String>? _lrcIndex;

  /// Dựng lại chỉ mục phụ đề cục bộ. Gọi trước khi đo cả loạt.
  Future<void> primeLocalIndex() async {
    try {
      final items = await YtMediaStore.list();
      _lrcIndex = {
        for (final it in items)
          if (it.lrcPath != null) it.videoId: it.lrcPath!,
      };
    } catch (e) {
      debugPrint('[in4up-yt] coverage index failed: $e');
      _lrcIndex = {};
    }
  }

  /// Đọc chữ phụ đề đã lưu của [videoId] (`.lrc`), đã bỏ mốc thời gian.
  Future<String?> readLocalCaptionText(String videoId) async {
    _lrcIndex ??= await _buildIndex();
    final path = _lrcIndex![videoId];
    if (path == null) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    return await f.readAsString();
  }

  Future<Map<String, String>> _buildIndex() async {
    try {
      final items = await YtMediaStore.list();
      return {
        for (final it in items)
          if (it.lrcPath != null) it.videoId: it.lrcPath!,
      };
    } catch (_) {
      return {};
    }
  }

  /// Tải phụ đề (nếu chưa có) rồi đo — dùng cho nút "Phân tích cả trang".
  ///
  /// `save: true` ⇒ lưu `.lrc` vào `YtMediaStore` để đọc lại/đưa sang tab Đọc;
  /// quyết định (c) của owner: cache có dung lượng, hiện và xoá được.
  /// Trả `null` khi video không có phụ đề ngôn ngữ đó hoặc mạng lỗi.
  Future<YtVideoCoverage?> analyzeByDownloading(
    String videoId, {
    String lang = 'en',
    bool save = true,
  }) async {
    final id = videoId.trim();
    if (id.isEmpty) return null;

    // Đã có sẵn trên máy thì không tải lại (0 byte).
    final local = await analyzeLocal(id);
    if (local != null) return local;

    try {
      final lines = await YtService.instance.fetchCaptions(id, lang: lang);
      if (lines.isEmpty) return null;
      if (save) {
        await YtMediaStore.saveLrc(
          videoId: id,
          content: lines.map((YtCaptionLine l) => l.toLrc()).join('\n'),
        );
      }
      final text = lines.map((l) => l.text).join('\n');
      final c = computeCoverage(id: id, rawCaptionText: text);
      if (c == null) return null;
      await _persist(c);
      return c;
    } catch (e) {
      debugPrint('[in4up-yt] coverage download failed: $e');
      return null;
    }
  }

  // ─── Tính (thuần, test được) ────────────────────────────────────────

  /// Tính độ phủ từ từ **chữ phụ đề thô** (có hay không có mốc LRC đều được —
  /// mốc `[mm:ss.xx]` bị bỏ trước khi tách từ).
  ///
  /// Tách từ bằng regex chứ KHÔNG dùng `SyntaxHighlighterService`: service đó
  /// cần Flutter binding + chậm hơn nhiều với 2–3 nghìn dòng, trong khi ở đây
  /// chỉ cần "từ nội dung". Hệ quả: viết tắt/ghép (`don't`, `well-known`) được
  /// giữ nguyên nhờ `['’-]` trong lớp ký tự.
  YtVideoCoverage? computeCoverage({
    required String id,
    required String rawCaptionText,
  }) {
    final tokens = contentTokens(rawCaptionText);
    if (tokens.isEmpty) {
      return YtVideoCoverage(
        videoId: id,
        known: 0,
        tokens: 0,
        at: DateTime.now(),
      );
    }
    var known = 0;
    for (final t in tokens) {
      if (isKnownWord(t)) known++;
    }
    return YtVideoCoverage(
      videoId: id,
      known: known,
      tokens: tokens.length,
      at: DateTime.now(),
    );
  }

  /// Từ "nội dung" của phụ đề: bỏ mốc thời gian, bỏ từ chức năng, bỏ số.
  ///
  /// Giữ thứ tự để test dễ so sánh; trùng lặp vẫn được giữ vì độ phủ phải tính
  /// theo **lượt xuất hiện** (một video lặp "the" 200 lần không được kéo điểm).
  List<String> contentTokens(String raw) {
    final noTags = raw
        // Mốc LRC: [12:34.56] — bỏ hẳn.
        .replaceAll(RegExp(r'\[\d{1,3}:\d{2}(?:\.\d{1,3})?\]'), ' ')
        // Nhãn dòng thời gian kiểu SRT.
        .replaceAll(RegExp(r'\d{2}:\d{2}:\d{2}[,.]\d{3}'), ' ')
        // Thẻ định dạng của timedtext.
        .replaceAll(RegExp(r'<[^>]{0,40}>'), ' ');
    final matches = RegExp(r"[A-Za-zÀ-ỹ][A-Za-zÀ-ỹ'’\-]*").allMatches(noTags);
    final out = <String>[];
    for (final m in matches) {
      final w = m.group(0)!.toLowerCase();
      if (w.length < 2) continue;
      if (_kFunctionWords.contains(w)) continue;
      out.add(w);
    }
    return out;
  }

  /// Người dùng đã biết từ này chưa?
  ///
  /// Ba nguồn, theo thứ tự rẻ → đắt:
  ///  1. Từ đã có trong Từ vựng (`VocabularyBridge.hasWord`);
  ///  2. Từ được đánh dấu **Dễ** ở pop tra từ / khay màu YouTube
  ///     (`userDifficulty == easy`) — gồm cả dữ liệu PR #142 ghi sang;
  ///  3. Từ được ghi nghĩa ở tab Đọc (`WordEntry.meaning` khác rỗng) — coi như
  ///     đã từng tra và hiểu.
  bool isKnownWord(String word) {
    final w = word.trim().toLowerCase();
    if (w.isEmpty) return false;
    try {
      if (!VocabularyBridge.isReady) return false;
      final entry = VocabularyBridge.findByWord(w);
      return _isKnownEntry(entry);
    } catch (_) {
      return false;
    }
  }

  bool _isKnownEntry(WordEntry? e) {
    if (e == null) return false;
    if (e.userDifficulty == DifficultyLevel.easy) return true;
    if ((e.meaning).trim().isNotEmpty) return true;
    // Có mặt trong Từ vựng nghĩa là người dùng đã lưu/chủ động thêm ⇒ tính là
    // biết. (Từ "đang học" khó phân biệt ở đây; `addContextual` của YouTube
    // thêm khi bấm "Đang học" nên vẫn tính — chấp nhận sai số ~vài %.)
    return true;
  }

  /// Từ chức năng (không mang nghĩa) — không tính vào "từ nội dung".
  ///
  /// Danh sách cố ý NGẮN và chỉ tiếng Anh: đây là bộ gợi ý cho 7 kênh mặc định
  /// (đều tiếng Anh). Ngôn ngữ khác: hàm vẫn chạy, chỉ là tỉ lệ thấp hơn thực
  /// tế một chút vì không lọc được từ chức năng.
  static const Set<String> _kFunctionWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'if', 'then', 'than', 'so', 'as',
    'of', 'to', 'in', 'on', 'at', 'by', 'for', 'from', 'with', 'without',
    'about', 'into', 'onto', 'over', 'under', 'after', 'before', 'between',
    'through', 'during', 'up', 'down', 'out', 'off', 'again', 'further',
    'is', 'am', 'are', 'was', 'were', 'be', 'been', 'being', 'do', 'does',
    'did', 'doing', 'have', 'has', 'had', 'having', 'will', 'would', 'shall',
    'should', 'can', 'could', 'may', 'might', 'must', 'ought',
    'i', 'me', 'my', 'mine', 'myself', 'you', 'your', 'yours', 'yourself',
    'he', 'him', 'his', 'himself', 'she', 'her', 'hers', 'herself', 'it',
    'its', 'itself', 'we', 'us', 'our', 'ours', 'ourselves', 'they', 'them',
    'their', 'theirs', 'themselves', 'this', 'that', 'these', 'those',
    'who', 'whom', 'whose', 'which', 'what', 'when', 'where', 'why', 'how',
    'all', 'any', 'both', 'each', 'few', 'more', 'most', 'other', 'some',
    'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'too', 'very', 'just',
    'also', 'there', 'here', 'now', 'well', 'yes', 'ok', 'okay',
  };
}
