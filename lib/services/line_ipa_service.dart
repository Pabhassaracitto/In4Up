// lib/services/line_ipa_service.dart
//
// Tạo dòng phiên âm IPA xếp chồng dưới dòng văn bản trong Read Mode.
//
// Pipeline tái dùng có sẵn: CMU Dict (EN, chính xác) → G2P rules (fallback).
// Service KHÔNG tự init — [TextProvider] ensure engine khi user bật chế độ,
// rồi clear cache để các dòng đã cache chất lượng thấp được dựng lại.
//
// READ-IPA-003 (P3): kết quả tính theo [IpaSegment] — mỗi token thô 1 segment
// (surface giữ nguyên để dựng interlinear word-chip; wordCore = lõi ASCII để
// tra IPA; phonemes để P4 tô màu). [buildLineIpa] là view phẳng join các
// segment — GIỮ NGUYÊN hợp đồng P1 (test/line_ipa_service_test.dart).
//
// Quy tắc eligibility của một dòng:
//   1. Tách dòng theo whitespace.
//   2. Mỗi token: bỏ ký tự không-phải-chữ ở 2 đầu (dấu câu, số bám ngoài).
//   3. Token rỗng sau khi bỏ (toàn dấu câu / số) → segment render-only,
//      không tính là từ, không tra IPA.
//   4. Core khớp `^[A-Za-z][A-Za-z']*$` → từ Anh, tra IPA bình thường.
//   5. Core KHÔNG khớp (từ ngoại có dấu như `cetanā`/chữ Việt, hoặc dính
//      dấu câu như `consciousness.If`, `wholesome(kusa`) → KHÔNG bỏ cả dòng
//      (READ-IPA-006 mục 1): tách token theo run chữ/glue — phần con khớp
//      ASCII thành từ (có IPA), phần còn lại (dấu câu / số / từ ngoại) là
//      segment render-only (skip, không tra IPA).
//   6. Nếu dòng không có từ ASCII nào → null (chặn dòng thuần Việt/Pali).
//
// Từ hợp lệ → list phoneme của resolver → join `''`
// (stress nằm trong phoneme, vd `wˈɝld` — KHÔNG dùng `ipaString`
// vì nó join bằng dấu chấm cho UI shadowing).
//
// Cache theo đúng content dòng (kể cả null), cap [_maxCache] entry —
// tràn thì clear-all (dòng cũ sẽ được tính lại khi cần).
import 'package:flutter/foundation.dart';

import '../features/shadowing/services/phoneme_analyzer.dart';

/// 1 token của dòng khi hiển thị IPA (READ-IPA-003).
///
/// [surface] = token thô (giữ dấu câu bám ngoài, vd `Hello,`).
/// [wordCore] = lõi sau khi strip ký tự biên — rỗng ⇔ token render-only
/// (dấu câu / số đứng riêng).
/// [ipa] = phiên âm joined `''` của wordCore — null nếu resolver trống.
/// [phonemes] = phoneme từng bước (P4 tô màu); override seam trả về 1 blob.
class IpaSegment {
  final String surface;
  final String wordCore;
  final String? ipa;
  final List<String> phonemes;

  const IpaSegment({
    required this.surface,
    required this.wordCore,
    this.ipa,
    this.phonemes = const [],
  });

  bool get isWord => wordCore.isNotEmpty;
  bool get hasIpa => ipa != null && ipa!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IpaSegment &&
          other.surface == surface &&
          other.wordCore == wordCore &&
          other.ipa == ipa &&
          listEquals(other.phonemes, phonemes);

  @override
  int get hashCode =>
      Object.hash(surface, wordCore, ipa, Object.hashAll(phonemes));

  @override
  String toString() =>
      'IpaSegment($surface, core=$wordCore, ipa=$ipa)';
}

class LineIpaService {
  LineIpaService._();

  static final Map<String, List<IpaSegment>?> _cache = {};
  static const int _maxCache = 600;

  /// Seam test: thay pipeline PhonemeAnalyzer bằng fake
  /// (trả về IPA đã join `''`, hoặc null/rỗng nếu không có IPA).
  static String? Function(String word)? wordIpaOverride;

  /// Chỉ chữ Latin + apostrophe, bắt đầu bằng chữ cái.
  static final RegExp _asciiWord = RegExp(r"^[A-Za-z][A-Za-z']*$");

  /// Grep run chữ liên tiếp trong token — dùng để tách dấu câu dính
  /// (`consciousness.If`) và từ ngoại chèn cùng token (`wholesome(kusa`),
  /// `(cetanā)`). Quét trên raw để giữ đúng offset khi cần nối ngữ cảnh ngoặc.
  static final RegExp _letterRun = RegExp(r'\p{L}+', unicode: true);

