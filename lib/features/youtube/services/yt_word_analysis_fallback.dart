// YT-AUDIT-05 (IN4-105) — Hậu phương cho tab GIẢI THÍCH khi AI không trả được.
//
// Triệu chứng owner báo (2026-10-20):
//   "Tab GIẢI THÍCH hiện 'AI chưa phân tích được - No local dict entry and
//    engine not ready'", và KHÔNG CÓ phần nào trong 7 phần cần có:
//    tóm tắt · mẹo nhớ · ngữ pháp · ví dụ trong ngữ cảnh · hình ảnh gợi nhớ ·
//    câu chuyện ghi nhớ (+ phiên âm).
//
// Ba việc của file này (THUẦN LOGIC, không Flutter, không mạng ⇒ test được):
//   1. Dựng `localDictEntry` ĐẦY ĐỦ gửi cho facade. Bản cũ chỉ gửi `meaning`
//      ⇒ khi offline dict không có từ đó, `localDictEntry == null` ⇒ facade rớt
//      thẳng vào nhánh "No local dict entry" dù ta VẪN CÓ nghĩa từ MDX và câu
//      ngữ cảnh.
//   2. Chọn nghĩa tốt nhất trong số nguồn offline (từ điển nhanh → MDX).
//   3. Liệt kê ĐÚNG những phần THẬT SỰ THIẾU để báo trung thực, thay vì hiện
//      một câu lỗi chung chung rồi để trắng.
//
// KHÔNG bịa nội dung: ngữ pháp / mẹo nhớ / hình ảnh / câu chuyện là thứ chỉ AI
// (hoặc người) làm được. Đoán bằng regex trên một câu bất kỳ sẽ SAI và dạy sai
// người học — thà báo "phần này cần AI" còn hơn.

import 'package:in4up_ai/in4up_ai.dart';

/// Khoá của 7 phần mà tab GIẢI THÍCH cần có (dùng cho [missingSections]).
class YtWordSection {
  static const String summary = 'summary';
  static const String memoryHook = 'memoryHook';
  static const String grammar = 'grammar';
  static const String examples = 'examples';
  static const String visual = 'visual';
  static const String pao = 'pao';

  const YtWordSection._();
}

class YtWordAnalysisFallback {
  YtWordAnalysisFallback._();

  /// Khoá `meaning` trong bản đồ gửi cho facade (`AiServiceFacade.lookupWord`).
  static const String kMeaning = 'meaning';

  /// Khoá `phonetic` — facade dùng để enrich khi AI không trả phiên âm.
  static const String kPhonetic = 'phonetic';

  /// Khoá `example` — CÂU NGỮ CẢNH (câu phụ đề đang phát). Đây là thứ quý nhất
  /// ta có sẵn mà không cần AI: chính là câu chứa từ người dùng vừa bấm.
  static const String kExample = 'example';

  /// Khoá `word_type` — facade đọc cả `word_type` lẫn `wordType`.
  static const String kWordType = 'word_type';

  /// Dựng bản đồ nghĩa địa phương gửi cho facade.
  ///
  /// Trả `null` khi **không có nghĩa** — khi đó facade trả mã lỗi
  /// `local_dict_missing` và UI hiện đúng thông báo đã dịch. Cố gửi một bản đồ
  /// rỗng sẽ làm facade trả `success: true` với nội dung trống ⇒ UI tưởng AI đã
  /// xong ⇒ tệ hơn nhiều so với báo lỗi.
  static Map<String, dynamic>? buildLocalDictEntry({
    String? meaning,
    String? phonetic,
    String? example,
    String? wordType,
  }) {
    final m = meaning?.trim() ?? '';
    if (m.isEmpty) return null;
    final out = <String, dynamic>{kMeaning: m};
    final p = phonetic?.trim() ?? '';
    if (p.isNotEmpty) out[kPhonetic] = p;
    final e = example?.trim() ?? '';
    if (e.isNotEmpty) out[kExample] = e;
    final t = wordType?.trim() ?? '';
    if (t.isNotEmpty) out[kWordType] = t;
    return out;
  }

  /// Nghĩa tốt nhất hiện có (từ điển offline nhanh trước, rồi tới MDX).
  ///
  /// Cắt bớt định nghĩa MDX quá dài vì nó đi thẳng vào `summary` của AI.
  static String? pickMeaning({
    String? offline,
    List<String> mdxDefinitions = const <String>[],
    int maxLen = 160,
  }) {
    final o = offline?.trim() ?? '';
    if (o.isNotEmpty) return _cap(o, maxLen);
    for (final d in mdxDefinitions) {
      final t = d.trim();
      if (t.isNotEmpty) return _cap(t, maxLen);
    }
    return null;
  }

  static String _cap(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen).trimRight()}…';
  }

  /// Những phần CHƯA CÓ trong kết quả (để báo trung thực, không im lặng).
  ///
  /// `null` ⇒ chưa có kết quả nào ⇒ mọi phần đều thiếu.
  static List<String> missingSections(AiAnalysis? a) {
    if (a == null) {
      return const <String>[
        YtWordSection.summary,
        YtWordSection.memoryHook,
        YtWordSection.grammar,
        YtWordSection.examples,
        YtWordSection.visual,
        YtWordSection.pao,
      ];
    }
    final missing = <String>[];
    if (a.summary.trim().isEmpty) missing.add(YtWordSection.summary);
    if ((a.wordDetail?.memoryHook ?? '').trim().isEmpty) {
      missing.add(YtWordSection.memoryHook);
    }
    if (a.grammar == null) missing.add(YtWordSection.grammar);
    if (a.contextExamples.isEmpty) missing.add(YtWordSection.examples);
    if ((a.visualPrompt ?? '').trim().isEmpty) missing.add(YtWordSection.visual);
    if (a.paoSuggestions.isEmpty) missing.add(YtWordSection.pao);
    return missing;
  }

  /// Có phần nội dung AI THẬT không (để quyết định hiện hay giấu ô "cần AI").
  static bool hasAnyAiDepth(AiAnalysis? a) =>
      a != null && missingSections(a).length < 6;

  /// Chuẩn hoá thông báo lỗi thô về mã máy (ủy quyền cho package `in4up_ai`).
  static String errorCode(String? raw) => aiErrorCode(raw);
}