  /// Bỏ ký tự không phải chữ (letter Unicode) ở 2 đầu token.
  /// Giữ nguyên chữ có dấu để detect ≠ bỏ sót chữ Việt/Pali.
  static final RegExp _edgeNonLetter =
      RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true);

  /// Segments cho dòng [content] — null nếu dòng không đủ điều kiện.
  /// Dùng cho interlinear (dòng active) + tô màu phoneme (P4).
  static List<IpaSegment>? buildLineIpaSegments(String content) {
    if (_cache.containsKey(content)) return _cache[content];
    final result = _computeSegments(content);
    if (_cache.length >= _maxCache) _cache.clear();
    _cache[content] = result;
    return result;
  }

  /// Dòng IPA phẳng (view P1) cho [content], null nếu không đủ điều kiện.
  static String? buildLineIpa(String content) =>
      flatIpa(buildLineIpaSegments(content));

  /// Join IPA của các segment bằng space — null nếu không có IPA nào
  /// (segment không có từ / mọi từ đều trống resolver).
  static String? flatIpa(List<IpaSegment>? segments) {
    if (segments == null) return null;
    final parts = <String>[];
    for (final s in segments) {
      if (s.ipa == null || s.ipa!.isEmpty) continue;
      parts.add(s.ipa!);
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  /// Xóa toàn bộ cache — gọi sau khi CMU Dictionary finishes loading
  /// (entry cache trước đó có thể đã fallthrough sang G2P chất lượng thấp).
  static void clearCache() => _cache.clear();

  /// Số entry đang cache (cho test).
  static int get cacheSize => _cache.length;

  static List<IpaSegment>? _computeSegments(String content) {
    // Phase 1 — thu thập token + eligibility.
    // Từ Anh hợp lệ (ASCII) tách riêng 1 segment; token dính dấu câu / chữ
    // ngoại không còn bỏ CẢ DÒNG — tách theo run chữ để giữ phần Anh có IPA
    // và skip phần còn lại. Chỉ dòng KHÔNG có từ Anh nào mới trả null.
    final raws = <String>[];
    final cores = <String>[];
    var hasWord = false;
    // Độ sâu ngoặc `(` chưa đóng tính từ đầu dòng — chú giải Pali thường
    // bọc ngoặc và có thể TRẢI QUA nhiều token (`wholesome(kusa la),`).
    var parenDepth = 0;
    for (final raw in content.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final core = raw.replaceAll(_edgeNonLetter, '');
      if (core.isEmpty) {
        // Token toàn dấu câu / số → render-only, không tra IPA.
        raws.add(raw);
        cores.add('');
        parenDepth = _updateParenDepth(raw, parenDepth);
        continue;
      }
      // Từ Anh sạch → segment từ. Trừ khi token TỰ MỞ ngoặc chưa đóng
      // (`(kusa` mở chú giải Pali trải dài sang token sau) → chuyển xuống
      // split để run trong ngoặc bị skip thay vì bị tra IPA sai.
      final opensParen = _opensParen(raw);
      if (_asciiWord.hasMatch(core) && parenDepth == 0 && !opensParen) {
        raws.add(raw);
        cores.add(core);
        hasWord = true;
      } else {
        // Core không-ASCII (dính dấu câu / chữ ngoại có dấu), nằm trong
        // chú giải ngoặc, hoặc tự mở ngoặc → tách run chữ: run Anh thành từ
        // (có IPA), phần còn lại là segment skip (KHÔNG bỏ cả dòng —
        // READ-IPA-006 mục 1).
        hasWord = _appendSplitToken(raw, parenDepth, raws, cores) || hasWord;
      }
      parenDepth = _updateParenDepth(raw, parenDepth);
    }
    if (!hasWord) return null;

    // Phase 2 — resolve IPA từng từ (từ không có phoneme → ipa null,
    // vẫn giữ segment để dựng interlinear; view phẳng sẽ bỏ qua).
    final override = wordIpaOverride;
    final out = <IpaSegment>[];
    for (var i = 0; i < raws.length; i++) {
      final core = cores[i];
      if (core.isEmpty) {
        out.add(IpaSegment(surface: raws[i], wordCore: ''));
        continue;
      }
      String? ipa;
      var phonemes = const <String>[];
      if (override != null) {
        ipa = override(core);
        phonemes =
            (ipa == null || ipa.isEmpty) ? const <String>[] : [ipa];
      } else {
        final r = PhonemeAnalyzer.getPhonemes(core);
        phonemes = r.phonemes;
        ipa = phonemes.join('');
      }
      out.add(IpaSegment(
        surface: raws[i],
        wordCore: core,
        ipa: ipa,
        phonemes: phonemes,
      ));
    }
    return out;
  }

  /// Tách 1 token cần skip/bỏ phần lạ (dính dấu câu như `consciousness.If`,
  /// hoặc chứa từ ngoại có dấu/trong chú giải như `wholesome(kusa`):
  ///  - Có ≥1 run chữ khớp `_asciiWord` và KHÔNG nằm trong chú giải ngoặc
  ///    `(...)` kỳ lạ → mỗi run như vậy là 1 segment TỪ (sẽ tra IPA).
  ///  - Run còn lại (dấu câu/số; từ ngoại có dấu; phần trong ngoặc Pali
  ///    `kusa`, `la`) → segment skip: surface giữ nguyên, không tra IPA.
  ///  - Không có run ASCII hợp lệ nào (toàn từ ngoại có dấu, vd `cetanā`;
  ///    hoặc nguyên token nằm trọn trong chú giải) → giữ NGUYÊN token làm
  ///    segment surface-only (Gemini: "return the token itself") — interlinear
  ///    render nguyên văn, view phẳng bỏ qua.
  ///
  /// Dấu câu dính GIỮA run (`consciousness.If`) → giữ làm segment surface-only
  /// (render nguyên văn ở interlinear), KHÔNG lọt vào view IPA phẳng — nhất
  /// quán hợp đồng P1 hiện tại "dấu câu bám quanh từ bị bỏ khỏi dòng IPA".
  ///
  /// [parenDepth] = độ sâu ngoặc `(` chưa đóng TRƯỚC token này; run chữ nằm
  /// trong độ sâu > 0 (hoặc giữa `(` và `)` trong cùng token) được coi là
  /// chú giải ngoại → surface-only.
  ///
  /// Trả về true nếu có ≥1 segment từ; false nếu toàn skip.
  static bool _appendSplitToken(
    String raw,
    int parenDepth,
    List<String> raws,
    List<String> cores,
  ) {
    final runs = _letterRun.allMatches(raw).toList(growable: false);
    if (runs.isEmpty) {
      raws.add(raw);
      cores.add('');
      return false;
    }

    // Phân loại TỪNG run chữ theo ngữ cảnh ngoặc (depth từ [parenDepth],
    // kết ngoặc đứng trước run trong raw). Run ASCII ngoài ngoặc → từ.
    final wordRun = <bool>[];
    var anyWord = false;
    for (final m in runs) {
      final before = raw.substring(0, m.start);
      var depth = parenDepth;
      for (final c in before.split('')) {
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          if (depth > 0) depth--;
        }
      }
      final isWord = depth == 0 && _asciiWord.hasMatch(m.group(0)!);
      wordRun.add(isWord);
      anyWord = anyWord || isWord;
    }

    if (!anyWord) {
      // Không run Anh hợp lệ (toàn từ ngoại có dấu / trong chú giải) →
      // giữ NGUYÊN token làm segment surface-only (return the token itself),
      // KHÔNG tra IPA.
      raws.add(raw);
      cores.add('');
      return false;
    }

    // Duyệt raw theo run: run từ → segment từ (có IPA); glue dính + run
    // ngoại/dấu → segment skip (surface giữ nguyên, flat view bỏ qua).
    final buffer = StringBuffer();
    var pos = 0;
    var addedWord = false;

    void flushNonWord() {
      if (buffer.isEmpty) return;
      raws.add(buffer.toString());
      cores.add('');
      buffer.clear();
    }

    for (var i = 0; i < runs.length; i++) {
      final m = runs[i];
      buffer.write(raw.substring(pos, m.start));
      if (wordRun[i]) {
        flushNonWord();
        raws.add(m.group(0)!);
        cores.add(m.group(0)!);
        addedWord = true;
      } else {
        buffer.write(m.group(0));
      }
      pos = m.end;
    }
    buffer.write(raw.substring(pos));
    flushNonWord();

    return addedWord;
  }

  /// Cập nhật độ sâu ngoặc sau khi duyệt xong 1 token (đếm ( và )).
  static int _updateParenDepth(String raw, int depth) {
    var d = depth;
    for (final c in raw.split('')) {
      if (c == '(') {
        d++;
      } else if (c == ')') {
        if (d > 0) d--;
      }
    }
    return d;
  }

  /// Token có mở ngoặc `(` nhiều hơn đóng `)` không (nguyên văn, kể cả dấu
  /// câu đã bị edge-strip). Dùng để nhận diện chú giải Pali bắt đầu gắn liền
  /// vào từ (`wholesome(kusa` — mở nhưng chưa đóng đến hết token).
  static bool _opensParen(String raw) {
    var d = 0;
    for (final c in raw.split('')) {
      if (c == '(') {
        d++;
      } else if (c == ')') {
        if (d > 0) d--;
      }
    }
    return d > 0;
  }
}
